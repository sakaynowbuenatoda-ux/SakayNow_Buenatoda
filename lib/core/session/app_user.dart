enum UserRole {
  admin,
  driver,
  passenger,
}

class AppUser {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String role;

  const AppUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String fallbackUserId) {
    return AppUser(
      userId: (data['user_id'] ?? fallbackUserId).toString(),
      firstName: (data['first_name'] ?? '').toString(),
      lastName: (data['last_name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      role: (data['role'] ?? '').toString().trim().toLowerCase(),
    );
  }

  UserRole get userRole {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'driver':
        return UserRole.driver;
      case 'regular':
      case 'student':
      case 'passenger':
        return UserRole.passenger;
      default:
        throw UnsupportedError('Unknown user role: $role');
    }
  }
}
