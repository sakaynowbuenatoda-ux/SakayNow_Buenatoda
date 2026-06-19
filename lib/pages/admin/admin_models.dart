import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/ride_location.dart';
import 'widgets/admin_ui.dart';

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
  final bool isDeactivated;
  final bool isDeleted;
  final String accountStatus;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final DateTime? deactivatedAt;
  final DateTime? deactivationRestoreDeadline;
  final DateTime? deactivationPurgeAfter;
  final DateTime? accountAnonymizedAt;
  final String? profilePictureUrl;
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
    required this.isDeactivated,
    required this.isDeleted,
    required this.accountStatus,
    required this.createdAt,
    required this.reviewedAt,
    required this.deactivatedAt,
    required this.deactivationRestoreDeadline,
    required this.deactivationPurgeAfter,
    required this.accountAnonymizedAt,
    required this.profilePictureUrl,
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
    final accountStatus = (data['account_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

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
      createdAt: _readDate(data['created_at']),
      reviewedAt: _readDate(data['reviewed_at']),
      deactivatedAt: _readDate(data['deactivated_at']),
      deactivationRestoreDeadline: _readDate(
        data['deactivation_restore_deadline'],
      ),
      deactivationPurgeAfter: _readDate(data['deactivation_purge_after']),
      accountAnonymizedAt: _readDate(data['account_anonymized_at']),
      profilePictureUrl: _readNullableString(
        data['profile_picture_url'] ?? data['profile_image_url'],
      ),
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
    if (value.isNotEmpty) {
      return value;
    }

    return isDeleted ? 'Deleted account' : 'Unnamed user';
  }

  String get genderLabel {
    if (gender.isEmpty) {
      return 'Not set';
    }

    return '${gender[0].toUpperCase()}${gender.substring(1).toLowerCase()}';
  }

  String get ageLabel => age.isEmpty ? 'Not set' : age;

  String? get profileImageUrl => profilePictureUrl ?? selfieUrl;

  bool get isDriver => role == 'driver';
  bool get isPassenger => role == 'passenger';
  bool get isAdmin => role == 'admin';
  bool get isMainAdmin => isAdmin && firstName.trim().toLowerCase() == 'admin';
  bool get isPassengerOrDriver => isPassenger || isDriver;
  bool get isStudentPassenger =>
      isPassenger && passengerType.toLowerCase() == 'student';
  bool get isEligibleDriverAccount =>
      isDriver && isVerified && !isBanned && !isDeactivated && !isDeleted;
  bool get canReceiveBookings => isEligibleDriverAccount && isActive;

  bool get isPendingVerification =>
      !isAdmin && !isBanned && !isDeactivated && !isDeleted && !isVerified;
  bool get needsApproval => isPendingVerification;
  bool get canRestoreDeactivated =>
      isDeactivated &&
      !isDeleted &&
      (deactivationRestoreDeadline == null ||
          deactivationRestoreDeadline!.isAfter(DateTime.now()));

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
    if (isPassenger) return 'Passenger';
    return 'User';
  }

  String get statusLabel {
    if (isDeleted) return 'Deleted';
    if (isBanned) return 'Restricted';
    if (isDeactivated) return 'Deactivated';
    if (isAdmin) return 'Developer managed';
    if (isPendingVerification) return 'Pending verification';
    if (isVerified && isActive) return 'Verified';
    if (isVerified) return 'Verified';
    return 'Review needed';
  }

  Color get statusColor {
    if (isDeleted) return AdminUi.body;
    if (isBanned) return AdminUi.danger;
    if (isDeactivated) return AdminUi.danger;
    if (needsApproval) return AdminUi.highlightAmber;
    return AdminUi.successText;
  }

  Color get statusBackgroundColor {
    if (isDeleted) return AdminUi.mutedSurface;
    if (isBanned) return AdminUi.dangerSoft;
    if (isDeactivated) return AdminUi.dangerSoft;
    if (needsApproval) return AdminUi.warningSoft;
    return AdminUi.successBackground;
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

class AdminDriverLocationRecord {
  final String driverId;
  final String fullName;
  final String? profileImageUrl;
  final LatLng latLng;
  final double? heading;
  final DateTime? updatedAt;
  final String? activeBookingId;

  const AdminDriverLocationRecord({
    required this.driverId,
    required this.fullName,
    required this.profileImageUrl,
    required this.latLng,
    required this.heading,
    required this.updatedAt,
    required this.activeBookingId,
  });

  factory AdminDriverLocationRecord.fromData({
    required String driverId,
    required AdminUserRecord driver,
    required Map<String, dynamic> locationData,
  }) {
    final geoPoint = locationData['geopoint'];
    final latitude =
        _readDouble(locationData['latitude']) ??
        (geoPoint is GeoPoint ? geoPoint.latitude : null);
    final longitude =
        _readDouble(locationData['longitude']) ??
        (geoPoint is GeoPoint ? geoPoint.longitude : null);

    if (latitude == null || longitude == null) {
      throw StateError('Driver location coordinates are missing.');
    }

    return AdminDriverLocationRecord(
      driverId: driverId,
      fullName: driver.fullName,
      profileImageUrl: driver.profileImageUrl,
      latLng: LatLng(latitude, longitude),
      heading: _readDouble(locationData['heading']),
      updatedAt: AdminUserRecord._readDate(locationData['updated_at']),
      activeBookingId: AdminUserRecord._readNullableString(
        locationData['active_booking_id'],
      ),
    );
  }

  bool get hasActiveBooking => activeBookingId != null;

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}

class AdminBookingRecord {
  final String bookingId;
  final String passengerId;
  final String driverId;
  final String pickupLocation;
  final String dropoffLocation;
  final RideLocation? pickupRideLocation;
  final RideLocation? dropoffRideLocation;
  final String status;
  final DateTime? timestamp;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? fareLabel;

  AdminBookingRecord({
    required this.bookingId,
    required this.passengerId,
    required this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupRideLocation,
    required this.dropoffRideLocation,
    required this.status,
    required this.timestamp,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.fareLabel,
  });

  factory AdminBookingRecord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final pickupRideLocation = _readRideLocation(data['pickup_location']);
    final dropoffRideLocation = _readRideLocation(data['dropoff_location']);

    return AdminBookingRecord(
      bookingId: (data['booking_id'] ?? document.id).toString(),
      passengerId: (data['passenger_id'] ?? '').toString().trim(),
      driverId: (data['driver_id'] ?? '').toString().trim(),
      pickupLocation: _readLocation(
        data['pickup_location'],
        parsedLocation: pickupRideLocation,
      ),
      dropoffLocation: _readLocation(
        data['dropoff_location'],
        parsedLocation: dropoffRideLocation,
      ),
      pickupRideLocation: pickupRideLocation,
      dropoffRideLocation: dropoffRideLocation,
      status: (data['status'] ?? 'pending').toString().trim().toLowerCase(),
      timestamp: AdminUserRecord._readDate(data['timestamp']),
      paymentMethod: _readNullableString(
        data['payment_method_label'] ??
            data['payment_method'] ??
            data['paymentMethod'],
      ),
      paymentStatus: _readNullableString(data['payment_status']),
      fareLabel: _readFare(data),
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isCancelled =>
      status == 'cancelled' || status == 'canceled' || status == 'rejected';
  bool get isQueued =>
      status == 'searching' ||
      status == 'pending' ||
      status == 'queued' ||
      status == 'new';
  bool get isActiveTrip =>
      status == 'accepted' ||
      status == 'driver_arriving' ||
      status == 'arrived' ||
      status == 'ongoing' ||
      status == 'in_progress' ||
      status == 'assigned';
  bool get canPreviewRoute =>
      pickupRideLocation?.hasCoordinates == true &&
      dropoffRideLocation?.hasCoordinates == true;

  String get paymentStatusLabel {
    final normalized = paymentStatus?.toLowerCase().trim() ?? '';
    if (isCancelled && normalized != 'paid') {
      return 'No payment collected';
    }

    return switch (normalized) {
      'paid' => 'Paid',
      'cash_collected' => 'Cash collected',
      'cash_cancelled' => 'No payment collected',
      'checkout_pending' => 'Checkout pending',
      'checkout_failed' => 'Checkout failed',
      'checkout_cancelled' => 'Checkout cancelled',
      'payment_cancelled' => 'Payment cancelled',
      'cash_pending' => 'Cash pending',
      '' => 'Pending',
      _ => _titleCase(normalized.replaceAll('_', ' ')),
    };
  }

  String get statusLabel {
    if (status.isEmpty) {
      return 'Pending';
    }

    final normalized = status.replaceAll('_', ' ');
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  Color get statusColor {
    if (isCompleted) return AdminUi.successText;
    if (isCancelled) return AdminUi.danger;
    if (isActiveTrip) return AdminUi.accentBlue;
    return AdminUi.highlightAmber;
  }

  Color get statusBackgroundColor {
    if (isCompleted) return AdminUi.successBackground;
    if (isCancelled) return AdminUi.dangerSoft;
    if (isActiveTrip) return AdminUi.blueSoft;
    return AdminUi.warningSoft;
  }

  static String _readLocation(Object? value, {RideLocation? parsedLocation}) {
    final location = parsedLocation ?? _readRideLocation(value);
    if (location != null) {
      return location.publicDisplayLabel;
    }

    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Unknown' : text;
  }

  static RideLocation? _readRideLocation(Object? value) {
    if (value is Map || value is GeoPoint) {
      return RideLocation.fromMap(value);
    }

    return null;
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

  static String _titleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
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

class AdminReportRecord {
  final String reportId;
  final String bookingId;
  final String reporterId;
  final String reporterRole;
  final String reportedUserId;
  final String reportedUserRole;
  final String reason;
  final String details;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminReportRecord({
    required this.reportId,
    required this.bookingId,
    required this.reporterId,
    required this.reporterRole,
    required this.reportedUserId,
    required this.reportedUserRole,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminReportRecord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return AdminReportRecord(
      reportId: (data['report_id'] ?? document.id).toString().trim(),
      bookingId: (data['booking_id'] ?? '').toString().trim(),
      reporterId: (data['reporter_id'] ?? '').toString().trim(),
      reporterRole: (data['reporter_role'] ?? '').toString().trim(),
      reportedUserId: (data['reported_user_id'] ?? '').toString().trim(),
      reportedUserRole: (data['reported_user_role'] ?? '').toString().trim(),
      reason: _readReason(data),
      details: _readDetails(data),
      status: (data['status'] ?? 'open').toString().trim().toLowerCase(),
      createdAt: AdminUserRecord._readDate(data['created_at']),
      updatedAt: AdminUserRecord._readDate(data['updated_at']),
    );
  }

  String get categoryLabel {
    final value = reason.trim();
    return value.isEmpty ? 'Other' : value;
  }

  String get reasonLabel {
    final value = reason.trim();
    return value.isEmpty ? 'No reason provided' : value;
  }

  String get statusLabel {
    if (status.isEmpty) {
      return 'Open';
    }

    final normalized = status.replaceAll('_', ' ');
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String get reporterRoleLabel => _roleLabel(reporterRole);
  String get reportedUserRoleLabel => _roleLabel(reportedUserRole);

  DateTime? get sortDate => createdAt ?? updatedAt;

  bool get isOpen => status.isEmpty || status == 'open' || status == 'pending';

  static String _readReason(Map<String, dynamic> data) {
    final candidates = <Object?>[
      data['reason'],
      data['category'],
      data['report_category'],
      data['type'],
    ];

    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  static String _readDetails(Map<String, dynamic> data) {
    final candidates = <Object?>[
      data['details'],
      data['description'],
      data['message'],
      data['comment'],
    ];

    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  static String _roleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'driver':
        return 'Driver';
      case 'passenger':
        return 'Passenger';
      default:
        return 'User';
    }
  }
}

class AdminActionLogRecord {
  final String logId;
  final String action;
  final String adminId;
  final String adminName;
  final String summary;
  final DateTime? createdAt;
  final String? targetId;
  final String? targetName;
  final String? targetRole;
  final Map<String, dynamic> metadata;

  const AdminActionLogRecord({
    required this.logId,
    required this.action,
    required this.adminId,
    required this.adminName,
    required this.summary,
    required this.createdAt,
    required this.targetId,
    required this.targetName,
    required this.targetRole,
    required this.metadata,
  });

  factory AdminActionLogRecord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};

    return AdminActionLogRecord(
      logId: (data['log_id'] ?? document.id).toString().trim(),
      action: (data['action'] ?? '').toString().trim(),
      adminId: (data['admin_id'] ?? '').toString().trim(),
      adminName: _readRequiredLabel(data['admin_name'], fallback: 'Admin'),
      summary: _readRequiredLabel(
        data['summary'],
        fallback: 'Admin action recorded.',
      ),
      createdAt: AdminUserRecord._readDate(data['created_at']),
      targetId: _readNullableString(data['target_id']),
      targetName: _readNullableString(data['target_name']),
      targetRole: _readNullableString(data['target_role']),
      metadata: _readMetadata(data['metadata']),
    );
  }

  String get actionLabel {
    final normalized = action.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) {
      return 'Admin Action';
    }

    return normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String get targetLabel {
    final name = targetName?.trim() ?? '';
    final role = targetRole?.trim() ?? '';
    if (name.isEmpty && role.isEmpty) {
      return 'System';
    }

    if (role.isEmpty) {
      return name;
    }

    if (name.isEmpty) {
      return role;
    }

    return '$name - $role';
  }

  static String _readRequiredLabel(Object? value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic> _readMetadata(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const <String, dynamic>{};
  }
}
