import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/auth/registration_service.dart';

class DriverVehicleService {
  DriverVehicleService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage? _storage;

  Future<void> saveVehicleDetails({
    required String driverId,
    required String vehicleType,
    required String tricycleColor,
    required String plateNumber,
    required String? existingFrontUrl,
    required String? existingBackUrl,
    RegistrationImageSelection? frontPhoto,
    RegistrationImageSelection? backPhoto,
  }) async {
    final normalizedDriverId = driverId.trim();
    final normalizedVehicleType = vehicleType.trim();
    final normalizedColor = tricycleColor.trim();
    final normalizedPlateNumber = plateNumber.trim();

    if (normalizedDriverId.isEmpty) {
      throw const DriverVehicleUpdateException(
        'Unable to identify the driver account.',
      );
    }
    if (normalizedVehicleType.isEmpty ||
        normalizedColor.isEmpty ||
        normalizedPlateNumber.isEmpty) {
      throw const DriverVehicleUpdateException(
        'Complete all vehicle details before saving.',
      );
    }
    if (normalizedVehicleType.length > 80 ||
        normalizedColor.length > 50 ||
        normalizedPlateNumber.length > 50) {
      throw const DriverVehicleUpdateException(
        'One or more vehicle details are too long.',
      );
    }
    if (frontPhoto == null && !_hasValue(existingFrontUrl)) {
      throw const DriverVehicleUpdateException(
        'Choose a clear front tricycle photo.',
      );
    }
    if (backPhoto == null && !_hasValue(existingBackUrl)) {
      throw const DriverVehicleUpdateException(
        'Choose a clear back tricycle photo.',
      );
    }

    final uploadedRefs = <Reference>[];
    final now = DateTime.now();

    try {
      final updates = <String, dynamic>{
        'vehicle_type': normalizedVehicleType,
        'tricycle_color': normalizedColor,
        'plate_number': normalizedPlateNumber,
        'vehicle_details_updated_at': FieldValue.serverTimestamp(),
        'is_verified': false,
        'isVerified': false,
        'isVerrified': false,
        'is_active': false,
        'isActive': false,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (frontPhoto != null) {
        await _uploadPhoto(
          driverId: normalizedDriverId,
          fieldName: 'tricycle_front',
          photo: frontPhoto,
          timestamp: now.millisecondsSinceEpoch,
          updates: updates,
          uploadedRefs: uploadedRefs,
        );
      }
      if (backPhoto != null) {
        await _uploadPhoto(
          driverId: normalizedDriverId,
          fieldName: 'tricycle_back',
          photo: backPhoto,
          timestamp: now.millisecondsSinceEpoch,
          updates: updates,
          uploadedRefs: uploadedRefs,
        );
      }

      await _firestore
          .collection('users')
          .doc(normalizedDriverId)
          .update(updates);
    } catch (error) {
      for (final ref in uploadedRefs) {
        try {
          await ref.delete();
        } catch (_) {
          // Preserve the original upload or profile update error.
        }
      }
      if (error is DriverVehicleUpdateException) rethrow;
      throw DriverVehicleUpdateException(
        'Unable to save vehicle details. Please try again.',
        cause: error,
      );
    }
  }

  Future<void> _uploadPhoto({
    required String driverId,
    required String fieldName,
    required RegistrationImageSelection photo,
    required int timestamp,
    required Map<String, dynamic> updates,
    required List<Reference> uploadedRefs,
  }) async {
    final suffix = _fileExtension(photo.file.name);
    final path =
        'users/$driverId/vehicle_photos/${fieldName}_$timestamp.$suffix';
    final ref = (_storage ?? FirebaseStorage.instance).ref(path);
    await ref.putData(
      photo.bytes,
      SettableMetadata(
        contentType: photo.contentType,
        customMetadata: <String, String>{
          'owner_id': driverId,
          'field_name': '${fieldName}_url',
          'kind': 'driver_vehicle_photo',
        },
      ),
    );
    uploadedRefs.add(ref);
    updates['${fieldName}_url'] = await ref.getDownloadURL();
    updates['${fieldName}_path'] = path;
  }

  static bool _hasValue(String? value) => value?.trim().isNotEmpty == true;

  static String _fileExtension(String fileName) {
    final parts = fileName.trim().toLowerCase().split('.');
    final value = parts.length > 1 ? parts.last : 'jpg';
    return switch (value) {
      'png' || 'webp' || 'gif' || 'heic' || 'heif' => value,
      _ => 'jpg',
    };
  }
}

class DriverVehicleUpdateException implements Exception {
  final String message;
  final Object? cause;

  const DriverVehicleUpdateException(this.message, {this.cause});

  @override
  String toString() => message;
}
