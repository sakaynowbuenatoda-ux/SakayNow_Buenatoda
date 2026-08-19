import 'package:flutter/material.dart';

import '../../models/driver_document_status.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/time_ago_text.dart';
import '../../utils/user_facing_error_message.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_message_user_button.dart';
import 'widgets/admin_shared.dart';

class AdminUserReviewPage extends StatefulWidget {
  final String userId;
  final String adminId;

  const AdminUserReviewPage({
    super.key,
    required this.userId,
    required this.adminId,
  });

  @override
  State<AdminUserReviewPage> createState() => _AdminUserReviewPageState();
}

class _AdminUserReviewPageState extends State<AdminUserReviewPage> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminUi.background,
      appBar: AppBar(
        backgroundColor: AdminUi.surface,
        surfaceTintColor: AdminUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: AdminUi.title),
        ),
        title: Text('Verification Review', style: AdminUi.cardTitle),
      ),
      body: StreamBuilder<AdminUserRecord>(
        stream: AdminService.watchUser(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return AdminPageContainer(
              maxContentWidth: AdminUi.detailContentWidth,
              child: AdminErrorCard(
                message:
                    'Unable to load this verification review. Please try again.',
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const AdminPageContainer(
              maxContentWidth: AdminUi.detailContentWidth,
              child: AdminEmptyCollection(
                icon: Icons.person_off_outlined,
                title: 'User not found',
                description:
                    'This account profile could not be loaded for review.',
              ),
            );
          }

          final documents = _buildDocuments(user);
          final credentialsSubtitle = user.isDriver
              ? 'Tap any image card to inspect the submitted selfie, NBI clearance, or driver\'s license.'
              : 'Tap any image card to inspect the submitted selfie and ID.';

          return AdminPageContainer(
            maxContentWidth: AdminUi.detailContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewSummaryCard(user: user),
                SizedBox(height: 18),
                Text('Profile Information', style: AdminUi.sectionTitle),
                SizedBox(height: 6),
                Text(
                  'Review the account details submitted during registration.',
                  style: AdminUi.bodyText,
                ),
                SizedBox(height: 12),
                AdminSurfaceCard(
                  child: Column(
                    children: [
                      _InfoRow(label: 'User ID', value: user.userId),
                      _InfoRow(label: 'Email', value: user.email),
                      _InfoRow(label: 'Role', value: user.roleLabel),
                      if (user.isPassenger)
                        _InfoRow(
                          label: 'Passenger Type',
                          value: user.passengerTypeLabel,
                        ),
                      _InfoRow(label: 'First Name', value: user.firstName),
                      _InfoRow(label: 'Last Name', value: user.lastName),
                      _InfoRow(label: 'Gender', value: user.genderLabel),
                      _InfoRow(label: 'Age', value: user.ageLabel),
                      _InfoTimeRow(
                        label: 'Created At',
                        value: user.createdAt,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                if (user.isDriver) ...[
                  SizedBox(height: 18),
                  Text('Vehicle Information', style: AdminUi.sectionTitle),
                  SizedBox(height: 12),
                  AdminSurfaceCard(
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Vehicle Type',
                          value: user.effectiveVehicleType ?? 'Not provided',
                        ),
                        _InfoRow(
                          label: 'Tricycle Color',
                          value: user.effectiveTricycleColor ?? 'Not provided',
                        ),
                        _InfoRow(
                          label: 'Plate / Franchise No.',
                          value: user.effectivePlateNumber ?? 'Not provided',
                        ),
                        _InfoTimeRow(
                          label: 'Driver\'s License Expiry',
                          value: user.effectiveDriversLicenseExpiry,
                        ),
                        _InfoTimeRow(
                          label: 'OR/CR Expiry',
                          value: user.effectiveOrCrExpiry,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 18),
                Text('Uploaded Credentials', style: AdminUi.sectionTitle),
                SizedBox(height: 6),
                Text(credentialsSubtitle, style: AdminUi.bodyText),
                SizedBox(height: 12),
                if (documents.isEmpty)
                  const AdminEmptyCollection(
                    icon: Icons.image_not_supported_outlined,
                    title: 'No uploaded credentials found',
                    description:
                        'This user does not currently have readable credential images for review.',
                  )
                else
                  _CredentialGrid(
                    documents: documents,
                    onPreview: (document) => _showImagePreview(
                      context,
                      title: document.label,
                      imageUrl: document.url,
                    ),
                  ),
                if (user.isPendingRenewal) ...[
                  SizedBox(height: 18),
                  _RenewalReviewPanel(
                    user: user,
                    isProcessing: _isProcessing,
                    onApprove: () => _confirmAndRunAction(
                      title: 'Approve Renewal?',
                      message:
                          'This replaces the current ${user.driverDocumentStatus.renewalDocumentType?.label ?? 'driver document'} and applies its new expiry date.',
                      confirmLabel: 'Approve Renewal',
                      icon: Icons.verified_rounded,
                      confirmColor: AdminUi.successText,
                      action: () => AdminService.approveDriverRenewal(
                        userId: user.userId,
                        adminId: widget.adminId,
                      ),
                      successMessage:
                          '${user.fullName}\'s document renewal was approved.',
                    ),
                    onReject: () => _promptAndRejectRenewal(user),
                  ),
                ],
                if (user.hasPendingDocumentReview && user.isVerified) ...[
                  SizedBox(height: 18),
                  _DocumentUpdateReviewPanel(
                    user: user,
                    isProcessing: _isProcessing,
                    onApprove: () => _confirmAndRunAction(
                      title: 'Approve Document Update?',
                      message:
                          'This applies the staged ${user.pendingDocumentReviewLabel.toLowerCase()} without changing the account\'s verified status.',
                      confirmLabel: 'Approve Update',
                      icon: Icons.fact_check_rounded,
                      confirmColor: AdminUi.successText,
                      action: () => AdminService.approveDocumentReview(
                        userId: user.userId,
                        adminId: widget.adminId,
                      ),
                      successMessage:
                          '${user.fullName}\'s document update was approved.',
                    ),
                    onReject: () => _promptAndRejectDocumentReview(user),
                  ),
                ],
                SizedBox(height: 18),
                _ActionPanel(
                  user: user,
                  adminId: widget.adminId,
                  isProcessing: _isProcessing,
                  onVerify: user.canBeApproved
                      ? () => _confirmAndRunAction(
                          title: 'Verify User?',
                          message:
                              'This will approve ${user.fullName} and unlock verification-gated features for this account.',
                          confirmLabel: 'Verify User',
                          icon: Icons.verified_user_rounded,
                          confirmColor: AdminUi.successText,
                          action: () => AdminService.approveUser(
                            userId: user.userId,
                            adminId: widget.adminId,
                          ),
                          successMessage: '${user.fullName} is now verified.',
                        )
                      : null,
                  onRestrict: !user.isBanned
                      ? () => _confirmAndRunAction(
                          title: 'Restrict Account?',
                          message:
                              'This will block ${user.fullName} from using verification-gated app features until access is restored.',
                          confirmLabel: 'Restrict',
                          icon: Icons.block_rounded,
                          confirmColor: AdminUi.primary,
                          action: () => AdminService.restrictUser(
                            userId: user.userId,
                            adminId: widget.adminId,
                          ),
                          successMessage:
                              '${user.fullName} has been restricted.',
                        )
                      : null,
                  onRestore: user.isBanned
                      ? () => _runAction(
                          action: () => AdminService.restoreUser(
                            userId: user.userId,
                            adminId: widget.adminId,
                          ),
                          successMessage: '${user.fullName} has been restored.',
                        )
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_ReviewDocument> _buildDocuments(AdminUserRecord user) {
    if (user.isDriver) {
      return <_ReviewDocument>[
        if (user.effectiveSelfieUrl != null)
          _ReviewDocument(label: 'Selfie', url: user.effectiveSelfieUrl!),
        if (user.effectiveNbiClearanceUrl != null)
          _ReviewDocument(
            label: 'NBI Clearance',
            url: user.effectiveNbiClearanceUrl!,
          ),
        if (user.effectiveDriversLicenseUrl != null)
          _ReviewDocument(
            label: 'Driver\'s License',
            url: user.effectiveDriversLicenseUrl!,
          ),
        if (user.effectiveOrCrUrl != null)
          _ReviewDocument(label: 'OR/CR Document', url: user.effectiveOrCrUrl!),
        if (user.effectiveTricycleFrontUrl != null)
          _ReviewDocument(
            label: 'Front Tricycle Photo',
            url: user.effectiveTricycleFrontUrl!,
          ),
        if (user.effectiveTricycleBackUrl != null)
          _ReviewDocument(
            label: 'Back Tricycle Photo',
            url: user.effectiveTricycleBackUrl!,
          ),
        if (user.driverDocumentStatus.renewalDocumentUrl != null)
          _ReviewDocument(
            label:
                'Renewal: ${user.driverDocumentStatus.renewalDocumentType?.label ?? 'Driver Document'}',
            url: user.driverDocumentStatus.renewalDocumentUrl!,
          ),
      ];
    }

    return <_ReviewDocument>[
      if (user.effectiveSelfieUrl != null)
        _ReviewDocument(label: 'Selfie', url: user.effectiveSelfieUrl!),
      if (user.effectiveIdImageUrl != null)
        _ReviewDocument(
          label: user.isStudentPassenger
              ? 'Student ID'
              : (user.isSeniorCitizenPassenger
                    ? 'Senior Citizen ID'
                    : 'ID Image'),
          url: user.effectiveIdImageUrl!,
        ),
    ];
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    setState(() => _isProcessing = true);

    try {
      await action();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback: 'Action failed. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _confirmAndRunAction({
    required String title,
    required String message,
    required String confirmLabel,
    required IconData icon,
    required Color confirmColor,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      icon: icon,
      confirmColor: confirmColor,
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _runAction(action: action, successMessage: successMessage);
  }

  Future<void> _promptAndRejectRenewal(AdminUserRecord user) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Renewal?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 240,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason for the driver',
            hintText: 'Explain what must be corrected.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Reject Renewal'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    await _runAction(
      action: () => AdminService.rejectDriverRenewal(
        userId: user.userId,
        adminId: widget.adminId,
        reason: reason,
      ),
      successMessage: '${user.fullName}\'s renewal was rejected.',
    );
  }

  Future<void> _promptAndRejectDocumentReview(AdminUserRecord user) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Document Update?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 240,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason for the user',
            hintText: 'Explain what must be corrected.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Reject Update'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    await _runAction(
      action: () => AdminService.rejectDocumentReview(
        userId: user.userId,
        adminId: widget.adminId,
        reason: reason,
      ),
      successMessage: '${user.fullName}\'s document update was rejected.',
    );
  }

  Future<void> _showImagePreview(
    BuildContext context, {
    required String title,
    required String imageUrl,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: AdminUi.cardTitle)),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.65,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: InteractiveViewer(
                      child: FirebaseStorageImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        fallback: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          color: AdminUi.mutedSurface,
                          child: Text(
                            'Unable to preview this image right now.',
                            style: AdminUi.bodyText,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  final AdminUserRecord user;

  const _ReviewSummaryCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewAvatar(user: user, size: 52),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: AdminUi.cardTitle),
                SizedBox(height: 4),
                Text(user.email, style: AdminUi.bodyText),
                SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AdminStatusChip(
                      label: user.roleLabel,
                      textColor: AdminUi.primary,
                      backgroundColor: AdminUi.dangerSoft,
                    ),
                    AdminStatusChip(
                      label: user.statusLabel,
                      textColor: user.statusColor,
                      backgroundColor: user.statusBackgroundColor,
                    ),
                    AdminStatusChip(
                      label: user.createdAt == null
                          ? 'New account'
                          : 'Joined ${TimeAgo.format(user.createdAt)}',
                      textColor: AdminUi.body,
                      backgroundColor: AdminUi.mutedSurface,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewAvatar extends StatelessWidget {
  final AdminUserRecord user;
  final double size;

  const _ReviewAvatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: FirebaseStorageImage(
          imageUrl: user.profileImageUrl,
          fit: BoxFit.cover,
          fallback: Container(
            color: AdminUi.blueSoft,
            alignment: Alignment.center,
            child: Text(
              _initials(user.fullName),
              style: TextStyle(
                color: AdminUi.accentBlue,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.34,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'U';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class _RenewalReviewPanel extends StatelessWidget {
  final AdminUserRecord user;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RenewalReviewPanel({
    required this.user,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = user.driverDocumentStatus;
    return AdminSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Pending Renewal Review', style: AdminUi.cardTitle),
              ),
              AdminStatusChip(
                label: 'Pending renewal',
                textColor: AdminUi.accentBlue,
                backgroundColor: AdminUi.blueSoft,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${status.renewalDocumentType?.label ?? 'Driver document'} replacement expires ${status.renewalExpiry == null ? 'on an unrecorded date' : _adminDate(status.renewalExpiry!)}.',
            style: AdminUi.bodyText,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              AdminActionButton(
                label: 'Approve Renewal',
                icon: Icons.verified_rounded,
                backgroundColor: AdminUi.successBackground,
                foregroundColor: AdminUi.successText,
                onPressed: isProcessing ? null : onApprove,
              ),
              AdminActionButton(
                label: 'Reject Renewal',
                icon: Icons.cancel_outlined,
                backgroundColor: AdminUi.dangerSoft,
                foregroundColor: AdminUi.primary,
                onPressed: isProcessing ? null : onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _adminDate(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _DocumentUpdateReviewPanel extends StatelessWidget {
  final AdminUserRecord user;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _DocumentUpdateReviewPanel({
    required this.user,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Pending Document Review',
                  style: AdminUi.cardTitle,
                ),
              ),
              AdminStatusChip(
                label: 'Verified account',
                textColor: AdminUi.successText,
                backgroundColor: AdminUi.successBackground,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${user.pendingDocumentReviewLabel} is staged for review. The account remains verified and its previously approved profile stays in service until this update is approved.',
            style: AdminUi.bodyText,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              AdminActionButton(
                label: 'Approve Update',
                icon: Icons.fact_check_rounded,
                backgroundColor: AdminUi.successBackground,
                foregroundColor: AdminUi.successText,
                onPressed: isProcessing ? null : onApprove,
              ),
              AdminActionButton(
                label: 'Reject Update',
                icon: Icons.cancel_outlined,
                backgroundColor: AdminUi.dangerSoft,
                foregroundColor: AdminUi.primary,
                onPressed: isProcessing ? null : onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final AdminUserRecord user;
  final String adminId;
  final bool isProcessing;
  final VoidCallback? onVerify;
  final VoidCallback? onRestrict;
  final VoidCallback? onRestore;

  const _ActionPanel({
    required this.user,
    required this.adminId,
    required this.isProcessing,
    required this.onVerify,
    required this.onRestrict,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final messageButton = user.isPassengerOrDriver && !user.isDeleted
        ? AdminMessageUserButton(
            adminId: adminId,
            user: user,
            label: 'Message User',
            enabled: !isProcessing,
          )
        : null;

    if (user.isBanned) {
      return AdminSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Restricted Account', style: AdminUi.cardTitle),
            SizedBox(height: 8),
            Text(
              'This account is currently restricted. Restore access if the review is complete and the user should be active again.',
              style: AdminUi.bodyText,
            ),
            SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ?messageButton,
                AdminActionButton(
                  label: 'Restore Access',
                  icon: Icons.restart_alt_rounded,
                  backgroundColor: AdminUi.successBackground,
                  foregroundColor: AdminUi.successText,
                  onPressed: isProcessing ? null : onRestore,
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (user.isVerified) {
      return AdminSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Actions', style: AdminUi.cardTitle),
            SizedBox(height: 8),
            Text(
              'This user is already verified. Account features that require verification should now be available.',
              style: AdminUi.bodyText,
            ),
            SizedBox(height: 14),
            ?messageButton,
          ],
        ),
      );
    }

    return AdminSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Actions', style: AdminUi.cardTitle),
          SizedBox(height: 8),
          Text(
            'Verify this account to approve the submitted credentials and unlock features that require verification.',
            style: AdminUi.bodyText,
          ),
          if (user.isDriver && !user.isDriverVerificationComplete) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminUi.warningSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AdminUi.highlightAmber.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AdminUi.highlightAmber,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cannot verify account: This driver has incomplete vehicle information or missing verification documents.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AdminUi.title,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ?messageButton,
              AdminActionButton(
                label: 'Verify User',
                icon: Icons.verified_rounded,
                backgroundColor: AdminUi.successBackground,
                foregroundColor: AdminUi.successText,
                onPressed: isProcessing ? null : onVerify,
              ),
              AdminActionButton(
                label: 'Restrict Account',
                icon: Icons.block_rounded,
                backgroundColor: AdminUi.dangerSoft,
                foregroundColor: AdminUi.primary,
                onPressed: isProcessing ? null : onRestrict,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CredentialGrid extends StatelessWidget {
  final List<_ReviewDocument> documents;
  final ValueChanged<_ReviewDocument> onPreview;

  const _CredentialGrid({required this.documents, required this.onPreview});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        final spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: documents
              .map((document) {
                return SizedBox(
                  width: itemWidth,
                  child: _VerificationDocumentCard(
                    document: document,
                    onPreview: () => onPreview(document),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _VerificationDocumentCard extends StatelessWidget {
  final _ReviewDocument document;
  final VoidCallback onPreview;

  const _VerificationDocumentCard({
    required this.document,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return AdminInteractiveCard(
      onTap: onPreview,
      padding: const EdgeInsets.all(14),
      semanticLabel: 'Preview ${document.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  document.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminUi.cardTitle,
                ),
              ),
              IconButton(
                tooltip: 'Preview',
                onPressed: onPreview,
                icon: const Icon(Icons.open_in_full_rounded, size: 19),
              ),
            ],
          ),
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: FirebaseStorageImage(
                imageUrl: document.url,
                fit: BoxFit.cover,
                fallback: Container(
                  color: AdminUi.mutedSurface,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Preview unavailable',
                    style: AdminUi.bodyText,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: AdminUi.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 10),
          Expanded(child: SelectableText(value, style: AdminUi.valueText)),
        ],
      ),
    );
  }
}

class _InfoTimeRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool isLast;

  const _InfoTimeRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: AdminUi.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: TimeAgoText(dateTime: value, style: AdminUi.valueText),
          ),
        ],
      ),
    );
  }
}

class _ReviewDocument {
  final String label;
  final String url;

  const _ReviewDocument({required this.label, required this.url});
}
