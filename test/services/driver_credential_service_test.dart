import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/services/driver_credential_service.dart';

void main() {
  group('DriverCredentialService', () {
    test('stages expiry updates without changing verified access', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('driver-1').set(<String, dynamic>{
        'user_id': 'driver-1',
        'role': 'driver',
        'is_verified': false,
        'isVerified': true,
        'is_active': true,
        'drivers_license_url': 'https://example.com/approved-license.jpg',
        'drivers_license_path': 'users/driver-1/drivers_license.jpg',
      });
      final service = DriverCredentialService(firestore: firestore);

      await service.saveCredential(
        driverId: 'driver-1',
        type: DriverCredentialType.driversLicense,
        expiry: DateTime.now().add(const Duration(days: 30)),
      );

      final data = (await firestore.collection('users').doc('driver-1').get())
          .data()!;
      final pendingReview = Map<String, dynamic>.from(
        data['pending_document_review'] as Map,
      );
      expect(pendingReview['kind'], 'driver_credential');
      expect(pendingReview['credential_type'], 'drivers_license');
      expect(
        pendingReview['document_url'],
        'https://example.com/approved-license.jpg',
      );
      expect(pendingReview.containsKey('document_path'), isFalse);
      expect(data['drivers_license_url'], contains('approved-license'));
      expect(data['document_review_status'], 'pending');
      expect(data['is_verified'], isTrue);
      expect(data['isVerified'], isTrue);
      expect(data['is_active'], isTrue);
    });

    test('does not overwrite another pending document review', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('driver-1').set(<String, dynamic>{
        'role': 'driver',
        'is_verified': true,
        'is_active': true,
        'document_review_status': 'pending',
        'drivers_license_url': 'https://example.com/approved-license.jpg',
      });
      final service = DriverCredentialService(firestore: firestore);

      expect(
        () => service.saveCredential(
          driverId: 'driver-1',
          type: DriverCredentialType.driversLicense,
          expiry: DateTime.now().add(const Duration(days: 30)),
        ),
        throwsA(
          isA<DriverCredentialUpdateException>().having(
            (error) => error.message,
            'message',
            contains('already waiting for admin review'),
          ),
        ),
      );
    });

    test(
      'attaches missing credentials directly for an unverified driver',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore
            .collection('users')
            .doc('driver-1')
            .set(<String, dynamic>{
              'role': 'driver',
              'is_verified': false,
              'is_active': false,
              'drivers_license_url': 'https://example.com/approved-license.jpg',
            });
        final service = DriverCredentialService(firestore: firestore);

        await service.saveCredential(
          driverId: 'driver-1',
          type: DriverCredentialType.driversLicense,
          expiry: DateTime.now().add(const Duration(days: 30)),
        );

        final data = (await firestore.collection('users').doc('driver-1').get())
            .data()!;
        expect(data['drivers_license_url'], contains('approved-license'));
        expect(data['drivers_license_expiry'], isNotNull);
        expect(data['document_upload_status'], 'uploaded');
        expect(data.containsKey('pending_document_review'), isFalse);
        expect(data['is_verified'], isFalse);
        expect(data['is_active'], isFalse);
      },
    );
  });
}
