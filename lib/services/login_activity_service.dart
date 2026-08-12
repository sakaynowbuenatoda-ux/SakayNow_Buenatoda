import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/login_activity_entry.dart';

class LoginActivityService {
  LoginActivityService({
    FirebaseFirestore? firestore,
    String Function()? platformProvider,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _platformProvider = platformProvider ?? _currentPlatform;

  static final LoginActivityService instance = LoginActivityService();
  static const int historyLimit = 25;

  final FirebaseFirestore _firestore;
  final String Function() _platformProvider;

  Future<void> recordSuccessfulLogin({required String userId}) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }

    try {
      await _activityCollection(normalizedUserId).add(<String, dynamic>{
        'user_id': normalizedUserId,
        'signed_in_at': FieldValue.serverTimestamp(),
        'platform': _platformProvider(),
        'auth_method': 'password',
      });
    } catch (_) {
      // A login-history write must never turn a successful login into a failure.
    }
  }

  Stream<List<LoginActivityEntry>> watchLoginHistory({required String userId}) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream<List<LoginActivityEntry>>.value(
        const <LoginActivityEntry>[],
      );
    }

    return _activityCollection(normalizedUserId)
        .orderBy('signed_in_at', descending: true)
        .limit(historyLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(LoginActivityEntry.fromDocument)
              .toList(growable: false),
        );
  }

  CollectionReference<Map<String, dynamic>> _activityCollection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('login_activity');
  }

  static String _currentPlatform() {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'unknown',
    };
  }
}
