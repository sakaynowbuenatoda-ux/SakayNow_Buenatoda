import 'package:flutter/material.dart';

import '../../../widgets/passenger_widgets/passenger_ui.dart';

class ProfileSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const ProfileSectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[Text(title, style: PassengerUi.cardTitle)],
    );
  }
}
