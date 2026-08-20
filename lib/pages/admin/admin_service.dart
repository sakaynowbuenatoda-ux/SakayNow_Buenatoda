import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/fare_settings.dart';
import '../../services/fare_settings_service.dart';
import '../../services/ride_tracking_service.dart';
import 'admin_models.dart';

class AdminService {
  AdminService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FareSettingsService _fareSettingsService = FareSettingsService(
    firestore: _firestore,
  );

  static Stream<List<AdminUserRecord>> watchUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs
          .map(AdminUserRecord.fromDocument)
          .toList(growable: false);

      users.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return users;
    });
  }

  static Stream<List<AdminUserRecord>> watchManagedAdmins() {
    return watchUsers().map((users) {
      final admins = users
          .where((user) => user.isRegularAdmin)
          .toList(growable: false);

      admins.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return admins;
    });
  }

  static Stream<List<AdminUserRecord>> watchActiveAdminStaff({
    String? excludingUserId,
  }) {
    final excludedId = excludingUserId?.trim() ?? '';
    return watchUsers().map((users) {
      final staff =
          users
              .where(
                (user) =>
                    user.isAdminStaff &&
                    user.isActive &&
                    !user.isBanned &&
                    !user.isDeactivated &&
                    !user.isDeleted &&
                    user.userId != excludedId,
              )
              .toList(growable: false)
            ..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );
      return staff;
    });
  }

  static Stream<List<AdminUserRecord>> watchActiveDrivers() {
    return _firestore
        .collection('driver_locations')
        .where('is_available', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final users = <AdminUserRecord>[];
          final seenDriverIds = <String>{};

          for (final document in snapshot.docs) {
            final locationData = document.data();
            if (!_isLiveActiveDriverLocation(locationData)) {
              continue;
            }

            final driverId = _driverIdFromLocation(
              fallbackId: document.id,
              data: locationData,
            );
            if (driverId.isEmpty || !seenDriverIds.add(driverId)) {
              continue;
            }

            final userSnapshot = await _firestore
                .collection('users')
                .doc(driverId)
                .get();
            if (!userSnapshot.exists) {
              continue;
            }

            final user = AdminUserRecord.fromDocument(userSnapshot);
            if (user.isEligibleDriverAccount) {
              users.add(user);
            }
          }

          users.sort((a, b) => a.fullName.compareTo(b.fullName));
          return users;
        });
  }

  static Stream<List<AdminDriverLocationRecord>> watchActiveDriverLocations() {
    return _firestore
        .collection('driver_locations')
        .where('is_available', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final drivers = <AdminDriverLocationRecord>[];
          final seenDriverIds = <String>{};

          for (final document in snapshot.docs) {
            final locationData = document.data();
            if (!_isLiveActiveDriverLocation(locationData)) {
              continue;
            }

            final driverId = _driverIdFromLocation(
              fallbackId: document.id,
              data: locationData,
            );
            if (driverId.isEmpty || !seenDriverIds.add(driverId)) {
              continue;
            }

            final userSnapshot = await _firestore
                .collection('users')
                .doc(driverId)
                .get();
            if (!userSnapshot.exists) {
              continue;
            }

            final user = AdminUserRecord.fromDocument(userSnapshot);
            if (!user.isEligibleDriverAccount) {
              continue;
            }

            drivers.add(
              AdminDriverLocationRecord.fromData(
                driverId: driverId,
                driver: user,
                locationData: <String, dynamic>{
                  ...locationData,
                  'driver_id': driverId,
                },
              ),
            );
          }

          drivers.sort((a, b) => a.fullName.compareTo(b.fullName));
          return drivers;
        });
  }

  static Stream<AdminUserRecord> watchUser(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((
      document,
    ) {
      if (!document.exists) {
        throw StateError('User record not found in Firestore.');
      }

      return AdminUserRecord.fromDocument(document);
    });
  }

  static Stream<List<AdminUserRecord>> watchDeactivatedUsers() {
    return _firestore
        .collection('users')
        .where('is_deactivated', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map(AdminUserRecord.fromDocument)
              .where(
                (user) =>
                    user.isPassengerOrDriver &&
                    user.isDeactivated &&
                    !user.isDeleted,
              )
              .toList(growable: false);

          users.sort((a, b) {
            final aDate =
                a.deactivatedAt ??
                a.deactivationRestoreDeadline ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                b.deactivatedAt ??
                b.deactivationRestoreDeadline ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

          return users;
        });
  }

  static Stream<List<AdminUserRecord>> watchRestrictedUsers() {
    return _firestore
        .collection('users')
        .where('is_banned', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map(AdminUserRecord.fromDocument)
              .where((user) => !user.isAdmin && user.isBanned)
              .toList(growable: false);

          users.sort((a, b) {
            final aDate =
                a.reviewedAt ??
                a.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                b.reviewedAt ??
                b.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

          return users;
        });
  }

  static Stream<List<AdminBookingRecord>> watchBookings() {
    return _firestore.collection('bookings').snapshots().map((snapshot) {
      final bookings = snapshot.docs
          .map(AdminBookingRecord.fromDocument)
          .toList(growable: false);

      bookings.sort((a, b) {
        final aDate = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return bookings;
    });
  }

  static Stream<AdminBookingRecord?> watchBooking(String bookingId) {
    final normalizedBookingId = bookingId.trim();
    if (normalizedBookingId.isEmpty) {
      return Stream<AdminBookingRecord?>.value(null);
    }

    return _firestore
        .collection('bookings')
        .doc(normalizedBookingId)
        .snapshots()
        .map(
          (document) => document.exists
              ? AdminBookingRecord.fromDocument(document)
              : null,
        );
  }

  static Stream<List<AdminBookingRecord>> watchBookingHistory({
    List<String> statuses = const <String>[],
    DateTime? startAt,
    DateTime? endAt,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('bookings');

    if (statuses.length == 1) {
      query = query.where('status', isEqualTo: statuses.single);
    } else if (statuses.isNotEmpty) {
      query = query.where('status', whereIn: statuses);
    }

    if (startAt != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startAt),
      );
    }

    if (endAt != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endAt),
      );
    }

    return query.orderBy('timestamp', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map(AdminBookingRecord.fromDocument)
          .toList(growable: false);
    });
  }

  static Stream<List<AdminReportRecord>> watchReports() {
    return _firestore.collection('reports').snapshots().map((snapshot) {
      final reports = snapshot.docs
          .map(AdminReportRecord.fromDocument)
          .toList(growable: false);

      reports.sort((a, b) {
        final aDate = a.sortDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.sortDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return reports;
    });
  }

  static Stream<List<AdminActionLogRecord>> watchAdminLogs({int? limit}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('admin_logs')
        .orderBy('created_at', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(AdminActionLogRecord.fromDocument)
          .toList(growable: false);
    });
  }

  static Stream<FareSettings> watchFareSettings() {
    return _fareSettingsService.watchSettings();
  }

  static Future<void> updateFareSettings({
    required FareSettings settings,
    required String adminId,
  }) {
    return _fareSettingsService.updateSettings(
      settings: settings,
      adminId: adminId,
    );
  }

  static Stream<List<AdminReviewRecord>> watchReviewsForUser(String userId) {
    return _firestore
        .collection('reviews')
        .where('reviewee_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs
              .map(AdminReviewRecord.fromDocument)
              .toList(growable: false);

          reviews.sort((a, b) {
            final aDate =
                a.updatedAt ??
                a.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                b.updatedAt ??
                b.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

          return reviews;
        });
  }

  static Future<void> approveUser({
    required String userId,
    required String adminId,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw StateError('User account not found.');
      }
      final data = snapshot.data() ?? <String, dynamic>{};
      final updates = <String, dynamic>{
        ..._approvedPendingDocumentReviewUpdates(data),
        'is_verified': true,
        'is_active': true,
        'is_banned': false,
        'account_status': 'active',
        'reviewed_by': adminId,
        'reviewed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (_hasPendingDocumentReview(data)) {
        _markDocumentReviewApproved(updates, adminId: adminId);
      }
      transaction.update(userRef, updates);
    });
  }

  static Future<void> approveDocumentReview({
    required String userId,
    required String adminId,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      if (!snapshot.exists || !_hasPendingDocumentReview(data)) {
        throw StateError('This document update is no longer pending.');
      }

      final updates = _approvedPendingDocumentReviewUpdates(data);
      _markDocumentReviewApproved(updates, adminId: adminId);
      updates['updated_at'] = FieldValue.serverTimestamp();
      transaction.update(userRef, updates);
    });
  }

  static Future<void> rejectDocumentReview({
    required String userId,
    required String adminId,
    required String reason,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError('A rejection reason is required.');
    }
    final userRef = _firestore.collection('users').doc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      if (!snapshot.exists || !_hasPendingDocumentReview(data)) {
        throw StateError('This document update is no longer pending.');
      }

      transaction.update(userRef, <String, dynamic>{
        'document_review_status': 'rejected',
        'document_upload_status': 'rejected',
        'document_review_reviewed_by': adminId,
        'document_review_reviewed_at': FieldValue.serverTimestamp(),
        'document_review_rejection_reason': normalizedReason,
        'reviewed_by': adminId,
        'reviewed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  static bool _hasPendingDocumentReview(Map<String, dynamic> data) {
    return data['document_review_status'] == 'pending' &&
        data['pending_document_review'] is Map;
  }

  static void _markDocumentReviewApproved(
    Map<String, dynamic> updates, {
    required String adminId,
  }) {
    updates.addAll(<String, dynamic>{
      'document_review_status': 'approved',
      'document_upload_status': 'approved',
      'document_review_reviewed_by': adminId,
      'document_review_reviewed_at': FieldValue.serverTimestamp(),
      'document_review_rejection_reason': FieldValue.delete(),
      'pending_document_review': FieldValue.delete(),
      'reviewed_by': adminId,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }

  static Map<String, dynamic> _approvedPendingDocumentReviewUpdates(
    Map<String, dynamic> data,
  ) {
    if (!_hasPendingDocumentReview(data)) return <String, dynamic>{};
    final rawReview = data['pending_document_review'];
    final review = Map<String, dynamic>.from(rawReview as Map);
    final kind = review['kind']?.toString().trim() ?? '';

    switch (kind) {
      case 'driver_credential':
        final type = review['credential_type']?.toString().trim() ?? '';
        if (!const <String>{
          'nbi_clearance',
          'drivers_license',
          'selfie',
          'or_cr',
        }.contains(type)) {
          throw StateError('The pending credential type is invalid.');
        }
        final documentUrl = review['document_url']?.toString().trim() ?? '';
        if (documentUrl.isEmpty) {
          throw StateError('The pending credential image is missing.');
        }
        final updates = <String, dynamic>{'${type}_url': documentUrl};
        final documentPath = review['document_path']?.toString().trim() ?? '';
        if (documentPath.isNotEmpty) updates['${type}_path'] = documentPath;

        if (type == 'drivers_license' || type == 'or_cr') {
          final expiry = review['expiry'];
          if (expiry is! Timestamp ||
              !expiry.toDate().isAfter(DateTime.now())) {
            throw StateError('The pending credential expiry is invalid.');
          }
          updates['${type}_expiry'] = expiry;
          final licenseExpiry = type == 'drivers_license'
              ? expiry.toDate()
              : _dateFromValue(data['drivers_license_expiry']);
          final orCrExpiry = type == 'or_cr'
              ? expiry.toDate()
              : _dateFromValue(data['or_cr_expiry']);
          final documentStatus = _documentStatusForDates(
            licenseExpiry: licenseExpiry,
            orCrExpiry: orCrExpiry,
            now: DateTime.now(),
          );
          updates['document_status'] = documentStatus;
          updates['document_status_updated_at'] = FieldValue.serverTimestamp();
          if (documentStatus == 'expired') updates['is_active'] = false;
        }
        return updates;
      case 'driver_vehicle':
        final requiredValues = <String>[
          'vehicle_type',
          'tricycle_color',
          'plate_number',
          'tricycle_front_url',
          'tricycle_back_url',
        ];
        final updates = <String, dynamic>{};
        for (final field in requiredValues) {
          final value = review[field]?.toString().trim() ?? '';
          if (value.isEmpty) {
            throw StateError('The pending vehicle update is incomplete.');
          }
          updates[field] = value;
        }
        for (final field in const <String>[
          'tricycle_front_path',
          'tricycle_back_path',
        ]) {
          final value = review[field]?.toString().trim() ?? '';
          if (value.isNotEmpty) updates[field] = value;
        }
        return updates;
      case 'passenger_identity':
        final updates = <String, dynamic>{};
        for (final field in const <String>[
          'id_image_url',
          'id_image_path',
          'selfie_url',
          'selfie_path',
        ]) {
          final value = review[field]?.toString().trim() ?? '';
          if (value.isNotEmpty) updates[field] = value;
        }
        if (!updates.containsKey('id_image_url') &&
            !updates.containsKey('selfie_url')) {
          throw StateError('The pending identity update is incomplete.');
        }
        return updates;
      default:
        throw StateError('The pending document review type is invalid.');
    }
  }

  static Future<void> approveDriverRenewal({
    required String userId,
    required String adminId,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      if (!snapshot.exists || data['role'] != 'driver') {
        throw StateError('Driver account not found.');
      }
      if (data['renewal_status'] != 'pending_renewal') {
        throw StateError('This renewal is no longer pending.');
      }

      final documentType = data['renewal_document_type']?.toString();
      final documentUrl = data['renewal_document_url']?.toString().trim() ?? '';
      final renewalExpiry = data['renewal_expiry'];
      if (!const <String>['drivers_license', 'or_cr'].contains(documentType) ||
          documentUrl.isEmpty ||
          renewalExpiry is! Timestamp) {
        throw StateError('The renewal submission is incomplete.');
      }

      final now = DateTime.now();
      if (!renewalExpiry.toDate().isAfter(now)) {
        throw StateError('The replacement document is already expired.');
      }

      final licenseExpiry = documentType == 'drivers_license'
          ? renewalExpiry.toDate()
          : _dateFromValue(data['drivers_license_expiry']);
      final orCrExpiry = documentType == 'or_cr'
          ? renewalExpiry.toDate()
          : _dateFromValue(data['or_cr_expiry']);
      final status = _documentStatusForDates(
        licenseExpiry: licenseExpiry,
        orCrExpiry: orCrExpiry,
        now: now,
      );

      transaction.update(userRef, <String, dynamic>{
        documentType == 'drivers_license' ? 'drivers_license_url' : 'or_cr_url':
            documentUrl,
        documentType == 'drivers_license'
                ? 'drivers_license_expiry'
                : 'or_cr_expiry':
            renewalExpiry,
        'renewal_status': 'approved',
        'renewal_reviewed_by': adminId,
        'renewal_reviewed_at': FieldValue.serverTimestamp(),
        'renewal_rejection_reason': FieldValue.delete(),
        'document_status': status,
        'document_status_updated_at': FieldValue.serverTimestamp(),
        if (status == 'expired') 'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> rejectDriverRenewal({
    required String userId,
    required String adminId,
    required String reason,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw ArgumentError('A rejection reason is required.');
    }
    await _firestore.collection('users').doc(userId).update({
      'renewal_status': 'rejected',
      'renewal_reviewed_by': adminId,
      'renewal_reviewed_at': FieldValue.serverTimestamp(),
      'renewal_rejection_reason': normalizedReason,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static DateTime? _dateFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _documentStatusForDates({
    required DateTime? licenseExpiry,
    required DateTime? orCrExpiry,
    required DateTime now,
  }) {
    final dates = <DateTime>[?licenseExpiry, ?orCrExpiry];
    if (dates.any((date) => !date.isAfter(now))) return 'expired';
    if (dates.any((date) => !date.isAfter(now.add(const Duration(days: 30))))) {
      return 'expiring_soon';
    }
    return 'valid';
  }

  static Future<void> restrictUser({
    required String userId,
    required String adminId,
  }) {
    return _firestore.collection('users').doc(userId).update({
      'is_active': false,
      'is_banned': true,
      'reviewed_by': adminId,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> restoreUser({
    required String userId,
    required String adminId,
  }) {
    return _firestore.collection('users').doc(userId).update({
      'is_banned': false,
      'is_verified': true,
      'is_active': true,
      'account_status': 'active',
      'reviewed_by': adminId,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> restoreDeactivatedUser({
    required String userId,
    required String adminId,
  }) {
    return _firestore.collection('users').doc(userId).update({
      'is_active': true,
      'is_deactivated': false,
      'account_status': 'active',
      'deactivated_at': FieldValue.delete(),
      'deactivation_restore_deadline': FieldValue.delete(),
      'deactivation_purge_after': FieldValue.delete(),
      'account_anonymized_at': FieldValue.delete(),
      'privacy_deletion_reason': FieldValue.delete(),
      'restored_by': adminId,
      'restored_at': FieldValue.serverTimestamp(),
      'reviewed_by': adminId,
      'reviewed_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static bool _isLiveActiveDriverLocation(Map<String, dynamic> data) {
    return data['is_available'] == true &&
        _hasCoordinates(data) &&
        !_isStaleLocation(data);
  }

  static String _driverIdFromLocation({
    required String fallbackId,
    required Map<String, dynamic> data,
  }) {
    final driverId = data['driver_id']?.toString().trim() ?? '';
    if (driverId.isNotEmpty && driverId != 'null') {
      return driverId;
    }

    return fallbackId.trim();
  }

  static bool _hasCoordinates(Map<String, dynamic> data) {
    return data['geopoint'] is GeoPoint ||
        (data['latitude'] != null && data['longitude'] != null);
  }

  static bool _isStaleLocation(Map<String, dynamic> data) {
    final updatedAt = _readDate(data['updated_at']);
    if (updatedAt == null) {
      return true;
    }

    return DateTime.now().difference(updatedAt) >
        RideTrackingService.driverAvailabilityTimeout;
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
}
