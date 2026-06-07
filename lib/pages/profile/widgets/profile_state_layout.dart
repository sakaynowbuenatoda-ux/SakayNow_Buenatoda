import 'package:flutter/material.dart';

import '../../../widgets/passenger_widgets/passenger_ui.dart';
import 'profile_header.dart';

class ProfileStateLayout extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showBackButton;
  final double? maxContentWidth;

  const ProfileStateLayout({
    super.key,
    required this.title,
    required this.child,
    this.showBackButton = true,
    this.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      maxContentWidth: maxContentWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ProfileHeader(title: title, showBackButton: showBackButton),
          SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
