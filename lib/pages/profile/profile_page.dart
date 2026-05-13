import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'models/profile_view_data.dart';
import 'profile_details.dart';
import 'widgets/profile_details_link_card.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_hero_card.dart';
import 'widgets/profile_reviews_card.dart';
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
          ProfileHeader(title: 'My Profile'),
          SizedBox(height: 18),
          ProfileHeroCard(profile: profile),
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
