import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

class AdminUserRecord {
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String passengerType;
  final String gender;
  final String age;
  final bool isVerified;
  final bool isActive;
  final bool isBanned;
  final DateTime? createdAt;
  final String? idImageUrl;
  final String? selfieUrl;
  final String? nbiClearanceUrl;
  final String? driversLicenseUrl;
  final double averageRating;
  final int reviewCount;

  AdminUserRecord({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.passengerType,
    required this.gender,
    required this.age,
    required this.isVerified,
    required this.isActive,
    required this.isBanned,
    required this.createdAt,
    required this.idImageUrl,
    required this.selfieUrl,
    required this.nbiClearanceUrl,
    required this.driversLicenseUrl,
    required this.averageRating,
    required this.reviewCount,
  });

  factory AdminUserRecord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return AdminUserRecord(
      userId: (data['user_id'] ?? document.id).toString(),
      firstName: (data['first_name'] ?? '').toString().trim(),
      lastName: (data['last_name'] ?? '').toString().trim(),
      email: (data['email'] ?? '').toString().trim(),
      role: (data['role'] ?? '').toString().trim().toLowerCase(),
      passengerType: (data['passenger_type'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      gender: (data['gender'] ?? '').toString().trim(),
      age: (data['age'] ?? '').toString().trim(),
      isVerified: (data['is_verified'] ?? data['isVerified'] ?? false) == true,
      isActive: (data['is_active'] ?? data['isActive'] ?? false) == true,
      isBanned: (data['is_banned'] ?? data['isBanned'] ?? false) == true,
      createdAt: _readDate(data['created_at']),
      idImageUrl: _readNullableString(data['id_image_url']),
      selfieUrl: _readNullableString(data['selfie_url']),
      nbiClearanceUrl: _readNullableString(data['nbi_clearance_url']),
      driversLicenseUrl: _readNullableString(data['drivers_license_url']),
      averageRating: _readDouble(
        data['driver_average_rating'] ??
            data['passenger_average_rating'] ??
            data['average_rating'] ??
            data['rating'] ??
            data['ratings'],
      ),
      reviewCount: _readInt(
        data['driver_review_count'] ??
            data['passenger_review_count'] ??
            data['review_count'],
      ),
    );
  }

  String get fullName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? 'Unnamed user' : value;
  }

  String get genderLabel {
    if (gender.isEmpty) {
      return 'Not set';
    }

    return '${gender[0].toUpperCase()}${gender.substring(1).toLowerCase()}';
  }

  String get ageLabel => age.isEmpty ? 'Not set' : age;

  String? get profileImageUrl => selfieUrl;

  bool get isDriver => role == 'driver';
  bool get isPassenger => role == 'passenger';
  bool get isAdmin => role == 'admin';
  bool get isStudentPassenger =>
      isPassenger && passengerType.toLowerCase() == 'student';

  bool get isPendingVerification => !isAdmin && !isBanned && !isVerified;
  bool get needsApproval => isPendingVerification;

  bool get hasPassengerDocuments =>
      _hasValue(idImageUrl) && _hasValue(selfieUrl);

  bool get hasDriverDocuments =>
      _hasValue(selfieUrl) &&
      _hasValue(nbiClearanceUrl) &&
      _hasValue(driversLicenseUrl);

  String get roleLabel {
    if (isAdmin) return 'Admin';
    if (isDriver) return 'Driver';
    if (isStudentPassenger) return 'Student Passenger';
    return 'Passenger';
  }

  String get statusLabel {
    if (isAdmin) return 'Developer managed';
    if (isBanned) return 'Restricted';
    if (isPendingVerification) return 'Pending verification';
    if (isVerified && isActive) return 'Verified';
    if (isVerified) return 'Verified';
    return 'Review needed';
  }

  Color get statusColor {
    if (isBanned) return PassengerUi.primary;
    if (needsApproval) return PassengerUi.highlightAmber;
    return PassengerUi.successText;
  }

