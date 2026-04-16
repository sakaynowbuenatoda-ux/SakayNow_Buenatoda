import 'package:flutter/material.dart';

import '../../pages/passenger/passenger_data.dart';
import 'passenger_ui.dart';

class PassengerFareInformationCard extends StatelessWidget {
  final List<PassengerFareDetail> fareDetails;

  const PassengerFareInformationCard({
    super.key,
    this.fareDetails = PassengerMockData.fareDetails,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Fare Information', style: PassengerUi.cardTitle),
          const SizedBox(height: 6),
          Text(
            'Transparent local fares, student-friendly pricing, and cashless options for safer travel.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 14),
          ...fareDetails.asMap().entries.map(
            (MapEntry<int, PassengerFareDetail> entry) => Padding(
              padding: EdgeInsets.only(bottom: entry.key == fareDetails.length - 1 ? 0 : 10),
              child: PassengerFareInformationRow(detail: entry.value),
            ),
          ),
        ],
      ),
    );
  }
}

class PassengerFareInformationRow extends StatelessWidget {
  final PassengerFareDetail detail;

  const PassengerFareInformationRow({
    super.key,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(
            Icons.circle,
            size: 8,
            color: PassengerUi.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: PassengerUi.bodyText,
              children: <InlineSpan>[
                TextSpan(text: '${detail.label}: '),
                TextSpan(
                  text: detail.value,
                  style: PassengerUi.valueText.copyWith(
                    color: detail.valueColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
