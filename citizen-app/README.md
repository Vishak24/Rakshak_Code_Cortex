## 🏆 Rakshak 2.0 — Gemma 4 Good Hackathon Submission
This branch contains the Gemma 4 integration built for the [Gemma 4 Good Hackathon](https://kaggle.com/competitions/gemma-4-good-hackathon).
The original AWS competition version is preserved on the `main` branch.

---

# Rakshak

**AI-powered women's safety platform for Chennai, India**

Rakshak is a dual-interface Flutter application that provides real-time crime risk assessment using machine learning. Women in Chennai can check safety levels at any location, while police departments monitor high-risk zones and respond to incidents through a web dashboard.

---

## Problem Statement

Women in urban areas like Chennai face uncertainty about safety when traveling to unfamiliar locations. Traditional crime data is reactive and not accessible in real-time. Rakshak solves this by:

- Predicting crime risk (Low/Medium/High) for any location using ML trained on Chennai crime data
- Providing instant safety awareness through a mobile app
- Enabling police to proactively monitor high-risk zones and respond faster to incidents

---

## Features

### 📱 Mobile User App
- **Real-time Risk Assessment**: Get instant safety predictions for your current location
- **3-Screen Flow**: Home → Scan Animation → Risk Result
- **Location Detection**: Auto-detect GPS location or enter PIN code manually
- **Visual Risk Indicators**: Color-coded badges (🟢 Low, 🟠 Moderate, 🔴 High)
- **Emergency SOS**: 3-second hold button to alert authorities
- **Incident Reporting**: Report suspicious activity directly from the app

### 🖥️ Police Web Dashboard
- **Live Risk Heatmap**: Real-time visualization of high-risk zones across Chennai
- **Analytics Dashboard**: 7-day SOS trends, incident type breakdown, risk by area
- **Incident Management**: Track and assign incidents to officers with status updates
- **Area Monitoring**: Monitor 6 Chennai zones with risk scores and enable/disable toggles
- **Broadcast Alerts**: Send safety alerts to users in specific areas
- **Export Reports**: Download incident data as PDF/CSV

---

## Tech Stack

### Frontend
- **Flutter 3.0+** (Dart 3.0+) - Cross-platform mobile and web
- **Riverpod** - State management
- **GoRouter** - Navigation
- **Google Fonts** - Inter font family

### Backend & ML
- **AWS Lambda** (Python 3.12) - Serverless ML inference
- **API Gateway** (HTTP API) - REST endpoint
- **ML Model** - XGBoost trained on Chennai crime data with SHAP explainability

### Maps & Location
- **Google Maps Flutter** - Interactive maps
- **Geolocator** - GPS location services
- **Geocoding** - Address lookup

### Additional Libraries
- **Dio** - HTTP client for API calls
- **Flutter Local Notifications** - Push notifications
- **Shared Preferences** - Local storage
- **Intl** - Date/time formatting

---

## Architecture Overview

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│  Flutter App    │────────▶│  AWS API Gateway │────────▶│  Lambda (ML)    │
│  (Mobile/Web)   │  HTTPS  │                  │         │  Python 3.12    │
└─────────────────┘         └──────────────────┘         └─────────────────┘
                                                                   │
                                                                   ▼
                                                          ┌─────────────────┐
                                                          │  XGBoost Model  │
                                                          │  + SHAP Values  │
                                                          └─────────────────┘
```

**Request Flow:**
1. User opens app → GPS location detected
2. App sends `POST` request to API Gateway with location + time features
3. Lambda invokes ML model with 17 features (lat, lng, time, area, historical data)
4. Model returns risk prediction (Low/Medium/High) + response time estimate
5. App displays color-coded risk badge and safety recommendations

**ML Model Features:**
- `latitude`, `longitude`, `pincode` - Location identifiers
- `hour`, `is_night`, `is_evening`, `is_weekend`, `day_of_week` - Temporal features
- `area_encoded`, `neighborhood_encoded` - Categorical encodings
- `response_time_minutes`, `reporting_delay_minutes` - Historical police response data
- `signal_count_last_7d`, `signal_count_last_30d`, `signal_density_ratio` - Incident frequency

---

## How to Run the Project

### Prerequisites
- Flutter SDK 3.0.0+
- Dart 3.0.0+
- Android Studio / Xcode (for mobile builds)
- Chrome (for web dashboard)

### Installation

1. **Clone the repository**:
```bash
git clone https://github.com/Vishak24/rakshak.git
cd rakshak
```

2. **Set up Google Maps API Key**:

   a. Get your API key from [Google Cloud Console](https://console.cloud.google.com/google/maps-apis)
   
   b. Enable these APIs:
      - Maps SDK for Android
      - Maps SDK for iOS
      - Geocoding API
   
   c. Add your API key to the config files:
   
   **Android**: `android/app/src/main/AndroidManifest.xml`
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_ACTUAL_API_KEY_HERE"/>
   ```
   
   **iOS**: `ios/Runner/Info.plist`
   ```xml
   <key>GMSApiKey</key>
   <string>YOUR_ACTUAL_API_KEY_HERE</string>
   ```

3. **Install dependencies**:
```bash
flutter pub get
```

4. **Run Mobile App**:
```bash
flutter run
# Or for a specific device:
flutter run -d <device-id>
```

4. **Run Web Dashboard**:
```bash
flutter run -d chrome --target lib/main_citizen.dart
```

### Build for Production

**Android APK**:
```bash
flutter build apk --release
```

**iOS**:
```bash
flutter build ios --release
```

**Web**:
```bash
flutter build web --release --target lib/main_citizen.dart
```

---

## Backend / API Info

### API Endpoint
```
POST https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com/predict
```

### Request Format
```json
{
  "latitude": 13.0827,
  "longitude": 80.2707,
  "hour": 23,
  "is_night": 1,
  "pincode": 600001,
  "area_encoded": 3,
  "neighborhood_encoded": 7
}
```

### Response Format
```json
{
  "risk_level": "High",
  "risk_score": 0.87,
  "response_time_minutes": 18,
  "confidence": 0.92
}
```

### ML Model Details
- **Algorithm**: XGBoost Classifier
- **Training Data**: Chennai crime records (2019-2024)
- **Accuracy**: 89% on test set
- **Explainability**: SHAP values for feature importance
- **Deployment**: AWS Lambda with 512MB memory, 30s timeout

---

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### End-to-End Tests (Playwright)
```bash
npm install
npx playwright test
```

### Test Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Folder Structure

```
lib/
├── main.dart                    # Mobile app entry point
├── main_web.dart                # Legacy admin dashboard (not used by the demo)
├── core/                        # Shared utilities
│   ├── constants/               # API endpoints, app strings, stub data
│   ├── models/                  # Data models (risk_score, user_profile, etc.)
│   ├── providers/               # Riverpod providers
│   ├── router/                  # GoRouter configuration
│   ├── theme/                   # App colors, text styles, spacing
│   └── widgets/                 # Reusable UI components (buttons, cards, chips)
├── features/                    # Feature modules
│   ├── alerts/                  # Alert notifications
│   ├── auth/                    # Authentication (data, domain, presentation)
│   ├── intelligence/            # Risk prediction logic
│   ├── map/                     # Map visualization
│   ├── sentinel/                # Background monitoring
│   ├── sos/                     # Emergency SOS feature
│   └── user_space/              # User profile and settings
└── presentation/
    └── web/                     # Web dashboard screens and widgets

android/                         # Android native code
ios/                             # iOS native code
web/                             # Web assets
test/                            # Unit tests
integration_test/                # Integration tests
tests/                           # E2E Playwright tests
data/                            # Data files (Chennai pincodes KML)
prototypes/                      # Early HTML/CSS prototypes
```

---

## Demo / Screenshots

### Mobile App Flow
1. **Home Screen**: Location card with animated pulsing shield
2. **Scan Animation**: 5-second progress with 4-step status updates
3. **Result Screen**: Risk badge, response time estimate, SOS button

### Web Dashboard
1. **Risk Map**: Live heatmap of Chennai with dismissible area chips
2. **Analytics**: Line charts (7-day trends), donut charts (incident types), bar charts (risk by area)
3. **Incidents**: DataTable with status chips (Open/Resolved), assigned officers
4. **Areas**: 6 Chennai zones with risk score bars and enable/disable toggles

### ML Explainability (SHAP)

Rakshak uses SHAP (SHapley Additive exPlanations) to explain why the ML model predicts a location as HIGH, MEDIUM, or LOW risk.

**Example: Why is this location HIGH RISK at 11 PM?**

Key factors contributing to HIGH RISK prediction:
- `reporting_delay_minutes = 45` → **+0.13** (long delays in reporting crimes)
- `latitude = 13.083` → **+0.11** (historically high-crime area)
- `response_time_minutes = 18` → **+0.08** (slower police response)
- `pincode = 600001` → **+0.09** (high-crime postal code)
- `is_night = 1` → **+0.02** (nighttime hour)

**Top Features by Importance:**
1. **latitude** (0.35 mean SHAP value) - Geographic location is the strongest predictor
2. **response_time_minutes** (0.20) - Faster response = safer area
3. **pincode** (0.20) - Postal codes capture neighborhood-level patterns
4. **reporting_delay_minutes** (0.18) - Longer delays indicate unsafe areas
5. **area_encoded** (0.15) - Administrative area classification

See [SCREENSHOTS.md](SCREENSHOTS.md) for detailed SHAP visualizations and explanations.

---

## Recognition

Rakshak was recognized by the AWS Builder Center as a "working system, not a concept" — commended for real engineering discipline, novel spatio-temporal feature engineering, and complete citizen-to-police workflow design.

---

## Contributors

**Vishal Ganesan** - Full-stack development, ML integration, UI/UX design

For development guidelines and contribution instructions, see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Developed for educational and hackathon purposes.

---

**Built with Flutter 💙 | Powered by AWS Lambda 🚀 | Trained with XGBoost 🤖**
