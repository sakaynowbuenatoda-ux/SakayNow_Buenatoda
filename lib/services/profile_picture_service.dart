import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePictureService {
  ProfilePictureService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _picker = picker ?? ImagePicker();

  static const Duration updateCooldown = Duration(days: 7);
  static const int maxImageBytes = 5 * 1024 * 1024;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  Future<ProfilePictureUploadResult?> pickAndUpload({
    required String userId,
    required ImageSource source,
  }) async {
    final selection = await pickProfilePicture(userId: userId, source: source);
    if (selection == null) {
      return null;
    }

    return uploadProfilePicture(userId: userId, selection: selection);
  }

  Future<ProfilePictureSelection?> pickProfilePicture({
    required String userId,
    required ImageSource source,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw const ProfilePictureUploadException('User account is missing.');
    }

    final userRef = _firestore.collection('users').doc(normalizedUserId);
    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data();
    if (!userSnapshot.exists || userData == null) {
      throw const ProfilePictureUploadException('User profile not found.');
    }

    _ensureWithinWeeklyLimit(userData);

    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (pickedFile == null) {
      return null;
    }

    final bytes = await pickedFile.readAsBytes();
    if (bytes.isEmpty) {
      throw const ProfilePictureUploadException(
        'Selected image could not be read.',
      );
    }

    if (bytes.lengthInBytes > maxImageBytes) {
      throw const ProfilePictureUploadException(
        'Profile picture must be 5 MB or smaller.',
      );
    }

    final contentType = _contentTypeFor(pickedFile);
    if (!contentType.startsWith('image/')) {
      throw const ProfilePictureUploadException(
        'Please choose a valid image file.',
      );
    }

    return ProfilePictureSelection(
      file: pickedFile,
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<ProfilePictureUploadResult> uploadProfilePicture({
    required String userId,
    required ProfilePictureSelection selection,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw const ProfilePictureUploadException('User account is missing.');
    }

    final userRef = _firestore.collection('users').doc(normalizedUserId);
    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data();
    if (!userSnapshot.exists || userData == null) {
      throw const ProfilePictureUploadException('User profile not found.');
    }

    _ensureWithinWeeklyLimit(userData);

    final extension = _extensionFor(selection.file, selection.contentType);
    final storagePath =
        'users/$normalizedUserId/profile_pictures/'
        'profile_picture_${DateTime.now().toUtc().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref(storagePath);
    var uploaded = false;

    try {
      await ref.putData(
        selection.bytes,
        SettableMetadata(
          contentType: selection.contentType,
          customMetadata: <String, String>{
            'owner_id': normalizedUserId,
            'kind': 'profile_picture',
          },
        ),
      );
      uploaded = true;

      final downloadUrl = await ref.getDownloadURL();
      await userRef.update(<String, dynamic>{
        'profile_picture_url': downloadUrl,
        'profile_picture_path': storagePath,
        'profile_picture_updated_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return ProfilePictureUploadResult(
        downloadUrl: downloadUrl,
        storagePath: storagePath,
      );
    } on FirebaseException catch (error) {
      if (uploaded) {
        await _deleteUploadedFile(ref);
      }

      if (error.code == 'permission-denied') {
        final nextAvailableAt = nextAvailableAtFrom(userData);
        if (nextAvailableAt != null) {
          throw ProfilePictureLimitException(nextAvailableAt);
        }
      }

      throw ProfilePictureUploadException(
        error.message ?? 'Unable to update profile picture.',
      );
    } catch (error) {
      if (uploaded) {
        await _deleteUploadedFile(ref);
      }

      throw ProfilePictureUploadException(
        'Unable to update profile picture: $error',
      );
    }
  }

  Future<DateTime?> nextAvailableAt(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    return nextAvailableAtFrom(snapshot.data() ?? <String, dynamic>{});
  }

  static DateTime? nextAvailableAtFrom(Map<String, dynamic> data) {
    final lastUpdated = _readDate(
      data['profile_picture_updated_at'] ?? data['profile_image_updated_at'],
    );
    return lastUpdated?.add(updateCooldown);
  }

  static bool canUpdateFrom(Map<String, dynamic> data, {DateTime? now}) {
    final nextAvailableAt = nextAvailableAtFrom(data);
    if (nextAvailableAt == null) {
      return true;
    }

    return !(now ?? DateTime.now()).isBefore(nextAvailableAt);
  }

  static void _ensureWithinWeeklyLimit(Map<String, dynamic> data) {
    final nextAvailableAt = nextAvailableAtFrom(data);
    if (nextAvailableAt == null) {
      return;
    }

    if (DateTime.now().isBefore(nextAvailableAt)) {
      throw ProfilePictureLimitException(nextAvailableAt);
    }
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
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

  static String _extensionFor(XFile file, String contentType) {
    final extension = _fileExtension(file.name);
    if (extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'webp' ||
        extension == 'gif' ||
        extension == 'heic' ||
        extension == 'heif') {
      return extension == 'jpeg' ? 'jpg' : extension;
    }

    return switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/heic' => 'heic',
      'image/heif' => 'heif',
      _ => 'jpg',
    };
  }

  static String _fileExtension(String fileName) {
    final parts = fileName.trim().toLowerCase().split('.');
    if (parts.length < 2) {
      return '';
    }

    return parts.last;
  }

  static Future<void> _deleteUploadedFile(Reference ref) async {
    try {
      await ref.delete();
    } catch (_) {
      // Keep the original upload/update error visible to the user.
    }
  }
}

class ProfilePictureSelection {
  final XFile file;
  final Uint8List bytes;
  final String contentType;

  const ProfilePictureSelection({
    required this.file,
    required this.bytes,
    required this.contentType,
  });
}

class ProfilePictureUploadResult {
  final String downloadUrl;
  final String storagePath;

  const ProfilePictureUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });
}

class ProfilePictureLimitException implements Exception {
  final DateTime nextAvailableAt;

  const ProfilePictureLimitException(this.nextAvailableAt);

  @override
  String toString() {
    return 'Profile picture can only be changed once per week.';
  }
}

class ProfilePictureUploadException implements Exception {
  final String message;

  const ProfilePictureUploadException(this.message);

  @override
  String toString() {
    return message;
  }
}
