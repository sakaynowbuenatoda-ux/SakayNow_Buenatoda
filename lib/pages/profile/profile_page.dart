import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/profile_picture_service.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../settings/email_verification_page.dart';
import 'models/profile_view_data.dart';
import 'profile_details.dart';
import 'profile_picture_sheet.dart';
import 'widgets/profile_details_link_card.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_hero_card.dart';
import 'widgets/profile_reviews_card.dart';
import 'widgets/profile_state_layout.dart';

class ProfilePage extends StatefulWidget {
  final String userId;
  final bool embeddedInAdmin;
  final bool embedded;

  const ProfilePage({
    super.key,
    required this.userId,
    this.embeddedInAdmin = false,
    this.embedded = false,
  });

  bool get isEmbedded => embedded || embeddedInAdmin;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfilePictureService _profilePictureService = ProfilePictureService();
  bool _isUploadingProfilePicture = false;
  bool? _emailVerifiedOverride;

  @override
  Widget build(BuildContext context) {
    final content = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ProfileStateLayout(
            title: 'Profile Unavailable',
            showBackButton: !widget.isEmbedded,
            maxContentWidth: _maxContentWidth,
            child: PassengerEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load profile',
              description:
                  'We could not fetch your profile details right now. Please try again in a moment.',
            ),
          );
        }

        final profileDoc = snapshot.data;
        if (profileDoc == null || !profileDoc.exists) {
          return ProfileStateLayout(
            title: 'Profile Unavailable',
            showBackButton: !widget.isEmbedded,
            maxContentWidth: _maxContentWidth,
            child: PassengerEmptyState(
              icon: Icons.person_off_outlined,
              title: 'Profile not found',
              description: 'No profile details were found for this account.',
            ),
          );
        }

        final data = profileDoc.data() ?? <String, dynamic>{};
        final profile = ProfileViewData.fromMap(data, widget.userId);
        final authUser = FirebaseAuth.instance.currentUser;
        final isCurrentUserProfile = authUser?.uid == widget.userId;
        final isEmailVerified =
            _emailVerifiedOverride ?? authUser?.emailVerified == true;

        return _ProfileContent(
          profile: profile,
          showBackButton: !widget.isEmbedded,
          maxContentWidth: _maxContentWidth,
          isUploadingProfilePicture: _isUploadingProfilePicture,
          showEmailVerificationPrompt: isCurrentUserProfile && !isEmailVerified,
          onVerifyEmailTap: _openEmailVerificationPage,
          onProfilePictureTap: () => _changeProfilePicture(profile),
        );
      },
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: PassengerUi.background,
      body: SafeArea(child: content),
    );
  }

  double? get _maxContentWidth => widget.isEmbedded ? 760 : null;

  Future<void> _changeProfilePicture(ProfileViewData profile) async {
    if (_isUploadingProfilePicture) {
      return;
    }

    if (!profile.canUpdateProfilePicture) {
      _showMessage(
        'Profile picture can be changed again on ${profile.profilePictureNextUpdateLabel}.',
      );
      return;
    }

    final source = await showProfilePictureSourceSheet(context);
    if (source == null || !mounted) {
      return;
    }

    setState(() => _isUploadingProfilePicture = true);

    try {
      final selection = await _profilePictureService.pickProfilePicture(
        userId: widget.userId,
        source: source,
      );

      if (!mounted || selection == null) {
        return;
      }

      setState(() => _isUploadingProfilePicture = false);
      final confirmed = await showProfilePictureConfirmationDialog(
        context,
        selection: selection,
      );
      if (!mounted || !confirmed) {
        return;
      }

      setState(() => _isUploadingProfilePicture = true);
      await _profilePictureService.uploadProfilePicture(
        userId: widget.userId,
        selection: selection,
      );

      _showMessage('Profile picture updated.');
    } on ProfilePictureLimitException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Profile picture can be changed again on ${_formatDate(error.nextAvailableAt)}.',
      );
    } on ProfilePictureUploadException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Unable to update profile picture: $error');
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfilePicture = false);
      }
    }
  }

  Future<void> _openEmailVerificationPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EmailVerificationPage()));

    await FirebaseAuth.instance.currentUser?.reload();
    if (!mounted) {
      return;
    }

    setState(() {
      _emailVerifiedOverride =
          FirebaseAuth.instance.currentUser?.emailVerified == true;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatDate(DateTime value) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _ProfileContent extends StatelessWidget {
  final ProfileViewData profile;
  final bool showBackButton;
  final double? maxContentWidth;
  final bool isUploadingProfilePicture;
  final bool showEmailVerificationPrompt;
  final VoidCallback onVerifyEmailTap;
  final VoidCallback onProfilePictureTap;

  const _ProfileContent({
    required this.profile,
    required this.showBackButton,
    required this.maxContentWidth,
    required this.isUploadingProfilePicture,
    required this.showEmailVerificationPrompt,
    required this.onVerifyEmailTap,
    required this.onProfilePictureTap,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      maxContentWidth: maxContentWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ProfileHeader(title: 'My Profile', showBackButton: showBackButton),
          SizedBox(height: 18),
          if (showEmailVerificationPrompt) ...<Widget>[
            _EmailVerificationPromptBadge(onVerifyEmailTap: onVerifyEmailTap),
            const SizedBox(height: 10),
          ],
          ProfileHeroCard(
            profile: profile,
            isUploadingProfilePicture: isUploadingProfilePicture,
            onAvatarTap: onProfilePictureTap,
          ),
          const SizedBox(height: 14),
          ProfileDetailsLinkCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileDetailsPage(profile: profile),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ProfileReviewsCard(profile: profile),
        ],
      ),
    );
  }
}

class _EmailVerificationPromptBadge extends StatelessWidget {
  final VoidCallback onVerifyEmailTap;

  const _EmailVerificationPromptBadge({required this.onVerifyEmailTap});

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return Align(
      alignment: Alignment.centerRight,
      widthFactor: 1,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, compact ? 8 : 9, 8, compact ? 8 : 9),
        decoration: BoxDecoration(
          color: PassengerUi.warningSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PassengerUi.highlightAmber.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.mark_email_unread_outlined,
              size: 18,
              color: PassengerUi.highlightAmber,
            ),
            const SizedBox(width: 8),
            Text(
              'Email not verified',
              style: PassengerUi.valueText.copyWith(
                fontSize: compact ? 12.5 : 13,
                color: PassengerUi.title,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onVerifyEmailTap,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: PassengerUi.accentBlue,
              ),
              icon: const Icon(Icons.verified_user_outlined, size: 16),
              label: const Text('Verify Email'),
            ),
          ],
        ),
      ),
    );
  }
}
