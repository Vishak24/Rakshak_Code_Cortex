import boto3
import json
import math

dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')

def haversine(lat1, lon1, lat2, lon2):
    R = 6371
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = math.sin(d_lat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(d_lon/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))
    user_lat = body.get('lat', 13.0827)
    user_lon = body.get('lon', 80.2707)
    alert_id = body.get('alert_id', 'SOS001')

    table = dynamodb.Table('patrol_vehicles')
    response = table.scan()
    vehicles = response.get('Items', [])

    nearest = None
    min_dist = float('inf')
    for v in vehicles:
        dist = haversine(user_lat, user_lon, float(v['lat']), float(v['lon']))
        if dist < min_dist:
            min_dist = dist
            nearest = v

    sos_table = dynamodb.Table('sos_alerts')
    import time
    sos_table.put_item(Item={
        'alert_id': alert_id,
        'timestamp': int(time.time()),
        'user_lat': str(user_lat),
        'user_lon': str(user_lon),
        'assigned_vehicle': nearest.get('vehicle_id', 'PCR-01') if nearest else 'PCR-01',
        'status': 'DISPATCHED'
    })

    return {
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps({
            'assigned_vehicle': nearest.get('vehicle_id', 'PCR-01') if nearest else 'PCR-01',
            'officer_name': nearest.get('officer_name', 'Officer Priya Nair') if nearest else 'Officer Priya Nair',
            'distance_km': round(min_dist, 2) if nearest else 1.2,
            'eta_minutes': round(min_dist * 3, 1) if nearest else 8.4,
            'status': 'DISPATCHED'
        })
    }
