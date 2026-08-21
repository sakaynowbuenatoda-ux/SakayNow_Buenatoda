import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/session/account_flags.dart';
import '../../../models/driver_rating.dart';
import '../../../core/session/user_roles.dart';

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
  final String? profilePictureUrl;
  final String? profilePicturePath;
  final Timestamp? profilePictureUpdatedAt;
  final String? idImageUrl;
  final String? selfieUrl;
  final String? nbiClearanceUrl;
  final String? driversLicenseUrl;
  final String? vehicleType;
  final String? tricycleColor;
  final String? plateNumber;
  final String? orCrUrl;
  final String? tricycleFrontUrl;
  final String? tricycleBackUrl;
  final Timestamp? createdAt;
  final double averageRating;
  final int reviewCount;
  final double weightedRating;
  final int? ratingRank;
  final String ratingBadge;

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
    required this.profilePictureUrl,
    required this.profilePicturePath,
    required this.profilePictureUpdatedAt,
    required this.idImageUrl,
    required this.selfieUrl,
    required this.nbiClearanceUrl,
    required this.driversLicenseUrl,
    required this.vehicleType,
    required this.tricycleColor,
    required this.plateNumber,
    required this.orCrUrl,
    required this.tricycleFrontUrl,
    required this.tricycleBackUrl,
    required this.createdAt,
    required this.averageRating,
    required this.reviewCount,
    required this.weightedRating,
    required this.ratingRank,
    required this.ratingBadge,
  });

  factory ProfileViewData.fromMap(
    Map<String, dynamic> data,
    String fallbackUserId,
  ) {
    final rawRole = (data['role'] ?? 'user').toString().trim().toLowerCase();
    final normalizedRole = normalizeUserRole(rawRole);

    final normalizedPassengerType =
        (data['passenger_type'] ?? '')
            .toString()
            .trim()
            .toLowerCase()
            .isNotEmpty
        ? (data['passenger_type'] ?? '').toString().trim().toLowerCase()
        : switch (rawRole) {
            'student' => 'student',
            'senior_citizen' => 'senior_citizen',
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
    final ratingTotal = _readInt(
      data['driver_review_rating_total'] ?? data['review_rating_total'],
    );
    final storedWeightedRating = _readDouble(data['driver_weighted_rating']);
    final weightedRating = normalizedRole == 'driver'
        ? storedWeightedRating > 0
              ? storedWeightedRating
              : DriverRating.weightedScore(
                  ratingTotal: ratingTotal > 0
                      ? ratingTotal
                      : (averageRating * reviewCount).round(),
                  reviewCount: reviewCount,
                )
        : 0.0;
    final ratingRank = normalizedRole == 'driver'
        ? _readNullableInt(data['driver_rating_rank'])
        : null;
    final computedBadge = normalizedRole == 'driver'
        ? DriverRating.badgeLabel(
            reviewCount: reviewCount,
            averageRating: averageRating,
            rank: ratingRank,
          )
        : '';

    return ProfileViewData(
      userId: fallbackUserId,
      firstName: (data['first_name'] ?? '').toString().trim(),
      lastName: (data['last_name'] ?? '').toString().trim(),
      email: (data['email'] ?? 'No email provided').toString(),
      role: normalizedRole,
      passengerType: normalizedPassengerType,
      gender: (data['gender'] ?? '').toString().trim(),
      age: (data['age'] ?? '').toString().trim(),
      isVerified: isVerifiedAccountData(data),
      profilePictureUrl: _normalizeOptional(
        data['profile_picture_url'] ?? data['profile_image_url'],
      ),
      profilePicturePath: _normalizeOptional(data['profile_picture_path']),
      profilePictureUpdatedAt: _readTimestamp(
        data['profile_picture_updated_at'] ?? data['profile_image_updated_at'],
      ),
      idImageUrl: _normalizeOptional(data['id_image_url']),
      selfieUrl: _normalizeOptional(data['selfie_url']),
      nbiClearanceUrl: _normalizeOptional(data['nbi_clearance_url']),
      driversLicenseUrl: _normalizeOptional(data['drivers_license_url']),
      vehicleType: _normalizeOptional(data['vehicle_type']),
      tricycleColor: _normalizeOptional(data['tricycle_color']),
      plateNumber: _normalizeOptional(data['plate_number']),
      orCrUrl: _normalizeOptional(data['or_cr_url']),
      tricycleFrontUrl: _normalizeOptional(data['tricycle_front_url']),
      tricycleBackUrl: _normalizeOptional(data['tricycle_back_url']),
      createdAt: data['created_at'] as Timestamp?,
      averageRating: averageRating,
      reviewCount: reviewCount,
      weightedRating: weightedRating,
      ratingRank: ratingRank,
      ratingBadge:
          _normalizeOptional(data['driver_rating_badge']) ?? computedBadge,
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

  static int? _readNullableInt(dynamic value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static Timestamp? _readTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value;
    }

    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }

    return null;
  }

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined.isEmpty ? 'Unnamed User' : combined;
  }

  bool get isAdmin => isAdminStaffRole(role);
  bool get isSuperAdmin => isSuperAdminRole(role);
  bool get isDriver => role == 'driver';
  bool get isPassenger => role == 'passenger';
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
        if (passengerType == 'senior_citizen') {
          return 'Senior Citizen Passenger';
        }
        return 'Passenger';
      case 'admin':
        return 'Admin';
      case 'super_admin':
        return 'Super Admin';
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
      ? isSuperAdmin
            ? 'Developer-managed super admin account'
            : 'Developer-managed admin account'
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

  bool get hasRank => ratingRank != null && ratingRank! >= 1;
  bool get hasTop20Rank =>
      ratingRank != null &&
      ratingRank! >= 1 &&
      ratingRank! <= DriverRating.leaderboardLimit;

  String get rankLabel {
    if (!isDriver) {
      return 'Not ranked';
    }

    if (hasTop20Rank) {
      return '#$ratingRank';
    }

    return 'Unranked';
  }

  String get weightedRatingLabel => isDriver && reviewCount > 0
      ? weightedRating.toStringAsFixed(2)
      : 'Not ranked';

  String get displayBadge {
    if (!isDriver) {
      return '';
    }

    if (ratingBadge.isNotEmpty) {
      return ratingBadge;
    }

    return DriverRating.badgeLabel(
      reviewCount: reviewCount,
      averageRating: averageRating,
      rank: ratingRank,
    );
  }

  String? get profileImageUrl => profilePictureUrl ?? selfieUrl;

  DateTime? get profilePictureLastUpdatedAt =>
      profilePictureUpdatedAt?.toDate();

  DateTime? get profilePictureNextUpdateAt =>
      profilePictureLastUpdatedAt?.add(profilePictureUpdateCooldown);

  bool get canUpdateProfilePicture {
    final nextUpdateAt = profilePictureNextUpdateAt;
    return nextUpdateAt == null || !DateTime.now().isBefore(nextUpdateAt);
  }

  String get profilePictureNextUpdateLabel {
    final date = profilePictureNextUpdateAt;
    if (date == null) {
      return '';
    }

    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  static const Duration profilePictureUpdateCooldown = Duration(days: 7);

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
