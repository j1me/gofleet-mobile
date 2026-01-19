import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api/api_client.dart';
import '../../services/storage/local_storage.dart';
import '../../services/storage/token_storage.dart';

/// Token storage provider
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// Local storage provider
final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage();
});

/// API client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(tokenStorage: tokenStorage);
});
