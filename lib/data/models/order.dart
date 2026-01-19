import 'package:equatable/equatable.dart';

/// Order status enum
enum OrderStatus {
  unassigned,
  assigned,
  outForDelivery,
  delivered,
  failed,
  cancelled;

  static OrderStatus fromString(String value) {
    switch (value) {
      case 'unassigned':
        return OrderStatus.unassigned;
      case 'assigned':
        return OrderStatus.assigned;
      case 'out_for_delivery':
        return OrderStatus.outForDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'failed':
        return OrderStatus.failed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.unassigned;
    }
  }

  String toApiString() {
    switch (this) {
      case OrderStatus.unassigned:
        return 'unassigned';
      case OrderStatus.assigned:
        return 'assigned';
      case OrderStatus.outForDelivery:
        return 'out_for_delivery';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.failed:
        return 'failed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }
}

/// Order model representing a delivery order
class Order extends Equatable {
  final String id;
  final String customerName;
  final String dropAddress;
  final double dropLat;
  final double dropLng;
  final String? notes;
  final OrderStatus status;

  const Order({
    required this.id,
    required this.customerName,
    required this.dropAddress,
    required this.dropLat,
    required this.dropLng,
    this.notes,
    required this.status,
  });

  /// Check if order is completed (delivered or failed)
  bool get isCompleted =>
      status == OrderStatus.delivered || status == OrderStatus.failed;

  /// Check if order is delivered
  bool get isDelivered => status == OrderStatus.delivered;

  /// Check if order is failed
  bool get isFailed => status == OrderStatus.failed;

  /// Check if order can be delivered
  bool get canDeliver => status == OrderStatus.outForDelivery;

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      customerName: json['customer_name'] as String,
      dropAddress: json['drop_address'] as String,
      dropLat: (json['drop_lat'] as num).toDouble(),
      dropLng: (json['drop_lng'] as num).toDouble(),
      notes: json['notes'] as String?,
      status: OrderStatus.fromString(json['status'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_name': customerName,
      'drop_address': dropAddress,
      'drop_lat': dropLat,
      'drop_lng': dropLng,
      'notes': notes,
      'status': status.toApiString(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        customerName,
        dropAddress,
        dropLat,
        dropLng,
        notes,
        status,
      ];
}
