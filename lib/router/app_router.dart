import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/signup_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/invitations/invitations_screen.dart';
import '../presentation/screens/no_tenant/no_tenant_screen.dart';
import '../presentation/screens/onboarding/onboarding_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/profile/change_password_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/tenants/tenant_list_screen.dart';
import '../presentation/screens/assignment/assignment_screen.dart';
import '../presentation/screens/order/order_detail_screen.dart';
import '../presentation/screens/delivery/delivery_screen.dart';
import '../presentation/screens/delivery/delivery_success_screen.dart';

/// Route names
class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String invitations = '/invitations';
  static const String tenants = '/tenants';
  static const String noTenant = '/no-tenant';
  static const String home = '/home';
  static const String assignment = '/assignment';
  static const String orderDetail = '/orders/:id';
  static const String delivery = '/deliver/:id';
  static const String deliverySuccess = '/deliver/:id/success';
  static const String profile = '/profile';
  static const String changePassword = '/profile/password';
  static const String settings = '/settings';
}

/// Listenable that notifies when auth state changes (for GoRouter refreshListenable)
/// This prevents router recreation while still allowing it to react to auth changes.
class _AuthStateChangeNotifier extends ChangeNotifier {
  final Ref _ref;
  AuthStatus? _lastStatus;

  _AuthStateChangeNotifier(this._ref) {
    debugPrint('[Router] AuthStateChangeNotifier created');
    // Listen to auth provider changes and notify router
    _ref.listen<AuthState>(authProvider, (previous, next) {
      debugPrint('[Router] Auth state changed: ${previous?.status} -> ${next.status}');
      if (_lastStatus != next.status) {
        _lastStatus = next.status;
        debugPrint('[Router] Notifying router of auth change');
        notifyListeners();
      }
    });
  }
}

/// Provider for the auth state change notifier
final _authChangeNotifierProvider = Provider<_AuthStateChangeNotifier>((ref) {
  return _AuthStateChangeNotifier(ref);
});

/// App router provider
/// IMPORTANT: Uses ref.read() instead of ref.watch() to prevent router recreation.
/// Auth state changes are handled via refreshListenable instead.
final appRouterProvider = Provider<GoRouter>((ref) {
  debugPrint('[Router] Creating GoRouter instance');
  
  // Get the change notifier for refresh (this triggers rebuilds without recreating router)
  final authChangeNotifier = ref.watch(_authChangeNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    // Use refreshListenable instead of watching auth state in provider
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      // READ auth state here (inside redirect), not in provider creation
      final authState = ref.read(authProvider);
      
      final currentPath = state.matchedLocation;
      final isAuthRoute = currentPath == AppRoutes.login ||
          currentPath == AppRoutes.signup ||
          currentPath == AppRoutes.onboarding;
      final isSplashRoute = currentPath == AppRoutes.splash;

      debugPrint('[Router] Redirect check: path=$currentPath, authStatus=${authState.status}');

      // Don't redirect from splash - let it handle navigation
      if (isSplashRoute) {
        debugPrint('[Router] On splash, no redirect');
        return null;
      }

      // Handle auth status
      switch (authState.status) {
        case AuthStatus.initial:
        case AuthStatus.loading:
          debugPrint('[Router] Auth loading/initial, no redirect');
          return null; // Stay on current page while loading
        case AuthStatus.unauthenticated:
          if (!isAuthRoute) {
            debugPrint('[Router] Unauthenticated, redirecting to login');
            return AppRoutes.login;
          }
          return null;
        case AuthStatus.noTenant:
          if (isAuthRoute) {
            debugPrint('[Router] No tenant, redirecting from auth route to noTenant');
            return AppRoutes.noTenant;
          }
          if (currentPath == AppRoutes.noTenant ||
              currentPath == AppRoutes.invitations) {
            return null;
          }
          debugPrint('[Router] No tenant, redirecting to noTenant');
          return AppRoutes.noTenant;
        case AuthStatus.authenticated:
          if (isAuthRoute || currentPath == AppRoutes.noTenant) {
            debugPrint('[Router] Authenticated, redirecting to home');
            return AppRoutes.home;
          }
          return null;
        case AuthStatus.error:
          if (!isAuthRoute) {
            debugPrint('[Router] Auth error, redirecting to login');
            return AppRoutes.login;
          }
          return null;
      }
    },
    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Onboarding
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),

      // Tenant routes
      GoRoute(
        path: AppRoutes.noTenant,
        builder: (context, state) => const NoTenantScreen(),
      ),
      GoRoute(
        path: AppRoutes.invitations,
        builder: (context, state) => const InvitationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.tenants,
        builder: (context, state) => const TenantListScreen(),
      ),

      // Main app routes
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.assignment,
        builder: (context, state) => const AssignmentScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderDetail,
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return OrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: AppRoutes.delivery,
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return DeliveryScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: AppRoutes.deliverySuccess,
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return DeliverySuccessScreen(orderId: orderId);
        },
      ),

      // Profile routes
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});
