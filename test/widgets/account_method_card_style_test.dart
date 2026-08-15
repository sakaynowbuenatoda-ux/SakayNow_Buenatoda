import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/driver_payout_account.dart';
import 'package:sakaynow_buenatoda/models/passenger_payment_method.dart';
import 'package:sakaynow_buenatoda/widgets/driver_widgets/driver_payout_account_card.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_payment_method_card.dart';
import 'package:sakaynow_buenatoda/widgets/passenger_widgets/passenger_ui.dart';

void main() {
  testWidgets('payment and payout cards use bare dark icons with subtext', (
    tester,
  ) async {
    const payoutAccount = DriverPayoutAccount(
      id: 'payout-1',
      driverId: 'driver-1',
      type: DriverPayoutAccountType.bank,
      label: 'Primary bank',
      accountName: 'Juan Driver',
      accountReference: '1234',
      bankName: 'Sample Bank',
      isDefault: true,
      createdAt: null,
      updatedAt: null,
    );
    const paymentMethod = PassengerPaymentMethod(
      id: 'payment-1',
      userId: 'passenger-1',
      type: PassengerPaymentMethodType.gcash,
      label: 'GCash',
      accountName: '',
      accountReference: '',
      isDefault: false,
      createdAt: null,
      updatedAt: null,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              DriverPayoutAccountCard(account: payoutAccount),
              PassengerPaymentMethodCard(method: paymentMethod),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.account_balance_rounded)).color,
      PassengerUi.dark,
    );
    expect(
      tester
          .widget<Icon>(find.byIcon(Icons.account_balance_wallet_rounded))
          .color,
      PassengerUi.dark,
    );
    expect(find.text('Sample Bank - Juan Driver - 1234'), findsOneWidget);
    expect(find.text('GCash via Xendit checkout'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });
}
