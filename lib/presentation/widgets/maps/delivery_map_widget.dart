import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../config/maps_config.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../data/models/assignment.dart';
import '../../../data/models/stop.dart';
import '../../../services/navigation/navigation_service.dart';
import '../common/app_button.dart';
import 'marker_generator.dart';

/// Delivery map widget with mini and expanded modes
class DeliveryMapWidget extends StatefulWidget {
  final Position? currentPosition;
  final Assignment? assignment;
  final bool isLoading;

  const DeliveryMapWidget({
    super.key,
    this.currentPosition,
    this.assignment,
    this.isLoading = false,
  });

  @override
  State<DeliveryMapWidget> createState() => _DeliveryMapWidgetState();
}

class _DeliveryMapWidgetState extends State<DeliveryMapWidget> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isExpanded = false;
  bool _isLoadingMarkers = false;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  @override
  void didUpdateWidget(DeliveryMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload markers if position or assignment changed
    if (oldWidget.currentPosition != widget.currentPosition ||
        oldWidget.assignment != widget.assignment) {
      _loadMarkers();
      _updateCameraPosition();
    }
  }

  Future<void> _loadMarkers() async {
    if (_isLoadingMarkers) return;
    
    setState(() {
      _isLoadingMarkers = true;
    });

    final markers = <Marker>{};

    // Add driver location marker
    if (widget.currentPosition != null) {
      final driverIcon = await MarkerGenerator.generateDriverMarker();
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          ),
          icon: driverIcon,
          anchor: const Offset(0.5, 0.5),
          zIndex: 100, // Driver marker on top
        ),
      );
    }

    // Add stop markers if we have an assignment
    if (widget.assignment != null) {
      final sortedStops = widget.assignment!.sortedStops;
      for (final stop in sortedStops) {
        final stopIcon = await MarkerGenerator.generateStopMarker(
          sequence: stop.sequence,
          isDelivered: stop.isDelivered,
          isFailed: stop.isFailed,
        );

        markers.add(
          Marker(
            markerId: MarkerId('stop_${stop.id}'),
            position: LatLng(stop.order.dropLat, stop.order.dropLng),
            icon: stopIcon,
            anchor: const Offset(0.5, 0.5),
            zIndex: stop.isPending ? 50 : 10,
            infoWindow: InfoWindow(
              title: 'Stop ${stop.sequence}',
              snippet: stop.order.customerName,
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _isLoadingMarkers = false;
      });
    }
  }

  void _updateCameraPosition() {
    if (_mapController == null) return;

    if (_isExpanded && widget.assignment != null) {
      // Fit all markers in expanded view
      _fitAllMarkers();
    } else if (widget.currentPosition != null) {
      // Center on driver in mini view
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          ),
          15,
        ),
      );
    }
  }

  void _fitAllMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = 90;
    double maxLat = -90;
    double minLng = 180;
    double maxLng = -180;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    // Add padding
    final latPadding = (maxLat - minLat) * 0.2;
    final lngPadding = (maxLng - minLng) * 0.2;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - latPadding, minLng - lngPadding),
          northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
        ),
        50, // padding in pixels
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    controller.setMapStyle(MapsConfig.darkMapStyle);
    _updateCameraPosition();
  }

  void _toggleExpanded() {
    if (_isExpanded) {
      Navigator.of(context).pop();
    } else {
      _showExpandedMap();
    }
  }

  void _showExpandedMap() {
    setState(() {
      _isExpanded = true;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildExpandedMap(),
    ).then((_) {
      setState(() {
        _isExpanded = false;
      });
    });
  }

  void _navigateToNextStop() {
    final nextStop = widget.assignment?.nextStop;
    if (nextStop != null) {
      NavigationService.navigateToLocation(
        lat: nextStop.order.dropLat,
        lng: nextStop.order.dropLng,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: _buildMiniMap(),
    );
  }

  Widget _buildMiniMap() {
    final initialPosition = widget.currentPosition != null
        ? LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          )
        : const LatLng(0, 0);

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Google Map
            if (widget.currentPosition != null)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialPosition,
                  zoom: 15,
                ),
                onMapCreated: _onMapCreated,
                markers: _markers,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                rotateGesturesEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                tiltGesturesEnabled: false,
              )
            else
              _buildLoadingPlaceholder(),

            // Tap to expand overlay
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.fullscreen,
                      color: AppColors.textPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tap to expand',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Loading indicator
            if (_isLoadingMarkers || widget.isLoading)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.darkGray,
            AppColors.mediumGray,
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            ),
            SizedBox(height: 12),
            Text(
              'Getting your location...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedMap() {
    final initialPosition = widget.currentPosition != null
        ? LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          )
        : const LatLng(0, 0);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.charcoal,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.assignment != null
                          ? 'Delivery Route'
                          : 'Your Location',
                      style: AppTypography.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Map
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: initialPosition,
                        zoom: 12,
                      ),
                      onMapCreated: (controller) {
                        controller.setMapStyle(MapsConfig.darkMapStyle);
                        // Fit all markers after a short delay
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (_markers.length > 1) {
                            _mapController = controller;
                            _fitAllMarkers();
                          }
                        });
                      },
                      markers: _markers,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      mapToolbarEnabled: false,
                      compassEnabled: true,
                    ),
                  ),
                ),
              ),

              // Stop list summary
              if (widget.assignment != null) _buildStopsSummary(),

              // Action button
              _buildActionButton(),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStopsSummary() {
    final assignment = widget.assignment!;
    final nextStop = assignment.nextStop;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${assignment.completedStops}/${assignment.totalStops} stops completed',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              _buildStatusBadge(assignment),
            ],
          ),
          if (nextStop != null) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.lightGray, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.warningYellow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '${nextStop.sequence}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next: ${nextStop.order.customerName}',
                        style: AppTypography.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Assignment assignment) {
    final Color badgeColor;
    final String badgeText;

    if (assignment.isCompleted) {
      badgeColor = AppColors.primaryGreen;
      badgeText = 'COMPLETED';
    } else if (assignment.isStarted) {
      badgeColor = AppColors.accentBlue;
      badgeText = 'IN PROGRESS';
    } else {
      badgeColor = AppColors.warningYellow;
      badgeText = 'NOT STARTED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    final assignment = widget.assignment;
    final nextStop = assignment?.nextStop;

    // Determine button state
    String buttonText;
    VoidCallback? onPressed;
    IconData icon;

    if (assignment == null) {
      buttonText = 'NO ACTIVE ASSIGNMENT';
      onPressed = null;
      icon = Icons.directions;
    } else if (nextStop != null) {
      // Show "START" for new assignments, "NAVIGATE" for in-progress
      buttonText = assignment.isStarted ? 'NAVIGATE TO NEXT' : 'START DELIVERIES';
      onPressed = _navigateToNextStop;
      icon = assignment.isStarted ? Icons.navigation : Icons.play_arrow;
    } else {
      buttonText = 'ALL STOPS COMPLETED';
      onPressed = null;
      icon = Icons.check_circle;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppButton(
        text: buttonText,
        icon: icon,
        onPressed: onPressed,
        isLoading: widget.isLoading,
        isEnabled: onPressed != null,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
