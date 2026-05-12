import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_payment_method_card.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'passenger_data.dart';

class PassengerDashboard extends StatelessWidget {
  final String userId;
  final String firstName;
  final String passengerType;
  final bool isVerified;

  const PassengerDashboard({
    super.key,
    required this.userId,
    required this.firstName,
    required this.passengerType,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Passenger Dashboard',
            subtitle:
                'A quick view of trips, payment readiness, and safety status.',
            icon: Icons.dashboard_rounded,
            accentColor: PassengerUi.primary,
          ),
          SizedBox(height: 16),
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
          SizedBox(height: 10),
          PassengerSectionHeader(title: 'Cashless Payment'),
          SizedBox(height: 12),
          ...PassengerMockData.paymentMethods.asMap().entries.map(
            (MapEntry<int, PassengerSavedPaymentMethod> entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == PassengerMockData.paymentMethods.length - 1
                    ? 0
                    : 12,
              ),
              child: PassengerPaymentMethodCard(method: entry.value),
            ),
          ),
          SizedBox(height: 20),
          PassengerSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Verification and Safety', style: PassengerUi.cardTitle),
                SizedBox(height: 8),
                PassengerStatusChip(
                  label: isVerified
                      ? 'Verified account'
                      : 'Pending verification',
                  textColor: isVerified
                      ? PassengerUi.successText
                      : PassengerUi.primary,
                  backgroundColor: isVerified
                      ? PassengerUi.successBackground
                      : PassengerUi.dangerSoft,
                ),
                SizedBox(height: 12),
                Text(_verificationMessage, style: PassengerUi.bodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _verificationMessage {
    final isStudentPassenger = passengerType.trim().toLowerCase() == 'student';

    if (isVerified && isStudentPassenger) {
      return 'Your student discount is active, profile tools are unlocked, and your account is ready for normal passenger features.';
    }

    if (isVerified) {
      return 'Your account is verified, profile editing is available, and ride records stay ready for support and reporting.';
    }

    if (isStudentPassenger) {
      return 'Your student discount and profile editing stay locked until an admin verifies your account and reviews your submitted documents.';
    }

    return 'You can already use the app, but profile editing stays locked until an admin verifies your account.';
  }
}
