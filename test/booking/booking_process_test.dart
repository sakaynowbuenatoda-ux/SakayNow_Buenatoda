import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sakaynow_buenatoda/models/ride_location.dart';
import 'package:sakaynow_buenatoda/models/ride_status.dart';
import 'package:sakaynow_buenatoda/models/route_result.dart';
import 'package:sakaynow_buenatoda/services/ride_tracking_service.dart';

void main() {
  group('RideTrackingService booking process', () {
    late FakeFirebaseFirestore firestore;
    late RideTrackingService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = RideTrackingService(firestore: firestore);
    });

    test(
      'creates a searching booking with passenger fare profile data',
      () async {
        const passengerId = 'passenger-1';
        await firestore
            .collection('users')
            .doc(passengerId)
            .set(<String, dynamic>{
              'user_id': passengerId,
              'first_name': 'Ana',
              'last_name': 'Reyes',
              'role': 'passenger',
              'passenger_type': 'student',
              'is_verified': true,
              'is_banned': false,
            });

        final bookingId = await service.createBooking(
          passengerId: passengerId,
          pickupLocation: const RideLocation(
            address: 'Poblacion, Buenavista, Bohol',
            latitude: 10.083,
            longitude: 124.178,
          ),
          dropoffLocation: const RideLocation(
            address: 'Poblacion, Buenavista, Bohol',
            latitude: 10.084,
            longitude: 124.179,
          ),
          route: const RouteResult(
            encodedPolyline: '',
            polylinePoints: <LatLng>[],
            distanceMeters: 1200,
            durationSeconds: 360,
            distanceText: '1.2 km',
            durationText: '6 mins',
          ),
        );

        final snapshot = await firestore
            .collection('bookings')
            .doc(bookingId)
            .get();
        final data = snapshot.data()!;

        expect(data['booking_id'], bookingId);
        expect(data['passenger_id'], passengerId);
        expect(data['driver_id'], isNull);
        expect(data['passenger_type'], 'student');
        expect(data['passenger_is_verified'], true);
        expect(data['status'], RideStatus.searching.firestoreValue);
        expect(data['payment_method'], 'cash');
        expect(data['payment_provider'], 'cash');
        expect(data['payment_status'], 'cash_pending');
        expect(data['pickup_location'], isA<Map>());
        expect(data['dropoff_location'], isA<Map>());
        expect(data['route'], isA<Map>());
        expect(data['fare_discount_applied'], true);
      },
    );

    test(
      'accepting a booking assigns the driver and removes availability',
      () async {
        const passengerId = 'passenger-1';
        const driverId = 'driver-1';
        final bookingRef = firestore.collection('bookings').doc('booking-1');

        await firestore.collection('users').doc(passengerId).set(
          <String, dynamic>{
            'user_id': passengerId,
            'role': 'passenger',
            'is_verified': true,
          },
        );
        await firestore.collection('users').doc(driverId).set(<String, dynamic>{
          'user_id': driverId,
          'role': 'driver',
          'is_verified': true,
          'is_active': true,
          'is_banned': false,
          'account_status': 'active',
        });
        await firestore
            .collection('driver_locations')
            .doc(driverId)
            .set(<String, dynamic>{
              'driver_id': driverId,
              'latitude': 10.083,
              'longitude': 124.178,
              'geopoint': const GeoPoint(10.083, 124.178),
              'is_available': true,
              'active_booking_id': null,
              'updated_at': Timestamp.now(),
            });
        await bookingRef.set(<String, dynamic>{
          'booking_id': bookingRef.id,
          'passenger_id': passengerId,
          'driver_id': null,
          'preferred_driver_id': null,
          'status': RideStatus.searching.firestoreValue,
          'pickup_location': const RideLocation(
            address: 'Pickup',
          ).toFirestore(),
          'dropoff_location': const RideLocation(
            address: 'Dropoff',
          ).toFirestore(),
          'payment_provider': 'cash',
          'payment_status': 'cash_pending',
          'created_at': Timestamp.now(),
          'updated_at': Timestamp.now(),
        });

        await service.acceptBooking(
          bookingId: bookingRef.id,
          driverId: driverId,
        );

        final booking = (await bookingRef.get()).data()!;
        final location =
            (await firestore.collection('driver_locations').doc(driverId).get())
                .data()!;

        expect(booking['driver_id'], driverId);
        expect(booking['status'], RideStatus.accepted.firestoreValue);
        expect(booking['driver_location'], isA<Map>());
        expect(location['is_available'], false);
        expect(location['active_booking_id'], bookingRef.id);
      },
    );

    test('unverified drivers cannot go available', () async {
      const driverId = 'driver-1';
      await firestore.collection('users').doc(driverId).set(<String, dynamic>{
        'user_id': driverId,
        'role': 'driver',
        'is_verified': false,
        'is_active': false,
        'is_banned': false,
      });

      await expectLater(
        service.updateDriverAvailability(driverId: driverId, isAvailable: true),
        throwsA(isA<StateError>()),
      );
    });

    test('legacy capitalized driver roles can go available', () async {
      const driverId = 'driver-1';
      await firestore.collection('users').doc(driverId).set(<String, dynamic>{
        'user_id': driverId,
        'role': 'Driver',
        'is_verified': true,
        'is_active': true,
        'is_banned': false,
      });

      await service.updateDriverAvailability(
        driverId: driverId,
        isAvailable: true,
      );

      final location =
          (await firestore.collection('driver_locations').doc(driverId).get())
              .data()!;

      expect(location['driver_id'], driverId);
      expect(location['is_available'], true);
    });
  });
}
