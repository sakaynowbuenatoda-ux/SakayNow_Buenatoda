import 'package:flutter/material.dart';

import '../../models/driver_document_status.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/time_ago_text.dart';
import '../../utils/user_facing_error_message.dart';
import '../admin/admin_models.dart';
import '../admin/admin_service.dart';
import '../admin/widgets/admin_shared.dart';
import '../admin/widgets/admin_user_app_bar_actions.dart';
import 'models/profile_review_item.dart';
import 'widgets/profile_reviews_section.dart';

class ViewUserProfilePage extends StatefulWidget {
  final String adminId;
  final String userId;

  const ViewUserProfilePage({
    super.key,
    required this.adminId,
    required this.userId,
  });

  @override
  State<ViewUserProfilePage> createState() => _ViewUserProfilePageState();
}

class _ViewUserProfilePageState extends State<ViewUserProfilePage> {
  bool _isProcessing = false;
  bool _areDocumentsVisible = false;
  late final Stream<AdminUserRecord> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = AdminService.watchUser(widget.userId).asBroadcastStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        toolbarHeight: 68,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text('User Profile', style: PassengerUi.cardTitle),
        actions: <Widget>[
          StreamBuilder<AdminUserRecord>(
            stream: _userStream,
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user == null) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: AdminUserAppBarActions(
                  user: user,
                  adminId: widget.adminId,
                  isProcessing: _isProcessing,
                  onRestrict: user.isBanned || user.isAdmin || user.isDeleted
                      ? null
                      : () => _restrictUser(user),
                  onRestore: user.isBanned ? () => _restoreUser(user) : null,
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<AdminUserRecord>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppSkeletonProfile();
          }

          if (snapshot.hasError) {
            return PassengerPageContainer(
              maxContentWidth: AdminUi.detailContentWidth,
              child: AdminErrorCard(
                message: 'Unable to load this user profile. Please try again.',
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const PassengerPageContainer(
              maxContentWidth: AdminUi.detailContentWidth,
              child: AdminEmptyCollection(
                icon: Icons.person_off_outlined,
                title: 'User not found',
                description: 'This account profile could not be loaded.',
              ),
            );
          }

          final documents = _buildDocuments(user);
          final showMissingDocumentsWarning =
              user.isDriver &&
              !user.isVerified &&
              !user.isBanned &&
              !user.isDeleted &&
              !user.isDriverVerificationComplete;

          return Stack(
            children: <Widget>[
              PassengerPageContainer(
                maxContentWidth: AdminUi.detailContentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showMissingDocumentsWarning) const SizedBox(height: 46),
                    _ProfileHero(user: user),
                    SizedBox(height: 16),
                    _ProfileStats(user: user),
                    SizedBox(height: 16),
                    _BasicInfoCard(user: user),
                    SizedBox(height: 16),
                    _UploadedDocumentsCard(
                      documents: documents,
                      isExpanded: _areDocumentsVisible,
                      onToggle: () => setState(
                        () => _areDocumentsVisible = !_areDocumentsVisible,
                      ),
                      onPreview: (document) => _showImagePreview(
                        context,
                        title: document.label,
                        imageUrl: document.url,
                      ),
                    ),
                    if (user.isDriver) ...[
                      SizedBox(height: 16),
                      _DriverReviewsSection(user: user),
                    ],
                  ],
                ),
              ),
              if (showMissingDocumentsWarning)
                const Positioned(
                  top: 10,
                  left: 16,
                  right: 16,
                  child: Center(child: AdminMissingDocumentsWarningPill()),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _restrictUser(AdminUserRecord user) {
    return _confirmAndRunAction(
      title: 'Restrict Account?',
      message:
          'This will block ${user.fullName} from using verification-gated app features until access is restored.',
      confirmLabel: 'Restrict',
      icon: Icons.block_rounded,
      confirmColor: Theme.of(context).colorScheme.error,
      action: () => AdminService.restrictUser(
        userId: user.userId,
        adminId: widget.adminId,
      ),
      successMessage: '${user.fullName} has been restricted.',
    );
  }

  Future<void> _restoreUser(AdminUserRecord user) {
    return _runAction(
      action: () => AdminService.restoreUser(
        userId: user.userId,
        adminId: widget.adminId,
      ),
      successMessage: '${user.fullName} has been restored.',
    );
  }

  List<_ProfileDocument> _buildDocuments(AdminUserRecord user) {
    if (user.isDriver) {
      return <_ProfileDocument>[
        if (user.selfieUrl != null)
          _ProfileDocument(label: 'Selfie', url: user.selfieUrl!),
        if (user.nbiClearanceUrl != null)
          _ProfileDocument(label: 'NBI Clearance', url: user.nbiClearanceUrl!),
        if (user.driversLicenseUrl != null)
          _ProfileDocument(
            label: 'Driver\'s License',
            url: user.driversLicenseUrl!,
          ),
        if (user.orCrUrl != null)
          _ProfileDocument(label: 'OR/CR Document', url: user.orCrUrl!),
        if (user.tricycleFrontUrl != null)
          _ProfileDocument(
            label: 'Front Tricycle Photo',
            url: user.tricycleFrontUrl!,
          ),
        if (user.tricycleBackUrl != null)
          _ProfileDocument(
            label: 'Back Tricycle Photo',
            url: user.tricycleBackUrl!,
          ),
        if (user.driverDocumentStatus.renewalDocumentUrl != null)
          _ProfileDocument(
            label:
                'Renewal: ${user.driverDocumentStatus.renewalDocumentType?.label ?? 'Driver Document'}',
            url: user.driverDocumentStatus.renewalDocumentUrl!,
          ),
      ];
    }

    return <_ProfileDocument>[
      if (user.selfieUrl != null)
        _ProfileDocument(label: 'Selfie', url: user.selfieUrl!),
      if (user.idImageUrl != null)
        _ProfileDocument(
          label: user.isStudentPassenger
              ? 'Student ID'
              : (user.isSeniorCitizenPassenger
                    ? 'Senior Citizen ID'
                    : 'ID Image'),
          url: user.idImageUrl!,
        ),
    ];
  }

  Future<void> _showImagePreview(
    BuildContext context, {
    required String title,
    required String imageUrl,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SizedBox(
                  height: MediaQuery.sizeOf(dialogContext).height * 0.65,
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
                          alignment: Alignment.center,
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
}

class _ProfileHero extends StatelessWidget {
  final AdminUserRecord user;

  const _ProfileHero({required this.user});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 118,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  PassengerUi.primary,
                  PassengerUi.accentBlue,
                  PassengerUi.secondary,
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(0, -38),
                  child: _ProfileAvatar(user: user, size: 92),
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: PassengerUi.sectionTitle.copyWith(fontSize: 24),
                      ),
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
                          if (user.isVerified)
                            PassengerStatusChip(
                              label: 'Verified badge',
                              textColor: PassengerUi.successText,
                              backgroundColor: PassengerUi.successBackground,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final AdminUserRecord user;
  final double size;

  const _ProfileAvatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PassengerUi.surface,
        border: Border.all(color: PassengerUi.surface, width: 4),
        boxShadow: PassengerUi.cardShadow,
      ),
      child: ClipOval(
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
                fontWeight: FontWeight.w800,
                fontSize: size * 0.32,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);
    return parts.isEmpty ? 'U' : parts.map((part) => part[0]).join();
  }
}

class _ProfileStats extends StatelessWidget {
  final AdminUserRecord user;

  const _ProfileStats({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Rating',
            value: user.reviewCount == 0
                ? 'No ratings'
                : user.averageRating.toStringAsFixed(1),
            icon: Icons.star_rate_rounded,
            color: PassengerUi.highlightAmber,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Reviews',
            value: user.reviewCount.toString(),
            icon: Icons.reviews_outlined,
            color: PassengerUi.accentBlue,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          SizedBox(height: 8),
          Text(value, style: PassengerUi.cardTitle),
          SizedBox(height: 2),
          Text(label, style: PassengerUi.bodyText),
        ],
      ),
    );
  }
}

class _BasicInfoCard extends StatelessWidget {
  final AdminUserRecord user;

  const _BasicInfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Basic Information', style: PassengerUi.cardTitle),
          SizedBox(height: 12),
          _InfoRow(label: 'User ID', value: user.userId),
          _InfoRow(label: 'First Name', value: user.firstName),
          _InfoRow(label: 'Last Name', value: user.lastName),
          _InfoRow(label: 'Role', value: user.roleLabel),
          if (user.isPassenger)
            _InfoRow(label: 'Passenger Type', value: user.passengerTypeLabel),
          _InfoRow(label: 'Gender', value: user.genderLabel),
          _InfoRow(label: 'Age', value: user.ageLabel),
          _InfoTimeRow(label: 'Joined', value: user.createdAt),
        ],
      ),
    );
  }
}

