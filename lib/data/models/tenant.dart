import 'package:equatable/equatable.dart';

/// Tenant model representing an organization the driver belongs to
class Tenant extends Equatable {
  final String id;
  final String name;
  final String status;
  final DateTime? joinedAt;

  const Tenant({
    required this.id,
    required this.name,
    required this.status,
    this.joinedAt,
  });

  /// Check if tenant is active
  bool get isActive => status == 'active';

  /// Check if tenant is suspended
  bool get isSuspended => status == 'suspended';

  /// Check if tenant is terminated
  bool get isTerminated => status == 'terminated';

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'joined_at': joinedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, name, status, joinedAt];
}
