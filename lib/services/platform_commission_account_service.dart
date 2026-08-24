import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/platform_commission_account.dart';

class PlatformCommissionAccountService {
  PlatformCommissionAccountService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String collectionPath = 'platform_commission_accounts';
  static const String currentDocumentId = 'current';

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _currentAccount =>
      _firestore.collection(collectionPath).doc(currentDocumentId);

  Stream<PlatformCommissionAccount?> watchAccount() {
    return _currentAccount.snapshots().map(
      (snapshot) => snapshot.exists
          ? PlatformCommissionAccount.fromDocument(snapshot)
          : null,
    );
  }

  Future<void> saveAccount({
    required PlatformCommissionAccount account,
    required String adminId,
  }) async {
    final normalizedAdminId = adminId.trim();
    if (normalizedAdminId.isEmpty) {
      throw ArgumentError('An admin ID is required.');
    }

    final existing = await _currentAccount.get();
    await _currentAccount.set(
      account.toFirestore(
        adminId: normalizedAdminId,
        includeCreatedAt: !existing.exists,
      ),
      SetOptions(merge: true),
    );
  }
}
