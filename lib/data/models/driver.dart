import 'package:equatable/equatable.dart';

/// Driver model representing the authenticated driver
class Driver extends Equatable {
  final String id;
  final String? tenantId;
  final String name;
  final String phone;
  final String? email;
  final String status;
  final DateTime? shiftStartedAt;
  final DateTime? lastSeenAt;

  const Driver({
    required this.id,
    this.tenantId,
    required this.name,
    required this.phone,
    this.email,
    required this.status,
    this.shiftStartedAt,
    this.lastSeenAt,
  });

  /// Check if driver is currently on shift
  bool get isOnShift => shiftStartedAt != null;

  /// Check if driver is active
  bool get isActive => status == 'active';

  /// Get shift duration if on shift
  Duration? get shiftDuration {
    if (shiftStartedAt == null) return null;
    return DateTime.now().difference(shiftStartedAt!);
  }

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String?,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      status: json['status'] as String,
      shiftStartedAt: json['shift_started_at'] != null
          ? DateTime.parse(json['shift_started_at'] as String)
          : null,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'phone': phone,
      'email': email,
      'status': status,
      'shift_started_at': shiftStartedAt?.toIso8601String(),
      'last_seen_at': lastSeenAt?.toIso8601String(),
    };
  }

  Driver copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? phone,
    String? email,
    String? status,
    DateTime? shiftStartedAt,
    DateTime? lastSeenAt,
  }) {
    return Driver(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      shiftStartedAt: shiftStartedAt ?? this.shiftStartedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        name,
        phone,
        email,
        status,
        shiftStartedAt,
        lastSeenAt,
      ];
}
