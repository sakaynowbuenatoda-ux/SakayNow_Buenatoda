import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/passenger_payment_method.dart';

class PaymentMethodService {
  PaymentMethodService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _methods(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('payment_methods');
  }

  Stream<List<PassengerPaymentMethod>> watchPaymentMethods(String userId) {
    return _methods(userId).snapshots().map((snapshot) {
      final methods = snapshot.docs
          .map(PassengerPaymentMethod.fromDocument)
          .where((method) => !method.isCash)
          .toList();
      methods.sort((a, b) {
        if (a.isDefault != b.isDefault) {
          return a.isDefault ? -1 : 1;
        }

        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });

      return <PassengerPaymentMethod>[
        PassengerPaymentMethod.cash(userId: userId),
        ...methods,
      ];
    });
  }

  Future<List<PassengerPaymentMethod>> loadPaymentMethods(String userId) {
    return watchPaymentMethods(userId).first;
  }

  Future<void> savePaymentMethod(PassengerPaymentMethod method) async {
    if (method.isCash) {
      throw ArgumentError('Cash is a built-in payment method.');
    }

    final collection = _methods(method.userId);
    final isNew = method.id.trim().isEmpty;
    final doc = isNew ? collection.doc() : collection.doc(method.id);
    final savedMethod = method.copyWith(id: doc.id);
    final batch = _firestore.batch();

    if (method.isDefault) {
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
      savedMethod.toFirestore(includeCreatedAt: isNew),
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> deletePaymentMethod({
    required String userId,
    required String paymentMethodId,
  }) {
    return _methods(userId).doc(paymentMethodId).delete();
  }

  Future<void> setDefaultPaymentMethod({
    required String userId,
    required String paymentMethodId,
  }) async {
    if (paymentMethodId == PassengerPaymentMethod.cashMethodId) {
      final snapshot = await _methods(userId).get();
      final batch = _firestore.batch();
      for (final item in snapshot.docs) {
        batch.update(item.reference, <String, dynamic>{
          'is_default': false,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return;
    }

    final snapshot = await _methods(userId).get();
    final batch = _firestore.batch();
    for (final item in snapshot.docs) {
      batch.update(item.reference, <String, dynamic>{
        'is_default': item.id == paymentMethodId,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
