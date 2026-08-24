import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String functionsSource;

  setUpAll(() {
    functionsSource = File('functions/src/index.ts').readAsStringSync();
  });

  test('commission account changes are written to admin audit logs', () {
    expect(
      functionsSource,
      contains('export const logPlatformCommissionAccountChanged'),
    );
    expect(functionsSource, contains('onDocumentWrittenWithAuthContext'));
    expect(functionsSource, contains('readOptionalString(event.authId)'));
    expect(
      functionsSource,
      contains('document: "platform_commission_accounts/{accountId}"'),
    );
    expect(functionsSource, contains('"platform_commission_account_created"'));
    expect(functionsSource, contains('"platform_commission_account_updated"'));
    expect(functionsSource, contains('"platform_commission_account_disabled"'));
    expect(functionsSource, contains('account_reference_last4'));
  });

  test('fare edits log changed fields and before-after values', () {
    expect(functionsSource, contains('export const logFareSettingsUpdated'));
    expect(functionsSource, contains('changed_fields: changedFields'));
    expect(functionsSource, contains('previous_values: previousValues'));
    expect(functionsSource, contains('new_values: newValues'));
    expect(functionsSource, contains('"fare_settings_updated"'));
  });

  test('nonzero commission requires the enabled account at checkout', () {
    expect(
      functionsSource,
      contains('await loadActivePlatformCommissionAccount()'),
    );
    expect(
      functionsSource,
      contains('"Platform commission checkout account is not configured."'),
    );
    expect(
      functionsSource,
      contains('platform_commission_account_id: platformCommissionAccount.id'),
    );
  });
}
