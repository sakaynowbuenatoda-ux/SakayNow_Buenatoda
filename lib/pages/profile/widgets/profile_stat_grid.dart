import 'package:flutter/material.dart';

import '../../../widgets/passenger_widgets/passenger_ui.dart';
import '../models/profile_view_data.dart';

class ProfileStatGrid extends StatelessWidget {
  final ProfileViewData profile;

  const ProfileStatGrid({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final List<_ProfileStatData> stats = <_ProfileStatData>[
      _ProfileStatData(
        label: 'Average Rating',
        value: profile.reviewCount == 0
            ? 'New'
            : profile.averageRating.toStringAsFixed(1),
        icon: Icons.star_rounded,
        color: PassengerUi.highlightAmber,
      ),
      _ProfileStatData(
        label: 'Feedback Count',
        value: profile.reviewCount.toString(),
        icon: Icons.reviews_outlined,
        color: PassengerUi.accentBlue,
      ),
      _ProfileStatData(
        label: 'Completion Rate',
        value: '96%',
        icon: Icons.trending_up_rounded,
        color: PassengerUi.secondary,
      ),
      _ProfileStatData(
        label: 'This Month',
        value: '+12',
        icon: Icons.insights_outlined,
        color: PassengerUi.primary,
      ),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final compact = PassengerUi.isCompactWidth(context);
    final crossAxisCount = width < 330 ? 1 : 2;

    return GridView.builder(
      itemCount: stats.length,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: crossAxisCount == 1 ? 2.7 : (compact ? 1.18 : 1.35),
      ),
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            color: PassengerUi.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PassengerUi.border),
            boxShadow: PassengerUi.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: compact ? 38 : 40,
                height: compact ? 38 : 40,
                decoration: BoxDecoration(
                  color: stat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(stat.icon, color: stat.color),
              ),
              Spacer(),
              Text(
                stat.value,
                style: PassengerUi.sectionTitle.copyWith(
                  fontSize: compact ? 18 : 20,
                ),
              ),
              SizedBox(height: 4),
              Text(
                stat.label,
                style: PassengerUi.bodyText.copyWith(
                  fontSize: compact ? 12 : 12.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileStatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ProfileStatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
