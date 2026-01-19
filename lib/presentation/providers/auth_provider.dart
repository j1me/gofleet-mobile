import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/models.dart';
import '../../services/api/api_client.dart';
import '../../services/storage/local_storage.dart';
import '../../services/storage/token_storage.dart';
import 'providers.dart';

/// Auth state enum
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  noTenant,
  error,
}

/// Auth state class
class AuthState {
  final AuthStatus status;
  final Driver? driver;
  final List<Tenant> tenants;
  final Tenant? activeTenant;
  final List<Invitation> invitations;
  final String? error;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.initial,
    this.driver,
    this.tenants = const [],
    this.activeTenant,
    this.invitations = const [],
    this.error,
    this.isLoading = false,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasNoTenant => status == AuthStatus.noTenant;
  bool get hasTenants => tenants.isNotEmpty;
  bool get hasInvitations => invitations.isNotEmpty;

  AuthState copyWith({
    AuthStatus? status,
    Driver? driver,
    List<Tenant>? tenants,
    Tenant? activeTenant,
    List<Invitation>? invitations,
    String? error,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      driver: driver ?? this.driver,
      tenants: tenants ?? this.tenants,
      activeTenant: activeTenant ?? this.activeTenant,
      invitations: invitations ?? this.invitations,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Auth notifier for managing authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final LocalStorage _localStorage;

  AuthNotifier({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
    required LocalStorage localStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage,
        _localStorage = localStorage,
        super(const AuthState());

  /// Check initial auth state
  Future<void> checkAuthState() async {
    state = state.copyWith(status: AuthStatus.loading, isLoading: true);

    try {
      final hasTokens = await _tokenStorage.hasTokens();
      if (!hasTokens) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
        );
        return;
      }

      // Validate tokens by fetching profile
      final driver = await _apiClient.getProfile();
      final tenants = await _apiClient.getTenants();
      final invitations = await _apiClient.getInvitations();

      if (tenants.isEmpty) {
        state = state.copyWith(
          status: AuthStatus.noTenant,
          driver: driver,
          tenants: tenants,
          invitations: invitations,
          isLoading: false,
        );
      } else {
        // Find active tenant (one with matching tenant_id in driver)
        Tenant? activeTenant;
        if (driver.tenantId != null) {
          activeTenant = tenants.firstWhere(
            (t) => t.id == driver.tenantId,
            orElse: () => tenants.first,
          );
        } else {
          activeTenant = tenants.first;
        }

        state = state.copyWith(
          status: AuthStatus.authenticated,
          driver: driver,
          tenants: tenants,
          activeTenant: activeTenant,
          invitations: invitations,
          isLoading: false,
        );
      }
    } on ApiException catch (e) {
      if (e.isAuthError) {
        await _tokenStorage.clearTokens();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          error: e.message,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  /// Login with phone and password
  Future<void> login({
    required String phone,
    required String password,
    String? deviceId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.login(
        phone: phone,
        password: password,
        deviceId: deviceId,
      );

      // Fetch invitations opportunistically; don't fail login if it errors.
      List<Invitation> invitations = const [];
      try {
        invitations = await _apiClient.getInvitations();
      } catch (_) {
        // Ignore invitation fetch errors during login.
      }

      if (response.tenants.isEmpty && response.activeTenant == null) {
        state = state.copyWith(
          status: AuthStatus.noTenant,
          driver: response.driver,
          tenants: response.tenants,
          invitations: invitations,
          isLoading: false,
        );
      } else {
        await _localStorage.setLastActiveTenantId(response.activeTenant?.id);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          driver: response.driver,
          tenants: response.tenants,
          activeTenant: response.activeTenant,
          invitations: invitations,
          isLoading: false,
        );
      }
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Signup new driver
  Future<void> signup({
    required String name,
    required String phone,
    required String password,
    String? email,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.signup(
        name: name,
        phone: phone,
        password: password,
        email: email,
      );

      // New drivers typically don't have tenants yet; skip invitations fetch
      // to avoid auth/tenant edge cases right after signup.
      state = state.copyWith(
        status: AuthStatus.noTenant,
        driver: response.driver,
        tenants: response.tenants,
        invitations: const [],
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      await _apiClient.logout();
      await _localStorage.setLastActiveTenantId(null);
    } catch (_) {
      // Ignore errors during logout
    } finally {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Accept invitation
  Future<void> acceptInvitation(String invitationId, String tenantId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Accept invitation - this saves new tokens and returns tenant info
      final response = await _apiClient.acceptInvitation(invitationId);
      
      // Extract tenant from response
      final tenantData = response['tenant'] as Map<String, dynamic>?;
      Tenant? newTenant;
      if (tenantData != null) {
        newTenant = Tenant.fromJson(tenantData);
      }

      // Refresh profile and tenants with fresh tokens
      final driver = await _apiClient.getProfile();
      final tenants = await _apiClient.getTenants();
      final invitations = await _apiClient.getInvitations();

      // Use returned tenant or find from tenants list
      final activeTenant = newTenant ?? tenants.firstWhere((t) => t.id == tenantId);
      await _localStorage.setLastActiveTenantId(activeTenant.id);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        driver: driver,
        tenants: tenants,
        activeTenant: activeTenant,
        invitations: invitations,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      rethrow;
    }
  }

  /// Reject invitation
  Future<void> rejectInvitation(String invitationId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _apiClient.rejectInvitation(invitationId);

      // Remove from local list
      final updatedInvitations =
          state.invitations.where((i) => i.id != invitationId).toList();

      state = state.copyWith(
        invitations: updatedInvitations,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      rethrow;
    }
  }

  /// Switch active tenant
  Future<void> switchTenant(String tenantId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _apiClient.switchTenant(tenantId);
      await _localStorage.setLastActiveTenantId(tenantId);

      // Refresh profile with new tenant context
      final driver = await _apiClient.getProfile();

      state = state.copyWith(
        driver: driver,
        activeTenant: result.tenant,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      rethrow;
    }
  }

  /// Leave tenant
  Future<void> leaveTenant(String tenantId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _apiClient.leaveTenant(tenantId);

      // Refresh tenants
      final tenants = await _apiClient.getTenants();
      final driver = await _apiClient.getProfile();

      if (tenants.isEmpty) {
        await _localStorage.setLastActiveTenantId(null);
        state = state.copyWith(
          status: AuthStatus.noTenant,
          driver: driver,
          tenants: tenants,
          activeTenant: null,
          isLoading: false,
        );
      } else {
        // Switch to first available tenant if we left the active one
        Tenant? newActiveTenant = state.activeTenant;
        if (state.activeTenant?.id == tenantId) {
          newActiveTenant = tenants.first;
          await _apiClient.switchTenant(newActiveTenant.id);
          await _localStorage.setLastActiveTenantId(newActiveTenant.id);
        }

        state = state.copyWith(
          tenants: tenants,
          activeTenant: newActiveTenant,
          isLoading: false,
        );
      }
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      rethrow;
    }
  }

  /// Refresh invitations
  Future<void> refreshInvitations() async {
    try {
      final invitations = await _apiClient.getInvitations();
      state = state.copyWith(invitations: invitations);
    } catch (_) {
      // Ignore errors
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    localStorage: ref.watch(localStorageProvider),
  );
});

/// Convenience providers
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentDriverProvider = Provider<Driver?>((ref) {
  return ref.watch(authProvider).driver;
});

final activeTenantProvider = Provider<Tenant?>((ref) {
  return ref.watch(authProvider).activeTenant;
});

final pendingInvitationsProvider = Provider<List<Invitation>>((ref) {
  return ref.watch(authProvider).invitations;
});
