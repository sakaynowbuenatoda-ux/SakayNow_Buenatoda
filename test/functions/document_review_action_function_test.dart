import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String functionsSource;
  late String callableSource;
  late String adminServiceSource;

  setUpAll(() {
    functionsSource = File('functions/src/index.ts').readAsStringSync();
    final callableStart = functionsSource.indexOf(
      'export const reviewDocumentUpdate = onCall(',
    );
    final callableEnd = functionsSource.indexOf(
      'export const ensureAdminDirectConversation = onCall(',
      callableStart,
    );
    expect(callableStart, greaterThanOrEqualTo(0));
    expect(callableEnd, greaterThan(callableStart));
    callableSource = functionsSource.substring(callableStart, callableEnd);

    final serviceSource = File(
      'lib/pages/admin/admin_service.dart',
    ).readAsStringSync();
    final serviceStart = serviceSource.indexOf(
      'static Future<void> approveDocumentReview(',
    );
    final serviceEnd = serviceSource.indexOf(
      'static Future<void> approveDriverRenewal(',
      serviceStart,
    );
    expect(serviceStart, greaterThanOrEqualTo(0));
    expect(serviceEnd, greaterThan(serviceStart));
    adminServiceSource = serviceSource.substring(serviceStart, serviceEnd);
  });

  test('document review decisions use authenticated admin authority', () {
    expect(callableSource, contains('const requesterId = request.auth?.uid'));
    expect(callableSource, contains('!isAdminStaff(requester)'));
    expect(functionsSource, contains('if (role === "superadmin")'));
    expect(callableSource, contains('firestore.runTransaction'));
    expect(
      callableSource,
      contains('approvedDocumentReviewDecisionUpdates(target, requesterId)'),
    );
    expect(
      callableSource,
      contains('document_review_reviewed_by: requesterId'),
    );
    expect(callableSource, isNot(contains('admin_id')));
  });

  test('rejections require a bounded reason', () {
    expect(callableSource, contains('decision === "rejected" && !reason'));
    expect(callableSource, contains('reason.length > 240'));
    expect(
      callableSource,
      contains('document_review_rejection_reason: reason'),
    );
  });

  test('admin clients send decisions through the secured callable', () {
    expect(
      adminServiceSource,
      contains("_functions.httpsCallable('reviewDocumentUpdate')"),
    );
    expect(adminServiceSource, contains("decision: 'approved'"));
    expect(adminServiceSource, contains("decision: 'rejected'"));
    expect(adminServiceSource, isNot(contains('runTransaction')));
    expect(adminServiceSource, isNot(contains('adminId')));
  });
}
