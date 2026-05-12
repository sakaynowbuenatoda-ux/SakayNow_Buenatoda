import 'package:flutter/material.dart';

import '../../widgets/firebase_storage_image.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/time_ago_text.dart';
import 'admin_models.dart';
import 'admin_service.dart';
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
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text('Verification Review', style: PassengerUi.cardTitle),
      ),
      body: StreamBuilder<AdminUserRecord>(
        stream: AdminService.watchUser(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return PassengerPageContainer(
              child: AdminErrorCard(
                message: 'Unable to load this user review: ${snapshot.error}',
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const PassengerPageContainer(
              child: AdminEmptyCollection(
                icon: Icons.person_off_outlined,
                title: 'User not found',
                description:
                    'This account record could not be loaded from Firestore.',
              ),
            );
          }

          final documents = _buildDocuments(user);
          final credentialsSubtitle = user.isDriver
              ? 'Tap any image card to inspect the submitted selfie, NBI clearance, or driver\'s license.'
              : 'Tap any image card to inspect the submitted selfie and ID.';

          return PassengerPageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewHeaderCard(user: user),
                SizedBox(height: 16),
                _ReviewSummaryCard(user: user),
                SizedBox(height: 18),
                Text('Profile Information', style: PassengerUi.sectionTitle),
                SizedBox(height: 6),
                Text(
                  'These values come directly from the current user document in Firestore.',
                  style: PassengerUi.bodyText,
                ),
                SizedBox(height: 12),
                PassengerSurfaceCard(
                  child: Column(
                    children: [
                      _InfoRow(label: 'User ID', value: user.userId),
                      _InfoRow(label: 'Email', value: user.email),
                      _InfoRow(label: 'Role', value: user.roleLabel),
                      if (user.isPassenger)
                        _InfoRow(
                          label: 'Passenger Type',
                          value: user.isStudentPassenger
                              ? 'Student'
                              : 'Regular',
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
                SizedBox(height: 18),
                Text('Uploaded Credentials', style: PassengerUi.sectionTitle),
                SizedBox(height: 6),
                Text(credentialsSubtitle, style: PassengerUi.bodyText),
                SizedBox(height: 12),
                if (documents.isEmpty)
                  const AdminEmptyCollection(
                    icon: Icons.image_not_supported_outlined,
                    title: 'No uploaded credentials found',
                    description:
                        'This user does not currently have readable document image links saved in Firestore.',
                  )
                else
                  ...documents.map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _VerificationDocumentCard(
                        document: document,
                        onPreview: () => _showImagePreview(
                          context,
                          title: document.label,
                          imageUrl: document.url,
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: 18),
                _ActionPanel(
                  user: user,
                  isProcessing: _isProcessing,
                  onVerify: user.isPendingVerification
                      ? () => _runAction(
                          action: () => AdminService.approveUser(
                            userId: user.userId,
                            adminId: widget.adminId,
                          ),
                          successMessage: '${user.fullName} is now verified.',
                        )
                      : null,
                  onRestrict: !user.isBanned
                      ? () => _runAction(
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
        if (user.selfieUrl != null)
          _ReviewDocument(
            label: 'Selfie',
            url: user.selfieUrl!,
            icon: Icons.portrait_outlined,
          ),
        if (user.nbiClearanceUrl != null)
          _ReviewDocument(
            label: 'NBI Clearance',
            url: user.nbiClearanceUrl!,
            icon: Icons.description_outlined,
          ),
        if (user.driversLicenseUrl != null)
          _ReviewDocument(
            label: 'Driver\'s License',
            url: user.driversLicenseUrl!,
            icon: Icons.credit_card_outlined,
          ),
      ];
    }

    return <_ReviewDocument>[
      if (user.selfieUrl != null)
        _ReviewDocument(
          label: 'Selfie',
          url: user.selfieUrl!,
          icon: Icons.portrait_outlined,
        ),
      if (user.idImageUrl != null)
        _ReviewDocument(
          label: user.isStudentPassenger ? 'Student ID' : 'ID Image',
          url: user.idImageUrl!,
          icon: Icons.badge_outlined,
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
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
                    Expanded(child: Text(title, style: PassengerUi.cardTitle)),
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
                          color: PassengerUi.mutedSurface,
                          child: Text(
                            'Unable to preview this image right now.',
                            style: PassengerUi.bodyText,
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

class _ReviewHeaderCard extends StatelessWidget {
  final AdminUserRecord user;

  const _ReviewHeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          _ReviewAvatar(user: user, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              user.fullName,
              style: PassengerUi.sectionTitle.copyWith(fontSize: 20),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  final AdminUserRecord user;

  const _ReviewSummaryCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewAvatar(user: user, size: 52),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: PassengerUi.cardTitle),
                SizedBox(height: 4),
                Text(user.email, style: PassengerUi.bodyText),
                SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PassengerStatusChip(
                      label: user.roleLabel,
                      textColor: PassengerUi.primary,
                      backgroundColor: PassengerUi.dangerSoft,
                    ),
                    PassengerStatusChip(
                      label: user.statusLabel,
                      textColor: user.statusColor,
                      backgroundColor: user.statusBackgroundColor,
                    ),
                    PassengerStatusChip(
                      label: user.createdAt == null
                          ? 'New account'
                          : 'Joined ${TimeAgo.format(user.createdAt)}',
                      textColor: PassengerUi.body,
                      backgroundColor: PassengerUi.mutedSurface,
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
            color: PassengerUi.blueSoft,
            alignment: Alignment.center,
            child: Text(
              _initials(user.fullName),
              style: TextStyle(
                color: PassengerUi.accentBlue,
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

class _ActionPanel extends StatelessWidget {
  final AdminUserRecord user;
  final bool isProcessing;
  final VoidCallback? onVerify;
  final VoidCallback? onRestrict;
  final VoidCallback? onRestore;

  const _ActionPanel({
    required this.user,
    required this.isProcessing,
    required this.onVerify,
    required this.onRestrict,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    if (user.isBanned) {
      return PassengerSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Restricted Account', style: PassengerUi.cardTitle),
            SizedBox(height: 8),
            Text(
              'This account is currently restricted. Restore access if the review is complete and the user should be active again.',
              style: PassengerUi.bodyText,
            ),
            SizedBox(height: 14),
            AdminActionButton(
              label: 'Restore Access',
              icon: Icons.restart_alt_rounded,
              backgroundColor: PassengerUi.successBackground,
              foregroundColor: PassengerUi.successText,
              onPressed: isProcessing ? null : onRestore,
            ),
          ],
        ),
      );
    }

    if (user.isVerified) {
      return AdminInfoPanel(
        title: 'Account Already Verified',
        description:
            'This user already has is_verified set to true in Firestore. Verification-gated features should now be available on the user side.',
        icon: Icons.verified_rounded,
        accentColor: PassengerUi.successText,
      );
    }

    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Actions', style: PassengerUi.cardTitle),
          SizedBox(height: 8),
          Text(
            'Verify this account to switch is_verified from false to true in Firestore and unlock verification-gated features for the user.',
            style: PassengerUi.bodyText,
          ),
          SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AdminActionButton(
                label: 'Verify User',
                icon: Icons.verified_rounded,
                backgroundColor: PassengerUi.successBackground,
                foregroundColor: PassengerUi.successText,
                onPressed: isProcessing ? null : onVerify,
              ),
              AdminActionButton(
                label: 'Restrict Account',
                icon: Icons.block_rounded,
                backgroundColor: PassengerUi.dangerSoft,
                foregroundColor: PassengerUi.primary,
                onPressed: isProcessing ? null : onRestrict,
              ),
            ],
          ),
        ],
      ),
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
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PassengerUi.mutedSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(document.icon, color: PassengerUi.accentBlue),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(document.label, style: PassengerUi.cardTitle),
              ),
              OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: const Text('Preview'),
              ),
            ],
          ),
          SizedBox(height: 12),
          GestureDetector(
            onTap: onPreview,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: FirebaseStorageImage(
                  imageUrl: document.url,
                  fit: BoxFit.cover,
                  fallback: Container(
                    color: PassengerUi.mutedSurface,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Unable to display this image preview.',
                      style: PassengerUi.bodyText,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          SelectableText(
            document.url,
            style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
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
              style: PassengerUi.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 10),
          Expanded(child: SelectableText(value, style: PassengerUi.valueText)),
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
              style: PassengerUi.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: TimeAgoText(dateTime: value, style: PassengerUi.valueText),
          ),
        ],
      ),
    );
  }
}

class _ReviewDocument {
  final String label;
  final String url;
  final IconData icon;

  const _ReviewDocument({
    required this.label,
    required this.url,
    required this.icon,
  });
}
