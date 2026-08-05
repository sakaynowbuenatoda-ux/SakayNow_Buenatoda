import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../preferences/app_preferences_controller.dart';
import '../../pages/admin/admin_home_page.dart';
import '../../pages/driver/driver_shell.dart';
import '../../pages/passenger/passenger_shell.dart';
import '../../services/notification_service.dart';
import '../../services/ride_tracking_service.dart';
import 'app_user.dart';

class SessionService {
  SessionService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<AppUser> loadUserProfile(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw StateError('Account profile not found.');
      }

      final AppUser user = AppUser.fromMap(
        userDoc.data() ?? <String, dynamic>{},
        uid,
      );
      await saveUserSession(user);
      return user;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw StateError(
          'You do not have access to this account profile right now.',
        );
      }

      throw StateError(
        'Unable to load your account profile. Please try again.',
      );
    }
  }

  static Stream<AppUser> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().asyncMap((
      userDoc,
    ) async {
      if (!userDoc.exists) {
        throw StateError('Account profile not found.');
      }

      final AppUser user = AppUser.fromMap(
        userDoc.data() ?? <String, dynamic>{},
        uid,
      );
      await saveUserSession(user);
      return user;
    });
  }

  static Future<void> saveUserSession(AppUser user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.userId);
    await prefs.setString('first_name', user.firstName);
    await prefs.setString('last_name', user.lastName);
    await prefs.setString('email', user.email);
    await prefs.setString('role', user.role);
    await prefs.setString('passenger_type', user.passengerType);
  }

  static Future<void> clearUserSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('first_name');
    await prefs.remove('last_name');
    await prefs.remove('email');
    await prefs.remove('role');
    await prefs.remove('passenger_type');
    await AppPreferencesController.instance.clearThemePreference();
  }

  static Future<void> signOut() async {
    await _markCurrentDriverUnavailable();
    await NotificationService.instance.unregisterCurrentDevice();
    await clearUserSession();
    await _auth.signOut();
  }

  static Future<void> _markCurrentDriverUnavailable() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role')?.trim().toLowerCase();
      if (role != 'driver') {
        return;
      }

      await RideTrackingService().markDriverUnavailable(
        driverId: currentUser.uid,
      );
    } on Exception {
      // Continue signing out even if the availability write cannot complete.
    }
  }

  static Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  static Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  static Widget buildHomeForUser(AppUser user) {
    switch (user.userRole) {
      case UserRole.admin:
        return AdminHomePage(
          userId: user.userId,
          firstName: user.firstName,
          profileImageUrl: user.profileImageUrl,
        );
      case UserRole.driver:
        return DriverShell(
          userId: user.userId,
          firstName: user.firstName,
          isVerified: user.isVerified,
          canReceiveBookings: user.canReceiveDriverBookings,
          profileImageUrl: user.profileImageUrl,
        );
      case UserRole.passenger:
        return PassengerShell(
          userId: user.userId,
          firstName: user.firstName,
          passengerType: user.passengerType,
          isVerified: user.isVerified,
          profileImageUrl: user.profileImageUrl,
        );
    }
  }
}
