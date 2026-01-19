import 'package:equatable/equatable.dart';

/// Invitation model representing a pending tenant invitation
class Invitation extends Equatable {
  final String id;
  final String tenantId;
  final String tenantName;
  final DateTime invitedAt;
  final String status;

  const Invitation({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.invitedAt,
    required this.status,
  });

  /// Check if invitation is pending
  bool get isPending => status == 'pending';

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      tenantName: json['tenant_name'] as String,
      invitedAt: DateTime.parse(json['invited_at'] as String),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'tenant_name': tenantName,
      'invited_at': invitedAt.toIso8601String(),
      'status': status,
    };
  }

  @override
  List<Object?> get props => [id, tenantId, tenantName, invitedAt, status];
}
