import 'package:equatable/equatable.dart';

import 'order.dart';

/// Stop status enum
enum StopStatus {
  pending,
  delivered,
  failed;

  static StopStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return StopStatus.pending;
      case 'delivered':
        return StopStatus.delivered;
      case 'failed':
        return StopStatus.failed;
      default:
        return StopStatus.pending;
    }
  }

  String toApiString() {
    switch (this) {
      case StopStatus.pending:
        return 'pending';
      case StopStatus.delivered:
        return 'delivered';
      case StopStatus.failed:
        return 'failed';
    }
  }
}

/// Stop model representing an individual delivery stop in an assignment
class Stop extends Equatable {
  final String id;
  final int sequence;
  final StopStatus status;
  final DateTime? completedAt;
  final Order order;

  const Stop({
    required this.id,
    required this.sequence,
    required this.status,
    this.completedAt,
    required this.order,
  });

  /// Check if stop is completed
  bool get isCompleted =>
      status == StopStatus.delivered || status == StopStatus.failed;

  /// Check if stop is pending
  bool get isPending => status == StopStatus.pending;

  /// Check if stop is delivered
  bool get isDelivered => status == StopStatus.delivered;

  /// Check if stop is failed
  bool get isFailed => status == StopStatus.failed;

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['id'] as String,
      sequence: json['sequence'] as int,
      status: StopStatus.fromString(json['status'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      order: Order.fromJson(json['order'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sequence': sequence,
      'status': status.toApiString(),
      'completed_at': completedAt?.toIso8601String(),
      'order': order.toJson(),
    };
  }

  @override
  List<Object?> get props => [id, sequence, status, completedAt, order];
}
