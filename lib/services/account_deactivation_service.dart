import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/session/session_service.dart';
import 'ride_tracking_service.dart';

class AccountDeactivationService {
  AccountDeactivationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    RideTrackingService? rideTrackingService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _rideTrackingService = rideTrackingService ?? RideTrackingService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final RideTrackingService _rideTrackingService;

  Future<void> deactivateCurrentAccount({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();

    if (user == null || email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Unable to confirm the current signed-in account.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    final userRef = _firestore.collection('users').doc(user.uid);
    final userSnapshot = await userRef.get();
    if (!userSnapshot.exists) {
      throw StateError('User profile not found.');
    }

    final userData = userSnapshot.data() ?? <String, dynamic>{};
    final role = (userData['role'] ?? '').toString().trim().toLowerCase();
    await _ensureNoActiveRide(user.uid, role);

    if (role == 'driver') {
      await _rideTrackingService.markDriverUnavailable(driverId: user.uid);
    }

    await userRef.update(<String, dynamic>{
      'is_active': false,
      'is_deactivated': true,
      'account_status': 'deactivated',
      'deactivated_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await SessionService.signOut();
  }

  Future<void> _ensureNoActiveRide(String userId, String role) async {
    if (role == 'driver') {
      final activeRide = await _rideTrackingService.findDriverActiveRide(
        userId,
      );
      if (activeRide != null) {
        throw StateError(
          'Finish or cancel your active ride before deactivating your account.',
        );
      }
      return;
    }

    final activeRide = await _rideTrackingService.findPassengerActiveRide(
      userId,
    );
    if (activeRide != null) {
      throw StateError(
        'Finish or cancel your active ride before deactivating your account.',
      );
    }
  }
}
