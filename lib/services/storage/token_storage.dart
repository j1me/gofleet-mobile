import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/auth_tokens.dart';

/// Secure storage service for authentication tokens
class TokenStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// Save both access and refresh tokens
  Future<void> saveTokens(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: tokens.accessToken),
      _storage.write(key: _refreshTokenKey, value: tokens.refreshToken),
    ]);
  }

  /// Save access token only
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  /// Save refresh token only
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  /// Get access token (with timeout protection)
  Future<String?> getAccessToken() async {
    debugPrint('[TokenStorage] getAccessToken() START');
    try {
      final token = await _storage.read(key: _accessTokenKey)
          .timeout(const Duration(seconds: 3));
      debugPrint('[TokenStorage] getAccessToken() = ${token != null ? "[TOKEN_EXISTS]" : "null"}');
      return token;
    } on TimeoutException {
      debugPrint('[TokenStorage] getAccessToken() TIMEOUT');
      return null;
    } catch (e) {
      debugPrint('[TokenStorage] getAccessToken() ERROR: $e');
      return null;
    }
  }

  /// Get refresh token (with timeout protection)
  Future<String?> getRefreshToken() async {
    debugPrint('[TokenStorage] getRefreshToken() START');
    try {
      final token = await _storage.read(key: _refreshTokenKey)
          .timeout(const Duration(seconds: 3));
      debugPrint('[TokenStorage] getRefreshToken() = ${token != null ? "[TOKEN_EXISTS]" : "null"}');
      return token;
    } on TimeoutException {
      debugPrint('[TokenStorage] getRefreshToken() TIMEOUT');
      return null;
    } catch (e) {
      debugPrint('[TokenStorage] getRefreshToken() ERROR: $e');
      return null;
    }
  }

  /// Get both tokens
  Future<AuthTokens?> getTokens() async {
    final results = await Future.wait([
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _refreshTokenKey),
    ]);

    final accessToken = results[0];
    final refreshToken = results[1];

    if (accessToken == null || refreshToken == null) {
      return null;
    }

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  /// Check if tokens exist (with timeout protection for Android secure storage issues)
  Future<bool> hasTokens() async {
    debugPrint('[TokenStorage] hasTokens() START');
    final stopwatch = Stopwatch()..start();
    
    try {
      debugPrint('[TokenStorage] Reading access token from secure storage...');
      final accessToken = await _storage.read(key: _accessTokenKey)
          .timeout(const Duration(seconds: 3));
      
      final hasToken = accessToken != null;
      debugPrint('[TokenStorage] hasTokens() = $hasToken [${stopwatch.elapsedMilliseconds}ms]');
      return hasToken;
    } on TimeoutException {
      debugPrint('[TokenStorage] hasTokens() TIMEOUT after 3s - treating as no tokens');
      return false;
    } catch (e) {
      debugPrint('[TokenStorage] hasTokens() ERROR: $e [${stopwatch.elapsedMilliseconds}ms]');
      // On any error, treat as no tokens to avoid blocking
      return false;
    }
  }

  /// Clear all tokens
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  /// Clear all storage
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
