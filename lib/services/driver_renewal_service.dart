import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/auth/registration_service.dart';
import '../models/driver_document_status.dart';

class DriverRenewalService {
  DriverRenewalService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Stream<Map<String, dynamic>> watchDriver(String driverId) {
    return _firestore
        .collection('users')
        .doc(driverId)
        .snapshots()
        .map((snapshot) => snapshot.data() ?? <String, dynamic>{});
  }

  Future<void> submitRenewal({
    required String driverId,
    required DriverDocumentType documentType,
    required RegistrationImageSelection document,
    required DateTime newExpiry,
  }) async {
    final now = DateTime.now();
    final expiry = DateTime(
      newExpiry.year,
      newExpiry.month,
      newExpiry.day,
      23,
      59,
      59,
      999,
    );
    if (!expiry.isAfter(now)) {
      throw const DriverRenewalSubmissionException(
        'The replacement document expiry must be in the future.',
      );
    }

    final suffix = _fileExtension(document.file.name);
    final fileName =
        '${documentType.firestoreValue}_${now.millisecondsSinceEpoch}.$suffix';
    final path = 'users/$driverId/renewals/$fileName';
    final ref = _storage.ref(path);

    try {
      await ref.putData(
        document.bytes,
        SettableMetadata(
          contentType: document.contentType,
          customMetadata: <String, String>{
            'owner_id': driverId,
            'field_name': 'renewal_document_url',
            'document_type': documentType.firestoreValue,
            'kind': 'driver_document_renewal',
          },
        ),
      );
      final downloadUrl = await ref.getDownloadURL();

      await _firestore
          .collection('users')
          .doc(driverId)
          .update(<String, dynamic>{
            'renewal_status': 'pending_renewal',
            'renewal_document_type': documentType.firestoreValue,
            'renewal_document_url': downloadUrl,
            'renewal_document_path': path,
            'renewal_expiry': Timestamp.fromDate(expiry),
            'renewal_submitted_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      try {
        await ref.delete();
      } catch (_) {
        // Preserve the original upload or profile update error.
      }
      throw DriverRenewalSubmissionException(
        'Unable to submit the renewal document. Please try again.',
        cause: error,
      );
    }
  }

  static String _fileExtension(String fileName) {
    final parts = fileName.trim().toLowerCase().split('.');
    final value = parts.length > 1 ? parts.last : 'jpg';
    return switch (value) {
      'png' || 'webp' || 'gif' || 'heic' || 'heif' => value,
      _ => 'jpg',
    };
  }
}

class DriverRenewalSubmissionException implements Exception {
  final String message;
  final Object? cause;

  const DriverRenewalSubmissionException(this.message, {this.cause});

  @override
  String toString() => message;
}
