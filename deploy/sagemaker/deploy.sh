#!/usr/bin/env bash
# Reproducible deploy of the Rakshak risk model to a SageMaker real-time endpoint.
#
#   Profile : agent-toolkit          Region  : ap-south-1
#   Account : 468704514492           Endpoint: rakshak-risk-endpoint
#
# Prereqs: a venv with  xgboost==3.2.0 scikit-learn numpy pandas joblib
#          and the v2 artifacts from s3://rakshak-models-vishalganesan/ :
#             rakshak_chennai_model_v2.pkl
#             label_encoder_area_v2.pkl  label_encoder_neighborhood_v2.pkl
#             data/chennai_sos_enhanced_data_v2.csv   (-> chennai_v2.csv)
set -euo pipefail
cd "$(dirname "$0")"
export AWS_PROFILE=agent-toolkit AWS_REGION=ap-south-1
ACCT=468704514492
BUCKET=rakshak-models-vishalganesan
ROLE=arn:aws:iam::$ACCT:role/rakshak-sagemaker-role
IMAGE=720646828776.dkr.ecr.ap-south-1.amazonaws.com/sagemaker-xgboost:3.2-0
STAMP=$(date -u +%Y%m%d%H%M)
KEY=sagemaker/model-v2-$STAMP.tar.gz
MODEL=rakshak-risk-model-v2-$STAMP        # immutable — new name each run
CONFIG=rakshak-risk-endpoint-config-$STAMP
ENDPOINT=rakshak-risk-endpoint            # stable — updated in place

[ "$(aws sts get-caller-identity --query Account --output text)" = "$ACCT" ] || { echo "WRONG ACCOUNT"; exit 1; }

# 1. build + validate the artifact (writes pkg/, validation.json ; asserts booster==sklearn proba)
python build_model.py

# 2. package  model.json + model.pkl + code/inference.py
( cd pkg && tar czf ../model-v2.tar.gz model.pkl xgb_model.json booster.json code/inference.py )

# 3. upload
aws s3api put-object --bucket "$BUCKET" --key "$KEY" --body model-v2.tar.gz >/dev/null
echo "uploaded s3://$BUCKET/$KEY"

# 4. model  (script mode: SAGEMAKER_PROGRAM + SUBMIT_DIRECTORY point at code/inference.py)
aws sagemaker create-model --model-name "$MODEL" --execution-role-arn "$ROLE" \
  --primary-container "Image=$IMAGE,ModelDataUrl=s3://$BUCKET/$KEY,Environment={SAGEMAKER_PROGRAM=inference.py,SAGEMAKER_SUBMIT_DIRECTORY=/opt/ml/model/code,SAGEMAKER_CONTAINER_LOG_LEVEL=20}"

# 5. endpoint config  (real-time; ml.m5.large has ~7ms warm ModelLatency for this 300-tree model)
aws sagemaker create-endpoint-config --endpoint-config-name "$CONFIG" \
  --production-variants "VariantName=AllTraffic,ModelName=$MODEL,InstanceType=ml.m5.large,InitialInstanceCount=1,InitialVariantWeight=1.0"

# 6. endpoint  (create, or swap config if it already exists)
if aws sagemaker describe-endpoint --endpoint-name "$ENDPOINT" >/dev/null 2>&1; then
  aws sagemaker update-endpoint --endpoint-name "$ENDPOINT" --endpoint-config-name "$CONFIG"
else
  aws sagemaker create-endpoint --endpoint-name "$ENDPOINT" --endpoint-config-name "$CONFIG"
fi
aws sagemaker wait endpoint-in-service --endpoint-name "$ENDPOINT"

# 7. smoke test against 3 real rows
PAYLOAD=$(python -c "import json;v=json.load(open('validation.json'));print(json.dumps({'instances':v['sample_rows'][:3]}))")
aws sagemaker-runtime invoke-endpoint --endpoint-name "$ENDPOINT" \
  --content-type application/json --body "$PAYLOAD" --cli-binary-format raw-in-base64-out /dev/stdout
echo
echo "expected pred: $(python -c "import json;print(json.load(open('validation.json'))['expected_pred'][:3])")"

# teardown (post-demo):
#   aws sagemaker delete-endpoint        --endpoint-name $ENDPOINT
#   aws sagemaker delete-endpoint-config --endpoint-config-name $CONFIG
#   aws sagemaker delete-model           --model-name $MODEL
