import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fare_settings.dart';

class FareSettingsService {
  FareSettingsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String collectionPath = 'fare_settings';
  static const String currentDocumentId = 'current';

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _currentSettings =>
      _firestore.collection(collectionPath).doc(currentDocumentId);

  Stream<FareSettings> watchSettings() {
    return _currentSettings.snapshots().map(FareSettings.fromDocument);
  }

  Future<FareSettings> loadSettings() async {
    final snapshot = await _currentSettings.get();
    return FareSettings.fromDocument(snapshot);
  }

  Future<void> updateSettings({
    required FareSettings settings,
    required String adminId,
  }) {
    return _currentSettings.set(
      settings.toFirestore(updatedBy: adminId),
      SetOptions(merge: true),
    );
  }
}
