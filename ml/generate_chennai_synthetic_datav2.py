"""
Enhanced Chennai-focused synthetic SOS dataset - WORKING VERSION
"""
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json

np.random.seed(42)

print("=== Generating Enhanced Chennai SOS Dataset ===\n")

# Chennai areas with real pincodes
chennai_areas = [
    {"pincode": 600001, "area": "Parrys Corner", "neighborhood": "George Town", "lat": 13.0878, "lon": 80.2785, "base_risk": 0.75, "avg_police_response_min": 18},
    {"pincode": 600003, "area": "Park Town", "neighborhood": "Central Chennai", "lat": 13.0781, "lon": 80.2847, "base_risk": 0.70, "avg_police_response_min": 15},
    {"pincode": 600007, "area": "Perambur", "neighborhood": "North Chennai", "lat": 13.1143, "lon": 80.2378, "base_risk": 0.72, "avg_police_response_min": 20},
    {"pincode": 600011, "area": "Royapuram", "neighborhood": "North Chennai", "lat": 13.1067, "lon": 80.2897, "base_risk": 0.68, "avg_police_response_min": 17},
    {"pincode": 600021, "area": "Kodungaiyur", "neighborhood": "North Chennai", "lat": 13.1323, "lon": 80.2539, "base_risk": 0.74, "avg_police_response_min": 22},
    {"pincode": 600023, "area": "Vyasarpadi", "neighborhood": "North Chennai", "lat": 13.1095, "lon": 80.2485, "base_risk": 0.69, "avg_police_response_min": 19},
    {"pincode": 600004, "area": "Mylapore", "neighborhood": "Central Chennai", "lat": 13.0339, "lon": 80.2619, "base_risk": 0.45, "avg_police_response_min": 10},
    {"pincode": 600006, "area": "Triplicane", "neighborhood": "Central Chennai", "lat": 13.0569, "lon": 80.2779, "base_risk": 0.50, "avg_police_response_min": 12},
    {"pincode": 600017, "area": "T. Nagar", "neighborhood": "Central Chennai", "lat": 13.0389, "lon": 80.2341, "base_risk": 0.52, "avg_police_response_min": 11},
    {"pincode": 600018, "area": "Kodambakkam", "neighborhood": "West Chennai", "lat": 13.0517, "lon": 80.2250, "base_risk": 0.48, "avg_police_response_min": 13},
    {"pincode": 600020, "area": "Anna Nagar", "neighborhood": "West Chennai", "lat": 13.0850, "lon": 80.2101, "base_risk": 0.42, "avg_police_response_min": 9},
    {"pincode": 600024, "area": "Ashok Nagar", "neighborhood": "West Chennai", "lat": 13.0358, "lon": 80.2108, "base_risk": 0.46, "avg_police_response_min": 11},
    {"pincode": 600028, "area": "Nungambakkam", "neighborhood": "Central Chennai", "lat": 13.0569, "lon": 80.2426, "base_risk": 0.44, "avg_police_response_min": 10},
    {"pincode": 600041, "area": "Adyar", "neighborhood": "South Chennai", "lat": 13.0067, "lon": 80.2573, "base_risk": 0.28, "avg_police_response_min": 7},
    {"pincode": 600042, "area": "Thiruvanmiyur", "neighborhood": "South Chennai", "lat": 12.9842, "lon": 80.2611, "base_risk": 0.25, "avg_police_response_min": 6},
    {"pincode": 600090, "area": "Velachery", "neighborhood": "South Chennai", "lat": 12.9756, "lon": 80.2169, "base_risk": 0.35, "avg_police_response_min": 9},
    {"pincode": 600096, "area": "OMR", "neighborhood": "IT Corridor", "lat": 12.9406, "lon": 80.2297, "base_risk": 0.30, "avg_police_response_min": 8},
    {"pincode": 600113, "area": "Sholinganallur", "neighborhood": "IT Corridor", "lat": 12.9008, "lon": 80.2275, "base_risk": 0.32, "avg_police_response_min": 10},
    {"pincode": 600119, "area": "Besant Nagar", "neighborhood": "South Chennai", "lat": 13.0006, "lon": 80.2667, "base_risk": 0.27, "avg_police_response_min": 7},
    {"pincode": 600127, "area": "Perungudi", "neighborhood": "IT Corridor", "lat": 12.9611, "lon": 80.2428, "base_risk": 0.33, "avg_police_response_min": 9},
]

