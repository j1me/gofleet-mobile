import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../config/api_config.dart';
import '../api/api_client.dart';

/// Location update with timestamp
class LocationUpdate {
  final double lat;
  final double lng;
  final double? speed;
  final double? heading;
  final double? accuracy;
  final DateTime capturedAt;

  LocationUpdate({
    required this.lat,
    required this.lng,
    this.speed,
    this.heading,
    this.accuracy,
    required this.capturedAt,
  });
}

/// Location tracking service with rate limiting and offline queueing
class LocationService {
  final ApiClient _apiClient;
  
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _uploadTimer;
  
  Position? _lastPosition;
  DateTime? _lastUploadTime;
  bool _isTracking = false;
  bool _isOnline = true;
  
  // Offline queue for location updates
  final Queue<LocationUpdate> _offlineQueue = Queue<LocationUpdate>();
  static const int _maxQueueSize = 100;
  
  // Rate limiting: max 2 updates per 10 seconds
  int _updateCountInInterval = 0;
  DateTime? _intervalStartTime;

  LocationService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Check if location permission is granted
  Future<bool> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final permission = await checkPermission();
      if (!permission) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Start tracking location updates
  Future<void> startTracking() async {
    if (_isTracking) return;

    final permission = await checkPermission();
    if (!permission) {
      throw Exception('Location permission not granted');
    }

    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services disabled');
    }

    _isTracking = true;
    _isOnline = true;

    // Listen to position updates
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Minimum distance (meters) before update
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        debugPrint('Position stream error: $error');
      },
    );

    // Listen to connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChange,
    );

    // Start periodic upload timer
    _uploadTimer = Timer.periodic(
      ApiConfig.locationUpdateInterval,
      (_) => _uploadQueuedLocations(),
    );

    debugPrint('Location tracking started');
  }

  /// Stop tracking location updates
  void stopTracking() {
    _isTracking = false;
    
    _positionSubscription?.cancel();
    _positionSubscription = null;
    
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    
    _uploadTimer?.cancel();
    _uploadTimer = null;
    
    // Clear queue when stopping
    _offlineQueue.clear();
    
    debugPrint('Location tracking stopped');
  }

  /// Handle position update from stream
  void _onPositionUpdate(Position position) {
    _lastPosition = position;
    
    // Create location update
    final update = LocationUpdate(
      lat: position.latitude,
      lng: position.longitude,
      speed: position.speed,
      heading: position.heading,
      accuracy: position.accuracy,
      capturedAt: position.timestamp,
    );

    // Check rate limit
    if (!_shouldSendUpdate()) {
      debugPrint('Rate limited, skipping location update');
      return;
    }

    if (_isOnline) {
      _sendLocationUpdate(update);
    } else {
      _queueLocationUpdate(update);
    }
  }

  /// Check rate limiting (max 2 updates per 10 seconds)
  bool _shouldSendUpdate() {
    final now = DateTime.now();
    
    // Reset counter if interval has passed
    if (_intervalStartTime == null ||
        now.difference(_intervalStartTime!).inSeconds >= 
            ApiConfig.locationRateLimitInterval.inSeconds) {
      _intervalStartTime = now;
      _updateCountInInterval = 0;
    }

    // Check if under limit
    if (_updateCountInInterval < ApiConfig.locationRateLimitPerInterval) {
      _updateCountInInterval++;
      return true;
    }

    return false;
  }

  /// Send location update to API
  Future<void> _sendLocationUpdate(LocationUpdate update) async {
    try {
      await _apiClient.updateLocation(
        lat: update.lat,
        lng: update.lng,
        speed: update.speed,
        heading: update.heading,
        accuracy: update.accuracy,
        capturedAt: update.capturedAt,
      );
      
      _lastUploadTime = DateTime.now();
      debugPrint('Location update sent: ${update.lat}, ${update.lng}');
    } catch (e) {
      debugPrint('Failed to send location update: $e');
      // Queue for retry if network error
      _queueLocationUpdate(update);
    }
  }

  /// Queue location update for later sending
  void _queueLocationUpdate(LocationUpdate update) {
    // Limit queue size
    if (_offlineQueue.length >= _maxQueueSize) {
      _offlineQueue.removeFirst();
    }
    
    _offlineQueue.add(update);
    debugPrint('Location queued. Queue size: ${_offlineQueue.length}');
  }

  /// Handle connectivity changes
  void _onConnectivityChange(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    if (!wasOnline && _isOnline) {
      // Came back online, upload queued locations
      debugPrint('Back online, uploading queued locations');
      _uploadQueuedLocations();
    }
  }

  /// Upload all queued locations
  Future<void> _uploadQueuedLocations() async {
    if (!_isOnline || _offlineQueue.isEmpty) return;

    debugPrint('Uploading ${_offlineQueue.length} queued locations');
    
    // Process queue in order
    while (_offlineQueue.isNotEmpty && _isOnline) {
      final update = _offlineQueue.first;
      
      try {
        await _apiClient.updateLocation(
          lat: update.lat,
          lng: update.lng,
          speed: update.speed,
          heading: update.heading,
          accuracy: update.accuracy,
          capturedAt: update.capturedAt,
        );
        
        _offlineQueue.removeFirst();
        _lastUploadTime = DateTime.now();
        
        // Small delay to prevent overwhelming server
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('Failed to upload queued location: $e');
        // Stop processing if we hit an error
        break;
      }
    }
  }

  /// Get last known position
  Position? get lastPosition => _lastPosition;

  /// Get last upload time
  DateTime? get lastUploadTime => _lastUploadTime;

  /// Check if tracking is active
  bool get isTracking => _isTracking;

  /// Get number of queued updates
  int get queuedUpdatesCount => _offlineQueue.length;

  /// Check if online
  bool get isOnline => _isOnline;

  /// Dispose resources
  void dispose() {
    stopTracking();
  }
}
