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
            if (!_isLiveAvailableDriverLocation(locationData)) {
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
            if (user.canReceiveBookings) {
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
            if (!_isLiveAvailableDriverLocation(locationData)) {
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
            if (!user.canReceiveBookings) {
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
              .where((user) => user.isDeactivated && !user.isDeleted)
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
  }) {
    return _firestore.collection('users').doc(userId).update({
      'is_verified': true,
      'is_active': true,
      'is_banned': false,
      'account_status': 'active',
      'reviewed_by': adminId,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
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

  static bool _isLiveAvailableDriverLocation(Map<String, dynamic> data) {
    return data['is_available'] == true &&
        _hasCoordinates(data) &&
        !_hasActiveBookingMarker(data) &&
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

  static bool _hasActiveBookingMarker(Map<String, dynamic> data) {
    final activeBookingId = data['active_booking_id']?.toString().trim() ?? '';
    return activeBookingId.isNotEmpty && activeBookingId != 'null';
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
