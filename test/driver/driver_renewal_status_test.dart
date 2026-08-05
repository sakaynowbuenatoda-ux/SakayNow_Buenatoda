import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/driver_document_status.dart';
import 'package:sakaynow_buenatoda/pages/driver/driver_info_hub_page.dart';

void main() {
  final now = DateTime(2026, 8, 5, 12);

  Future<void> pumpStatus(
    WidgetTester tester,
    DriverDocumentStatus status,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DriverRenewalStatusCard(status: status, now: now),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('DriverRenewalStatusCard', () {
    testWidgets('renders valid state', (tester) async {
      await pumpStatus(
        tester,
        DriverDocumentStatus(
          driversLicenseExpiry: now.add(const Duration(days: 120)),
          orCrExpiry: now.add(const Duration(days: 180)),
          documentStatus: 'valid',
        ),
      );

      expect(
        find.byKey(const Key('driver-renewal-state-valid')),
        findsOneWidget,
      );
      expect(find.text('Valid'), findsOneWidget);
    });

    testWidgets('renders expiring soon state', (tester) async {
      await pumpStatus(
        tester,
        DriverDocumentStatus(
          driversLicenseExpiry: now.add(const Duration(days: 14)),
          orCrExpiry: now.add(const Duration(days: 120)),
          documentStatus: 'expiring_soon',
        ),
      );

      expect(
        find.byKey(const Key('driver-renewal-state-expiringSoon')),
        findsOneWidget,
      );
      expect(find.text('Expiring soon'), findsOneWidget);
    });

    testWidgets('renders expired state and blocks eligibility', (tester) async {
      final status = DriverDocumentStatus(
        driversLicenseExpiry: now.subtract(const Duration(days: 1)),
        orCrExpiry: now.add(const Duration(days: 120)),
        documentStatus: 'expired',
      );
      await pumpStatus(tester, status);

      expect(
        find.byKey(const Key('driver-renewal-state-expired')),
        findsOneWidget,
      );
      expect(find.text('Expired'), findsOneWidget);
      expect(status.isEligibleAt(now), isFalse);
    });

    testWidgets('pending renewal takes precedence over expiry copy', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        DriverDocumentStatus(
          driversLicenseExpiry: now.subtract(const Duration(days: 2)),
          orCrExpiry: now.add(const Duration(days: 120)),
          documentStatus: 'expired',
          renewalStatus: 'pending_renewal',
          renewalDocumentType: DriverDocumentType.driversLicense,
          renewalExpiry: now.add(const Duration(days: 365)),
        ),
      );

      expect(
        find.byKey(const Key('driver-renewal-state-pendingRenewal')),
        findsOneWidget,
      );
      expect(find.text('Pending renewal'), findsOneWidget);
    });
  });
}
