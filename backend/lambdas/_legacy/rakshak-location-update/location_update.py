import boto3
import json
import time

dynamodb = boto3.resource('dynamodb', region_name='ap-south-1')

def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))
    
    vehicle_id = body.get('vehicle_id', 'PCR-01')
    lat = body.get('lat', 13.0827)
    lon = body.get('lon', 80.2707)
    officer_name = body.get('officer_name', 'Officer Priya Nair')
    status = body.get('status', 'ON_PATROL')

    table = dynamodb.Table('patrol_vehicles')
    table.put_item(Item={
        'vehicle_id': vehicle_id,
        'lat': str(lat),
        'lon': str(lon),
        'officer_name': officer_name,
        'status': status,
        'last_updated': int(time.time())
    })

    loc_table = dynamodb.Table('user_locations')
    loc_table.put_item(Item={
        'user_id': vehicle_id,
        'timestamp': int(time.time()),
        'lat': str(lat),
        'lon': str(lon),
        'type': 'PATROL'
    })

    return {
        'statusCode': 200,
        'headers': {'Access-Control-Allow-Origin': '*'},
        'body': json.dumps({
            'vehicle_id': vehicle_id,
            'status': status,
            'updated': True
        })
    }
