import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'signup_validators.dart';

class RegistrationService {
  RegistrationService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const int maxDocumentImageBytes = 10 * 1024 * 1024;

  static Future<void> registerPassenger({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String age,
    required String? gender,
    required String passengerType,
    required RegistrationImageSelection idFile,
    required RegistrationImageSelection selfieFile,
  }) async {
    if (SignupValidators.isReservedAdminName(firstName)) {
      throw ArgumentError('The name admin is reserved.');
    }

    final parsedAge = int.tryParse(age.trim());
    final profileData = <String, dynamic>{
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'role': 'passenger',
      'passenger_type': passengerType,
      'is_verified': false,
      'is_active': false,
      'is_banned': false,
      'is_deactivated': false,
      'account_status': 'active',
    };

    if (parsedAge != null) {
      profileData['age'] = parsedAge;
    }

    if (gender != null) {
      profileData['gender'] = gender;
    }

    await _registerUser(
      email: email,
      password: password,
      profileData: profileData,
      uploads: <_UploadPayload>[
        _UploadPayload(
          fieldName: 'id_image_url',
          fileName: 'id_upload.jpg',
          file: idFile,
        ),
        _UploadPayload(
          fieldName: 'selfie_url',
          fileName: 'selfie.jpg',
          file: selfieFile,
        ),
      ],
    );
  }

  static Future<void> registerDriver({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String age,
    required String? gender,
    required RegistrationImageSelection nbiFile,
    required RegistrationImageSelection licenseFile,
    required RegistrationImageSelection selfieFile,
  }) async {
    if (SignupValidators.isReservedAdminName(firstName)) {
      throw ArgumentError('The name admin is reserved.');
    }

    final parsedAge = int.tryParse(age.trim());
    final profileData = <String, dynamic>{
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'role': 'driver',
      'is_verified': false,
      'is_active': false,
      'is_banned': false,
      'is_deactivated': false,
      'account_status': 'active',
    };

    if (parsedAge != null) {
      profileData['age'] = parsedAge;
    }

    if (gender != null) {
      profileData['gender'] = gender;
    }

    await _registerUser(
      email: email,
      password: password,
      profileData: profileData,
      uploads: <_UploadPayload>[
        _UploadPayload(
          fieldName: 'nbi_clearance_url',
          fileName: 'nbi_clearance.jpg',
          file: nbiFile,
        ),
        _UploadPayload(
          fieldName: 'drivers_license_url',
          fileName: 'drivers_license.jpg',
          file: licenseFile,
        ),
        _UploadPayload(
          fieldName: 'selfie_url',
          fileName: 'selfie.jpg',
          file: selfieFile,
        ),
      ],
    );
  }

  static Future<void> _registerUser({
    required String email,
    required String password,
    required Map<String, dynamic> profileData,
    required List<_UploadPayload> uploads,
  }) async {
    UserCredential? credential;
    final uploadedRefs = <Reference>[];
    var profileCreated = false;

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;
      final writeData = <String, dynamic>{
        'user_id': uid,
        'email': email.trim(),
        'email_verified': false,
        'created_at': FieldValue.serverTimestamp(),
        ...profileData,
      };

      await _firestore.collection('users').doc(uid).set(writeData);
      profileCreated = true;

      final uploadedUrls = <String, dynamic>{};
      try {
        for (final upload in uploads) {
          final ref = _storage.ref('users/$uid/${upload.fileName}');
          await ref.putData(
            upload.file.bytes,
            SettableMetadata(
              contentType: upload.file.contentType,
              customMetadata: <String, String>{
                'owner_id': uid,
                'field_name': upload.fieldName,
                'kind': 'registration_document',
              },
            ),
          );
          uploadedRefs.add(ref);
          uploadedUrls[upload.fieldName] = await ref.getDownloadURL();
        }
      } on FirebaseException catch (e) {
        await _deleteUploadedRefs(uploadedRefs);
        try {
          await _firestore.collection('users').doc(uid).update({
            'document_upload_status': 'failed',
            'document_upload_error': e.message ?? e.code,
          });
        } catch (_) {
          // Preserve the upload error shown to the user.
        }
        await _sendEmailVerificationIfPossible(credential.user);
        throw RegistrationDocumentUploadException(e.message ?? e.code);
      }

      try {
        await _firestore.collection('users').doc(uid).update({
          ...uploadedUrls,
          'document_upload_status': 'uploaded',
          'document_upload_error': FieldValue.delete(),
        });
      } on FirebaseException catch (e) {
        try {
          await _firestore.collection('users').doc(uid).update({
            'document_upload_status': 'uploaded',
            'document_upload_error': e.message ?? e.code,
          });
        } catch (_) {
          // Preserve the profile update error shown to the user.
        }
        await _sendEmailVerificationIfPossible(credential.user);
        throw RegistrationDocumentUploadException(e.message ?? e.code);
      }

      await _sendEmailVerificationIfPossible(credential.user);
    } catch (_) {
      if (!profileCreated) {
        await _deleteUploadedRefs(uploadedRefs);
      }

      if (!profileCreated && credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {
          // Ignore rollback failures and preserve the original error.
        }
      }

      rethrow;
    }
  }

  static Future<void> _sendEmailVerificationIfPossible(User? user) async {
    try {
      await user?.sendEmailVerification();
    } catch (_) {
      // Account creation should still succeed if the verification email fails.
    }
  }

  static Future<void> _deleteUploadedRefs(List<Reference> uploadedRefs) async {
    for (final ref in uploadedRefs) {
      try {
        await ref.delete();
      } catch (_) {
        // Ignore storage cleanup failures and preserve the original error.
      }
    }
  }
}

class _UploadPayload {
  final String fieldName;
  final String fileName;
  final RegistrationImageSelection file;

  const _UploadPayload({
    required this.fieldName,
    required this.fileName,
    required this.file,
  });
}

class RegistrationImageSelection {
  final XFile file;
  final Uint8List bytes;
  final String contentType;

  const RegistrationImageSelection({
    required this.file,
    required this.bytes,
    required this.contentType,
  });

  static Future<RegistrationImageSelection> fromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const RegistrationImageSelectionException(
        'Selected image could not be read.',
      );
    }

    if (bytes.lengthInBytes >= RegistrationService.maxDocumentImageBytes) {
      throw const RegistrationImageSelectionException(
        'Verification images must be smaller than 10 MB.',
      );
    }

    final contentType = _contentTypeFor(file);
    if (!contentType.startsWith('image/')) {
      throw const RegistrationImageSelectionException(
        'Please choose a valid image file.',
      );
    }

    return RegistrationImageSelection(
      file: file,
      bytes: bytes,
      contentType: contentType,
    );
  }

  static String _contentTypeFor(XFile file) {
    final mimeType = file.mimeType?.trim().toLowerCase();
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType;
    }

    final extension = _fileExtension(file.name);
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
  }

  static String _fileExtension(String fileName) {
    final parts = fileName.trim().toLowerCase().split('.');
    if (parts.length < 2) {
      return '';
    }

    return parts.last;
  }
}

class RegistrationImageSelectionException implements Exception {
  final String message;

  const RegistrationImageSelectionException(this.message);

  @override
  String toString() {
    return message;
  }
}

class RegistrationDocumentUploadException implements Exception {
  final String message;

  const RegistrationDocumentUploadException(this.message);

  @override
  String toString() {
    return message;
  }
}
