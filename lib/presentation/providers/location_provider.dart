import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location/location_service.dart';
import 'providers.dart';

/// Location service provider
final locationServiceProvider = Provider<LocationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LocationService(apiClient: apiClient);
});

/// Location state
class LocationState {
  final bool isTracking;
  final bool hasPermission;
  final bool isServiceEnabled;
  final Position? lastPosition;
  final DateTime? lastUploadTime;
  final int queuedUpdatesCount;
  final bool isOnline;
  final String? error;

  const LocationState({
    this.isTracking = false,
    this.hasPermission = false,
    this.isServiceEnabled = true,
    this.lastPosition,
    this.lastUploadTime,
    this.queuedUpdatesCount = 0,
    this.isOnline = true,
    this.error,
  });

  LocationState copyWith({
    bool? isTracking,
    bool? hasPermission,
    bool? isServiceEnabled,
    Position? lastPosition,
    DateTime? lastUploadTime,
    int? queuedUpdatesCount,
    bool? isOnline,
    String? error,
  }) {
    return LocationState(
      isTracking: isTracking ?? this.isTracking,
      hasPermission: hasPermission ?? this.hasPermission,
      isServiceEnabled: isServiceEnabled ?? this.isServiceEnabled,
      lastPosition: lastPosition ?? this.lastPosition,
      lastUploadTime: lastUploadTime ?? this.lastUploadTime,
      queuedUpdatesCount: queuedUpdatesCount ?? this.queuedUpdatesCount,
      isOnline: isOnline ?? this.isOnline,
      error: error,
    );
  }
}

/// Location notifier for managing location tracking
class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService _locationService;

  LocationNotifier({required LocationService locationService})
      : _locationService = locationService,
        super(const LocationState());

  /// Initialize and check permissions
  Future<void> initialize() async {
    final hasPermission = await _locationService.checkPermission();
    final isServiceEnabled = await _locationService.isLocationServiceEnabled();

    state = state.copyWith(
      hasPermission: hasPermission,
      isServiceEnabled: isServiceEnabled,
    );
  }

  /// Request location permission
  Future<bool> requestPermission() async {
    final permission = await _locationService.requestPermission();
    final hasPermission = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    state = state.copyWith(hasPermission: hasPermission);
    return hasPermission;
  }

  /// Start location tracking
  Future<void> startTracking() async {
    try {
      state = state.copyWith(error: null);
      await _locationService.startTracking();
      state = state.copyWith(isTracking: true);
    } catch (e) {
      state = state.copyWith(
        isTracking: false,
        error: e.toString(),
      );
    }
  }

  /// Stop location tracking
  void stopTracking() {
    _locationService.stopTracking();
    state = state.copyWith(
      isTracking: false,
      queuedUpdatesCount: 0,
    );
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        state = state.copyWith(lastPosition: position);
      }
      return position;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Update state from service
  void updateFromService() {
    state = state.copyWith(
      isTracking: _locationService.isTracking,
      lastPosition: _locationService.lastPosition,
      lastUploadTime: _locationService.lastUploadTime,
      queuedUpdatesCount: _locationService.queuedUpdatesCount,
      isOnline: _locationService.isOnline,
    );
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}

/// Location provider
final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return LocationNotifier(locationService: locationService);
});

/// Convenience providers
final isTrackingProvider = Provider<bool>((ref) {
  return ref.watch(locationProvider).isTracking;
});

final hasLocationPermissionProvider = Provider<bool>((ref) {
  return ref.watch(locationProvider).hasPermission;
});

final lastKnownPositionProvider = Provider<Position?>((ref) {
  return ref.watch(locationProvider).lastPosition;
});
