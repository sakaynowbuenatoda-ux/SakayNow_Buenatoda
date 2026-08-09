enum UserRole { superAdmin, admin, driver, passenger }

String normalizeUserRole(Object? value) {
  final role =
      value?.toString().trim().toLowerCase().replaceAll(' ', '_') ?? '';
  return switch (role) {
    'regular' || 'student' || 'senior_citizen' => 'passenger',
    'superadmin' || 'super_admin' => 'super_admin',
    _ => role,
  };
}

bool isAdminStaffRole(Object? value) {
  final role = normalizeUserRole(value);
  return role == 'admin' || role == 'super_admin';
}

bool isRegularAdminRole(Object? value) => normalizeUserRole(value) == 'admin';

bool isSuperAdminRole(Object? value) =>
    normalizeUserRole(value) == 'super_admin';

String adminStaffRoleLabel(Object? value) =>
    isSuperAdminRole(value) ? 'Super Admin' : 'Admin';
