import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../data/models/models.dart';
import '../storage/token_storage.dart';

/// API Client for GoFleet Driver endpoints
class ApiClient {
  final Dio _dio;
  final TokenStorage _tokenStorage;
  final Uuid _uuid = const Uuid();

  bool _isRefreshing = false;
  final List<Completer<void>> _refreshQueue = [];

  ApiClient({
    required TokenStorage tokenStorage,
    Dio? dio,
  })  : _tokenStorage = tokenStorage,
        _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.requestTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(this, _tokenStorage),
      _LoggingInterceptor(),
    ]);
  }

  // ============== Auth Endpoints ==============

  /// Login with phone and password
  Future<LoginResponse> login({
    required String phone,
    required String password,
    String? deviceId,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/driver/login',
        data: {
          'phone': phone,
          'password': password,
          if (deviceId != null) 'device_id': deviceId,
        },
      );
      final loginResponse = LoginResponse.fromJson(response.data);
      await _tokenStorage.saveTokens(loginResponse.tokens);
      return loginResponse;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Signup new driver
  Future<LoginResponse> signup({
    required String name,
    required String phone,
    required String password,
    String? email,
  }) async {
    try {
      final response = await _dio.post(
        '/public/driver/signup',
        data: {
          'name': name,
          'phone': phone,
          'password': password,
          if (email != null && email.isNotEmpty) 'email': email,
        },
      );
      final loginResponse = LoginResponse.fromJson(response.data);
      await _tokenStorage.saveTokens(loginResponse.tokens);
      return loginResponse;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Refresh access token
  Future<AuthTokens> refreshToken() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        throw const ApiException(
          code: ApiException.unauthorized,
          message: 'No refresh token available',
        );
      }

      final response = await _dio.post(
        '/auth/driver/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {'Authorization': null}, // Don't send expired access token
        ),
      );

      final tokens = AuthTokens.fromJson(response.data);
      await _tokenStorage.saveTokens(tokens);
      return tokens;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken != null) {
        await _dio.post(
          '/auth/driver/logout',
          data: {'refresh_token': refreshToken},
        );
      }
    } catch (_) {
      // Ignore errors during logout
    } finally {
      await _tokenStorage.clearTokens();
    }
  }

  /// Update password
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/driver/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      // Clear tokens after password change - user must login again
      await _tokenStorage.clearTokens();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ============== Profile Endpoints ==============

  /// Get driver profile
  Future<Driver> getProfile() async {
    try {
      final response = await _dio.get('/driver/me');
      return Driver.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ============== Shift Endpoints ==============

  /// Start shift
  Future<DateTime> startShift() async {
    try {
      final response = await _dio.post('/driver/shift/start');
      return DateTime.parse(response.data['shift_started_at'] as String);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// End shift
  Future<void> endShift() async {
    try {
      await _dio.post('/driver/shift/end');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ============== Invitation Endpoints ==============

  /// Get pending invitations
  Future<List<Invitation>> getInvitations() async {
    try {
      final response = await _dio.get('/driver/invitations');
      final data = response.data['data'] as List<dynamic>;
      return data
          .map((i) => Invitation.fromJson(i as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Accept invitation - returns response with new tokens and tenant info
  Future<Map<String, dynamic>> acceptInvitation(String invitationId) async {
    try {
      final response = await _dio.post('/driver/invitations/$invitationId/accept');
      
      // Save new tokens returned by the backend
      final accessToken = response.data['access_token'] as String?;
      final refreshToken = response.data['refresh_token'] as String?;
      if (accessToken != null && refreshToken != null) {
        await _tokenStorage.saveTokens(AuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        ));
      }
      
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Reject invitation
  Future<void> rejectInvitation(String invitationId) async {
    try {
      await _dio.post('/driver/invitations/$invitationId/reject');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ============== Tenant Endpoints ==============

  /// Get driver's tenants
  Future<List<Tenant>> getTenants() async {
    try {
      final response = await _dio.get('/driver/tenants');
      final data = response.data['data'] as List<dynamic>;
      return data
          .map((t) => Tenant.fromJson(t as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Switch active tenant
  Future<({String accessToken, Tenant tenant})> switchTenant(
      String tenantId) async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      final response = await _dio.post(
        '/driver/tenants/switch',
        data: {'tenant_id': tenantId},
        options: Options(
          headers: {'X-Refresh-Token': refreshToken},
        ),
      );

      final accessToken = response.data['access_token'] as String;
      final tenant =
          Tenant.fromJson(response.data['tenant'] as Map<String, dynamic>);

      // Save new access token
      await _tokenStorage.saveAccessToken(accessToken);

      return (accessToken: accessToken, tenant: tenant);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Leave tenant
  Future<void> leaveTenant(String tenantId) async {
    try {
      await _dio.delete('/driver/tenants/$tenantId');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ============== Assignment Endpoints ==============

  /// Get active assignment
  Future<Assignment?> getActiveAssignment() async {
    try {
      final response = await _dio.get('/driver/assignments/active');
      return Assignment.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // No active assignment
      }
      throw _handleDioError(e);
    }
  }

  /// Start active assignment (transitions from created to started)
  Future<Assignment> startAssignment() async {
    try {
      final response = await _dio.post('/driver/assignments/active/start');
      return Assignment.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ============== Order Endpoints ==============

  /// Get order details
  Future<Order> getOrder(String orderId) async {
    try {
      final response = await _dio.get('/driver/orders/$orderId');
      return Order.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Update order status (delivered or failed)
  Future<({String orderId, String status, String eventId})> updateOrderStatus({
    required String orderId,
    required String status,
    required double lat,
    required double lng,
    required DateTime occurredAt,
    String? notes,
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey ?? _uuid.v4();
      final response = await _dio.post(
        '/driver/orders/$orderId/status',
        data: {
          'status': status,
          'lat': lat,
          'lng': lng,
          'occurred_at': occurredAt.toIso8601String(),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
        options: Options(
          headers: {'Idempotency-Key': key},
        ),
      );

      return (
        orderId: response.data['order_id'] as String,
        status: response.data['status'] as String,
        eventId: response.data['event_id'] as String,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ============== Location Endpoints ==============

  /// Update driver location
  Future<void> updateLocation({
    required double lat,
    required double lng,
    double? speed,
    double? heading,
    double? accuracy,
    DateTime? capturedAt,
  }) async {
    try {
      await _dio.post(
        '/driver/location',
        data: {
          'lat': lat,
          'lng': lng,
          if (speed != null) 'speed': speed,
          if (heading != null) 'heading': heading,
          if (accuracy != null) 'accuracy': accuracy,
          if (capturedAt != null) 'captured_at': capturedAt.toIso8601String(),
        },
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // ============== Error Handling ==============

  ApiException _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ApiException.network();
    }

    if (e.response != null) {
      final statusCode = e.response!.statusCode ?? 500;
      final data = e.response!.data;

      if (data is Map<String, dynamic>) {
        return ApiException.fromResponse(data, statusCode);
      }

      return ApiException(
        code: 'HTTP_$statusCode',
        message: 'Request failed with status $statusCode',
        statusCode: statusCode,
      );
    }

    return ApiException.unknown(e.message);
  }

  // ============== Token Refresh ==============

  Future<void> _refreshTokenIfNeeded() async {
    if (_isRefreshing) {
      final completer = Completer<void>();
      _refreshQueue.add(completer);
      return completer.future;
    }

    _isRefreshing = true;

    try {
      await refreshToken();
      for (final completer in _refreshQueue) {
        completer.complete();
      }
    } catch (e) {
      for (final completer in _refreshQueue) {
        completer.completeError(e);
      }
      rethrow;
    } finally {
      _isRefreshing = false;
      _refreshQueue.clear();
    }
  }
}

/// Auth interceptor for adding token and handling 401s
class _AuthInterceptor extends Interceptor {
  final ApiClient _client;
  final TokenStorage _tokenStorage;

  _AuthInterceptor(this._client, this._tokenStorage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for public endpoints
    final publicEndpoints = [
      '/auth/driver/login',
      '/auth/driver/refresh',
      '/public/driver/signup',
      '/health',
    ];

    if (!publicEndpoints.any((e) => options.path.contains(e))) {
      final token = await _tokenStorage.getAccessToken();
      if (token != null) {
        final authHeader = token.startsWith('Bearer ') ? token : 'Bearer $token';
        options.headers['Authorization'] = authHeader;
      }
    }

    // Remove Content-Type and Accept for endpoints that don't need a body
    if ((options.path.contains('/invitations/') && (options.path.contains('/accept') || options.path.contains('/reject'))) ||
        options.path.contains('/driver/shift/start') ||
        options.path.contains('/driver/shift/end') ||
        options.path.contains('/driver/assignments/active/start')) {
      options.headers.remove('Content-Type');
      options.headers.remove('Accept');
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Don't retry refresh endpoint
      if (err.requestOptions.path.contains('/auth/driver/refresh')) {
        await _tokenStorage.clearTokens();
        handler.next(err);
        return;
      }

      try {
        await _client._refreshTokenIfNeeded();

        // Retry original request with new token
        final token = await _tokenStorage.getAccessToken();
        err.requestOptions.headers['Authorization'] = 'Bearer $token';

        final response = await _client._dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {
        // Refresh failed, clear tokens and pass error
        await _tokenStorage.clearTokens();
      }
    }

    handler.next(err);
  }
}

/// Logging interceptor for debugging
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('🌐 ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('✅ ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('❌ ${err.response?.statusCode} ${err.requestOptions.path}');
    print('   Error: ${err.response?.data}');
    handler.next(err);
  }
}
