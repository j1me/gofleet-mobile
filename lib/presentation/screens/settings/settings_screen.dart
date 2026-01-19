import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _backgroundLocationEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _soundEnabled = true;
  String _locationPermissionStatus = 'Checking...';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkLocationPermission();
  }

  Future<void> _loadSettings() async {
    final localStorage = ref.read(localStorageProvider);
    final backgroundLocation = await localStorage.isBackgroundLocationEnabled();
    final pushNotifications = await localStorage.isPushNotificationsEnabled();
    final sound = await localStorage.isSoundEnabled();

    if (mounted) {
      setState(() {
        _backgroundLocationEnabled = backgroundLocation;
        _pushNotificationsEnabled = pushNotifications;
        _soundEnabled = sound;
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;
    String statusText;

    if (status.isGranted) {
      final alwaysStatus = await Permission.locationAlways.status;
      if (alwaysStatus.isGranted) {
        statusText = 'Always allowed';
      } else {
        statusText = 'While using app';
      }
    } else if (status.isDenied) {
      statusText = 'Denied';
    } else if (status.isPermanentlyDenied) {
      statusText = 'Permanently denied';
    } else {
      statusText = 'Not determined';
    }

    if (mounted) {
      setState(() {
        _locationPermissionStatus = statusText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Location section
          _buildSectionHeader('LOCATION'),
          const SizedBox(height: 12),

          _buildActionTile(
            icon: Icons.location_on_outlined,
            title: 'Location Permission',
            subtitle: _locationPermissionStatus,
            onTap: () => openAppSettings(),
          ),

          _buildSwitchTile(
            icon: Icons.sync_outlined,
            title: 'Background Location',
            subtitle: 'Update location while app is minimized',
            value: _backgroundLocationEnabled,
            onChanged: (value) async {
              setState(() {
                _backgroundLocationEnabled = value;
              });
              await ref
                  .read(localStorageProvider)
                  .setBackgroundLocationEnabled(value);
            },
          ),

          const SizedBox(height: 24),

          // Notifications section
          _buildSectionHeader('NOTIFICATIONS'),
          const SizedBox(height: 12),

          _buildSwitchTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            subtitle: 'Receive assignment notifications',
            value: _pushNotificationsEnabled,
            onChanged: (value) async {
              setState(() {
                _pushNotificationsEnabled = value;
              });
              await ref
                  .read(localStorageProvider)
                  .setPushNotificationsEnabled(value);
            },
          ),

          _buildSwitchTile(
            icon: Icons.volume_up_outlined,
            title: 'Sound',
            subtitle: 'Play sound for notifications',
            value: _soundEnabled,
            onChanged: (value) async {
              setState(() {
                _soundEnabled = value;
              });
              await ref.read(localStorageProvider).setSoundEnabled(value);
            },
          ),

          const SizedBox(height: 24),

          // About section
          _buildSectionHeader('ABOUT'),
          const SizedBox(height: 12),

          _buildActionTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Version 1.0.0',
            onTap: () => _showAboutDialog(),
          ),

          _buildActionTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () {
              // TODO: Open terms of service
            },
          ),

          _buildActionTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {
              // TODO: Open privacy policy
            },
          ),

          const SizedBox(height: 32),

          // App version
          Center(
            child: Text(
              'GoFleet Driver v1.0.0',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.overline,
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.mediumGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.mediumGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_shipping,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: 16),
            const Text('GoFleet Driver'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version 1.0.0',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'GoFleet Driver is a mobile application for delivery drivers to manage shifts, receive assignments, and complete deliveries.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2024 GoFleet. All rights reserved.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
