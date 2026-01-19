import 'package:shared_preferences/shared_preferences.dart';

/// Local storage service for non-sensitive data
class LocalStorage {
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String _lastActiveTenanIdKey = 'last_active_tenant_id';
  static const String _preferredMapsAppKey = 'preferred_maps_app';
  static const String _backgroundLocationEnabledKey = 'background_location_enabled';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _pushNotificationsEnabledKey = 'push_notifications_enabled';

  SharedPreferences? _prefs;

  /// Initialize shared preferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure prefs is initialized
  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ============== Onboarding ==============

  /// Check if user has seen onboarding
  Future<bool> hasSeenOnboarding() async {
    final p = await prefs;
    return p.getBool(_hasSeenOnboardingKey) ?? false;
  }

  /// Mark onboarding as seen
  Future<void> setHasSeenOnboarding(bool value) async {
    final p = await prefs;
    await p.setBool(_hasSeenOnboardingKey, value);
  }

  // ============== Tenant ==============

  /// Get last active tenant ID
  Future<String?> getLastActiveTenantId() async {
    final p = await prefs;
    return p.getString(_lastActiveTenanIdKey);
  }

  /// Save last active tenant ID
  Future<void> setLastActiveTenantId(String? tenantId) async {
    final p = await prefs;
    if (tenantId == null) {
      await p.remove(_lastActiveTenanIdKey);
    } else {
      await p.setString(_lastActiveTenanIdKey, tenantId);
    }
  }

  // ============== Settings ==============

  /// Get preferred maps app (google, apple, waze)
  Future<String> getPreferredMapsApp() async {
    final p = await prefs;
    return p.getString(_preferredMapsAppKey) ?? 'google';
  }

  /// Set preferred maps app
  Future<void> setPreferredMapsApp(String app) async {
    final p = await prefs;
    await p.setString(_preferredMapsAppKey, app);
  }

  /// Check if background location is enabled
  Future<bool> isBackgroundLocationEnabled() async {
    final p = await prefs;
    return p.getBool(_backgroundLocationEnabledKey) ?? true;
  }

  /// Set background location enabled
  Future<void> setBackgroundLocationEnabled(bool value) async {
    final p = await prefs;
    await p.setBool(_backgroundLocationEnabledKey, value);
  }

  /// Check if sound is enabled
  Future<bool> isSoundEnabled() async {
    final p = await prefs;
    return p.getBool(_soundEnabledKey) ?? true;
  }

  /// Set sound enabled
  Future<void> setSoundEnabled(bool value) async {
    final p = await prefs;
    await p.setBool(_soundEnabledKey, value);
  }

  /// Check if push notifications are enabled
  Future<bool> isPushNotificationsEnabled() async {
    final p = await prefs;
    return p.getBool(_pushNotificationsEnabledKey) ?? true;
  }

  /// Set push notifications enabled
  Future<void> setPushNotificationsEnabled(bool value) async {
    final p = await prefs;
    await p.setBool(_pushNotificationsEnabledKey, value);
  }

  /// Clear all local storage
  Future<void> clearAll() async {
    final p = await prefs;
    await p.clear();
  }
}
