import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class EmailVerificationService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  EmailVerificationService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

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

    await refreshedUser.getIdToken(true);
    await _firestore.collection('users').doc(refreshedUser.uid).update({
      'email_verified': true,
      'email_verified_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
