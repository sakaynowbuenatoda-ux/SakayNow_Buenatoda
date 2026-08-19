import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DriverRegistrationRecoveryService {
  DriverRegistrationRecoveryService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Future<String> Function(String path)? downloadUrlForPath,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage,
       _downloadUrlForPath = downloadUrlForPath;

  final FirebaseFirestore _firestore;
  final FirebaseStorage? _storage;
  final Future<String> Function(String path)? _downloadUrlForPath;

  static const Map<String, String> _registrationFiles = <String, String>{
    'nbi_clearance_url': 'nbi_clearance.jpg',
    'drivers_license_url': 'drivers_license.jpg',
    'selfie_url': 'selfie.jpg',
    'or_cr_url': 'or_cr.jpg',
    'tricycle_front_url': 'tricycle_front.jpg',
    'tricycle_back_url': 'tricycle_back.jpg',
  };

  Future<bool> recoverIfPossible(String driverId) async {
    final normalizedDriverId = driverId.trim();
    if (normalizedDriverId.isEmpty) return false;

    final userRef = _firestore.collection('users').doc(normalizedDriverId);
    final snapshot = await userRef.get();
    final data = snapshot.data();
    if (data == null || data['role'] != 'driver' || _isVerified(data)) {
      return false;
    }

    if (_hasValue(data['drivers_license_url']) ||
        _hasValue(data['or_cr_url'])) {
      return false;
    }

    final recoveredUrls = <String, dynamic>{};
    try {
      for (final entry in _registrationFiles.entries) {
        recoveredUrls[entry.key] = await _downloadUrl(
          'users/$normalizedDriverId/${entry.value}',
        );
      }
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') return false;
      rethrow;
    }

    await userRef.update(<String, dynamic>{
      ...recoveredUrls,
      'document_upload_status': 'uploaded',
      'document_upload_error': FieldValue.delete(),
    });
    return true;
  }

  Future<String> _downloadUrl(String path) {
    final callback = _downloadUrlForPath;
    if (callback != null) return callback(path);
    return (_storage ?? FirebaseStorage.instance).ref(path).getDownloadURL();
  }

  static bool _isVerified(Map<String, dynamic> data) {
    return data['is_verified'] == true ||
        data['isVerified'] == true ||
        data['isVerrified'] == true;
  }

  static bool _hasValue(Object? value) {
    return value?.toString().trim().isNotEmpty == true;
  }
}
