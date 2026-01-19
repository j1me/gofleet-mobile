import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../providers/driver_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../../router/app_router.dart';
import '../../../services/navigation/navigation_service.dart';

class DeliverySuccessScreen extends ConsumerWidget {
  final String orderId;

  const DeliverySuccessScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverState = ref.watch(driverProvider);
    final assignment = driverState.activeAssignment;
    
    // Find the completed stop
    Stop? completedStop;
    if (assignment != null) {
      completedStop = assignment.stops.where((s) => s.order.id == orderId).firstOrNull;
    }

    // Get next stop if any
    final nextStop = assignment?.nextStop;
    final isAllComplete = assignment?.pendingStops == 0;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Success animation/icon
              _buildSuccessIcon(completedStop),

              const SizedBox(height: 32),

              // Title
              Text(
                isAllComplete == true
                    ? 'Assignment Complete!'
                    : 'Delivery Complete!',
                style: AppTypography.displaySmall,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Completed order info
              if (completedStop != null)
                Text(
                  '${completedStop.order.customerName}\n${completedStop.order.dropAddress}',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

              const Spacer(),

              // Next delivery or summary
              if (isAllComplete == true)
                _buildCompleteSummary(assignment!)
              else if (nextStop != null)
                _buildNextDelivery(context, nextStop),

              const SizedBox(height: 24),

              // Action buttons
              if (isAllComplete == true)
                AppButton(
                  text: 'BACK TO HOME',
                  onPressed: () => context.go(AppRoutes.home),
                )
              else ...[
                if (nextStop != null)
                  AppButton(
                    text: 'NAVIGATE TO NEXT',
                    icon: Icons.navigation,
                    onPressed: () {
                      NavigationService.navigateToLocation(
                        lat: nextStop.order.dropLat,
                        lng: nextStop.order.dropLng,
                      );
                      context.go(AppRoutes.home);
                    },
                  ),
                const SizedBox(height: 12),
                AppOutlinedButton(
                  text: 'VIEW ALL STOPS',
                  onPressed: () => context.go(AppRoutes.assignment),
                ),
              ],

              const SizedBox(height: 24),

              // Progress indicator
              if (assignment != null && isAllComplete != true)
                _buildProgress(assignment),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon(Stop? stop) {
    final isDelivered = stop?.isDelivered ?? true;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: (isDelivered ? AppColors.primaryGreen : AppColors.errorRed)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(60),
      ),
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isDelivered ? AppColors.primaryGreen : AppColors.errorRed,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: (isDelivered ? AppColors.primaryGreen : AppColors.errorRed)
                    .withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            isDelivered ? Icons.check : Icons.close,
            color: AppColors.textPrimary,
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildNextDelivery(BuildContext context, Stop nextStop) {
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
          Text(
            'NEXT DELIVERY',
            style: AppTypography.overline,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    '${nextStop.sequence}',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nextStop.order.customerName,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextStop.order.dropAddress,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteSummary(Assignment assignment) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'SUMMARY',
            style: AppTypography.overline,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                icon: Icons.check_circle,
                value: assignment.deliveredStops.toString(),
                label: 'Delivered',
                color: AppColors.primaryGreen,
              ),
              _buildSummaryItem(
                icon: Icons.cancel,
                value: assignment.failedStops.toString(),
                label: 'Failed',
                color: AppColors.errorRed,
              ),
              _buildSummaryItem(
                icon: Icons.access_time,
                value: _formatDuration(assignment.duration),
                label: 'Duration',
                color: AppColors.accentBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTypography.headlineMedium.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgress(Assignment assignment) {
    return Column(
      children: [
        Text(
          '${assignment.completedStops} of ${assignment.totalStops} deliveries complete',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
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
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
