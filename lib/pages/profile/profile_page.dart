import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'models/profile_view_data.dart';
import 'widgets/profile_feedback_preview_card.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_hero_card.dart';
import 'widgets/profile_personal_details_card.dart';
import 'widgets/profile_section_title.dart';
import 'widgets/profile_stat_grid.dart';
import 'widgets/profile_state_layout.dart';

class ProfilePage extends StatelessWidget {
  final String userId;

  const ProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ProfileStateLayout(
                title: 'Profile Unavailable',
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
                child: PassengerEmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'Profile not found',
                  description:
                      'No user record was found for this account in Firestore.',
                ),
              );
            }

            final data = profileDoc.data() ?? <String, dynamic>{};
            final profile = ProfileViewData.fromMap(data, userId);

            return _ProfileContent(profile: profile);
          },
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final ProfileViewData profile;

  const _ProfileContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ProfileHeader(title: '${profile.roleLabel} Profile'),
          SizedBox(height: 18),
          ProfileHeroCard(profile: profile),
          SizedBox(height: 18),
          ProfileSectionTitle(
            title: 'Performance Snapshot',
            subtitle:
                'These are placeholder insights for now and can be connected to real trip data later.',
          ),
          SizedBox(height: 12),
          ProfileStatGrid(profile: profile),
          SizedBox(height: 18),
          ProfileSectionTitle(
            title: 'Recent Feedback',
            subtitle:
                'Sample feedback layout for future integration with your ratings and review system.',
          ),
          SizedBox(height: 12),
          ProfileFeedbackPreviewCard(),
          SizedBox(height: 18),
          ProfilePersonalDetailsCard(profile: profile),
        ],
      ),
    );
  }
}
