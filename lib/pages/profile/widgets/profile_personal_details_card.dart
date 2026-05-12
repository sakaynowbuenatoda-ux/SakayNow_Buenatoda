import 'package:flutter/material.dart';

import '../../../widgets/passenger_widgets/passenger_ui.dart';
import '../models/profile_view_data.dart';

class ProfilePersonalDetailsCard extends StatelessWidget {
  final ProfileViewData profile;

  const ProfilePersonalDetailsCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          title: Text('View Personal Details', style: PassengerUi.cardTitle),
          subtitle: Text(
            'Account and document-related information from Firestore.',
            style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
          ),
          children: <Widget>[
            SizedBox(height: 8),
            _DetailRow(label: 'User ID', value: profile.userId),
            _DetailRow(label: 'First Name', value: profile.firstName),
            _DetailRow(label: 'Last Name', value: profile.lastName),
            _DetailRow(label: 'Email', value: profile.email),
            _DetailRow(label: 'Role', value: profile.roleLabel),
            _DetailRow(label: 'Gender', value: profile.genderLabel),
            _DetailRow(label: 'Age', value: profile.ageLabel),
            _DetailRow(label: 'Verification', value: profile.verificationLabel),
            _DetailRow(label: 'Created At', value: profile.createdAtLabel),
            _DetailRow(
              label: 'ID Image URL',
              value: profile.idImageUrl ?? 'Not provided',
            ),
            _DetailRow(
              label: 'Selfie URL',
              value: profile.selfieUrl ?? 'Not provided',
            ),
            _DetailRow(
              label: 'NBI Clearance URL',
              value: profile.nbiClearanceUrl ?? 'Not provided',
            ),
            _DetailRow(
              label: 'Driver\'s License URL',
              value: profile.driversLicenseUrl ?? 'Not provided',
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: PassengerUi.bodyText.copyWith(fontSize: 12.5)),
          SizedBox(height: 4),
          SelectableText(
            value,
            style: PassengerUi.valueText.copyWith(fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
