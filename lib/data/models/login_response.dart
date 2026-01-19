import 'package:equatable/equatable.dart';

import 'auth_tokens.dart';
import 'driver.dart';
import 'tenant.dart';

/// Login response model containing tokens, driver info, and tenants
class LoginResponse extends Equatable {
  final AuthTokens tokens;
  final Driver driver;
  final List<Tenant> tenants;
  final Tenant? activeTenant;

  const LoginResponse({
    required this.tokens,
    required this.driver,
    required this.tenants,
    this.activeTenant,
  });

  /// Check if driver has any tenants
  bool get hasTenants => tenants.isNotEmpty;

  /// Check if driver has an active tenant
  bool get hasActiveTenant => activeTenant != null;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      tokens: AuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
      ),
      driver: Driver.fromJson(json['driver'] as Map<String, dynamic>),
      tenants: (json['tenants'] as List<dynamic>?)
              ?.map((t) => Tenant.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      activeTenant: json['active_tenant'] != null
          ? Tenant.fromJson(json['active_tenant'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [tokens, driver, tenants, activeTenant];
}
