import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../../router/app_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _navigated = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    debugPrint('[Splash] initState: Animation started');
    
    // Defer navigation until after first frame to ensure router is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[Splash] initState: Post frame callback triggered, calling _initializeApp');
      _initializeApp();
    });

    // Fallback: if something blocks init, go to login after 8 seconds.
    _fallbackTimer = Timer(const Duration(seconds: 8), () {
      debugPrint('[Splash] FALLBACK TIMER FIRED - forcing navigation to login');
      _safeGo(AppRoutes.login);
    });
  }

  void _safeGo(String route) {
    debugPrint('[Splash] _safeGo called with route: $route');
    debugPrint('[Splash] mounted: $mounted, _navigated: $_navigated');
    
    if (!mounted || _navigated) {
      debugPrint('[Splash] _safeGo SKIPPED - already navigated or not mounted');
      return;
    }
    _navigated = true;
    _fallbackTimer?.cancel();
    debugPrint('[Splash] Attempting navigation to: $route');
    
    // Use router directly to avoid context timing issues on some devices.
    try {
      final router = ref.read(appRouterProvider);
      debugPrint('[Splash] Got router instance, calling go()');
      router.go(route);
      debugPrint('[Splash] Navigation call completed');
    } catch (e, stack) {
      debugPrint('[Splash] Navigation FAILED: $e');
      debugPrint('[Splash] Stack: $stack');
    }
  }

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();
    debugPrint('[Splash] _initializeApp START');
    
    try {
      // Initialize local storage
      debugPrint('[Splash] Step 1: Getting localStorage provider...');
      final localStorage = ref.read(localStorageProvider);
      debugPrint('[Splash] Step 2: Calling localStorage.init()... [${stopwatch.elapsedMilliseconds}ms]');
      await localStorage.init();
      debugPrint('[Splash] Step 2: localStorage.init() DONE [${stopwatch.elapsedMilliseconds}ms]');

      // Wait for animation to complete
      debugPrint('[Splash] Step 3: Waiting for animation delay... [${stopwatch.elapsedMilliseconds}ms]');
      await Future.delayed(const Duration(milliseconds: 2000));
      debugPrint('[Splash] Step 3: Animation delay DONE [${stopwatch.elapsedMilliseconds}ms]');

      if (!mounted) {
        debugPrint('[Splash] Widget not mounted after delay, aborting');
        return;
      }

      // Check if user has seen onboarding
      debugPrint('[Splash] Step 4: Checking hasSeenOnboarding... [${stopwatch.elapsedMilliseconds}ms]');
      final hasSeenOnboarding = await localStorage.hasSeenOnboarding();
      debugPrint('[Splash] Step 4: hasSeenOnboarding = $hasSeenOnboarding [${stopwatch.elapsedMilliseconds}ms]');

      // Try to check auth state (with timeout)
      debugPrint('[Splash] Step 5: Calling checkAuthState (5s timeout)... [${stopwatch.elapsedMilliseconds}ms]');
      try {
        await ref.read(authProvider.notifier).checkAuthState()
            .timeout(const Duration(seconds: 5));
        debugPrint('[Splash] Step 5: checkAuthState DONE [${stopwatch.elapsedMilliseconds}ms]');
      } catch (e) {
        // On any error, treat as unauthenticated
        debugPrint('[Splash] Step 5: checkAuthState FAILED: $e [${stopwatch.elapsedMilliseconds}ms]');
      }

      if (!mounted) {
        debugPrint('[Splash] Widget not mounted after auth check, aborting');
        return;
      }

      // Navigate based on auth state
      final authState = ref.read(authProvider);
      
      debugPrint('[Splash] Step 6: Reading final auth state [${stopwatch.elapsedMilliseconds}ms]');
      debugPrint('[Splash] Auth status: ${authState.status}');
      debugPrint('[Splash] Has seen onboarding: $hasSeenOnboarding');
      debugPrint('[Splash] isLoading: ${authState.isLoading}');
      debugPrint('[Splash] error: ${authState.error}');

      debugPrint('[Splash] Step 7: Determining navigation target... [${stopwatch.elapsedMilliseconds}ms]');
      switch (authState.status) {
        case AuthStatus.authenticated:
          debugPrint('[Splash] -> Navigating to HOME');
          _safeGo(AppRoutes.home);
          break;
        case AuthStatus.noTenant:
          if (authState.hasInvitations) {
            debugPrint('[Splash] -> Navigating to INVITATIONS');
            _safeGo(AppRoutes.invitations);
          } else {
            debugPrint('[Splash] -> Navigating to NO_TENANT');
            _safeGo(AppRoutes.noTenant);
          }
          break;
        case AuthStatus.unauthenticated:
        case AuthStatus.error:
        case AuthStatus.initial:
        case AuthStatus.loading:
          // For any non-authenticated state, go to login or onboarding
          if (!hasSeenOnboarding) {
            debugPrint('[Splash] -> Navigating to ONBOARDING');
            _safeGo(AppRoutes.onboarding);
          } else {
            debugPrint('[Splash] -> Navigating to LOGIN');
            _safeGo(AppRoutes.login);
          }
          break;
      }
      debugPrint('[Splash] _initializeApp COMPLETE [${stopwatch.elapsedMilliseconds}ms]');
    } catch (e, stack) {
      debugPrint('[Splash] _initializeApp ERROR: $e [${stopwatch.elapsedMilliseconds}ms]');
      debugPrint('[Splash] Stack: $stack');
      // On any error, navigate to login
      _safeGo(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo placeholder
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        size: 56,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'GoFleet',
                      style: AppTypography.displayLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Driver',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            'v1.0.0',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
