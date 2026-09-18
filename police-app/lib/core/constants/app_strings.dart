/// Bilingual strings for Rakshak Sentinel (English & Tamil)
class AppStrings {
  AppStrings._();

  // Language codes
  static const String english = 'en';
  static const String tamil = 'ta';

  // Common
  static const Map<String, String> appName = {
    'en': 'Rakshak',
    'ta': 'ரட்சகன்',
  };

  static const Map<String, String> loading = {
    'en': 'Loading...',
    'ta': 'ஏற்றுகிறது...',
  };

  static const Map<String, String> error = {
    'en': 'Error',
    'ta': 'பிழை',
  };

  static const Map<String, String> retry = {
    'en': 'Retry',
    'ta': 'மீண்டும் முயற்சிக்கவும்',
  };

  static const Map<String, String> cancel = {
    'en': 'Cancel',
    'ta': 'ரத்து செய்',
  };

  static const Map<String, String> confirm = {
    'en': 'Confirm',
    'ta': 'உறுதிப்படுத்து',
  };

  // Auth
  static const Map<String, String> loginTitle = {
    'en': 'Welcome to Rakshak',
    'ta': 'ரட்சகனுக்கு வரவேற்கிறோம்',
  };

  static const Map<String, String> loginSubtitle = {
    'en': 'Your AI-powered safety companion',
    'ta': 'உங்கள் AI சக்தி கொண்ட பாதுகாப்பு துணை',
  };

  static const Map<String, String> phoneNumber = {
    'en': 'Phone Number',
    'ta': 'தொலைபேசி எண்',
  };

  static const Map<String, String> enterPhone = {
    'en': 'Enter your phone number',
    'ta': 'உங்கள் தொலைபேசி எண்ணை உள்ளிடவும்',
  };

  static const Map<String, String> sendOtp = {
    'en': 'Send OTP',
    'ta': 'OTP அனுப்பு',
  };

  static const Map<String, String> verifyOtp = {
    'en': 'Verify OTP',
    'ta': 'OTP சரிபார்க்கவும்',
  };

  // Sentinel (Dashboard)
  static const Map<String, String> sentinel = {
    'en': 'Sentinel',
    'ta': 'காவலன்',
  };

  static const Map<String, String> riskScore = {
    'en': 'Risk Score',
    'ta': 'ஆபத்து மதிப்பெண்',
  };

  static const Map<String, String> currentLocation = {
    'en': 'Current Location',
    'ta': 'தற்போதைய இடம்',
  };

  static const Map<String, String> nightWatch = {
    'en': 'Night Watch',
    'ta': 'இரவு காவல்',
  };

  static const Map<String, String> activateNightWatch = {
    'en': 'Activate Night Watch',
    'ta': 'இரவு காவலை செயல்படுத்து',
  };

  static const Map<String, String> sos = {
    'en': 'SOS',
    'ta': 'SOS',
  };

  static const Map<String, String> emergencySos = {
    'en': 'Emergency SOS',
    'ta': 'அவசர SOS',
  };

  // Intelligence
  static const Map<String, String> intelligence = {
    'en': 'Intelligence',
    'ta': 'நுண்ணறிவு',
  };

  static const Map<String, String> scanLocation = {
    'en': 'Scan Location',
    'ta': 'இடத்தை ஸ்கேன் செய்',
  };

  static const Map<String, String> analyzing = {
    'en': 'Analyzing...',
    'ta': 'பகுப்பாய்வு செய்கிறது...',
  };

  static const Map<String, String> riskAnalysis = {
    'en': 'Risk Analysis',
    'ta': 'ஆபத்து பகுப்பாய்வு',
  };

  // User Space
  static const Map<String, String> userSpace = {
    'en': 'User Space',
    'ta': 'பயனர் இடம்',
  };

  static const Map<String, String> profile = {
    'en': 'Profile',
    'ta': 'சுயவிவரம்',
  };

  static const Map<String, String> emergencyContacts = {
    'en': 'Emergency Contacts',
    'ta': 'அவசர தொடர்புகள்',
  };

  static const Map<String, String> settings = {
    'en': 'Settings',
    'ta': 'அமைப்புகள்',
  };

  // Risk Levels
  static const Map<String, String> riskLow = {
    'en': 'Low Risk',
    'ta': 'குறைந்த ஆபத்து',
  };

  static const Map<String, String> riskMedium = {
    'en': 'Medium Risk',
    'ta': 'நடுத்தர ஆபத்து',
  };

  static const Map<String, String> riskHigh = {
    'en': 'High Risk',
    'ta': 'அதிக ஆபத்து',
  };

  static const Map<String, String> riskCritical = {
    'en': 'Critical Risk',
    'ta': 'முக்கியமான ஆபத்து',
  };

  // Bottom Navigation
  static const Map<String, String> navSentinel = {
    'en': 'Sentinel',
    'ta': 'காவலன்',
  };

  static const Map<String, String> navAlerts = {
    'en': 'Alerts',
    'ta': 'எச்சரிக்கைகள்',
  };

  static const Map<String, String> navMap = {
    'en': 'Map',
    'ta': 'வரைபடம்',
  };

  static const Map<String, String> navUserSpace = {
    'en': 'Profile',
    'ta': 'சுயவிவரம்',
  };

  // Network / API errors
  static const Map<String, String> networkError = {
    'en': 'Network error. Check your connection and try again.',
    'ta': 'நெட்வொர்க் பிழை. உங்கள் இணைப்பை சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
  };

  static const Map<String, String> serverError = {
    'en': 'Server error. Please try again later.',
    'ta': 'சர்வர் பிழை. பின்னர் மீண்டும் முயற்சிக்கவும்.',
  };

  static const Map<String, String> timeoutError = {
    'en': 'Request timed out. Please try again.',
    'ta': 'கோரிக்கை நேர்முகமானது. மீண்டும் முயற்சிக்கவும்.',
  };

  // Helper method to get string by language
  static String get(Map<String, String> strings, String lang) {
    return strings[lang] ?? strings['en']!;
  }
}
