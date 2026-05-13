import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileViewData {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String passengerType;
  final String gender;
  final String age;
  final bool isVerified;
  final String? idImageUrl;
  final String? selfieUrl;
  final String? nbiClearanceUrl;
  final String? driversLicenseUrl;
  final Timestamp? createdAt;
  final double averageRating;
  final int reviewCount;

  ProfileViewData({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.passengerType,
    required this.gender,
    required this.age,
    required this.isVerified,
    required this.idImageUrl,
    required this.selfieUrl,
    required this.nbiClearanceUrl,
    required this.driversLicenseUrl,
    required this.createdAt,
    required this.averageRating,
    required this.reviewCount,
  });

  factory ProfileViewData.fromMap(
    Map<String, dynamic> data,
    String fallbackUserId,
  ) {
    final rawRole = (data['role'] ?? 'user').toString().trim().toLowerCase();
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

    final averageRating = _readDouble(
      normalizedRole == 'driver'
          ? data['driver_average_rating'] ?? data['average_rating']
          : data['passenger_average_rating'] ?? data['average_rating'],
    );
    final reviewCount = _readInt(
      normalizedRole == 'driver'
          ? data['driver_review_count'] ?? data['review_count']
          : data['passenger_review_count'] ?? data['review_count'],
    );

    return ProfileViewData(
      userId: (data['user_id'] ?? fallbackUserId).toString(),
      firstName: (data['first_name'] ?? '').toString().trim(),
      lastName: (data['last_name'] ?? '').toString().trim(),
      email: (data['email'] ?? 'No email provided').toString(),
      role: normalizedRole,
      passengerType: normalizedPassengerType,
      gender: (data['gender'] ?? '').toString().trim(),
      age: (data['age'] ?? '').toString().trim(),
      isVerified:
          (data['is_verified'] ??
              data['isVerified'] ??
              data['isVerrified'] ??
              false) ==
          true,
      idImageUrl: _normalizeOptional(data['id_image_url']),
      selfieUrl: _normalizeOptional(data['selfie_url']),
      nbiClearanceUrl: _normalizeOptional(data['nbi_clearance_url']),
      driversLicenseUrl: _normalizeOptional(data['drivers_license_url']),
      createdAt: data['created_at'] as Timestamp?,
      averageRating: averageRating,
      reviewCount: reviewCount,
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

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(dynamic value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined.isEmpty ? 'Unnamed User' : combined;
  }

  bool get isAdmin => role == 'admin';
  bool get showVerifiedBadge => !isAdmin && isVerified;

  String get initials {
    final List<String> parts = fullName
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }

  String get roleLabel {
    switch (role) {
      case 'driver':
        return 'Driver';
      case 'passenger':
        if (passengerType == 'student') {
          return 'Student Passenger';
        }
        return 'Passenger';
      case 'admin':
        return 'Admin';
      default:
        return role.isEmpty ? 'User' : _titleCase(role);
    }
  }

  String get genderLabel {
    if (gender.isEmpty) {
      return 'Not set';
    }

    return _titleCase(gender);
  }

  String get ageLabel => age.isEmpty ? 'Not set' : age;

  String get verificationLabel => isAdmin
      ? 'Developer-managed admin account'
      : (isVerified ? 'Verified' : 'Pending verification');

  String get joinedAtLabel {
    if (createdAt == null) {
      return 'Not available';
    }

    final date = createdAt!.toDate();
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  String get ratingLabel =>
      reviewCount == 0 ? 'No ratings yet' : averageRating.toStringAsFixed(1);

  String? get profileImageUrl => selfieUrl ?? idImageUrl;

  static String _titleCase(String value) {
    return value
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static String _monthName(int month) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }
}
