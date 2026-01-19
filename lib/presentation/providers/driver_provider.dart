import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../data/models/models.dart';
import '../../services/api/api_client.dart';
import 'providers.dart';

/// Driver state for shift and assignment management
class DriverState {
  final Driver? driver;
  final Assignment? activeAssignment;
  final bool isLoading;
  final String? error;

  const DriverState({
    this.driver,
    this.activeAssignment,
    this.isLoading = false,
    this.error,
  });

  bool get isOnShift => driver?.isOnShift ?? false;
  bool get hasActiveAssignment => activeAssignment != null;

  DriverState copyWith({
    Driver? driver,
    Assignment? activeAssignment,
    bool? isLoading,
    String? error,
    bool clearAssignment = false,
  }) {
    return DriverState(
      driver: driver ?? this.driver,
      activeAssignment: clearAssignment ? null : (activeAssignment ?? this.activeAssignment),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Driver notifier for managing shift and assignment state
class DriverNotifier extends StateNotifier<DriverState> {
  final ApiClient _apiClient;
  Timer? _assignmentPollingTimer;

  DriverNotifier({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(const DriverState());

  /// Load driver profile
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final driver = await _apiClient.getProfile();
      state = state.copyWith(driver: driver, isLoading: false);

      // If on shift, load assignment and start polling
      if (driver.isOnShift) {
        await loadActiveAssignment();
        _startAssignmentPolling();
      }
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  /// Start shift
  Future<void> startShift() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final shiftStartedAt = await _apiClient.startShift();
      final updatedDriver = state.driver?.copyWith(shiftStartedAt: shiftStartedAt);
      state = state.copyWith(driver: updatedDriver, isLoading: false);

      // Start polling for assignments
      _startAssignmentPolling();
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// End shift
  Future<void> endShift() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _apiClient.endShift();
      final updatedDriver = state.driver?.copyWith(shiftStartedAt: null);
      state = state.copyWith(
        driver: updatedDriver,
        isLoading: false,
        clearAssignment: true,
      );

      // Stop polling
      _stopAssignmentPolling();
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// Load active assignment
  Future<void> loadActiveAssignment() async {
    try {
      final assignment = await _apiClient.getActiveAssignment();
      state = state.copyWith(activeAssignment: assignment);
    } on ApiException catch (e) {
      if (e.code != ApiException.notFound) {
        state = state.copyWith(error: e.message);
      }
    } catch (e) {
      // Catch parsing errors and other exceptions
      print('Error loading assignment: $e');
      state = state.copyWith(error: 'Failed to load assignment');
    }
  }

  /// Start the active assignment (transitions from created to started)
  Future<void> startAssignment() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final assignment = await _apiClient.startAssignment();
      state = state.copyWith(activeAssignment: assignment, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// Ensure assignment is started before performing actions
  Future<void> ensureAssignmentStarted() async {
    final assignment = state.activeAssignment;
    if (assignment != null && !assignment.isStarted) {
      await startAssignment();
    }
  }

  /// Update order status
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    required double lat,
    required double lng,
    String? notes,
    String? idempotencyKey,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _apiClient.updateOrderStatus(
        orderId: orderId,
        status: status,
        lat: lat,
        lng: lng,
        occurredAt: DateTime.now(),
        notes: notes,
        idempotencyKey: idempotencyKey,
      );

      // Reload assignment to get updated status
      await loadActiveAssignment();
      state = state.copyWith(isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// Start polling for assignment updates
  void _startAssignmentPolling() {
    _stopAssignmentPolling();
    _assignmentPollingTimer = Timer.periodic(
      ApiConfig.assignmentPollingInterval,
      (_) => loadActiveAssignment(),
    );
  }

  /// Stop polling for assignment updates
  void _stopAssignmentPolling() {
    _assignmentPollingTimer?.cancel();
    _assignmentPollingTimer = null;
  }

  /// Set driver (from auth)
  void setDriver(Driver? driver) {
    state = state.copyWith(driver: driver);
    if (driver?.isOnShift == true) {
      _startAssignmentPolling();
    } else {
      _stopAssignmentPolling();
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _stopAssignmentPolling();
    super.dispose();
  }
}

/// Driver state provider
final driverProvider = StateNotifierProvider<DriverNotifier, DriverState>((ref) {
  return DriverNotifier(apiClient: ref.watch(apiClientProvider));
});

/// Convenience providers
final isOnShiftProvider = Provider<bool>((ref) {
  return ref.watch(driverProvider).isOnShift;
});

final activeAssignmentProvider = Provider<Assignment?>((ref) {
  return ref.watch(driverProvider).activeAssignment;
});

final nextStopProvider = Provider<Stop?>((ref) {
  return ref.watch(driverProvider).activeAssignment?.nextStop;
});
