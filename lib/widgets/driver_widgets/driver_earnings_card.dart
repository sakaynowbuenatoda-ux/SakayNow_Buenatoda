import 'package:flutter/material.dart';

import '../../models/driver_earnings_summary.dart';
import '../passenger_widgets/passenger_ui.dart';

class DriverEarningsCard extends StatelessWidget {
  final DriverEarningsSummary summary;

  const DriverEarningsCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      key: const ValueKey<String>('driver-earnings-card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Earnings breakdown', style: PassengerUi.cardTitle),
          const SizedBox(height: 5),
          Text(
            'Gross fares minus the configured platform commission.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 14),
          _EarningsPeriod(
            title: 'Today totals',
            gross: summary.todayGross,
            commission: summary.todayCommission,
            net: summary.todayNet,
          ),
          const SizedBox(height: 12),
          _EarningsPeriod(
            title: 'Lifetime totals',
            gross: summary.lifetimeGross,
            commission: summary.lifetimeCommission,
            net: summary.lifetimeNet,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PassengerUi.blueSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PassengerUi.border),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: PassengerUi.accentBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Cashless payout status',
                        style: PassengerUi.valueText,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        summary.cashlessPayoutStatusLabel,
                        style: PassengerUi.bodyText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsPeriod extends StatelessWidget {
  final String title;
  final int gross;
  final int commission;
  final int net;

  const _EarningsPeriod({
    required this.title,
    required this.gross,
    required this.commission,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: PassengerUi.valueText),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            _EarningsValue(
              label: 'Gross',
              value: DriverEarningsSummary.peso(gross),
            ),
            _EarningsValue(
              label: 'Commission',
              value: '-${DriverEarningsSummary.peso(commission)}',
            ),
            _EarningsValue(
              label: 'Net earnings',
              value: DriverEarningsSummary.peso(net),
              emphasize: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _EarningsValue extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _EarningsValue({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: PassengerUi.bodyText.copyWith(fontSize: 11)),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: emphasize
                  ? PassengerUi.cardTitle.copyWith(
                      color: PassengerUi.successText,
                    )
                  : PassengerUi.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
