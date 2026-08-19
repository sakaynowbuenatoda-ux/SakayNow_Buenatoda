import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/services/driver_registration_recovery_service.dart';

void main() {
  test('reattaches a complete orphaned registration upload', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('driver-1').set(<String, dynamic>{
      'role': 'driver',
      'is_verified': false,
      'is_active': false,
    });
    final requestedPaths = <String>[];
    final service = DriverRegistrationRecoveryService(
      firestore: firestore,
      downloadUrlForPath: (path) async {
        requestedPaths.add(path);
        return 'https://example.com/$path';
      },
    );

    final recovered = await service.recoverIfPossible('driver-1');

    expect(recovered, isTrue);
    expect(requestedPaths, hasLength(6));
    final data = (await firestore.collection('users').doc('driver-1').get())
        .data()!;
    expect(data['document_upload_status'], 'uploaded');
    expect(data['nbi_clearance_url'], contains('nbi_clearance.jpg'));
    expect(data['drivers_license_url'], contains('drivers_license.jpg'));
    expect(data['selfie_url'], contains('selfie.jpg'));
    expect(data['or_cr_url'], contains('or_cr.jpg'));
    expect(data['tricycle_front_url'], contains('tricycle_front.jpg'));
    expect(data['tricycle_back_url'], contains('tricycle_back.jpg'));
    expect(data['is_verified'], isFalse);
    expect(data['is_active'], isFalse);
  });

  test('does not alter a verified driver', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('driver-1').set(<String, dynamic>{
      'role': 'driver',
      'is_verified': true,
      'is_active': true,
    });
    final service = DriverRegistrationRecoveryService(
      firestore: firestore,
      downloadUrlForPath: (_) async => throw StateError('must not download'),
    );

    expect(await service.recoverIfPossible('driver-1'), isFalse);
  });
}
