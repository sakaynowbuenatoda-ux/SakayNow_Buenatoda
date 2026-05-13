import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'models/profile_view_data.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_state_layout.dart';

class ProfileDetailsLoaderPage extends StatelessWidget {
  final String userId;

  const ProfileDetailsLoaderPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: PassengerUi.background,
            body: const SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data?.exists != true) {
          return Scaffold(
            backgroundColor: PassengerUi.background,
            body: SafeArea(
              child: ProfileStateLayout(
                title: 'Profile Details',
                child: PassengerEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load details',
                  description:
                      snapshot.error?.toString() ??
                      'No profile record was found for this account.',
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() ?? <String, dynamic>{};
        return ProfileDetailsPage(
          profile: ProfileViewData.fromMap(data, userId),
        );
      },
    );
  }
}

class ProfileDetailsPage extends StatelessWidget {
  final ProfileViewData profile;

  const ProfileDetailsPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      body: SafeArea(
        child: PassengerPageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ProfileHeader(title: 'Profile Details'),
              const SizedBox(height: 18),
              PassengerSurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'First Name',
                      value: profile.firstName,
                    ),
                    _DetailRow(
                      icon: Icons.badge_outlined,
                      label: 'Last Name',
                      value: profile.lastName,
                    ),
                    _DetailRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: profile.email,
                    ),
                    _DetailRow(
                      icon: Icons.work_outline_rounded,
                      label: 'Role',
                      value: profile.roleLabel,
                    ),
                    _DetailRow(
                      icon: Icons.wc_rounded,
                      label: 'Gender',
                      value: profile.genderLabel,
                    ),
                    _DetailRow(
                      icon: Icons.cake_outlined,
                      label: 'Age',
                      value: profile.ageLabel,
                    ),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Joined At',
                      value: profile.joinedAtLabel,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedValue = value.isEmpty ? 'Not set' : value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : PassengerUi.border,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTight = constraints.maxWidth < 390;

          if (isTight) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DetailIcon(icon: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        resolvedValue,
                        style: PassengerUi.valueText.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _DetailIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: PassengerUi.bodyText.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SelectableText(
                  resolvedValue,
                  textAlign: TextAlign.right,
                  style: PassengerUi.valueText.copyWith(fontSize: 14),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailIcon extends StatelessWidget {
  final IconData icon;

  const _DetailIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: PassengerUi.blueSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: PassengerUi.accentBlue),
    );
  }
}
