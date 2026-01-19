import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/maps/delivery_map_widget.dart';
import '../../../router/app_router.dart';
import '../../../services/navigation/navigation_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load driver profile, assignment, and initialize location on mount
    Future.microtask(() {
      final driver = ref.read(authProvider).driver;
      ref.read(driverProvider.notifier).setDriver(driver);
      if (driver?.isOnShift == true) {
        ref.read(driverProvider.notifier).loadActiveAssignment();
      }
      // Initialize location tracking
      _initializeLocation();
    });
  }

  Future<void> _initializeLocation() async {
    final locationNotifier = ref.read(locationProvider.notifier);
    await locationNotifier.initialize();
    
    // Request permission if not granted
    final hasPermission = ref.read(locationProvider).hasPermission;
    if (!hasPermission) {
      await locationNotifier.requestPermission();
    }
    
    // Get current position
    await locationNotifier.getCurrentPosition();
  }

  Future<void> _toggleShift() async {
    final driverState = ref.read(driverProvider);
    
    if (driverState.isOnShift) {
      // Confirm end shift
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.darkGray,
          title: const Text('End Shift'),
          content: driverState.hasActiveAssignment
              ? const Text(
                  'You have an active assignment. Are you sure you want to go offline?',
                )
              : const Text('Are you sure you want to end your shift?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End Shift'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await ref.read(driverProvider.notifier).endShift();
      }
    } else {
      // Start shift
      try {
        await ref.read(driverProvider.notifier).startShift();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You're now online!"),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start shift: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final driverState = ref.watch(driverProvider);
    final locationState = ref.watch(locationProvider);
    final driver = authState.driver;
    final activeTenant = authState.activeTenant;
    
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _showDrawer(context),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authProvider.notifier).checkAuthState();
          if (driverState.isOnShift) {
            await ref.read(driverProvider.notifier).loadActiveAssignment();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                _buildGreeting(driver, activeTenant),
                
                const SizedBox(height: 24),
                
                // Delivery Map
                DeliveryMapWidget(
                  currentPosition: locationState.lastPosition,
                  assignment: driverState.activeAssignment,
                  isLoading: driverState.isLoading,
                ),
                
                const SizedBox(height: 24),
                
                // Main content based on state
                if (!driverState.isOnShift)
                  _buildOfflineState()
                else if (driverState.activeAssignment == null)
                  _buildWaitingState(driverState.driver)
                else
                  _buildActiveAssignmentState(driverState.activeAssignment!),
                  
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(Driver? driver, Tenant? tenant) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${driver?.name.split(' ').first ?? 'Driver'}',
          style: AppTypography.headlineLarge,
        ),
        const SizedBox(height: 4),
        Text(
          tenant?.name ?? 'No organization',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.mediumGray,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.power_settings_new,
              color: AppColors.textSecondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "You're offline",
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Go online to receive delivery assignments',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'GO ONLINE',
            icon: Icons.power_settings_new,
            onPressed: _toggleShift,
            isLoading: ref.watch(driverProvider).isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingState(Driver? driver) {
    final shiftDuration = driver?.shiftDuration;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ON DUTY',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
              const Spacer(),
              if (shiftDuration != null)
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(shiftDuration),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen.withOpacity(0.3),
                    ),
                  ),
                ),
                const Icon(
                  Icons.radar,
                  size: 40,
                  color: AppColors.primaryGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Waiting for assignments...',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your dispatcher will assign deliveries to you shortly',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AppOutlinedButton(
            text: 'GO OFFLINE',
            onPressed: _toggleShift,
            isLoading: ref.watch(driverProvider).isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAssignmentState(Assignment assignment) {
    final nextStop = assignment.nextStop;
    final completedCount = assignment.completedStops;
    final totalCount = assignment.totalStops;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ACTIVE ASSIGNMENT',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (nextStop != null) ...[
            Text(
              'NEXT DELIVERY',
              style: AppTypography.overline,
            ),
            const SizedBox(height: 12),

            // Next stop card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mediumGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nextStop.order.customerName,
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nextStop.order.dropAddress,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (nextStop.order.notes != null &&
                      nextStop.order.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.note,
                          size: 14,
                          color: AppColors.warningYellow,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            nextStop.order.notes!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.warningYellow,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'NAVIGATE',
                    icon: Icons.navigation,
                    onPressed: () => NavigationService.navigateToLocation(
                      lat: nextStop.order.dropLat,
                      lng: nextStop.order.dropLng,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppOutlinedButton(
                    text: 'DELIVER',
                    icon: Icons.check_circle_outline,
                    onPressed: () => context.push(
                      '/deliver/${nextStop.order.id}',
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          const Divider(color: AppColors.lightGray),
          const SizedBox(height: 16),

          // Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedCount of $totalCount stops completed',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              GestureDetector(
                onTap: () => context.push(AppRoutes.assignment),
                child: Text(
                  'View all stops',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: assignment.completionPercentage,
              backgroundColor: AppColors.lightGray,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryGreen,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  void _showDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _buildDrawerContent(),
    );
  }

  Widget _buildDrawerContent() {
    final authState = ref.watch(authProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Menu items
          _buildMenuItem(
            icon: Icons.home,
            title: 'Home',
            onTap: () => Navigator.pop(context),
          ),
          _buildMenuItem(
            icon: Icons.business,
            title: 'Organizations',
            subtitle: authState.activeTenant?.name,
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.tenants);
            },
          ),
          if (authState.invitations.isNotEmpty)
            _buildMenuItem(
              icon: Icons.mail,
              title: 'Invitations',
              badge: authState.invitations.length.toString(),
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.invitations);
              },
            ),
          _buildMenuItem(
            icon: Icons.person,
            title: 'Profile',
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.profile);
            },
          ),
          _buildMenuItem(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.settings);
            },
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.lightGray),
          const SizedBox(height: 16),
          _buildMenuItem(
            icon: Icons.logout,
            title: 'Log Out',
            textColor: AppColors.errorRed,
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? badge,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.darkGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: textColor ?? AppColors.textPrimary),
      ),
      title: Text(
        title,
        style: AppTypography.titleMedium.copyWith(color: textColor),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.black,
                ),
              ),
            )
          : const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
      onTap: onTap,
    );
  }
}
