import pandas as pd
import numpy as np
import random

ALL_44 = {
  '600002': (13.0674, 80.2574), '600005': (13.0600, 80.2780),
  '600008': (13.0750, 80.2496), '600009': (13.0850, 80.2100),
  '600010': (13.0950, 80.2496), '600012': (13.1000, 80.2674),
  '600013': (13.1150, 80.2830), '600015': (13.0496, 80.2300),
  '600019': (13.1300, 80.3000), '600029': (13.0800, 80.2300),
  '600032': (13.0496, 80.2100), '600033': (13.0400, 80.2200),
  '600034': (13.0750, 80.2574), '600035': (13.0496, 80.2400),
  '600036': (13.0100, 80.2300), '600040': (13.0700, 80.2200),
  '600044': (12.9600, 80.1300), '600045': (12.9300, 80.1300),
  '600050': (13.0750, 80.2100), '600053': (13.0850, 80.1900),
  '600056': (13.0496, 80.1700), '600061': (12.9800, 80.1800),
  '600064': (12.9400, 80.1300), '600078': (13.0496, 80.2000),
  '600081': (13.1100, 80.3000), '600082': (13.1050, 80.2496),
  '600083': (13.0496, 80.2150), '600099': (13.0900, 80.2200),
  '600118': (13.1000, 80.2800)
}

# Risk profile by latitude — North Chennai = higher risk
def get_risk_profile(lat):
    if lat >= 13.10:   return 'high'
    elif lat >= 13.05: return 'medium'
    else:              return 'low'

area_map = {
  '600002':'Sowcarpet','600005':'Chintadripet','600008':'Chepauk',
  '600009':'Kilpauk','600010':'Vepery','600012':'Tondiarpet',
  '600013':'Tiruvottiyur','600015':'Padi','600019':'Ennore',
  '600029':'Aminjikarai','600032':'Vadapalani','600033':'Saidapet',
  '600034':'Teynampet','600035':'Alandur','600036':'St. Thomas Mount',
  '600040':'Virugambakkam','600044':'Tambaram','600045':'Pallavaram',
  '600050':'Arumbakkam','600053':'Ambattur','600056':'Porur',
  '600061':'Chromepet','600064':'Vandalur','600078':'Valasaravakkam',
  '600081':'Manali','600082':'Madhavaram','600083':'Villivakkam',
  '600099':'Poonamallee','600118':'Kathivakkam'
}

neighborhood_map = {
  '600002':'George Town','600005':'Central Chennai','600008':'Central Chennai',
  '600009':'West Chennai','600010':'Central Chennai','600012':'North Chennai',
  '600013':'North Chennai','600015':'West Chennai','600019':'North Chennai',
  '600029':'West Chennai','600032':'West Chennai','600033':'South Chennai',
  '600034':'Central Chennai','600035':'South Chennai','600036':'South Chennai',
  '600040':'West Chennai','600044':'South Chennai','600045':'South Chennai',
  '600050':'West Chennai','600053':'West Chennai','600056':'West Chennai',
  '600061':'South Chennai','600064':'South Chennai','600078':'West Chennai',
  '600081':'North Chennai','600082':'North Chennai','600083':'North Chennai',
  '600099':'West Chennai','600118':'North Chennai'
}

rows = []
base_date = pd.Timestamp('2025-06-01')

for pincode, (lat, lon) in ALL_44.items():
    profile = get_risk_profile(lat)
    for _ in range(200):
        hour = random.randint(0, 23)
        dow  = random.randint(0, 6)
        is_weekend = 1 if dow >= 5 else 0
        is_night   = 1 if (hour >= 22 or hour <= 5) else 0
        is_evening = 1 if (17 <= hour <= 21) else 0
        is_rush    = 1 if (hour in [8,9,17,18,19]) else 0

        if profile == 'high':
            rep_delay = random.randint(10, 50)
            resp_time = random.randint(15, 35)
            sig7      = random.randint(4, 12)
            sig30     = random.randint(25, 55)
            vic_age   = random.randint(15, 65)
            risk = 2 if (is_night or sig7 > 7) else (1 if hour > 17 else 2)
        elif profile == 'medium':
            rep_delay = random.randint(5, 30)
            resp_time = random.randint(8, 20)
            sig7      = random.randint(2, 7)
            sig30     = random.randint(10, 30)
            vic_age   = random.randint(18, 75)
            risk = 1 if (is_night or sig7 > 4) else 0
        else:
            rep_delay = random.randint(1, 15)
            resp_time = random.randint(5, 15)
            sig7      = random.randint(1, 4)
            sig30     = random.randint(5, 18)
            vic_age   = random.randint(20, 80)
            risk = 0

        density = round(sig7 / sig30, 3) if sig30 > 0 else 0
        total   = rep_delay + resp_time
        occ_dt  = base_date + pd.Timedelta(days=random.randint(0,180),
                                            hours=hour, minutes=random.randint(0,59))
        rep_dt  = occ_dt + pd.Timedelta(minutes=rep_delay)
        arr_dt  = rep_dt + pd.Timedelta(minutes=resp_time)

        rows.append({
            'pincode': int(pincode),
            'area': area_map[pincode],
            'neighborhood': neighborhood_map[pincode],
            'latitude': round(lat + random.uniform(-0.005, 0.005), 6),
            'longitude': round(lon + random.uniform(-0.005, 0.005), 6),
            'occurrence_time': occ_dt.isoformat(),
            'report_time': rep_dt.isoformat(),
            'authority_arrival_time': arr_dt.isoformat(),
            'hour': hour, 'day_of_week': dow,
            'is_weekend': is_weekend, 'is_night': is_night,
            'is_evening': is_evening, 'is_rush_hour': is_rush,
            'reporting_delay_minutes': rep_delay,
            'response_time_minutes': resp_time,
            'total_resolution_time_minutes': total,
            'victim_age': vic_age,
            'signal_count_last_7d': sig7,
            'signal_count_last_30d': sig30,
            'signal_density_ratio': density,
            'risk_level': risk
        })

new_df = pd.DataFrame(rows)
old_df = pd.read_csv('chennai_sos_enhanced_data.csv')
combined = pd.concat([old_df, new_df], ignore_index=True)
combined.to_csv('chennai_sos_enhanced_data_v2.csv', index=False)
print(f"Done! Old: {len(old_df)} rows | New: {len(new_df)} rows | Total: {len(combined)} rows")
print(f"Unique pincodes: {combined['pincode'].nunique()}")