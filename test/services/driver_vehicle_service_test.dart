import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/services/driver_vehicle_service.dart';

void main() {
  group('DriverVehicleService', () {
    test('lets an existing driver complete vehicle details', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('driver-1').set(<String, dynamic>{
        'user_id': 'driver-1',
        'role': 'driver',
        'is_verified': true,
        'isVerified': true,
        'is_active': true,
        'isActive': true,
        'tricycle_front_url': 'https://example.com/front.jpg',
        'tricycle_back_url': 'https://example.com/back.jpg',
      });
      final service = DriverVehicleService(firestore: firestore);

      await service.saveVehicleDetails(
        driverId: 'driver-1',
        vehicleType: ' Traditional Tricycle ',
        tricycleColor: ' Blue ',
        plateNumber: ' BUENA-101 ',
        existingFrontUrl: 'https://example.com/front.jpg',
        existingBackUrl: 'https://example.com/back.jpg',
      );

      final data = (await firestore.collection('users').doc('driver-1').get())
          .data()!;
      final pendingReview = Map<String, dynamic>.from(
        data['pending_document_review'] as Map,
      );
      expect(pendingReview['kind'], 'driver_vehicle');
      expect(pendingReview['vehicle_type'], 'Traditional Tricycle');
      expect(pendingReview['tricycle_color'], 'Blue');
      expect(pendingReview['plate_number'], 'BUENA-101');
      expect(
        pendingReview['tricycle_front_url'],
        'https://example.com/front.jpg',
      );
      expect(
        pendingReview['tricycle_back_url'],
        'https://example.com/back.jpg',
      );
      expect(data['document_review_status'], 'pending');
      expect(data['vehicle_details_updated_at'], isNotNull);
      expect(data['updated_at'], isNotNull);
      expect(data['is_verified'], isTrue);
      expect(data['isVerified'], isTrue);
      expect(data['is_active'], isTrue);
      expect(data['isActive'], isTrue);
      expect(data.containsKey('isVerrified'), isFalse);
    });

    test('requires both an existing or newly selected vehicle photo', () async {
      final firestore = FakeFirebaseFirestore();
      final service = DriverVehicleService(firestore: firestore);

      expect(
        () => service.saveVehicleDetails(
          driverId: 'driver-1',
          vehicleType: 'Traditional Tricycle',
          tricycleColor: 'Blue',
          plateNumber: 'BUENA-101',
          existingFrontUrl: null,
          existingBackUrl: 'https://example.com/back.jpg',
        ),
        throwsA(
          isA<DriverVehicleUpdateException>().having(
            (error) => error.message,
            'message',
            'Choose a clear front tricycle photo.',
          ),
        ),
      );
    });

    test(
      'attaches vehicle details directly for an unverified driver',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore
            .collection('users')
            .doc('driver-1')
            .set(<String, dynamic>{
              'role': 'driver',
              'is_verified': false,
              'is_active': false,
              'tricycle_front_url': 'https://example.com/front.jpg',
              'tricycle_back_url': 'https://example.com/back.jpg',
            });
        final service = DriverVehicleService(firestore: firestore);

        await service.saveVehicleDetails(
          driverId: 'driver-1',
          vehicleType: 'Traditional Tricycle',
          tricycleColor: 'Blue',
          plateNumber: 'BUENA-101',
          existingFrontUrl: 'https://example.com/front.jpg',
          existingBackUrl: 'https://example.com/back.jpg',
        );

        final data = (await firestore.collection('users').doc('driver-1').get())
            .data()!;
        expect(data['vehicle_type'], 'Traditional Tricycle');
        expect(data['tricycle_color'], 'Blue');
        expect(data['plate_number'], 'BUENA-101');
        expect(data['document_upload_status'], 'uploaded');
        expect(data.containsKey('pending_document_review'), isFalse);
        expect(data['is_verified'], isFalse);
        expect(data['is_active'], isFalse);
      },
    );
  });
}
