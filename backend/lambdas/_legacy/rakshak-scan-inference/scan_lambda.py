import json, boto3, os, math, io
from datetime import datetime, timezone
import joblib, numpy as np

s3 = boto3.client('s3', region_name='ap-south-1')
BUCKET = 'rakshak-models-vishalganesan'
MODEL_KEY = 'rakshak_chennai_model.pkl'
_model = None

def get_model():
    global _model
    if _model is None:
        buf = io.BytesIO()
        s3.download_fileobj(BUCKET, MODEL_KEY, buf)
        buf.seek(0)
        _model = joblib.load(buf)
    return _model

RISK_MAP = {0:'LOW',1:'MEDIUM',2:'HIGH',3:'ELEVATED'}
SAFETY_MAP = {0:95.0,1:65.0,2:30.0,3:10.0}

def haversine(lat1,lon1,lat2,lon2):
    R=6371; dlat=math.radians(lat2-lat1); dlon=math.radians(lon2-lon1)
    a=math.sin(dlat/2)**2+math.cos(math.radians(lat1))*math.cos(math.radians(lat2))*math.sin(dlon/2)**2
    return R*2*math.asin(math.sqrt(a))

def lambda_handler(event, context):
    H={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'Content-Type,Authorization','Access-Control-Allow-Methods':'OPTIONS,POST'}
    if event.get('requestContext',{}).get('http',{}).get('method')=='OPTIONS':
        return {'statusCode':200,'headers':H,'body':''}
    try:
        body=json.loads(event.get('body','{}'))
        lat=float(body.get('lat',13.0827)); lon=float(body.get('lon',80.2707))
        pincode=int(body.get('pincode',600001))
        now=datetime.now(timezone.utc)
        hour=int(body.get('hour',(now.hour+5)%24))
        dow=int(body.get('day_of_week',now.weekday()))
        is_night=1 if (hour>=20 or hour<=5) else 0
        is_eve=1 if (17<=hour<20) else 0
        is_rush=1 if hour in [8,9,17,18,19] else 0
        is_wknd=1 if dow>=5 else 0
        patrols=[(13.0827,80.2707),(13.1067,80.2897),(13.0569,80.2425)]
        dist=min(haversine(lat,lon,p[0],p[1]) for p in patrols)
        resp_min=(dist/40)*60
        area_enc={'royapuram':3,'parrys':1,'perambur':2,'washermanpet':4,'vyasarpadi':0}
        area=body.get('area','royapuram').lower()
        features=np.array([[lat,lon,pincode,hour,dow,is_wknd,is_night,is_eve,is_rush,
                   float(body.get('reporting_delay_minutes',20)),resp_min,
                   int(body.get('victim_age',25)),int(body.get('signal_count_last7d',5)),
                   int(body.get('signal_count_last30d',18)),float(body.get('signal_density_ratio',0.35)),
                   area_enc.get(area,2),int(body.get('neighborhood_encoded',4))]])
        model=get_model()
        pred=int(model.predict(features)[0])
        probs=model.predict_proba(features)[0].tolist()
        return {'statusCode':200,'headers':H,'body':json.dumps({
            'risk_level':RISK_MAP.get(pred,'MEDIUM'),
            'safety_score':SAFETY_MAP.get(pred,50.0),
            'risk_index':pred,'confidence':round(max(probs),4),
            'probabilities':{'LOW':round(probs[0],4),'MEDIUM':round(probs[1],4),'HIGH':round(probs[2],4)},
            'nearest_patrol_km':round(dist,2),'estimated_response_min':round(resp_min,1),
            'is_night':bool(is_night),'area':area,
            'model':'rf-v1','source':'s3-direct'
        })}
    except Exception as e:
        import traceback; traceback.print_exc()
        return {'statusCode':500,'headers':H,'body':json.dumps({'error':str(e),'risk_level':'UNKNOWN'})}
