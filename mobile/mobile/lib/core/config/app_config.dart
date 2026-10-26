/// Build-time configuration. Override with:
///   flutter run --dart-define=API_BASE_URL=https://api.example.org/api/v1
abstract final class AppConfig {
  /// Production unless a test build overrides it (e.g. http://localhost:4000/api/v1 together with
  /// "adb reverse tcp:4000 tcp:4000"; plain HTTP is only allowed for local hosts).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://app.hersolan.pro/api/v1',
  );

  static const appVersion = '1.5.3';

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 30);
  static const pageSize = 20;
}
