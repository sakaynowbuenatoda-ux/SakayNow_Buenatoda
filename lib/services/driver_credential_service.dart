import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/auth/registration_service.dart';

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
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

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
      final updates = <String, dynamic>{
        'document_upload_status': 'uploaded',
        'document_upload_error': FieldValue.delete(),
        'credential_updated_at': FieldValue.serverTimestamp(),
        'is_verified': false,
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (document != null) {
        final suffix = _fileExtension(document.file.name);
        final fileName =
            '${type.storageName}_${now.millisecondsSinceEpoch}.$suffix';
        final path = 'users/$normalizedDriverId/credentials/$fileName';
        uploadedRef = _storage.ref(path);
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
        updates[type.urlField] = await uploadedRef.getDownloadURL();
        updates[type.pathField] = path;
      }

      final expiryField = type.expiryField;
      if (normalizedExpiry != null && expiryField != null) {
        updates[expiryField] = Timestamp.fromDate(normalizedExpiry);
        updates['document_status'] = 'valid';
        updates['document_status_updated_at'] = FieldValue.serverTimestamp();
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
      throw DriverCredentialUpdateException(
        'Unable to save ${type.label}. Please try again.',
        cause: error,
      );
    }
  }

  static DateTime _endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
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
