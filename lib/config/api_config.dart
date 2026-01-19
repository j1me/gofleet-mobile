/// API Configuration for GoFleet Driver App
class ApiConfig {
  ApiConfig._();

  /// Production API base URL
  static const String prodBaseUrl = 'https://api.gofleet.cloud';

  /// Development API base URL
  static const String devBaseUrl = 'http://localhost:3000';

  /// Current base URL (change for different environments)
  static const String baseUrl = prodBaseUrl;

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Connection timeout duration
  static const Duration connectTimeout = Duration(seconds: 30);

  /// Location update interval (while on shift)
  static const Duration locationUpdateInterval = Duration(seconds: 10);

  /// Location update rate limit (max 2 per 10 seconds)
  static const int locationRateLimitPerInterval = 2;
  static const Duration locationRateLimitInterval = Duration(seconds: 10);

  /// Assignment polling interval (when on duty, no assignment)
  static const Duration assignmentPollingInterval = Duration(seconds: 30);
}
