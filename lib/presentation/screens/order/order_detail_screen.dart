import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../providers/driver_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../../services/navigation/navigation_service.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverState = ref.watch(driverProvider);
    final assignment = driverState.activeAssignment;
    
    // Find the stop/order
    Stop? stop;
    if (assignment != null) {
      stop = assignment.stops.where((s) => s.order.id == orderId).firstOrNull;
    }

    if (stop == null) {
      return Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          title: const Text('Order Details'),
        ),
        body: const Center(
          child: Text(
            'Order not found',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final order = stop.order;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Delivery Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map preview
            _buildMapPreview(order),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer section
                  _buildSection(
                    title: 'CUSTOMER',
                    child: _buildInfoCard(
                      icon: Icons.person_outline,
                      content: order.customerName,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Address section
                  _buildSection(
                    title: 'ADDRESS',
                    child: _buildAddressCard(context, order),
                  ),

                  const SizedBox(height: 24),

                  // Notes section
                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    _buildSection(
                      title: 'DELIVERY NOTES',
                      child: _buildInfoCard(
                        icon: Icons.note_outlined,
                        content: order.notes!,
                        iconColor: AppColors.warningYellow,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Status section
                  _buildSection(
                    title: 'STATUS',
                    child: _buildStatusCard(stop),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: stop.isPending
          ? _buildBottomActions(context, order)
          : null,
    );
  }

  Widget _buildMapPreview(Order order) {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Stack(
        children: [
          // Dark map style placeholder
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.darkGray,
                  AppColors.mediumGray,
                ],
              ),
            ),
          ),
          // Grid lines
          CustomPaint(
            size: const Size(double.infinity, 200),
            painter: _MapGridPainter(),
          ),
          // Location marker
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.black,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.dropAddress.split(',').first,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.overline,
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String content,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              content,
              style: AppTypography.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, Order order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  order.dropAddress,
                  style: AppTypography.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: order.dropAddress));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Address copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.lightGray),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => NavigationService.openInMaps(
                    lat: order.dropLat,
                    lng: order.dropLng,
                    label: order.dropAddress,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open Maps'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.lightGray),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Stop stop) {
    IconData statusIcon;
    Color statusColor;
    String statusText;

    if (stop.isDelivered) {
      statusIcon = Icons.check_circle;
      statusColor = AppColors.primaryGreen;
      statusText = 'Delivered';
    } else if (stop.isFailed) {
      statusIcon = Icons.cancel;
      statusColor = AppColors.errorRed;
      statusText = 'Failed';
    } else {
      statusIcon = Icons.local_shipping;
      statusColor = AppColors.accentBlue;
      statusText = 'Out for Delivery';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Text(
            statusText,
            style: AppTypography.bodyLarge.copyWith(
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, Order order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.charcoal,
        border: Border(
          top: BorderSide(color: AppColors.lightGray),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              text: 'NAVIGATE',
              icon: Icons.navigation,
              onPressed: () => NavigationService.navigateToLocation(
                lat: order.dropLat,
                lng: order.dropLng,
              ),
            ),
            const SizedBox(height: 12),
            AppOutlinedButton(
              text: 'MARK AS DELIVERED',
              icon: Icons.check_circle_outline,
              onPressed: () => context.push('/deliver/${order.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.lightGray.withOpacity(0.2)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 25) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 25) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
