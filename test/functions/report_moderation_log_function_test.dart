import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String functionsSource;

  setUpAll(() {
    functionsSource = File('functions/src/index.ts').readAsStringSync();
  });

  test('report moderation transitions create authenticated admin logs', () {
    expect(
      functionsSource,
      contains(
        'export const logAdminReportAction = '
        'onDocumentUpdatedWithAuthContext',
      ),
    );
    expect(functionsSource, contains('document: "reports/{reportId}"'));
    expect(functionsSource, contains('readOptionalString(event.authId)'));
    expect(functionsSource, contains('!isAdminStaff(admin)'));
    expect(functionsSource, contains(r'logDocumentId: `report_${event.id}`'));
  });

  test('resolved, ignored, and spam actions include report audit metadata', () {
    expect(functionsSource, contains('action: "report_resolved"'));
    expect(functionsSource, contains('action: "report_ignored"'));
    expect(functionsSource, contains('action: "report_marked_spam"'));
    expect(functionsSource, contains('report_id: reportId'));
    expect(functionsSource, contains('previous_status: previousStatus'));
    expect(functionsSource, contains('reported_user_id: reportedUserId ?? ""'));
  });
}
