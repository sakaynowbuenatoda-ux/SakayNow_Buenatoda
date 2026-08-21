import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/auth/registration_service.dart';
import '../core/session/account_flags.dart';

enum DriverCredentialType {
  driversLicense,
  orCr,
  nbiClearance,
  selfie;

  String get label => switch (this) {
    DriverCredentialType.driversLicense => 'Driver\'s License',
    DriverCredentialType.orCr => 'OR/CR',
    DriverCredentialType.nbiClearance => 'NBI Clearance',
    DriverCredentialType.selfie => 'Driver Selfie',
  };

  String get storageName => switch (this) {
    DriverCredentialType.driversLicense => 'drivers_license',
    DriverCredentialType.orCr => 'or_cr',
    DriverCredentialType.nbiClearance => 'nbi_clearance',
    DriverCredentialType.selfie => 'selfie',
  };

  String get urlField => '${storageName}_url';

  String get pathField => '${storageName}_path';

  String? get expiryField => switch (this) {
    DriverCredentialType.driversLicense => 'drivers_license_expiry',
    DriverCredentialType.orCr => 'or_cr_expiry',
    DriverCredentialType.nbiClearance || DriverCredentialType.selfie => null,
  };

  bool get requiresExpiry => expiryField != null;
}

class DriverCredentialService {
  DriverCredentialService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage? _storage;

  Future<void> saveCredential({
    required String driverId,
    required DriverCredentialType type,
    RegistrationImageSelection? document,
    DateTime? expiry,
  }) async {
    final normalizedDriverId = driverId.trim();
    if (normalizedDriverId.isEmpty) {
      throw const DriverCredentialUpdateException(
        'Unable to identify the driver account.',
      );
    }

    final normalizedExpiry = expiry == null ? null : _endOfDay(expiry);
    if (type.requiresExpiry &&
        (normalizedExpiry == null ||
            !normalizedExpiry.isAfter(DateTime.now()))) {
      throw DriverCredentialUpdateException(
        '${type.label} expiry must be in the future.',
      );
    }
    if (document == null && !type.requiresExpiry) {
      throw DriverCredentialUpdateException(
        'Choose an image for ${type.label}.',
      );
    }

    final now = DateTime.now();
    Reference? uploadedRef;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(normalizedDriverId)
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final isVerified = _isVerified(data);
      if (isVerified && data['document_review_status'] == 'pending') {
        throw const DriverCredentialUpdateException(
          'Another document update is already waiting for admin review.',
        );
      }

      String documentUrl;
      String? documentPath;

      if (document == null) {
        documentUrl = _readOptionalString(data[type.urlField]) ?? '';
        // Reuse the approved URL without resubmitting a legacy storage path.
        // The rules verify that this URL matches the approved record.
        documentPath = null;
        if (documentUrl.isEmpty) {
          throw DriverCredentialUpdateException(
            'Choose an image for ${type.label}.',
          );
        }
      } else {
        final suffix = _fileExtension(document.file.name);
        final fileName =
            '${type.storageName}_${now.millisecondsSinceEpoch}.$suffix';
        final path = 'users/$normalizedDriverId/credentials/$fileName';
        uploadedRef = (_storage ?? FirebaseStorage.instance).ref(path);
        await uploadedRef.putData(
          document.bytes,
          SettableMetadata(
            contentType: document.contentType,
            customMetadata: <String, String>{
              'owner_id': normalizedDriverId,
              'field_name': type.urlField,
              'credential_type': type.storageName,
              'kind': 'driver_credential',
            },
          ),
        );
        documentUrl = await uploadedRef.getDownloadURL();
        documentPath = path;
      }

      final updates = <String, dynamic>{
        'document_upload_status': 'uploaded',
        'document_upload_error': FieldValue.delete(),
        'credential_updated_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (isVerified && data['is_verified'] != true) {
        updates['is_verified'] = true;
      }
      if (isVerified) {
        final pendingReview = <String, dynamic>{
          'kind': 'driver_credential',
          'credential_type': type.storageName,
          'document_url': documentUrl,
          if (normalizedExpiry != null)
            'expiry': Timestamp.fromDate(normalizedExpiry),
          'submitted_at': FieldValue.serverTimestamp(),
        };
        if (documentPath != null) {
          pendingReview['document_path'] = documentPath;
        }
        updates.addAll(<String, dynamic>{
          'document_review_status': 'pending',
          'document_review_submitted_at': FieldValue.serverTimestamp(),
          'document_review_rejection_reason': FieldValue.delete(),
          'pending_document_review': pendingReview,
        });
      } else {
        updates[type.urlField] = documentUrl;
        if (documentPath != null) updates[type.pathField] = documentPath;
        if (type.expiryField case final expiryField?) {
          updates[expiryField] = Timestamp.fromDate(normalizedExpiry!);
        }
      }

      await _firestore
          .collection('users')
          .doc(normalizedDriverId)
          .update(updates);
    } catch (error) {
      if (uploadedRef != null) {
        try {
          await uploadedRef.delete();
        } catch (_) {
          // Preserve the upload or profile update error shown to the driver.
        }
      }
      if (error is DriverCredentialUpdateException) rethrow;
      throw DriverCredentialUpdateException(
        'Unable to save ${type.label}. Please try again.',
        cause: error,
      );
    }
  }

  static DateTime _endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
  }

  static String? _readOptionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  static bool _isVerified(Map<String, dynamic> data) {
    return isVerifiedAccountData(data);
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

class DriverCredentialUpdateException implements Exception {
  final String message;
  final Object? cause;

  const DriverCredentialUpdateException(this.message, {this.cause});

  @override
  String toString() => message;
}
