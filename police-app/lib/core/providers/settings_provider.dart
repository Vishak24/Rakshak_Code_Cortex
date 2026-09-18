import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings state
class SettingsState {
  final String languageCode;
  final bool isDarkMode;

  const SettingsState({
    this.languageCode = 'en',
    this.isDarkMode = true,
  });

  SettingsState copyWith({
    String? languageCode,
    bool? isDarkMode,
  }) {
    return SettingsState(
      languageCode: languageCode ?? this.languageCode,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}

/// Settings notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void setLanguage(String languageCode) {
    state = state.copyWith(languageCode: languageCode);
  }

  void toggleLanguage() {
    final newLang = state.languageCode == 'en' ? 'ta' : 'en';
    state = state.copyWith(languageCode: newLang);
  }

  void setDarkMode(bool isDark) {
    state = state.copyWith(isDarkMode: isDark);
  }
}

/// Settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
