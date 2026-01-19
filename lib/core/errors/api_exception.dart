/// API Exception class for handling API errors
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  /// Common error codes
  static const String validationError = 'VALIDATION_ERROR';
  static const String badRequest = 'BAD_REQUEST';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String tokenExpired = 'TOKEN_EXPIRED';
  static const String forbidden = 'FORBIDDEN';
  static const String tenantSuspended = 'TENANT_SUSPENDED';
  static const String tenantTerminated = 'TENANT_TERMINATED';
  static const String notFound = 'NOT_FOUND';
  static const String conflict = 'CONFLICT';
  static const String duplicate = 'DUPLICATE';
  static const String driverNotOnDuty = 'DRIVER_NOT_ON_DUTY';
  static const String idempotencyConflict = 'IDEMPOTENCY_CONFLICT';
  static const String rateLimitExceeded = 'RATE_LIMIT_EXCEEDED';
  static const String internalError = 'INTERNAL_ERROR';
  static const String networkError = 'NETWORK_ERROR';

  /// Check if this is an authentication error
  bool get isAuthError =>
      code == unauthorized ||
      code == invalidCredentials ||
      code == tokenExpired;

  /// Check if this is a tenant status error
  bool get isTenantError => code == tenantSuspended || code == tenantTerminated;

  /// Check if this is a rate limit error
  bool get isRateLimitError => code == rateLimitExceeded;

  /// Check if this is a network error
  bool get isNetworkError => code == networkError;

  /// Create from API response
  factory ApiException.fromResponse(Map<String, dynamic> response, int statusCode) {
    final error = response['error'] as Map<String, dynamic>?;
    return ApiException(
      code: error?['code'] as String? ?? 'UNKNOWN_ERROR',
      message: error?['message'] as String? ?? 'An unexpected error occurred',
      statusCode: statusCode,
      details: error?['details'] as Map<String, dynamic>?,
    );
  }

  /// Create network error
  factory ApiException.network([String? message]) {
    return ApiException(
      code: networkError,
      message: message ?? 'Network error. Please check your connection.',
    );
  }

  /// Create unknown error
  factory ApiException.unknown([String? message]) {
    return ApiException(
      code: internalError,
      message: message ?? 'An unexpected error occurred',
    );
  }

  @override
  String toString() => message;
}
