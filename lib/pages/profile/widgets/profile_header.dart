import 'package:flutter/material.dart';

import '../../../widgets/passenger_widgets/passenger_ui.dart';

class ProfileHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;

  const ProfileHeader({
    super.key,
    required this.title,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showBackButton) ...<Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: PassengerUi.surface,
              side: BorderSide(color: PassengerUi.border),
            ),
            icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
          ),
          SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: PassengerUi.sectionTitle.copyWith(
                  fontSize: compact ? 20 : 22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
