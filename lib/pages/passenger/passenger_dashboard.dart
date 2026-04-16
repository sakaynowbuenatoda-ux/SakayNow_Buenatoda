import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_payment_method_card.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'passenger_data.dart';

class PassengerDashboard extends StatelessWidget {
  final String userId;
  final String firstName;
  final String role;

  const PassengerDashboard({
    super.key,
    required this.userId,
    required this.firstName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Passenger Dashboard', style: PassengerUi.sectionTitle.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            'Manage your profile, cashless setup, savings, and ride activity in one place.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 18),
          ...PassengerMockData.dashboardStats.asMap().entries.map(
            (MapEntry<int, PassengerInfoStat> entry) => Padding(
              padding: EdgeInsets.only(bottom: entry.key.isEven ? 12 : 12),
              child: PassengerStatTile(
                icon: entry.value.icon,
                label: entry.value.label,
                value: entry.value.value,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const PassengerSectionHeader(title: 'Cashless Payment'),
          const SizedBox(height: 12),
          ...PassengerMockData.paymentMethods.asMap().entries.map(
            (MapEntry<int, PassengerSavedPaymentMethod> entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == PassengerMockData.paymentMethods.length - 1 ? 0 : 12,
              ),
              child: PassengerPaymentMethodCard(method: entry.value),
            ),
          ),
          const SizedBox(height: 20),
          PassengerSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Verification and Safety', style: PassengerUi.cardTitle),
                SizedBox(height: 8),
                Text(
                  'Student discount is active, account is protected, and ride records stay available for support and reporting.',
                  style: PassengerUi.bodyText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
