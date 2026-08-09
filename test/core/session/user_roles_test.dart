import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/core/session/app_user.dart';
import 'package:sakaynow_buenatoda/core/session/user_roles.dart';

void main() {
  test('normalizes and classifies admin staff roles', () {
    expect(normalizeUserRole('Super Admin'), 'super_admin');
    expect(isAdminStaffRole('admin'), isTrue);
    expect(isAdminStaffRole('super_admin'), isTrue);
    expect(isRegularAdminRole('admin'), isTrue);
    expect(isSuperAdminRole('super_admin'), isTrue);
    expect(isAdminStaffRole('driver'), isFalse);
  });

  test('AppUser exposes super admin authority and label', () {
    final user = AppUser.fromMap(<String, dynamic>{
      'first_name': 'Admin',
      'last_name': 'Owner',
      'email': 'owner@example.com',
      'role': 'super_admin',
      'is_active': true,
      'is_verified': true,
      'is_banned': false,
      'is_deactivated': false,
      'account_status': 'active',
    }, 'super-1');

    expect(user.userRole, UserRole.superAdmin);
    expect(user.isAdminStaff, isTrue);
    expect(user.isRegularAdmin, isFalse);
    expect(user.isSuperAdmin, isTrue);
    expect(user.roleLabel, 'Super Admin');
    expect(user.accessState(), AccountAccessState.active);
  });
}
