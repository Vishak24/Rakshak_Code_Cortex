"""
Train production risk prediction model on Chennai enhanced dataset
"""
import pandas as pd
import numpy as np
from xgboost import XGBClassifier
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.preprocessing import LabelEncoder
import joblib
import json

print("=== Training Rakshak Risk Prediction Model (Chennai) ===\n")

# Load enhanced Chennai data
df = pd.read_csv("chennai_sos_enhanced_data.csv")
print(f"Loaded {len(df)} SOS signals from Chennai\n")

# Feature engineering
print("Preparing features...")

# Encode categorical variables
le_area = LabelEncoder()
df['area_encoded'] = le_area.fit_transform(df['area'])

le_neighborhood = LabelEncoder()
df['neighborhood_encoded'] = le_neighborhood.fit_transform(df['neighborhood'])

# Select features for model
feature_columns = [
    'latitude',
    'longitude',
    'pincode',
    'hour',
    'day_of_week',
    'is_weekend',
    'is_night',
    'is_evening',
    'is_rush_hour',
    'reporting_delay_minutes',
    'response_time_minutes',
    'victim_age',
    'signal_count_last_7d',
    'signal_count_last_30d',
    'signal_density_ratio',
    'area_encoded',
    'neighborhood_encoded'
]

X = df[feature_columns]
y = df['risk_level']

print(f"Features: {len(feature_columns)}")
print(f"Feature names: {feature_columns}\n")

# Train-test split
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

print(f"Training samples: {len(X_train)}")
print(f"Test samples: {len(X_test)}\n")

# Train XGBoost model
print("Training XGBoost model...")
model = XGBClassifier(
    n_estimators=200,
    max_depth=6,
    learning_rate=0.1,
    subsample=0.8,
    colsample_bytree=0.8,
    random_state=42,
    eval_metric='mlogloss'
)

model.fit(X_train, y_train, verbose=False)
print("✅ Training complete\n")

# Evaluate
print("Evaluating model...")
predictions = model.predict(X_test)
accuracy = accuracy_score(y_test, predictions)

print(f"Test Accuracy: {accuracy:.2%}\n")
print("Classification Report:")
print(classification_report(y_test, predictions, 
                           target_names=['Low Risk', 'Medium Risk', 'High Risk']))

# Confusion matrix
print("Confusion Matrix:")
cm = confusion_matrix(y_test, predictions)
print(cm)
print()

# Cross-validation
print("Running 5-fold cross-validation...")
cv_scores = cross_val_score(model, X_train, y_train, cv=5, scoring='accuracy')
print(f"CV scores: {cv_scores}")
print(f"Mean CV accuracy: {cv_scores.mean():.2%} (+/- {cv_scores.std() * 2:.2%})\n")

# Feature importance
feature_importance = pd.DataFrame({
    'feature': feature_columns,
    'importance': model.feature_importances_
}).sort_values('importance', ascending=False)

print("Top 10 Most Important Features:")
print(feature_importance.head(10))
print()

# Save model artifacts
print("Saving model artifacts...")
model.save_model("rakshak_chennai_model.json")
joblib.dump(model, "rakshak_chennai_model.pkl")
joblib.dump(le_area, "label_encoder_area.pkl")
joblib.dump(le_neighborhood, "label_encoder_neighborhood.pkl")

# Save metadata
model_metadata = {
    "model_type": "XGBClassifier",
    "city": "Chennai",
    "training_date": pd.Timestamp.now().isoformat(),
    "features": feature_columns,
    "feature_importance": feature_importance.to_dict('records'),
    "accuracy": float(accuracy),
    "cv_mean_accuracy": float(cv_scores.mean()),
    "cv_std_accuracy": float(cv_scores.std()),
    "classes": ["Low Risk", "Medium Risk", "High Risk"],
    "training_samples": len(X_train),
    "test_samples": len(X_test),
    "n_estimators": 200,
    "max_depth": 6,
    "learning_rate": 0.1
}

with open("model_metadata.json", "w") as f:
    json.dump(model_metadata, f, indent=2)

print("✅ Model saved: rakshak_chennai_model.pkl")
print("✅ Metadata saved: model_metadata.json")
print()

# Test inference with sample predictions
print("=== Testing Inference ===")
print("\nSample predictions:")

for i in range(3):
    sample = X_test.iloc[i:i+1]
    prediction = model.predict(sample)[0]
    probabilities = model.predict_proba(sample)[0]
    
    print(f"\nSample {i+1}:")
    print(f"  Area: {df.iloc[X_test.index[i]]['area']}")
    print(f"  Hour: {int(sample['hour'].values[0])}, Night: {int(sample['is_night'].values[0])}")
    print(f"  Response time: {int(sample['response_time_minutes'].values[0])} min")
    print(f"  Predicted: {['Low', 'Medium', 'High'][prediction]} Risk")
    print(f"  Confidence: Low={probabilities[0]:.1%}, Med={probabilities[1]:.1%}, High={probabilities[2]:.1%}")

print("\n=== Model Training Complete ===")
print(f"\n🎯 Final Test Accuracy: {accuracy:.2%}")
print(f"🎯 Cross-Validation Accuracy: {cv_scores.mean():.2%}")
