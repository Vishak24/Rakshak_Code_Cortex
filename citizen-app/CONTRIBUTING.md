# Contributing to Rakshak

Thank you for your interest in Rakshak! This document provides guidelines for understanding and contributing to the project.

---

## Project Overview

Rakshak is a production-ready Flutter application with:
- **Mobile app** for end users (women in Chennai)
- **Web dashboard** for police departments
- **AWS Lambda backend** for ML inference
- **XGBoost ML model** trained on Chennai crime data

---

## Development Setup

### Prerequisites
- Flutter SDK 3.0.0+ ([Install Flutter](https://docs.flutter.dev/get-started/install))
- Dart 3.0.0+
- Android Studio (for Android builds)
- Xcode (for iOS builds, macOS only)
- Chrome (for web development)
- Node.js 18+ (for Playwright E2E tests)

### Initial Setup

1. **Clone the repository**:
```bash
git clone https://github.com/Vishak24/rakshak.git
cd rakshak
```

2. **Set up Google Maps API Key**:
   - Get your API key from [Google Cloud Console](https://console.cloud.google.com/google/maps-apis)
   - Enable Maps SDK for Android, Maps SDK for iOS, and Geocoding API
   - Add your key to:
     - `android/app/src/main/AndroidManifest.xml` (replace `YOUR_GOOGLE_MAPS_API_KEY_HERE`)
     - `ios/Runner/Info.plist` (replace `YOUR_GOOGLE_MAPS_API_KEY_HERE`)
   - **Never commit your actual API key to the repository**

3. **Install Flutter dependencies**:
```bash
flutter pub get
```

3. **Install Playwright dependencies** (for E2E tests):
```bash
npm install
npx playwright install
```

4. **Verify setup**:
```bash
flutter doctor
```

---

## Project Structure

```
lib/
├── main.dart                    # Mobile app entry point
├── main_web.dart                # Legacy admin dashboard (not used by the demo)
├── core/                        # Shared utilities
│   ├── constants/               # API endpoints, app strings
│   ├── models/                  # Data models
│   ├── providers/               # Riverpod state management
│   ├── router/                  # GoRouter navigation
│   ├── theme/                   # Design system (colors, text, spacing)
│   └── widgets/                 # Reusable UI components
├── features/                    # Feature modules (Clean Architecture)
│   ├── alerts/                  # Alert notifications
│   ├── auth/                    # Authentication
│   ├── intelligence/            # Risk prediction logic
│   ├── map/                     # Map visualization
│   ├── sentinel/                # Background monitoring
│   ├── sos/                     # Emergency SOS
│   └── user_space/              # User profile
└── presentation/
    └── web/                     # Web dashboard screens

test/                            # Unit tests
integration_test/                # Integration tests
tests/                           # E2E Playwright tests
```

### Architecture Pattern

Rakshak follows **Clean Architecture** with feature-based organization:

```
features/
└── <feature_name>/
    ├── data/                    # API clients, repositories
    ├── domain/                  # Business logic, entities
    └── presentation/            # UI screens, widgets
```

**Example**: `features/intelligence/`
- `data/intelligence_repository.dart` - API calls to AWS Lambda
- `domain/risk_calculator.dart` - Business logic for risk scoring
- `presentation/risk_result_screen.dart` - UI for displaying risk

---

## Running the App

### Mobile App (Android/iOS)
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run in debug mode (hot reload enabled)
flutter run

# Run in release mode (optimized)
flutter run --release
```

### Web Dashboard
```bash
# Run web dashboard in Chrome
flutter run -d chrome --target lib/main_citizen.dart

# Build for production
flutter build web --release --target lib/main_citizen.dart
```

---

## Testing

### Unit Tests
```bash
# Run all unit tests
flutter test

# Run specific test file
flutter test test/domain/risk_calculator_test.dart

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Integration Tests
```bash
# Run integration tests on connected device
flutter test integration_test/

# Run on specific device
flutter test integration_test/ -d <device-id>
```

### E2E Tests (Playwright)
```bash
# Run all E2E tests
npx playwright test

# Run specific test
npx playwright test tests/risk-high.spec.ts

# Run in headed mode (see browser)
npx playwright test --headed

# Debug mode
npx playwright test --debug
```

---

## Code Style

### Dart Style Guide
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `flutter analyze` to check for issues
- Format code with `dart format .`

### Naming Conventions
- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables/Functions**: `camelCase`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Private members**: `_leadingUnderscore`

### Widget Naming
- Prefix custom widgets with `Rk` (e.g., `RkButton`, `RkCard`)
- Screen widgets end with `Screen` (e.g., `HomeScreen`, `RiskMapScreen`)
- Page widgets end with `Page` (e.g., `AnalyticsPage`)

---

## State Management

Rakshak uses **Riverpod** for state management.

### Provider Types
- **Provider**: Immutable data (e.g., API endpoints)
- **StateProvider**: Simple mutable state (e.g., selected tab)
- **StateNotifierProvider**: Complex state with logic (e.g., risk prediction state)
- **FutureProvider**: Async data fetching (e.g., API calls)

### Example
```dart
// Define provider
final riskScoreProvider = StateNotifierProvider<RiskScoreNotifier, RiskScoreState>(
  (ref) => RiskScoreNotifier(ref.read(intelligenceRepositoryProvider)),
);

// Use in widget
class RiskResultScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riskState = ref.watch(riskScoreProvider);
    
    return riskState.when(
      loading: () => CircularProgressIndicator(),
      data: (score) => RiskBadge(score: score),
      error: (err, stack) => ErrorWidget(err),
    );
  }
}
```

---

## API Integration

### Endpoint
```
POST https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com/predict
```

### Request Example
```dart
final response = await dio.post(
  'https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com/predict',
  data: {
    'latitude': 13.0827,
    'longitude': 80.2707,
    'hour': 23,
    'is_night': 1,
    'pincode': 600001,
    'area_encoded': 3,
    'neighborhood_encoded': 7,
  },
);
```

### Response Example
```json
{
  "risk_level": "High",
  "risk_score": 0.87,
  "response_time_minutes": 18,
  "confidence": 0.92
}
```

---

## Building for Production

### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS
```bash
flutter build ios --release
# Then open ios/Runner.xcworkspace in Xcode and archive
```

### Web
```bash
flutter build web --release --target lib/main_citizen.dart
# Output: build/web/
```

---

## Deployment

### Mobile App
- **Android**: Upload `app-release.aab` to Google Play Console
- **iOS**: Archive in Xcode and upload to App Store Connect

### Web Dashboard
- **Firebase Hosting**:
  ```bash
  firebase init hosting
  firebase deploy --only hosting
  ```
- **Netlify**:
  ```bash
  netlify deploy --dir=build/web --prod
  ```
- **AWS S3 + CloudFront**:
  ```bash
  aws s3 sync build/web/ s3://your-bucket-name
  ```

---

## Common Issues

### Issue: "Waiting for another flutter command to release the startup lock"
**Solution**:
```bash
rm -rf ~/.flutter/bin/cache/lockfile
```

### Issue: "CocoaPods not installed" (iOS)
**Solution**:
```bash
sudo gem install cocoapods
cd ios && pod install
```

### Issue: "Gradle build failed" (Android)
**Solution**:
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Issue: "Google Maps not showing"
**Solution**: Verify API key in:
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

---

## Git Workflow

### Branch Naming
- `feature/<feature-name>` - New features
- `bugfix/<bug-name>` - Bug fixes
- `hotfix/<issue-name>` - Urgent production fixes
- `refactor/<component-name>` - Code refactoring

### Commit Messages
Follow [Conventional Commits](https://www.conventionalcommits.org/):
- `feat: add SOS button to result screen`
- `fix: resolve map rendering issue on iOS`
- `docs: update README with API documentation`
- `test: add unit tests for risk calculator`
- `refactor: extract risk badge into reusable widget`

---

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Riverpod Documentation](https://riverpod.dev/)
- [GoRouter Documentation](https://pub.dev/packages/go_router)
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter)
- [Playwright Documentation](https://playwright.dev/)

---

## Contact

For questions or issues, please open a GitHub issue or contact the maintainer.

---

**Happy Coding! 🚀**