  Color get statusBackgroundColor {
    if (isBanned) return PassengerUi.dangerSoft;
    if (needsApproval) return Color(0xFFF8E8C6);
    return PassengerUi.successBackground;
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

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AdminBookingRecord {
  final String bookingId;
  final String passengerId;
  final String driverId;
  final String pickupLocation;
  final String dropoffLocation;
  final String status;
  final DateTime? timestamp;
  final String? paymentMethod;
  final String? fareLabel;

  AdminBookingRecord({
    required this.bookingId,
    required this.passengerId,
    required this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.status,
    required this.timestamp,
    required this.paymentMethod,
    required this.fareLabel,
  });

  factory AdminBookingRecord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return AdminBookingRecord(
      bookingId: (data['booking_id'] ?? document.id).toString(),
      passengerId: (data['passenger_id'] ?? '').toString().trim(),
      driverId: (data['driver_id'] ?? '').toString().trim(),
      pickupLocation: _readLocation(data['pickup_location']),
      dropoffLocation: _readLocation(data['dropoff_location']),
      status: (data['status'] ?? 'pending').toString().trim().toLowerCase(),
      timestamp: AdminUserRecord._readDate(data['timestamp']),
      paymentMethod: _readNullableString(
        data['payment_method'] ?? data['paymentMethod'],
      ),
      fareLabel: _readFare(data),
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled' || status == 'rejected';
  bool get isQueued =>
      status == 'pending' || status == 'queued' || status == 'new';
  bool get isActiveTrip =>
      status == 'accepted' ||
      status == 'ongoing' ||
      status == 'in_progress' ||
      status == 'assigned';

  String get statusLabel {
    if (status.isEmpty) {
      return 'Pending';
    }

    final normalized = status.replaceAll('_', ' ');
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  Color get statusColor {
    if (isCompleted) return PassengerUi.successText;
    if (isCancelled) return PassengerUi.primary;
    if (isActiveTrip) return PassengerUi.accentBlue;
    return PassengerUi.highlightAmber;
  }

  Color get statusBackgroundColor {
    if (isCompleted) return PassengerUi.successBackground;
    if (isCancelled) return PassengerUi.dangerSoft;
    if (isActiveTrip) return Color(0xFFE2EBF1);
    return Color(0xFFF8E8C6);
  }

  static String _readLocation(Object? value) {
    if (value is Map<String, dynamic>) {
      final address = value['address']?.toString().trim() ?? '';
      final name = value['name']?.toString().trim() ?? '';
      return address.isNotEmpty
          ? address
          : (name.isNotEmpty ? name : 'Unknown');
    }

    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Unknown' : text;
  }

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _readFare(Map<String, dynamic> data) {
    final candidates = <Object?>[
      data['fare'],
      data['fare_amount'],
      data['final_fare'],
      data['estimated_fare'],
    ];

    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        if (text.toLowerCase().contains('php')) {
          return text;
        }

        return 'PHP $text';
      }
    }

    return null;
  }
}

class AdminReviewRecord {
  final String reviewId;
  final String bookingId;
  final String reviewerId;
  final String reviewerRole;
  final String revieweeId;
  final String revieweeRole;
  final int rating;
  final String comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminReviewRecord({
    required this.reviewId,
    required this.bookingId,
    required this.reviewerId,
    required this.reviewerRole,
    required this.revieweeId,
    required this.revieweeRole,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminReviewRecord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return AdminReviewRecord(
      reviewId: (data['review_id'] ?? document.id).toString(),
      bookingId: (data['booking_id'] ?? '').toString().trim(),
      reviewerId: (data['reviewer_id'] ?? '').toString().trim(),
      reviewerRole: (data['reviewer_role'] ?? '').toString().trim(),
      revieweeId: (data['reviewee_id'] ?? '').toString().trim(),
      revieweeRole: (data['reviewee_role'] ?? '').toString().trim(),
      rating: AdminUserRecord._readInt(data['rating']).clamp(0, 5),
      comment: _readComment(data),
      createdAt: AdminUserRecord._readDate(data['created_at']),
      updatedAt: AdminUserRecord._readDate(data['updated_at']),
    );
  }

  static String _readComment(Map<String, dynamic> data) {
    final candidates = <Object?>[
      data['comment'],
      data['review'],
      data['review_text'],
      data['feedback'],
      data['message'],
    ];

    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }
}
