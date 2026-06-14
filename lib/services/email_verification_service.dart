import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/auth/signup_validators.dart';

class EmailVerificationStatus {
  final String? email;
  final bool isVerified;
  final bool hasSignedInUser;

  const EmailVerificationStatus({
    required this.email,
    required this.isVerified,
    required this.hasSignedInUser,
  });

  bool get hasEmail => email != null && email!.trim().isNotEmpty;
}

abstract class EmailVerificationClient {
  Future<EmailVerificationStatus> loadStatus({bool refresh = false});

  Future<void> sendVerificationEmail();

  Future<void> requestEmailUpdate({
    required String newEmail,
    required String currentPassword,
  });

  Future<void> syncVerifiedEmailToProfile();
}

class EmailVerificationService implements EmailVerificationClient {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  EmailVerificationService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<EmailVerificationStatus> loadStatus({bool refresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const EmailVerificationStatus(
        email: null,
        isVerified: false,
        hasSignedInUser: false,
      );
    }

    if (refresh) {
      await user.reload();
    }

    final refreshedUser = _auth.currentUser ?? user;
    return EmailVerificationStatus(
      email: refreshedUser.email,
      isVerified: refreshedUser.emailVerified,
      hasSignedInUser: true,
    );
  }

  @override
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();
    if (user == null || email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'No email address is linked to this signed-in account.',
      );
    }

    if (user.emailVerified) {
      return;
    }

    await user.sendEmailVerification();
  }

  @override
  Future<void> requestEmailUpdate({
    required String newEmail,
    required String currentPassword,
  }) async {
    final normalizedEmail = newEmail.trim();
    final password = currentPassword;
    final user = _auth.currentUser;
    final currentEmail = user?.email?.trim();

    if (user == null || currentEmail == null || currentEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'No email address is linked to this signed-in account.',
      );
    }

    if (SignupValidators.email(normalizedEmail) != null) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Enter a valid email address.',
      );
    }

    if (currentEmail.toLowerCase() == normalizedEmail.toLowerCase()) {
      throw FirebaseAuthException(
        code: 'same-email',
        message: 'Enter a different email address.',
      );
    }

    if (password.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-password',
        message: 'Enter your current password.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: currentEmail,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);

    final refreshedUser = _auth.currentUser ?? user;
    await refreshedUser.verifyBeforeUpdateEmail(normalizedEmail);
  }

  @override
  Future<void> syncVerifiedEmailToProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Unable to confirm the current signed-in account.',
      );
    }

    await user.reload();
    final refreshedUser = _auth.currentUser ?? user;
    if (!refreshedUser.emailVerified) {
      return;
    }

    final verifiedEmail = refreshedUser.email?.trim();
    if (verifiedEmail == null || verifiedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'No email address is linked to this signed-in account.',
      );
    }

    await refreshedUser.getIdToken(true);
    await _firestore.collection('users').doc(refreshedUser.uid).update({
      'email': verifiedEmail,
      'email_verified': true,
      'email_verified_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
