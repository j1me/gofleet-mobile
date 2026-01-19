import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../data/models/tenant.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../../router/app_router.dart';

class TenantListScreen extends ConsumerStatefulWidget {
  const TenantListScreen({super.key});

  @override
  ConsumerState<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends ConsumerState<TenantListScreen> {
  bool _isProcessing = false;
  String? _processingTenantId;

  Future<void> _switchTenant(Tenant tenant) async {
    setState(() {
      _isProcessing = true;
      _processingTenantId = tenant.id;
    });

    try {
      await ref.read(authProvider.notifier).switchTenant(tenant.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${tenant.name}'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );

      context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingTenantId = null;
        });
      }
    }
  }

  Future<void> _leaveTenant(Tenant tenant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: const Text('Leave Organization'),
        content: Text(
          'Are you sure you want to leave ${tenant.name}? You will need a new invitation to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Leave',
              style: TextStyle(color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
      _processingTenantId = tenant.id;
    });

    try {
      await ref.read(authProvider.notifier).leaveTenant(tenant.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Left ${tenant.name}'),
        ),
      );

      // Check if user still has tenants
      final authState = ref.read(authProvider);
      if (!authState.hasTenants) {
        context.go(AppRoutes.noTenant);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingTenantId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final tenants = authState.tenants;
    final activeTenant = authState.activeTenant;
    final pendingInvitations = authState.invitations;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Organizations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isProcessing,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Current tenant section
            if (activeTenant != null) ...[
              Text(
                'CURRENT',
                style: AppTypography.overline,
              ),
              const SizedBox(height: 12),
              _buildTenantCard(activeTenant, isActive: true),
              const SizedBox(height: 24),
            ],

            // Other tenants section
            if (tenants.where((t) => t.id != activeTenant?.id).isNotEmpty) ...[
              Text(
                'OTHER',
                style: AppTypography.overline,
              ),
              const SizedBox(height: 12),
              ...tenants
                  .where((t) => t.id != activeTenant?.id)
                  .map((tenant) => _buildTenantCard(tenant)),
              const SizedBox(height: 24),
            ],

            // Pending invitations link
            if (pendingInvitations.isNotEmpty) ...[
              const Divider(color: AppColors.lightGray),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.mail,
                    color: AppColors.primaryGreen,
                  ),
                ),
                title: Text(
                  '${pendingInvitations.length} pending invitation${pendingInvitations.length > 1 ? 's' : ''}',
                  style: AppTypography.titleMedium,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
                onTap: () => context.push(AppRoutes.invitations),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTenantCard(Tenant tenant, {bool isActive = false}) {
    final isProcessing = _processingTenantId == tenant.id;
    final dateFormat = DateFormat('MMM yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.primaryGreen : AppColors.lightGray,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.mediumGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business,
                  color: isActive ? AppColors.primaryGreen : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.name,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Member since ${tenant.joinedAt != null ? dateFormat.format(tenant.joinedAt!) : 'N/A'}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Active',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (!isActive) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    text: 'Leave',
                    height: 40,
                    borderColor: AppColors.errorRed.withOpacity(0.5),
                    textColor: AppColors.errorRed,
                    isLoading: isProcessing && !_isProcessing,
                    onPressed: isProcessing ? null : () => _leaveTenant(tenant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: 'Switch',
                    height: 40,
                    isLoading: isProcessing && _isProcessing,
                    onPressed: isProcessing ? null : () => _switchTenant(tenant),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
