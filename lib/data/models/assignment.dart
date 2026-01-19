import 'package:equatable/equatable.dart';

import 'stop.dart';

/// Assignment status enum
enum AssignmentStatus {
  created,
  started,
  completed,
  cancelled;

  static AssignmentStatus fromString(String value) {
    switch (value) {
      case 'created':
        return AssignmentStatus.created;
      case 'started':
        return AssignmentStatus.started;
      case 'completed':
        return AssignmentStatus.completed;
      case 'cancelled':
        return AssignmentStatus.cancelled;
      default:
        return AssignmentStatus.created;
    }
  }

  String toApiString() {
    switch (this) {
      case AssignmentStatus.created:
        return 'created';
      case AssignmentStatus.started:
        return 'started';
      case AssignmentStatus.completed:
        return 'completed';
      case AssignmentStatus.cancelled:
        return 'cancelled';
    }
  }
}

/// Assignment model representing a batch of orders assigned to a driver
class Assignment extends Equatable {
  final String id;
  final AssignmentStatus status;
  final DateTime assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<Stop> stops;

  const Assignment({
    required this.id,
    required this.status,
    required this.assignedAt,
    this.startedAt,
    this.completedAt,
    required this.stops,
  });

  /// Check if assignment is active (created or started)
  bool get isActive =>
      status == AssignmentStatus.created || status == AssignmentStatus.started;

  /// Check if assignment has been started
  bool get isStarted => status == AssignmentStatus.started;

  /// Check if assignment is completed
  bool get isCompleted => status == AssignmentStatus.completed;

  /// Get total number of stops
  int get totalStops => stops.length;

  /// Get number of completed stops
  int get completedStops => stops.where((s) => s.isCompleted).length;

  /// Get number of pending stops
  int get pendingStops => stops.where((s) => s.isPending).length;

  /// Get number of delivered stops
  int get deliveredStops => stops.where((s) => s.isDelivered).length;

  /// Get number of failed stops
  int get failedStops => stops.where((s) => s.isFailed).length;

  /// Get completion percentage
  double get completionPercentage {
    if (totalStops == 0) return 0;
    return completedStops / totalStops;
  }

  /// Get the next pending stop (first pending in sequence)
  Stop? get nextStop {
    final pendingStopsList = stops.where((s) => s.isPending).toList();
    if (pendingStopsList.isEmpty) return null;
    pendingStopsList.sort((a, b) => a.sequence.compareTo(b.sequence));
    return pendingStopsList.first;
  }

  /// Get stops sorted by sequence
  List<Stop> get sortedStops {
    final sorted = List<Stop>.from(stops);
    sorted.sort((a, b) => a.sequence.compareTo(b.sequence));
    return sorted;
  }

  /// Get duration since assignment started
  Duration? get duration {
    if (startedAt == null) return null;
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt!);
  }

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as String,
      status: AssignmentStatus.fromString(json['status'] as String),
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      stops: (json['stops'] as List<dynamic>)
          .map((s) => Stop.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status.toApiString(),
      'assigned_at': assignedAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'stops': stops.map((s) => s.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        status,
        assignedAt,
        startedAt,
        completedAt,
        stops,
      ];
}
