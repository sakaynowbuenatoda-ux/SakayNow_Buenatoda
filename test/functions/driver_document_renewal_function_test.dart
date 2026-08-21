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

  test('document expiry preserves verification and notifies admins', () {
    final functionStart = functionsSource.indexOf(
      'export const refreshDriverDocumentStatuses = onSchedule',
    );
    final nextFunction = functionsSource.indexOf(
      'export const notifyNewBookingRequest',
      functionStart,
    );
    final scheduledFunction = functionsSource.substring(
      functionStart,
      nextFunction,
    );

    expect(functionStart, greaterThanOrEqualTo(0));
    expect(nextFunction, greaterThan(functionStart));
    expect(scheduledFunction, isNot(contains('is_verified')));
    expect(scheduledFunction, isNot(contains('isVerified')));
    expect(scheduledFunction, isNot(contains('isVerrified')));
    expect(scheduledFunction, contains('await notifyAdmins({'));
    expect(
      scheduledFunction,
      contains('type: "driver_documents_expired_admin"'),
    );
    expect(scheduledFunction, contains('Your account remains verified'));
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

  test('staged document reviews notify admins and users', () {
    expect(
      functionsSource,
      contains('export const notifyDocumentReviewSubmitted'),
    );
    expect(
      functionsSource,
      contains('export const notifyDocumentReviewDecision'),
    );
    expect(functionsSource, contains('document_review_submitted'));
    expect(functionsSource, contains('document_review_approved'));
    expect(functionsSource, contains('document_review_rejected'));
  });
}