def generate_chennai_sos_signals(num_samples=15000):
    data = []
    start_date = datetime(2025, 6, 1)
    
    for i in range(num_samples):
        # Select area weighted by risk
        area_weights = [a["base_risk"] for a in chennai_areas]
        area = np.random.choice(chennai_areas, p=np.array(area_weights)/sum(area_weights))
        
        # Generate occurrence date
        days_offset = np.random.randint(0, 180)
        occurrence_date = start_date + timedelta(days=days_offset)
        
        # Hour generation (simplified to avoid probability errors)
        if area["base_risk"] > 0.65:
            if np.random.random() < 0.4:
                hour = np.random.randint(20, 24)  # Evening 8PM-midnight (40%)
            elif np.random.random() < 0.3:
                hour = np.random.randint(0, 6)    # Late night (30% of rest)
            else:
                hour = np.random.randint(6, 20)   # Daytime
        elif area["base_risk"] > 0.4:
            if np.random.random() < 0.3:
                hour = np.random.randint(18, 23)
            else:
                hour = np.random.randint(0, 24)
        else:
            hour = np.random.randint(0, 24)
        
        minute = np.random.randint(0, 60)
        occurrence_datetime = occurrence_date.replace(hour=hour, minute=minute)
        
        # Reporting delay
        if area["base_risk"] > 0.6:
            reporting_delay_minutes = np.random.randint(5, 45)
        elif area["base_risk"] > 0.4:
            reporting_delay_minutes = np.random.randint(2, 20)
        else:
            reporting_delay_minutes = np.random.randint(1, 10)
        
        report_datetime = occurrence_datetime + timedelta(minutes=reporting_delay_minutes)
        
        # Response time
        base_response = area["avg_police_response_min"]
        
        if hour >= 22 or hour <= 5:
            time_multiplier = 1.2
        elif (8 <= hour <= 10) or (17 <= hour <= 20):
            time_multiplier = 1.3
        else:
            time_multiplier = 1.0
        
        response_time_minutes = int(base_response * time_multiplier * np.random.uniform(0.8, 1.4))
        response_time_minutes = max(3, min(45, response_time_minutes))
        
        authority_arrival_datetime = report_datetime + timedelta(minutes=response_time_minutes)
        
        # Location with noise
        lat = area["lat"] + np.random.normal(0, 0.003)
        lon = area["lon"] + np.random.normal(0, 0.003)
        
        # Victim age
        victim_age = int(np.random.choice(
            [np.random.randint(15, 25),
             np.random.randint(25, 45),
             np.random.randint(45, 65),
             np.random.randint(65, 85)],
            p=[0.3, 0.4, 0.2, 0.1]
        ))
        
        # Historical counts
        base_count = int(area["base_risk"] * 60)
        signal_count_last_7d = max(0, np.random.poisson(base_count * 0.15))
        signal_count_last_30d = max(signal_count_last_7d, np.random.poisson(base_count))
        
        # Day of week
        day_of_week = occurrence_datetime.weekday()
        is_weekend = 1 if day_of_week >= 5 else 0
        
        # Derived features
        is_night = 1 if (hour >= 22 or hour <= 5) else 0
        is_evening = 1 if (18 <= hour <= 22) else 0
        is_rush_hour = 1 if ((8 <= hour <= 10) or (17 <= hour <= 20)) else 0
        signal_density_ratio = signal_count_last_7d / (signal_count_last_30d + 1)
        
        # Risk level calculation
        risk_score = area["base_risk"]
        if is_night:
            risk_score += 0.12
        if signal_count_last_7d > 12:
            risk_score += 0.08
        if response_time_minutes > 15:
            risk_score += 0.05
        if reporting_delay_minutes > 20:
            risk_score += 0.05
        
        if risk_score >= 0.65:
            risk_level = 2
        elif risk_score >= 0.4:
            risk_level = 1
        else:
            risk_level = 0
        
        data.append({
            "pincode": area["pincode"],
            "area": area["area"],
            "neighborhood": area["neighborhood"],
            "latitude": round(lat, 6),
            "longitude": round(lon, 6),
            "occurrence_time": occurrence_datetime.isoformat(),
            "report_time": report_datetime.isoformat(),
            "authority_arrival_time": authority_arrival_datetime.isoformat(),
            "hour": hour,
            "day_of_week": day_of_week,
            "is_weekend": is_weekend,
            "is_night": is_night,
            "is_evening": is_evening,
            "is_rush_hour": is_rush_hour,
            "reporting_delay_minutes": reporting_delay_minutes,
            "response_time_minutes": response_time_minutes,
            "total_resolution_time_minutes": reporting_delay_minutes + response_time_minutes,
            "victim_age": victim_age,
            "signal_count_last_7d": signal_count_last_7d,
            "signal_count_last_30d": signal_count_last_30d,
            "signal_density_ratio": round(signal_density_ratio, 3),
            "risk_level": risk_level
        })
    
    return pd.DataFrame(data)

# Generate
print("Generating 15,000 Chennai SOS signals...")
df = generate_chennai_sos_signals(15000)

print(f"\n✅ Generated {len(df)} signals\n")
print("Risk Distribution:")
print(df["risk_level"].value_counts().sort_index())
print(f"\nTop High-Risk Areas:")
print(df[df['risk_level']==2]['area'].value_counts().head())
print(f"\nResponse Time: Avg={df['response_time_minutes'].mean():.1f} min, Median={df['response_time_minutes'].median():.1f} min")
print(f"Reporting Delay: Avg={df['reporting_delay_minutes'].mean():.1f} min")
print(f"\nVictim Age: Mean={df['victim_age'].mean():.1f}, Range={df['victim_age'].min()}-{df['victim_age'].max()}")

# Save
df.to_csv("chennai_sos_enhanced_data.csv", index=False)
print(f"\n✅ Saved: chennai_sos_enhanced_data.csv")

with open("chennai_area_metadata.json", "w") as f:
    json.dump(chennai_areas, f, indent=2)
print("✅ Saved: chennai_area_metadata.json")

summary = {
    "total_signals": len(df),
    "city": "Chennai",
    "areas_covered": len(chennai_areas),
    "features": list(df.columns)
}
with open("dataset_summary.json", "w") as f:
    json.dump(summary, f, indent=2)
print("✅ Saved: dataset_summary.json")

print("\n=== COMPLETE ===")
