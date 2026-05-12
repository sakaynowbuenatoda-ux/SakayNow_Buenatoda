import 'package:flutter/material.dart';

import '../../../widgets/passenger_widgets/passenger_ui.dart';

class ProfileFeedbackPreviewCard extends StatelessWidget {
  const ProfileFeedbackPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        children: <Widget>[
          _FeedbackTile(
            author: 'Maria S.',
            rating: '5.0',
            feedback:
                'Very smooth trip and easy to coordinate. The profile page can later show real review history here.',
          ),
          SizedBox(height: 12),
          Divider(color: PassengerUi.border, height: 1),
          SizedBox(height: 12),
          _FeedbackTile(
            author: 'System Preview',
            rating: '4.8',
            feedback:
                'A clean summary of user feedback helps build trust and gives space for future analytics.',
          ),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  final String author;
  final String rating;
  final String feedback;

  const _FeedbackTile({
    required this.author,
    required this.rating,
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PassengerUi.mutedSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            author[0],
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: PassengerUi.primary,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(author, style: PassengerUi.valueText),
                  SizedBox(width: 8),
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: PassengerUi.highlightAmber,
                  ),
                  SizedBox(width: 3),
                  Text(
                    rating,
                    style: PassengerUi.bodyText.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(feedback, style: PassengerUi.bodyText),
            ],
          ),
        ),
      ],
    );
  }
}
