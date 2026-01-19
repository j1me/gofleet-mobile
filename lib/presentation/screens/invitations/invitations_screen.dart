import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../data/models/invitation.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../../router/app_router.dart';

class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({super.key});

  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen> {
  bool _isAccepting = false;
  String? _processingTenantId;

  Future<void> _acceptInvitation(Invitation invitation) async {
    // #region agent log
    print('[DEBUG] Accept clicked - id: ${invitation.id}, tenantId: ${invitation.tenantId}, tenantName: ${invitation.tenantName}');
    // #endregion
    setState(() {
      _isAccepting = true;
      _processingTenantId = invitation.tenantId;
    });

    try {
      await ref.read(authProvider.notifier).acceptInvitation(invitation.id, invitation.tenantId);
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have joined ${invitation.tenantName}'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );

      context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept invitation: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
          _processingTenantId = null;
        });
      }
    }
  }

  Future<void> _declineInvitation(Invitation invitation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: const Text('Decline Invitation'),
        content: Text(
          'Are you sure you want to decline the invitation from ${invitation.tenantName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Decline',
              style: TextStyle(color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _processingTenantId = invitation.tenantId;
    });

    try {
      await ref.read(authProvider.notifier).rejectInvitation(invitation.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation declined'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingTenantId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final invitations = authState.invitations;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Invitations'),
        leading: authState.hasTenants
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          if (!authState.hasTenants)
            TextButton(
              onPressed: () => context.go(AppRoutes.noTenant),
              child: Text(
                'Skip',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isAccepting,
        message: 'Joining organization...',
        child: invitations.isEmpty
            ? _buildEmptyState()
            : _buildInvitationsList(invitations),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.darkGray,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.mail_outline,
                size: 56,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No pending invitations',
              style: AppTypography.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ask your dispatcher to send you an invitation to join their organization.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            AppOutlinedButton(
              text: 'Refresh',
              icon: Icons.refresh,
              onPressed: () {
                ref.read(authProvider.notifier).refreshInvitations();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationsList(List<Invitation> invitations) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          "You've been invited to join",
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        ...invitations.map((invitation) => _buildInvitationCard(invitation)),
      ],
    );
  }

  Widget _buildInvitationCard(Invitation invitation) {
    final isProcessing = _processingTenantId == invitation.tenantId;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: const Icon(
                  Icons.business,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.tenantName,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Invited ${dateFormat.format(invitation.invitedAt)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppOutlinedButton(
                  text: 'Decline',
                  height: 44,
                  onPressed: isProcessing
                      ? null
                      : () => _declineInvitation(invitation),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  text: 'Accept',
                  height: 44,
                  isLoading: isProcessing && _isAccepting,
                  onPressed: isProcessing
                      ? null
                      : () => _acceptInvitation(invitation),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
