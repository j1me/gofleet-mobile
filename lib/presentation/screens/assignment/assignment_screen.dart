import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../providers/driver_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../../services/navigation/navigation_service.dart';

class AssignmentScreen extends ConsumerWidget {
  const AssignmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverState = ref.watch(driverProvider);
    final assignment = driverState.activeAssignment;

    if (assignment == null) {
      return Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          title: const Text('Assignment'),
        ),
        body: const Center(
          child: Text(
            'No active assignment',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Assignment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: LoadingOverlay(
        isLoading: driverState.isLoading,
        child: RefreshIndicator(
          onRefresh: () => ref.read(driverProvider.notifier).loadActiveAssignment(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Assignment header
              _buildHeader(assignment),
              
              const SizedBox(height: 24),
              
              // Progress bar
              _buildProgressBar(assignment),
              
              const SizedBox(height: 24),
              
              // Stops list
              ...assignment.sortedStops.map(
                (stop) => _buildStopCard(context, stop, assignment),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Assignment assignment) {
    final duration = assignment.duration;
    final timeFormat = DateFormat('h:mm a');

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'IN PROGRESS',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (assignment.startedAt != null)
          Text(
            'Started ${timeFormat.format(assignment.startedAt!)}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        if (duration != null) ...[
          const SizedBox(width: 8),
          Text(
            '•',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(duration),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar(Assignment assignment) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${assignment.completedStops}/${assignment.totalStops} stops',
              style: AppTypography.titleMedium,
            ),
            Text(
              '${(assignment.completionPercentage * 100).toInt()}%',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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

  Widget _buildStopCard(BuildContext context, Stop stop, Assignment assignment) {
    final isNext = assignment.nextStop?.id == stop.id;
    final timeFormat = DateFormat('h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator
          Column(
            children: [
              _buildStatusIcon(stop, isNext),
              if (stop.sequence < assignment.totalStops)
                Container(
                  width: 2,
                  height: 60,
                  color: stop.isCompleted
                      ? AppColors.primaryGreen.withOpacity(0.3)
                      : AppColors.lightGray,
                ),
            ],
          ),
          const SizedBox(width: 16),
          
          // Card content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isNext ? AppColors.mediumGray : AppColors.darkGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isNext
                      ? AppColors.primaryGreen
                      : stop.isCompleted
                          ? AppColors.primaryGreen.withOpacity(0.3)
                          : AppColors.lightGray,
                  width: isNext ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stop header
                  Row(
                    children: [
                      Text(
                        'STOP ${stop.sequence}',
                        style: AppTypography.overline.copyWith(
                          color: isNext
                              ? AppColors.primaryGreen
                              : AppColors.textMuted,
                        ),
                      ),
                      if (isNext) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'NEXT',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.black,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (stop.isDelivered)
                        Text(
                          'Delivered ${stop.completedAt != null ? timeFormat.format(stop.completedAt!) : ''}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primaryGreen,
                          ),
                        )
                      else if (stop.isFailed)
                        Text(
                          'Failed',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.errorRed,
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Customer name
                  Text(
                    stop.order.customerName,
                    style: AppTypography.titleMedium.copyWith(
                      color: stop.isCompleted
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: stop.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Address
                  Text(
                    stop.order.dropAddress,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  
                  // Notes
                  if (stop.order.notes != null &&
                      stop.order.notes!.isNotEmpty &&
                      !stop.isCompleted) ...[
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
                            stop.order.notes!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.warningYellow,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Action buttons for next stop
                  if (isNext) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Navigate',
                            icon: Icons.navigation,
                            height: 44,
                            onPressed: () => NavigationService.navigateToLocation(
                              lat: stop.order.dropLat,
                              lng: stop.order.dropLng,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppOutlinedButton(
                            text: 'Deliver',
                            icon: Icons.check,
                            height: 44,
                            onPressed: () => context.push(
                              '/deliver/${stop.order.id}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(Stop stop, bool isNext) {
    if (stop.isDelivered) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.check,
          color: AppColors.black,
          size: 18,
        ),
      );
    } else if (stop.isFailed) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.errorRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.close,
          color: AppColors.textPrimary,
          size: 18,
        ),
      );
    } else if (isNext) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            '${stop.sequence}',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.black,
            ),
          ),
        ),
      );
    } else {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.darkGray,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightGray),
        ),
        child: Center(
          child: Text(
            '${stop.sequence}',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
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
}
