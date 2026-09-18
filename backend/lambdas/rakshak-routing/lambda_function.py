import json, math, urllib.request, boto3

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


def haversine(lat1, lon1, lat2, lon2):
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi    = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return round(R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)), 2)


def reverse_geocode(lat, lng):
    try:
        url = f"https://nominatim.openstreetmap.org/reverse?lat={lat}&lon={lng}&format=json"
        req = urllib.request.Request(url, headers={"User-Agent": "Rakshak-Police/1.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
        address  = data.get('address', {})
        postcode = address.get('postcode', '').replace(' ', '')
        area     = (address.get('suburb') or address.get('neighbourhood')
                    or address.get('city_district') or address.get('town', 'Unknown'))
        if postcode in PINCODE_MAP:
            area = PINCODE_MAP[postcode]
        return postcode, area
    except Exception:
        return '', 'Unknown'


def _sos_table():
    return boto3.resource('dynamodb', region_name=REGION).Table('rakshak-sos-alerts')


def lambda_handler(event, context):
    method = event.get('requestContext', {}).get('http', {}).get('method', 'GET')

    if method == 'OPTIONS':
        return {'statusCode': 200, 'headers': CORS, 'body': ''}

    try:
        qs = event.get('queryStringParameters') or {}
        try:
            from_lat = float(qs['from_lat'])
            from_lng = float(qs['from_lng'])
            to_lat   = float(qs['to_lat'])
            to_lng   = float(qs['to_lng'])
        except (KeyError, ValueError, TypeError):
            return {
                'statusCode': 400, 'headers': CORS,
                'body': json.dumps({'error': 'from_lat, from_lng, to_lat, to_lng are required'}),
            }

        sos_id      = qs.get('sos_id', '')
        distance_km = haversine(from_lat, from_lng, to_lat, to_lng)
        eta_minutes = max(1, round(distance_km / 0.3))

        pincode, area_name = reverse_geocode(to_lat, to_lng)

        if not pincode and sos_id:
            try:
                item      = _sos_table().get_item(Key={'sos_id': sos_id}).get('Item', {})
                pincode   = str(item.get('pincode', ''))
                area_name = PINCODE_MAP.get(pincode, item.get('area_name', 'Unknown'))
            except Exception:
                pass

        google_maps_url = (
            f"https://www.google.com/maps/dir/?api=1"
            f"&origin={from_lat},{from_lng}"
            f"&destination={to_lat},{to_lng}"
            f"&travelmode=driving"
        )

        return {
            'statusCode': 200, 'headers': CORS,
            'body': json.dumps({
                'sos_id': sos_id,
                'destination': {'lat': to_lat, 'lng': to_lng, 'pincode': pincode, 'area_name': area_name},
                'google_maps_url': google_maps_url,
                'distance_km':     distance_km,
                'eta_minutes':     eta_minutes,
            }),
        }

    except Exception as e:
        return {'statusCode': 500, 'headers': CORS, 'body': json.dumps({'error': str(e)})}