class _UploadedDocumentsCard extends StatelessWidget {
  final List<_ProfileDocument> documents;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<_ProfileDocument> onPreview;

  const _UploadedDocumentsCard({
    required this.documents,
    required this.isExpanded,
    required this.onToggle,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final documentCountLabel = documents.length == 1
        ? '1 uploaded document'
        : '${documents.length} uploaded documents';

    return PassengerSurfaceCard(
      key: const Key('admin-profile-documents-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Uploaded Documents', style: PassengerUi.cardTitle),
                    SizedBox(height: 4),
                    Text(documentCountLabel, style: PassengerUi.bodyText),
                  ],
                ),
              ),
              TextButton.icon(
                key: const Key('admin-profile-documents-toggle'),
                onPressed: onToggle,
                icon: Icon(
                  isExpanded
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 19,
                ),
                label: Text(isExpanded ? 'Hide documents' : 'View documents'),
              ),
            ],
          ),
          if (isExpanded) ...[
            SizedBox(height: 14),
            if (documents.isEmpty)
              Container(
                key: const Key('admin-profile-documents-content'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PassengerUi.mutedSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: PassengerUi.body,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No uploaded documents found',
                      style: PassengerUi.valueText,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'This user does not currently have readable document images.',
                      style: PassengerUi.bodyText,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              _ProfileDocumentGrid(
                key: const Key('admin-profile-documents-content'),
                documents: documents,
                onPreview: onPreview,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProfileDocumentGrid extends StatelessWidget {
  final List<_ProfileDocument> documents;
  final ValueChanged<_ProfileDocument> onPreview;

  const _ProfileDocumentGrid({
    super.key,
    required this.documents,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: documents
              .map(
                (document) => SizedBox(
                  width: itemWidth,
                  child: _ProfileDocumentCard(
                    document: document,
                    onPreview: () => onPreview(document),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ProfileDocumentCard extends StatelessWidget {
  final _ProfileDocument document;
  final VoidCallback onPreview;

  const _ProfileDocumentCard({required this.document, required this.onPreview});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPreview,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PassengerUi.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PassengerUi.border),
          ),
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
                      style: PassengerUi.valueText,
                    ),
                  ),
                  Icon(
                    Icons.open_in_full_rounded,
                    size: 18,
                    color: PassengerUi.body,
                  ),
                ],
              ),
              SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: FirebaseStorageImage(
                    imageUrl: document.url,
                    fit: BoxFit.cover,
                    fallback: Container(
                      color: PassengerUi.mutedSurface,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Preview unavailable',
                        style: PassengerUi.bodyText,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDocument {
  final String label;
  final String url;

  const _ProfileDocument({required this.label, required this.url});
}

class _DriverReviewsSection extends StatelessWidget {
  final AdminUserRecord user;

  const _DriverReviewsSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return ProfileReviewsPreview(
      title: 'Ratings and Reviews',
      profileName: user.fullName,
      emptyTitle: 'No driver reviews yet',
      emptyDescription:
          'Driver reviews will appear here after passengers submit feedback.',
      allReviewsMaxContentWidth: AdminUi.detailContentWidth,
      reviewsLoader: () => AdminService.watchReviewsForUser(user.userId).map(
        (reviews) => reviews
            .map(ProfileReviewItem.fromAdminReview)
            .toList(growable: false),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: PassengerUi.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value.isEmpty ? 'Not set' : value,
              style: PassengerUi.valueText,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTimeRow extends StatelessWidget {
  final String label;
  final DateTime? value;

  const _InfoTimeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
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
    );
  }
}
