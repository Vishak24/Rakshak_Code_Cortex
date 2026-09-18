import json, boto3
from boto3.dynamodb.conditions import Attr
from datetime import datetime, timedelta, timezone

REGION = 'ap-south-1'

CORS = {
    'Access-Control-Allow-Origin':  '*',
    'Access-Control-Allow-Methods': 'GET,POST,PATCH,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
}

PINCODE_MAP = {
    "600001": "Parrys",        "600002": "Anna Salai",    "600003": "Mylapore",
    "600004": "Anna Nagar",    "600005": "Royapettah",    "600006": "Adyar",
    "600007": "Egmore",        "600008": "Kilpauk",       "600010": "Vepery",
    "600011": "Purasawalkam",  "600012": "Perambur",      "600013": "Tondiarpet",
    "600015": "Kodambakkam",   "600017": "T. Nagar",      "600018": "Saidapet",
    "600020": "Guindy",        "600025": "Velachery",     "600028": "Nandanam",
    "600029": "Alwarpet",      "600058": "Sholinganallur",
}


def _users_table():
    return boto3.resource('dynamodb', region_name=REGION).Table('rakshak-users')


def risk_label(count):
    if count > 10:  return 'HIGH'
    if count >= 5:  return 'MEDIUM'
    return 'LOW'


def lambda_handler(event, context):
    method = event.get('requestContext', {}).get('http', {}).get('method', 'GET')
    path   = event.get('rawPath', '')

    if method == 'OPTIONS':
        return {'statusCode': 200, 'headers': CORS, 'body': ''}

    try:
        table = _users_table()

        if method == 'GET' and path.endswith('/police/citizens/active'):
            qs = event.get('queryStringParameters') or {}
            try:
                after_hour = int(qs.get('after_hour', 22))
            except (ValueError, TypeError):
                after_hour = 22

            now_utc      = datetime.now(timezone.utc)
            now_ist      = now_utc + timedelta(hours=5, minutes=30)
            current_hour = now_ist.hour

            if current_hour < after_hour:
                return {
                    'statusCode': 200, 'headers': CORS,
                    'body': json.dumps({
                        'total_count':  0,
                        'by_pincode':   [],
                        'last_updated': now_utc.isoformat() + 'Z',
                        'note': f'Current IST hour {current_hour} is before after_hour={after_hour}',
                    }),
                }

            cutoff = (now_utc - timedelta(minutes=30)).strftime('%Y-%m-%dT%H:%M:%S') + 'Z'
            resp   = table.scan(FilterExpression=Attr('last_ping').gte(cutoff))
            items  = resp.get('Items', [])

            by_pincode = {}
            for item in items:
                pc = str(item.get('pincode', 'unknown'))
                by_pincode[pc] = by_pincode.get(pc, 0) + 1

            result_list = [
                {'pincode': pc, 'area': PINCODE_MAP.get(pc, 'Unknown'),
                 'count': cnt, 'risk': risk_label(cnt)}
                for pc, cnt in sorted(by_pincode.items(), key=lambda x: -x[1])
            ]

            return {
                'statusCode': 200, 'headers': CORS,
                'body': json.dumps({
                    'total_count':  len(items),
                    'by_pincode':   result_list,
                    'last_updated': now_utc.isoformat() + 'Z',
                }),
            }

        if method == 'POST' and path.endswith('/citizens/ping'):
            body    = json.loads(event.get('body', '{}') or '{}')
            user_id = body.get('user_id')
            if not user_id:
                return {'statusCode': 400, 'headers': CORS, 'body': json.dumps({'error': 'user_id required'})}

            table.put_item(Item={
                'user_id':   user_id,
                'lat':       str(body.get('lat', '')),
                'lng':       str(body.get('lng', '')),
                'pincode':   str(body.get('pincode', '')),
                'last_ping': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S') + 'Z',
            })
            return {'statusCode': 200, 'headers': CORS, 'body': json.dumps({'status': 'ok'})}

        return {'statusCode': 404, 'headers': CORS, 'body': json.dumps({'error': 'route not found'})}

    except Exception as e:
        return {'statusCode': 500, 'headers': CORS, 'body': json.dumps({'error': str(e)})}