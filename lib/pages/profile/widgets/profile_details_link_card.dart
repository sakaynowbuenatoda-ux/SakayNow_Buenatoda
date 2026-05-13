import 'package:flutter/material.dart';

import '../../../widgets/passenger_widgets/passenger_ui.dart';

class ProfileDetailsLinkCard extends StatelessWidget {
  final VoidCallback onTap;

  const ProfileDetailsLinkCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: PassengerUi.cardRadius,
      onTap: onTap,
      child: PassengerSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PassengerUi.blueSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person_search_rounded,
                color: PassengerUi.accentBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('View Profile Details', style: PassengerUi.cardTitle),
                  const SizedBox(height: 3),
                  Text(
                    'Personal information and account basics.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: PassengerUi.body),
          ],
        ),
      ),
    );
  }
}
