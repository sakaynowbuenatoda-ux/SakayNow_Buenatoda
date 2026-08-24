import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/platform_commission_account.dart';

void main() {
  test('platform commission account persists checkout settlement fields', () {
    const account = PlatformCommissionAccount(
      id: 'current',
      type: PlatformCommissionAccountType.gcash,
      label: 'Main commission wallet',
      accountName: 'SakayNow Buenatoda',
      accountReference: '09171234567',
      isEnabled: true,
      updatedBy: 'admin-1',
      createdAt: null,
      updatedAt: null,
    );

    final data = account.toFirestore(
      adminId: 'admin-1',
      includeCreatedAt: true,
    );

    expect(data['account_type'], 'gcash');
    expect(data['provider'], 'xendit');
    expect(data['is_enabled'], isTrue);
    expect(data['updated_by'], 'admin-1');
    expect(data, contains('created_at'));
    expect(account.maskedReference, '*******4567');
  });

  test('bank account summary includes the bank and masks its number', () {
    const account = PlatformCommissionAccount(
      id: 'current',
      type: PlatformCommissionAccountType.bank,
      label: 'Settlement bank',
      accountName: 'SakayNow Buenatoda',
      accountReference: '1234567890',
      bankName: 'Example Bank',
      isEnabled: false,
      updatedBy: 'admin-1',
      createdAt: null,
      updatedAt: null,
    );

    expect(
      account.accountSummary,
      'Example Bank - SakayNow Buenatoda - ******7890',
    );
  });
}
