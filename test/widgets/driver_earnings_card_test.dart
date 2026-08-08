import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/driver_earnings_summary.dart';
import 'package:sakaynow_buenatoda/widgets/driver_widgets/driver_earnings_card.dart';

void main() {
  testWidgets('renders today lifetime and payout earnings transparency', (
    WidgetTester tester,
  ) async {
    const summary = DriverEarningsSummary(
      todayGross: 100,
      todayCommission: 10,
      todayNet: 90,
      lifetimeGross: 500,
      lifetimeCommission: 50,
      lifetimeNet: 450,
      completedTrips: 5,
      cashlessCompletedTrips: 2,
      pendingCashlessPayouts: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DriverEarningsCard(summary: summary)),
      ),
    );

    expect(find.text('Earnings breakdown'), findsOneWidget);
    expect(find.text('Today totals'), findsOneWidget);
    expect(find.text('Lifetime totals'), findsOneWidget);
    expect(find.text('Gross'), findsNWidgets(2));
    expect(find.text('Commission'), findsNWidgets(2));
    expect(find.text('Net earnings'), findsNWidgets(2));
    expect(find.text('PHP 90'), findsOneWidget);
    expect(find.text('PHP 450'), findsOneWidget);
    expect(find.text('Cashless payout status'), findsOneWidget);
    expect(find.text('1 cashless payout pending'), findsOneWidget);
  });
}
