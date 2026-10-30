class ApiConfig {
  /// Default Gemini API key (empty by default, user enters in app settings)
  static const String defaultGeminiApiKey = '';

  /// Daily safety limit for free tier requests (Google allows up to 1500)
  static const int dailyRequestLimit = 1000;
}

