// Default entrypoint for citizen-app.
//
// This used to launch RakshakPoliceApp — a copy-paste leftover that meant
// `flutter build web` (no --target) shipped the police UI from the citizen
// project. It now delegates to the real citizen entrypoint, so both
// `flutter build web` and `flutter build web --target lib/main_citizen.dart`
// produce the citizen app.
import 'main_citizen.dart' as citizen;

void main() => citizen.main();
