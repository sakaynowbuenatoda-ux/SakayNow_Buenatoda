import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, driver, passenger }

enum PassengerType { regular, student }

enum AccountAccessState {
  active,
  pendingApproval,
  banned,
  deactivated,
  deleted,
}

class AppUser {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String passengerType;
  final bool isVerified;
  final bool isActive;
  final bool isBanned;
  final bool isDeactivated;
  final bool isDeleted;
  final String accountStatus;
  final DateTime? deactivatedAt;
  final DateTime? deactivationRestoreDeadline;
  final DateTime? deactivationPurgeAfter;
  final DateTime? accountAnonymizedAt;
  final String? profilePictureUrl;
  final String? selfieUrl;

  AppUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.passengerType,
    required this.isVerified,
    required this.isActive,
    required this.isBanned,
    required this.isDeactivated,
    required this.isDeleted,
    required this.accountStatus,
    required this.deactivatedAt,
    required this.deactivationRestoreDeadline,
    required this.deactivationPurgeAfter,
    required this.accountAnonymizedAt,
    required this.profilePictureUrl,
    required this.selfieUrl,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String fallbackUserId) {
    final rawRole = (data['role'] ?? '').toString().trim().toLowerCase();
    final normalizedRole = switch (rawRole) {
      'regular' || 'student' => 'passenger',
      _ => rawRole,
    };

    final normalizedPassengerType =
        (data['passenger_type'] ?? '')
            .toString()
            .trim()
            .toLowerCase()
            .isNotEmpty
        ? (data['passenger_type'] ?? '').toString().trim().toLowerCase()
        : switch (rawRole) {
            'student' => 'student',
            _ => 'regular',
          };

    final accountStatus = (data['account_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    return AppUser(
      userId: fallbackUserId,
      firstName: (data['first_name'] ?? '').toString(),
      lastName: (data['last_name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      role: normalizedRole,
      passengerType: normalizedPassengerType,
      isVerified:
          (data['is_verified'] ??
              data['isVerified'] ??
              data['isVerrified'] ??
              false) ==
          true,
      isActive: (data['is_active'] ?? data['isActive'] ?? false) == true,
      isBanned: (data['is_banned'] ?? data['isBanned'] ?? false) == true,
      isDeactivated:
          (data['is_deactivated'] ?? data['isDeactivated'] ?? false) == true ||
          accountStatus == 'deactivated',
      isDeleted:
          accountStatus == 'deleted' || data['account_anonymized_at'] != null,
      accountStatus: accountStatus,
      deactivatedAt: _readDate(data['deactivated_at']),
      deactivationRestoreDeadline: _readDate(
        data['deactivation_restore_deadline'],
      ),
      deactivationPurgeAfter: _readDate(data['deactivation_purge_after']),
      accountAnonymizedAt: _readDate(data['account_anonymized_at']),
      profilePictureUrl: _normalizeOptional(
        data['profile_picture_url'] ?? data['profile_image_url'],
      ),
      selfieUrl: _normalizeOptional(data['selfie_url']),
    );
  }

  static String? _normalizeOptional(dynamic value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    if (normalized.isEmpty || normalized == 'null') {
      return null;
    }

    return normalized;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String? get profileImageUrl => profilePictureUrl ?? selfieUrl;

  UserRole get userRole {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'driver':
        return UserRole.driver;
      case 'passenger':
        return UserRole.passenger;
      default:
        throw UnsupportedError('Unknown user role: $role');
    }
  }

  PassengerType get normalizedPassengerType {
    switch (passengerType) {
      case 'student':
        return PassengerType.student;
      case 'regular':
      default:
        return PassengerType.regular;
    }
  }

  String get roleLabel {
    switch (userRole) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.driver:
        return 'Driver';
      case UserRole.passenger:
        return normalizedPassengerType == PassengerType.student
            ? 'Student Passenger'
            : 'Passenger';
    }
  }

  AccountAccessState accessState() {
    if (isBanned) {
      return AccountAccessState.banned;
    }

    if (isDeleted) {
      return AccountAccessState.deleted;
    }

    if (isDeactivated) {
      return AccountAccessState.deactivated;
    }

    if (userRole == UserRole.admin) {
      return AccountAccessState.active;
    }

    // Signup writes new users with is_verified: false, so pending approval
    // should follow that Firestore flag directly.
    if (!isVerified) {
      return AccountAccessState.pendingApproval;
    }

    return AccountAccessState.active;
  }
}
