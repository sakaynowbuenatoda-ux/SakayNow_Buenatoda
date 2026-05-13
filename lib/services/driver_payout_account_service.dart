import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/driver_payout_account.dart';

class DriverPayoutAccountService {
  DriverPayoutAccountService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _accounts(String driverId) {
    return _firestore
        .collection('users')
        .doc(driverId)
        .collection('payout_accounts');
  }

  DocumentReference<Map<String, dynamic>> _driver(String driverId) {
    return _firestore.collection('users').doc(driverId);
  }

  Stream<List<DriverPayoutAccount>> watchPayoutAccounts(String driverId) {
    return _accounts(driverId).snapshots().map((snapshot) {
      final accounts = snapshot.docs
          .map(DriverPayoutAccount.fromDocument)
          .toList();
      accounts.sort((a, b) {
        if (a.isDefault != b.isDefault) {
          return a.isDefault ? -1 : 1;
        }

        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
      return accounts;
    });
  }

  Future<void> savePayoutAccount(DriverPayoutAccount account) async {
    final collection = _accounts(account.driverId);
    final isNew = account.id.trim().isEmpty;
    final doc = isNew ? collection.doc() : collection.doc(account.id);
    final savedAccount = account.copyWith(id: doc.id);
    final batch = _firestore.batch();

    if (account.isDefault) {
      final existing = await collection.get();
      for (final item in existing.docs) {
        if (item.id != doc.id) {
          batch.update(item.reference, <String, dynamic>{
            'is_default': false,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    batch.set(
      doc,
      savedAccount.toFirestore(includeCreatedAt: isNew),
      SetOptions(merge: true),
    );
    await batch.commit();
    await _syncOnlinePaymentSupport(account.driverId);
  }

  Future<void> deletePayoutAccount({
    required String driverId,
    required String payoutAccountId,
  }) async {
    await _accounts(driverId).doc(payoutAccountId).delete();
    await _syncOnlinePaymentSupport(driverId);
  }

  Future<void> setDefaultPayoutAccount({
    required String driverId,
    required String payoutAccountId,
  }) async {
    final snapshot = await _accounts(driverId).get();
    final batch = _firestore.batch();
    for (final item in snapshot.docs) {
      batch.update(item.reference, <String, dynamic>{
        'is_default': item.id == payoutAccountId,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    await _syncOnlinePaymentSupport(driverId);
  }

  Future<void> _syncOnlinePaymentSupport(String driverId) async {
    final snapshot = await _accounts(driverId).get();
    final accounts = snapshot.docs
        .map(DriverPayoutAccount.fromDocument)
        .toList();
    final onlineMethods =
        accounts.map((account) => account.type.firestoreValue).toSet().toList()
          ..sort();
    DriverPayoutAccount? defaultAccount;
    for (final account in accounts) {
      if (account.isDefault) {
        defaultAccount = account;
        break;
      }
    }

    await _driver(driverId).set(<String, dynamic>{
      'accepts_online_payments': accounts.isNotEmpty,
      'online_payment_methods': onlineMethods,
      'default_payout_account_id': defaultAccount?.id,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
