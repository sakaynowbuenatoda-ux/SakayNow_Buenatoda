import 'package:flutter/material.dart';

import '../../../widgets/firebase_storage_image.dart';
import '../../../widgets/passenger_widgets/passenger_ui.dart';
import '../models/profile_view_data.dart';

class ProfileHeroCard extends StatelessWidget {
  final ProfileViewData profile;

  const ProfileHeroCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 18,
              compact ? 16 : 18,
              compact ? 16 : 18,
              compact ? 18 : 20,
            ),
            decoration: BoxDecoration(
              gradient: PassengerUi.darkActionGradient,
              borderRadius: BorderRadius.only(
                topLeft: PassengerUi.cardRadius.topLeft,
                topRight: PassengerUi.cardRadius.topRight,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTight = constraints.maxWidth < 340;

                if (isTight) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ProfileAvatar(profile: profile, compact: compact),
                      SizedBox(height: 14),
                      _HeroDetails(profile: profile, compact: compact),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ProfileAvatar(profile: profile, compact: compact),
                    SizedBox(width: compact ? 12 : 16),
                    Expanded(
                      child: _HeroDetails(profile: profile, compact: compact),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 16 : 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTight = constraints.maxWidth < 340;
                final cardWidth = isTight
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      child: _MainInfoItem(
                        icon: Icons.badge_outlined,
                        label: 'Role',
                        value: profile.roleLabel,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MainInfoItem(
                        icon: Icons.cake_outlined,
                        label: 'Age',
                        value: profile.ageLabel,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MainInfoItem(
                        icon: Icons.wc_outlined,
                        label: 'Gender',
                        value: profile.genderLabel,
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
            color: Colors.white70,
            height: 1.35,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _HeroChip(label: profile.roleLabel),
            _HeroChip(label: profile.genderLabel),
            _HeroChip(label: profile.ageLabel),
          ],
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
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: PassengerUi.successBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.verified_rounded,
            size: compact ? 14 : 16,
            color: PassengerUi.successText,
          ),
          SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: compact ? 11.5 : 12,
              fontWeight: FontWeight.w800,
              color: PassengerUi.successText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final ProfileViewData profile;
  final bool compact;

  const _ProfileAvatar({required this.profile, required this.compact});

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = profile.profileImageUrl;

    return Container(
      width: compact ? 72 : 82,
      height: compact ? 72 : 82,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: FirebaseStorageImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          fallback: _AvatarFallback(
            initials: profile.initials,
            compact: compact,
          ),
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
      color: Colors.white.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: compact ? 24 : 28,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: PassengerUi.accentBlue),
          SizedBox(height: 10),
          Text(label, style: PassengerUi.bodyText.copyWith(fontSize: 12.5)),
          SizedBox(height: 2),
          Text(value, style: PassengerUi.valueText),
        ],
      ),
    );
  }
}
