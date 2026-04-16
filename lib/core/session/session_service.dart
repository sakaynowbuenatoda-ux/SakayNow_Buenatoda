import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../pages/admin/admin_home_page.dart';
import '../../pages/driver/driver_shell.dart';
import '../../pages/passenger/passenger_shell.dart';
import 'app_user.dart';

class SessionService {
  SessionService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final AppUser user = await loadUserProfile(credential.user!.uid);
    await saveUserSession(user);
    return user;
  }

  static Future<AppUser> loadUserProfile(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      throw StateError('User record not found in Firestore.');
    }

    final AppUser user =
        AppUser.fromMap(userDoc.data() ?? <String, dynamic>{}, uid);
    await saveUserSession(user);
    return user;
  }

  static Future<void> saveUserSession(AppUser user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.userId);
    await prefs.setString('first_name', user.firstName);
    await prefs.setString('last_name', user.lastName);
    await prefs.setString('email', user.email);
    await prefs.setString('role', user.role);
  }

  static Future<void> clearUserSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('first_name');
    await prefs.remove('last_name');
    await prefs.remove('email');
    await prefs.remove('role');
  }

  static Future<void> signOut() async {
    await clearUserSession();
    await _auth.signOut();
  }

  static Widget buildHomeForUser(AppUser user) {
    switch (user.userRole) {
      case UserRole.admin:
        return AdminHomePage(
          userId: user.userId,
          firstName: user.firstName,
        );
      case UserRole.driver:
        return DriverShell(
          userId: user.userId,
          firstName: user.firstName,
        );
      case UserRole.passenger:
        return PassengerShell(
          userId: user.userId,
          firstName: user.firstName,
          role: user.role,
        );
    }
  }
}
