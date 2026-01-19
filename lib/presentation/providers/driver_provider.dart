import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../data/models/models.dart';
import '../../services/api/api_client.dart';
import 'providers.dart';

// #region agent log
void _debugLog(String hypothesisId, String location, String message, Map<String, dynamic> data) {
  try {
    final logEntry = jsonEncode({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
    });
    File('/Users/jimmey/gofleet-driver-mobile/.cursor/debug.log').writeAsStringSync('$logEntry\n', mode: FileMode.append);
  } catch (_) {}
}
// #endregion

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
      // #region agent log
      _debugLog('C', 'driver_provider.dart:loadActiveAssignment:loaded', 'Assignment loaded from API', {
        'assignmentId': assignment?.id,
        'status': assignment?.status.toString(),
        'isStarted': assignment?.isStarted,
      });
      // #endregion
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
    // #region agent log
    _debugLog('E', 'driver_provider.dart:startAssignment:entry', 'startAssignment called', {
      'currentAssignmentStatus': state.activeAssignment?.status.toString(),
      'isLoading': state.isLoading,
    });
    // #endregion
    state = state.copyWith(isLoading: true, error: null);

    try {
      final assignment = await _apiClient.startAssignment();
      // #region agent log
      _debugLog('E', 'driver_provider.dart:startAssignment:success', 'startAssignment succeeded', {
        'newStatus': assignment.status.toString(),
      });
      // #endregion
      state = state.copyWith(activeAssignment: assignment, isLoading: false);
    } on ApiException catch (e) {
      // #region agent log
      _debugLog('D', 'driver_provider.dart:startAssignment:error', 'startAssignment API error', {
        'errorCode': e.code,
        'errorMessage': e.message,
      });
      // #endregion
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// Ensure assignment is started before performing actions
  Future<void> ensureAssignmentStarted() async {
    final assignment = state.activeAssignment;
    // #region agent log
    _debugLog('A', 'driver_provider.dart:ensureAssignmentStarted:entry', 'ensureAssignmentStarted called', {
      'assignmentId': assignment?.id,
      'assignmentStatus': assignment?.status.toString(),
      'isStarted': assignment?.isStarted,
      'isLoading': state.isLoading,
    });
    // #endregion
    if (assignment != null && !assignment.isStarted) {
      // #region agent log
      _debugLog('B', 'driver_provider.dart:ensureAssignmentStarted:willStart', 'About to call startAssignment', {
        'reason': 'assignment.isStarted is false',
      });
      // #endregion
      await startAssignment();
    } else {
      // #region agent log
      _debugLog('A', 'driver_provider.dart:ensureAssignmentStarted:skip', 'Skipping startAssignment', {
        'reason': assignment == null ? 'no assignment' : 'already started',
      });
      // #endregion
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
        occurredAt: DateTime.now().toUtc(),
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
