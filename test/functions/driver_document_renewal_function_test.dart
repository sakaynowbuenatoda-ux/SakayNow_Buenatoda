import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String functionsSource;

  setUpAll(() {
    functionsSource = File('functions/src/index.ts').readAsStringSync();
  });

  test('scheduled function refreshes driver document states daily', () {
    expect(
      functionsSource,
      contains('export const refreshDriverDocumentStatuses = onSchedule'),
    );
    expect(functionsSource, contains('schedule: "every day 01:00"'));
    expect(functionsSource, contains('timeZone: "Asia/Manila"'));
    expect(functionsSource, contains('driverDocumentExpiryState(driver, now)'));
    expect(functionsSource, contains('document_status: status'));
    expect(functionsSource, contains('is_active: false'));
    expect(functionsSource, contains('is_available: false'));
  });

  test('expiry and renewal transitions create notifications', () {
    expect(
      functionsSource,
      contains('export const notifyDriverRenewalSubmitted'),
    );
    expect(
      functionsSource,
      contains('export const notifyDriverRenewalDecision'),
    );
    expect(functionsSource, contains('driver_documents_expiring'));
    expect(functionsSource, contains('driver_documents_expired'));
    expect(functionsSource, contains('driver_renewal_approved'));
    expect(functionsSource, contains('driver_renewal_rejected'));
  });
}
