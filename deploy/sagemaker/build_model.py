"""Build + validate the v2 SageMaker model artifact for rakshak-risk-endpoint."""
import json, os, joblib, numpy as np, pandas as pd, xgboost as xgb

D = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(D, "pkg")
os.makedirs(os.path.join(OUT, "code"), exist_ok=True)

FEATURES = ["latitude","longitude","pincode","hour","day_of_week","is_weekend",
            "is_night","is_evening","is_rush_hour","reporting_delay_minutes",
            "response_time_minutes","victim_age","signal_count_last_7d",
            "signal_count_last_30d","signal_density_ratio","area_encoded","neighborhood_encoded"]

clf = joblib.load(os.path.join(D, "rakshak_chennai_model_v2.pkl"))
print("loaded:", type(clf).__name__, "| classes_:", clf.classes_, "| n_features_in_:", clf.n_features_in_)
booster = clf.get_booster()
cfg = json.loads(booster.save_config())
objective = cfg["learner"]["objective"]["name"]
num_class = cfg["learner"]["learner_model_param"].get("num_class")
print("objective:", objective, "| num_class:", num_class)

# cross-version-safe artifacts
clf.save_model(os.path.join(OUT, "xgb_model.json"))          # sklearn-wrapper JSON (keeps classes_)
booster.save_model(os.path.join(OUT, "booster.json"))         # raw booster JSON
joblib.dump(clf, os.path.join(OUT, "model.pkl"))              # primary (container is xgb 3.2)
print("wrote:", os.listdir(OUT))

# ---- validation: rebuild the 17-vector from raw rows with the v2 label encoders ----
le_area = joblib.load(os.path.join(D, "label_encoder_area_v2.pkl"))
le_nbhd = joblib.load(os.path.join(D, "label_encoder_neighborhood_v2.pkl"))
df = pd.read_csv(os.path.join(D, "chennai_v2.csv"))
df["area_encoded"] = le_area.transform(df["area"])
df["neighborhood_encoded"] = le_nbhd.transform(df["neighborhood"])
sample = df.sample(8, random_state=7).reset_index(drop=True)
X = sample[FEATURES].astype(float).values
proba = clf.predict_proba(X)
pred = clf.predict(X)
print("\n--- reference (local xgboost 3.2 predict_proba) ---")
for i in range(len(sample)):
    print(f"row{i}: true={sample['risk_level'][i]} pred={int(pred[i])} "
          f"proba={[round(float(p),4) for p in proba[i]]}")

# emulate what inference.py will do via raw booster on DMatrix
bpred = booster.inplace_predict(X)
print("\n--- booster.inplace_predict (what inference.py Booster-fallback yields) ---")
maxdiff = float(np.max(np.abs(bpred - proba)))
print("max |booster - sklearn proba| =", maxdiff)
assert maxdiff < 1e-4, "booster vs sklearn mismatch!"

np.save(os.path.join(D, "val_X.npy"), X)
np.save(os.path.join(D, "val_proba.npy"), proba)
json.dump({"features": FEATURES, "objective": objective, "num_class": num_class,
           "classes": [int(c) for c in clf.classes_],
           "sample_rows": X.tolist(), "expected_proba": proba.tolist(),
           "expected_pred": [int(p) for p in pred]},
          open(os.path.join(D, "validation.json"), "w"), indent=2)
print("\nOK - validation.json written")
