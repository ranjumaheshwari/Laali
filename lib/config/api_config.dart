// lib/config/api_config.dart
// Keep secrets out of source control. Provide the Gemini/OpenAI key via
// a Dart environment variable (use --dart-define=GEMINI_API_KEY=your_key
// when running or building) or another secure secret manager.
class ApiConfig {
  /// The Gemini API key. Empty when not provided — do NOT commit real keys.
  static const String geminiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
}