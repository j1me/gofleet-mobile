import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../providers/driver_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/loading_overlay.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  final String orderId;

  const DeliveryScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  final _notesController = TextEditingController();
  String _selectedStatus = 'delivered';
  String? _failedReason;
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isSubmitting = false;
  String? _locationError;
  late String _idempotencyKey;

  final List<String> _failedReasons = [
    'Customer not available',
    'Wrong address',
    'Customer refused delivery',
    'Access denied',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _idempotencyKey = const Uuid().v4();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permission permanently denied';
          _isLoadingLocation = false;
        });
        return;
      }

      // Check if service enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get location';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _submitDelivery() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for GPS location'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (_selectedStatus == 'failed' && _failedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason for failure'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String notes = _notesController.text.trim();
      if (_selectedStatus == 'failed' && _failedReason != null) {
        notes = '$_failedReason${notes.isNotEmpty ? ': $notes' : ''}';
      }

      await ref.read(driverProvider.notifier).updateOrderStatus(
            orderId: widget.orderId,
            status: _selectedStatus,
            lat: _currentPosition!.latitude,
            lng: _currentPosition!.longitude,
            notes: notes.isNotEmpty ? notes : null,
            idempotencyKey: _idempotencyKey,
          );

      if (!mounted) return;

      context.go('/deliver/${widget.orderId}/success');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverProvider);
    final assignment = driverState.activeAssignment;

    // Find the stop/order
    Stop? stop;
    if (assignment != null) {
      stop = assignment.stops.where((s) => s.order.id == widget.orderId).firstOrNull;
    }

    if (stop == null) {
      return Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          title: const Text('Complete Delivery'),
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
        title: const Text('Complete Delivery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isSubmitting,
        message: 'Updating delivery status...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order info
              Text(
                order.customerName,
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                order.dropAddress,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 32),
              const Divider(color: AppColors.lightGray),
              const SizedBox(height: 24),

              // Status selection
              Text(
                'DELIVERY STATUS',
                style: AppTypography.overline,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildStatusOption(
                      status: 'delivered',
                      icon: Icons.check,
                      label: 'DELIVERED',
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatusOption(
                      status: 'failed',
                      icon: Icons.close,
                      label: 'FAILED',
                      color: AppColors.errorRed,
                    ),
                  ),
                ],
              ),

              // Failed reason
              if (_selectedStatus == 'failed') ...[
                const SizedBox(height: 24),
                Text(
                  'REASON FOR FAILURE',
                  style: AppTypography.overline,
                ),
                const SizedBox(height: 12),
                ..._failedReasons.map((reason) => _buildReasonOption(reason)),
              ],

              const SizedBox(height: 24),

              // Notes
              Text(
                'NOTES (optional)',
                style: AppTypography.overline,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _notesController,
                hint: 'Add delivery notes...',
                maxLines: 3,
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: 24),

              // GPS verification
              Text(
                'GPS VERIFICATION',
                style: AppTypography.overline,
              ),
              const SizedBox(height: 12),
              _buildGpsCard(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.charcoal,
          border: Border(
            top: BorderSide(color: AppColors.lightGray),
          ),
        ),
        child: SafeArea(
          child: AppButton(
            text: 'CONFIRM ${_selectedStatus.toUpperCase()}',
            onPressed: _currentPosition != null && !_isSubmitting
                ? _submitDelivery
                : null,
            isLoading: _isSubmitting,
            isEnabled: _currentPosition != null,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption({
    required String status,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _selectedStatus == status;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = status;
          if (status == 'delivered') {
            _failedReason = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.darkGray,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.lightGray,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected ? color : AppColors.mediumGray,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? color : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonOption(String reason) {
    final isSelected = _failedReason == reason;

    return GestureDetector(
      onTap: () {
        setState(() {
          _failedReason = reason;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.errorRed.withOpacity(0.1)
              : AppColors.darkGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.errorRed : AppColors.lightGray,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.errorRed : AppColors.lightGray,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.errorRed,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              reason,
              style: AppTypography.bodyMedium.copyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _currentPosition != null
                  ? AppColors.primaryGreen.withOpacity(0.1)
                  : _locationError != null
                      ? AppColors.errorRed.withOpacity(0.1)
                      : AppColors.mediumGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isLoadingLocation
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGreen,
                      ),
                    ),
                  )
                : Icon(
                    _currentPosition != null
                        ? Icons.check
                        : _locationError != null
                            ? Icons.error_outline
                            : Icons.gps_fixed,
                    color: _currentPosition != null
                        ? AppColors.primaryGreen
                        : _locationError != null
                            ? AppColors.errorRed
                            : AppColors.textMuted,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoadingLocation
                      ? 'Getting location...'
                      : _currentPosition != null
                          ? 'Location captured'
                          : _locationError ?? 'Location unavailable',
                  style: AppTypography.titleSmall.copyWith(
                    color: _currentPosition != null
                        ? AppColors.primaryGreen
                        : _locationError != null
                            ? AppColors.errorRed
                            : AppColors.textSecondary,
                  ),
                ),
                if (_currentPosition != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    'Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(0)}m',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_locationError != null || _currentPosition == null)
            IconButton(
              icon: const Icon(
                Icons.refresh,
                color: AppColors.textSecondary,
              ),
              onPressed: _getCurrentLocation,
            ),
        ],
      ),
    );
  }
}
