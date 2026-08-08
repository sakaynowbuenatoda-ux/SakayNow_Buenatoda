import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('storage.rules').readAsStringSync();
  });

  group('Storage rules', () {
    test('limit profile picture writes to images inside cooldown window', () {
      expect(
        rules,
        contains('match /users/{userId}/profile_pictures/{fileName}'),
      );
      expect(rules, contains('allow read: if signedIn();'));
      expect(rules, contains('allow create, update: if isSelf(userId)'));
      expect(rules, contains('&& isImage()'));
      expect(rules, contains('request.resource.size < 5 * 1024 * 1024'));
      expect(rules, contains('profilePictureCooldownPassed(userId)'));
    });

    test('keep signup document uploads owner-scoped and size-limited', () {
      expect(rules, contains('match /users/{userId}/{fileName}'));
      expect(rules, contains('allow read: if isSelf(userId) || isAdmin()'));
      expect(
        rules,
        contains(
          "|| (signedIn() && fileName in ['selfie.jpg', 'tricycle_front.jpg', 'tricycle_back.jpg'])",
        ),
      );
      expect(rules, contains('allow write: if isSelf(userId)'));
      expect(rules, contains('request.resource.size < 10 * 1024 * 1024'));
    });

    test('admin storage checks still resolve through Firestore user roles', () {
      expect(rules, contains('function isAdmin()'));
      expect(rules, contains('firestore.get('));
      expect(rules, contains(".data.role == 'admin'"));
    });

    test('keep renewal uploads private to the driver and admins', () {
      expect(rules, contains('match /users/{userId}/renewals/{fileName}'));
      expect(rules, contains('allow read: if isSelf(userId) || isAdmin();'));
      expect(rules, contains('allow create, update: if isSelf(userId)'));
      expect(rules, contains('&& isImage()'));
      expect(rules, contains('request.resource.size < 10 * 1024 * 1024'));
    });

    test('keep credential uploads private and owner scoped', () {
      expect(rules, contains('match /users/{userId}/credentials/{fileName}'));
      expect(rules, contains('allow read: if isSelf(userId) || isAdmin();'));
      expect(rules, contains('allow create: if isSelf(userId)'));
      expect(rules, contains('&& isImage()'));
      expect(rules, contains('request.resource.size < 10 * 1024 * 1024'));
    });
  });
}
