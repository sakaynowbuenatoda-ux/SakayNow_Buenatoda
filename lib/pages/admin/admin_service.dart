import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_models.dart';

class AdminService {
  AdminService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      'reviewed_by': adminId,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }
}
