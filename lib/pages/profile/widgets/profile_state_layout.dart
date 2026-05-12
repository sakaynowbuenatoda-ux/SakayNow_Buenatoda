import 'package:flutter/material.dart';

import '../../../widgets/passenger_widgets/passenger_ui.dart';
import 'profile_header.dart';

class ProfileStateLayout extends StatelessWidget {
  final String title;
  final Widget child;

  const ProfileStateLayout({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ProfileHeader(title: title),
          SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
