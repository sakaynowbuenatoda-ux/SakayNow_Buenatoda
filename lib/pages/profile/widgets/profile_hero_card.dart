import 'package:flutter/material.dart';

import '../../../widgets/firebase_storage_image.dart';
import '../../../widgets/passenger_widgets/passenger_ui.dart';
import '../models/profile_view_data.dart';

class ProfileHeroCard extends StatelessWidget {
  final ProfileViewData profile;
  final VoidCallback? onAvatarTap;
  final bool isUploadingProfilePicture;

  const ProfileHeroCard({
    super.key,
    required this.profile,
    this.onAvatarTap,
    this.isUploadingProfilePicture = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Container(
            key: const Key('profile-hero-identity'),
            padding: EdgeInsets.all(compact ? 16 : 20),
            decoration: BoxDecoration(
              color: PassengerUi.dark,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTight = constraints.maxWidth < 340;

                if (isTight) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ProfileAvatar(
                        profile: profile,
                        compact: compact,
                        onTap: onAvatarTap,
                        isUploading: isUploadingProfilePicture,
                      ),
                      SizedBox(height: 14),
                      _HeroDetails(profile: profile, compact: compact),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ProfileAvatar(
                      profile: profile,
                      compact: compact,
                      onTap: onAvatarTap,
                      isUploading: isUploadingProfilePicture,
                    ),
                    SizedBox(width: compact ? 12 : 16),
                    Expanded(
                      child: _HeroDetails(profile: profile, compact: compact),
                    ),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, thickness: 1, color: PassengerUi.border),
          Padding(
            padding: EdgeInsets.all(compact ? 14 : 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTight = constraints.maxWidth < 340;
                final cardWidth = isTight
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      child: _MainInfoItem(
                        icon: Icons.star_rounded,
                        label: 'Average Rating',
                        value: profile.ratingLabel,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MainInfoItem(
                        icon: Icons.reviews_outlined,
                        label: 'Reviews',
                        value: profile.reviewCount.toString(),
                      ),
                    ),
                    if (profile.isDriver)
                      SizedBox(
                        width: cardWidth,
                        child: _MainInfoItem(
                          icon: Icons.leaderboard_rounded,
                          label: 'Rank',
                          value: profile.rankLabel,
                        ),
                      ),
                    if (profile.isDriver)
                      SizedBox(
                        width: cardWidth,
                        child: _MainInfoItem(
                          icon: Icons.trending_up_rounded,
                          label: 'Rank Score',
                          value: profile.weightedRatingLabel,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDetails extends StatelessWidget {
  final ProfileViewData profile;
  final bool compact;

  const _HeroDetails({required this.profile, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                profile.fullName,
                style: TextStyle(
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            if (profile.showVerifiedBadge) ...[
              SizedBox(width: 10),
              _VerifiedBadge(compact: compact),
            ],
          ],
        ),
        SizedBox(height: 6),
        Text(
          profile.email,
          style: TextStyle(
            fontSize: compact ? 13 : 13.5,
            color: Colors.white.withValues(alpha: 0.72),
            height: 1.35,
          ),
        ),
        SizedBox(height: 12),
        Text(
          profile.roleLabel,
          style: TextStyle(
            fontSize: compact ? 12.5 : 13,
            fontWeight: FontWeight.w700,
            color: PassengerUi.accentBlue,
          ),
        ),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  final bool compact;

  const _VerifiedBadge({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: PassengerUi.successBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        Icons.verified_rounded,
        size: compact ? 15 : 17,
        color: PassengerUi.successText,
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final ProfileViewData profile;
  final bool compact;
  final VoidCallback? onTap;
  final bool isUploading;

  const _ProfileAvatar({
    required this.profile,
    required this.compact,
    required this.onTap,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = profile.profileImageUrl;
    final avatarSize = compact ? 72.0 : 82.0;
    final editIconSize = compact ? 25.0 : 27.0;

    final avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: PassengerUi.blueSoft,
        shape: BoxShape.circle,
        border: Border.all(color: PassengerUi.border, width: 2),
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            FirebaseStorageImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              fallback: _AvatarFallback(
                initials: profile.initials,
                compact: compact,
              ),
            ),
            if (isUploading)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.36),
                ),
                child: Center(
                  child: SizedBox(
                    width: compact ? 18 : 20,
                    height: compact ? 18 : 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final content = SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: Stack(
        children: <Widget>[
          avatar,
          if (onTap != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: editIconSize,
                height: editIconSize,
                decoration: BoxDecoration(
                  color: PassengerUi.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: PassengerUi.border, width: 1.4),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 7,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: compact ? 14 : 15,
                  color: PassengerUi.accentBlue,
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Tooltip(
      message: 'Change profile picture',
      child: Semantics(
        button: true,
        label: 'Change profile picture',
        child: GestureDetector(
          onTap: isUploading ? null : onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;
  final bool compact;

  const _AvatarFallback({required this.initials, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PassengerUi.blueSoft,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: compact ? 24 : 28,
          fontWeight: FontWeight.w800,
          color: PassengerUi.accentBlue,
        ),
      ),
    );
  }
}

class _MainInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MainInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: PassengerUi.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: PassengerUi.blueSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: PassengerUi.accentBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: PassengerUi.bodyText.copyWith(fontSize: 11.5),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.valueText.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
