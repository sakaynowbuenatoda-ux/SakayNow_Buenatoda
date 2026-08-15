import 'package:flutter/material.dart';

import '../../widgets/confirmation_dialog.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/time_ago_text.dart';
import '../../utils/user_facing_error_message.dart';
import '../admin/admin_models.dart';
import '../admin/admin_service.dart';
import '../admin/widgets/admin_shared.dart';
import '../admin/widgets/admin_message_user_button.dart';
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
        title: Text('User Profile', style: PassengerUi.cardTitle),
      ),
      body: StreamBuilder<AdminUserRecord>(
        stream: AdminService.watchUser(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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

          return PassengerPageContainer(
            maxContentWidth: AdminUi.detailContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHero(user: user),
                SizedBox(height: 16),
                _ProfileStats(user: user),
                SizedBox(height: 16),
                _BasicInfoCard(user: user),
                SizedBox(height: 16),
                _AdminProfileActions(
                  user: user,
                  adminId: widget.adminId,
                  isProcessing: _isProcessing,
                  onRestrict: user.isBanned || user.isAdmin
                      ? null
                      : () => _confirmAndRunAction(
                          title: 'Restrict Account?',
                          message:
                              'This will block ${user.fullName} from using verification-gated app features until access is restored.',
                          confirmLabel: 'Restrict',
                          icon: Icons.block_rounded,
                          confirmColor: PassengerUi.primary,
                          action: () => AdminService.restrictUser(
                            userId: user.userId,
                            adminId: widget.adminId,
                          ),
                          successMessage:
                              '${user.fullName} has been restricted.',
                        ),
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
                if (user.isDriver) ...[
                  SizedBox(height: 16),
                  _DriverReviewsSection(user: user),
                ],
              ],
            ),
          );
        },
      ),
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

class _AdminProfileActions extends StatelessWidget {
  final AdminUserRecord user;
  final String adminId;
  final bool isProcessing;
  final VoidCallback? onRestrict;
  final VoidCallback? onRestore;

  const _AdminProfileActions({
    required this.user,
    required this.adminId,
    required this.isProcessing,
    required this.onRestrict,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Actions', style: PassengerUi.cardTitle),
          SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (user.isPassengerOrDriver && !user.isDeleted)
                AdminMessageUserButton(
                  adminId: adminId,
                  user: user,
                  enabled: !isProcessing,
                ),
              if (user.isBanned)
                AdminActionButton(
                  label: 'Restore Access',
                  icon: Icons.restart_alt_rounded,
                  backgroundColor: PassengerUi.successBackground,
                  foregroundColor: PassengerUi.successText,
                  onPressed: isProcessing ? null : onRestore,
                )
              else if (!user.isAdmin)
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
