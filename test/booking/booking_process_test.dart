import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sakaynow_buenatoda/models/passenger_payment_method.dart';
import 'package:sakaynow_buenatoda/models/fare_settings.dart';
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
        expect(data['payment_method_type'], 'cash');
        expect(data['payment_provider'], 'cash');
        expect(data['payment_status'], 'cash_pending');
        expect(data['xendit_invoice_id'], isNull);
        expect(data['xendit_checkout_url'], isNull);
        expect(data['checkout_url'], isNull);
        expect(data['pickup_location'], isA<Map>());
        expect(data['dropoff_location'], isA<Map>());
        expect(data['route'], isA<Map>());
        expect(data['fare_discount_applied'], true);
      },
    );

    test('creates Xendit checkout metadata for cashless bookings', () async {
      const passengerId = 'passenger-1';
      await firestore
          .collection('users')
          .doc(passengerId)
          .set(<String, dynamic>{
            'user_id': passengerId,
            'first_name': 'Ana',
            'last_name': 'Reyes',
            'role': 'passenger',
            'passenger_type': 'regular',
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
          address: 'Cambuhat, Buenavista, Bohol',
          latitude: 10.091,
          longitude: 124.194,
        ),
        route: const RouteResult(
          encodedPolyline: '',
          polylinePoints: <LatLng>[],
          distanceMeters: 2400,
          durationSeconds: 540,
          distanceText: '2.4 km',
          durationText: '9 mins',
        ),
        paymentMethod: const PassengerPaymentMethod(
          id: 'gcash-1',
          userId: passengerId,
          type: PassengerPaymentMethodType.gcash,
          label: 'GCash',
          accountName: 'Ana Reyes',
          accountReference: 'Xendit checkout',
          isDefault: true,
          createdAt: null,
          updatedAt: null,
        ),
      );

      final data = (await firestore.collection('bookings').doc(bookingId).get())
          .data()!;

      expect(data['payment_method'], 'gcash');
      expect(data['payment_method_id'], 'gcash-1');
      expect(data['payment_method_type'], 'GCASH');
      expect(data['payment_provider'], 'xendit');
      expect(data['payment_status'], 'checkout_pending');
      expect(data['xendit_invoice_id'], isNull);
      expect(data['xendit_checkout_url'], isNull);
      expect(data['checkout_url'], isNull);
    });

    test('changes unpaid bookings from cash to Xendit checkout', () async {
      const passengerId = 'passenger-1';
      await firestore.collection('users').doc(passengerId).set(
        <String, dynamic>{
          'user_id': passengerId,
          'role': 'passenger',
          'is_verified': true,
        },
      );

      final bookingId = await service.createBooking(
        passengerId: passengerId,
        pickupLocation: const RideLocation(address: 'Pickup'),
        dropoffLocation: const RideLocation(address: 'Dropoff'),
        route: const RouteResult(
          encodedPolyline: '',
          polylinePoints: <LatLng>[],
          distanceMeters: 1200,
          durationSeconds: 360,
          distanceText: '1.2 km',
          durationText: '6 mins',
        ),
      );

      await service.updateBookingPaymentMethod(
        bookingId: bookingId,
        passengerId: passengerId,
        paymentMethod: const PassengerPaymentMethod(
          id: 'card-1',
          userId: passengerId,
          type: PassengerPaymentMethodType.card,
          label: 'Bank Card',
          accountName: 'Ana Reyes',
          accountReference: 'Xendit checkout',
          isDefault: false,
          createdAt: null,
          updatedAt: null,
        ),
      );

      final booking =
          (await firestore.collection('bookings').doc(bookingId).get()).data()!;

      expect(booking['payment_method'], 'card');
      expect(booking['payment_method_label'], 'Bank Card');
      expect(booking['payment_method_id'], 'card-1');
      expect(booking['payment_method_type'], 'CREDIT_CARD');
      expect(booking['payment_provider'], 'xendit');
      expect(booking['payment_status'], 'checkout_pending');
      expect(booking['xendit_invoice_id'], isNull);
      expect(booking['checkout_url'], isNull);
    });

    test('changes unpaid Xendit bookings back to cash', () async {
      const passengerId = 'passenger-1';
      await firestore.collection('users').doc(passengerId).set(
        <String, dynamic>{
          'user_id': passengerId,
          'role': 'passenger',
          'is_verified': true,
        },
      );

      final bookingId = await service.createBooking(
        passengerId: passengerId,
        pickupLocation: const RideLocation(address: 'Pickup'),
        dropoffLocation: const RideLocation(address: 'Dropoff'),
        route: const RouteResult(
          encodedPolyline: '',
          polylinePoints: <LatLng>[],
          distanceMeters: 1200,
          durationSeconds: 360,
          distanceText: '1.2 km',
          durationText: '6 mins',
        ),
        paymentMethod: const PassengerPaymentMethod(
          id: 'gcash-1',
          userId: passengerId,
          type: PassengerPaymentMethodType.gcash,
          label: 'GCash',
          accountName: 'Ana Reyes',
          accountReference: 'Xendit checkout',
          isDefault: false,
          createdAt: null,
          updatedAt: null,
        ),
      );
      await firestore
          .collection('bookings')
          .doc(bookingId)
          .update(<String, dynamic>{
            'xendit_invoice_id': 'invoice-1',
            'xendit_checkout_url': 'https://checkout.test/invoice-1',
            'checkout_url': 'https://checkout.test/invoice-1',
            'xendit_invoice_status': 'PENDING',
          });

      await service.updateBookingPaymentMethod(
        bookingId: bookingId,
        passengerId: passengerId,
        paymentMethod: PassengerPaymentMethod.cash(userId: passengerId),
      );

      final booking =
          (await firestore.collection('bookings').doc(bookingId).get()).data()!;

      expect(booking['payment_method'], 'cash');
      expect(booking['payment_method_label'], 'Cash');
      expect(booking['payment_method_id'], isNull);
      expect(booking['payment_method_type'], 'cash');
      expect(booking['payment_provider'], 'cash');
      expect(booking['payment_status'], 'cash_pending');
      expect(booking['xendit_invoice_id'], isNull);
      expect(booking['xendit_checkout_url'], isNull);
      expect(booking['checkout_url'], isNull);
    });

    test(
      'adds preferred driver pickup surcharge when creating booking',
      () async {
        const passengerId = 'passenger-1';
        const driverId = 'driver-1';
        await firestore
            .collection('users')
            .doc(passengerId)
            .set(<String, dynamic>{
              'user_id': passengerId,
              'role': 'passenger',
              'passenger_type': 'regular',
              'is_verified': true,
            });
        await firestore
            .collection('driver_locations')
            .doc(driverId)
            .set(<String, dynamic>{
              'driver_id': driverId,
              'latitude': 10.113,
              'longitude': 124.178,
              'geopoint': const GeoPoint(10.113, 124.178),
              'is_available': true,
              'active_booking_id': null,
              'updated_at': Timestamp.now(),
            });

        final bookingId = await service.createBooking(
          passengerId: passengerId,
          preferredDriverId: driverId,
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

        final data =
            (await firestore.collection('bookings').doc(bookingId).get())
                .data()!;
        final fareDetails = data['fare_details'] as Map<String, dynamic>;

        expect(data['fare'], 30);
        expect(data['final_fare'], 30);
        expect(data['driver_pickup_surcharge'], 5);
        expect(data['driver_pickup_barangay_hop_estimate'], 2);
        expect(fareDetails['driver_pickup_surcharge'], 5);
      },
    );

    test(
      'accepting a booking keeps the driver active but marks them busy',
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
        expect(location['is_available'], true);
        expect(location['active_booking_id'], bookingRef.id);
      },
    );

    test(
      'accepting an open booking recalculates driver pickup surcharge',
      () async {
        const passengerId = 'passenger-1';
        const driverId = 'driver-1';
        final bookingRef = firestore.collection('bookings').doc('booking-1');

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
              'latitude': 10.113,
              'longitude': 124.178,
              'geopoint': const GeoPoint(10.113, 124.178),
              'is_available': true,
              'active_booking_id': null,
              'updated_at': Timestamp.now(),
            });
        await bookingRef.set(<String, dynamic>{
          'booking_id': bookingRef.id,
          'passenger_id': passengerId,
          'passenger_type': 'regular',
          'passenger_is_verified': true,
          'driver_id': null,
          'preferred_driver_id': null,
          'status': RideStatus.searching.firestoreValue,
          'pickup_location': const RideLocation(
            address: 'Poblacion, Buenavista, Bohol',
            latitude: 10.083,
            longitude: 124.178,
          ).toFirestore(),
          'dropoff_location': const RideLocation(
            address: 'Poblacion, Buenavista, Bohol',
            latitude: 10.084,
            longitude: 124.179,
          ).toFirestore(),
          'estimated_distance_meters': 1200,
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
        final fareDetails = booking['fare_details'] as Map<String, dynamic>;

        expect(booking['driver_id'], driverId);
        expect(booking['fare'], 30);
        expect(booking['final_fare'], 30);
        expect(booking['driver_pickup_surcharge'], 5);
        expect(fareDetails['driver_pickup_surcharge'], 5);
      },
    );

    test(
      'accepting a booking locks commission and earnings breakdown',
      () async {
        const passengerId = 'passenger-1';
        const driverId = 'driver-1';
        await firestore
            .collection('users')
            .doc(passengerId)
            .set(<String, dynamic>{
              'user_id': passengerId,
              'role': 'passenger',
              'passenger_type': 'regular',
              'is_verified': true,
            });
        await _seedVerifiedDriver(firestore, driverId);
        await _seedDriverLocation(
          firestore,
          driverId: driverId,
          isAvailable: true,
        );
        await firestore
            .collection('fare_settings')
            .doc('current')
            .set(
              FareSettings.defaults
                  .copyWith(commissionRate: 0.10)
                  .toFirestore(updatedBy: 'admin-1'),
            );

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

        await service.acceptBooking(bookingId: bookingId, driverId: driverId);

        final accepted =
            (await firestore.collection('bookings').doc(bookingId).get())
                .data()!;
        expect(accepted['gross_fare'], 25);
        expect(accepted['commission_rate'], 0.10);
        expect(accepted['commission_amount'], 3);
        expect(accepted['driver_net_earnings'], 22);
        expect(accepted['payment_method'], 'cash');
        expect(accepted['driver_payout_status'], 'cash_collection_pending');

        await service.updateRideStatus(
          bookingId: bookingId,
          status: RideStatus.completed,
          changedBy: driverId,
        );
        final completed =
            (await firestore.collection('bookings').doc(bookingId).get())
                .data()!;
        expect(completed['driver_payout_status'], 'cash_collected');
      },
    );

    test('completing a ride clears the driver busy marker', () async {
      const passengerId = 'passenger-1';
      const driverId = 'driver-1';
      const bookingId = 'booking-1';

      await _seedVerifiedDriver(firestore, driverId);
      await firestore
          .collection('driver_locations')
          .doc(driverId)
          .set(<String, dynamic>{
            'driver_id': driverId,
            'latitude': 10.083,
            'longitude': 124.178,
            'geopoint': const GeoPoint(10.083, 124.178),
            'is_available': true,
            'active_booking_id': bookingId,
            'updated_at': Timestamp.now(),
          });
      await firestore
          .collection('bookings')
          .doc(bookingId)
          .set(<String, dynamic>{
            'booking_id': bookingId,
            'passenger_id': passengerId,
            'driver_id': driverId,
            'status': RideStatus.inProgress.firestoreValue,
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

      await service.updateRideStatus(
        bookingId: bookingId,
        status: RideStatus.completed,
        changedBy: driverId,
      );

      final location =
          (await firestore.collection('driver_locations').doc(driverId).get())
              .data()!;

      expect(location['is_available'], true);
      expect(location['active_booking_id'], isNull);
    });

    test('completed cash bookings are marked cash collected', () async {
      const passengerId = 'passenger-1';
      await firestore.collection('users').doc(passengerId).set(
        <String, dynamic>{
          'user_id': passengerId,
          'role': 'passenger',
          'is_verified': true,
        },
      );

      final bookingId = await service.createBooking(
        passengerId: passengerId,
        pickupLocation: const RideLocation(address: 'Pickup'),
        dropoffLocation: const RideLocation(address: 'Dropoff'),
        route: const RouteResult(
          encodedPolyline: '',
          polylinePoints: <LatLng>[],
          distanceMeters: 1200,
          durationSeconds: 360,
          distanceText: '1.2 km',
          durationText: '6 mins',
        ),
      );

      await service.updateRideStatus(
        bookingId: bookingId,
        status: RideStatus.completed,
        changedBy: 'driver-1',
      );

      final booking =
          (await firestore.collection('bookings').doc(bookingId).get()).data()!;

      expect(booking['status'], RideStatus.completed.firestoreValue);
      expect(booking['payment_status'], 'cash_collected');
      expect(booking['payment_confirmed_by'], 'driver-1');
      expect(booking['payment_cancelled_by'], isNull);
    });

    test('cashless bookings cannot complete before checkout is paid', () async {
      const passengerId = 'passenger-1';
      await firestore.collection('users').doc(passengerId).set(
        <String, dynamic>{
          'user_id': passengerId,
          'role': 'passenger',
          'is_verified': true,
        },
      );

      final bookingId = await service.createBooking(
        passengerId: passengerId,
        pickupLocation: const RideLocation(address: 'Pickup'),
        dropoffLocation: const RideLocation(address: 'Dropoff'),
        route: const RouteResult(
          encodedPolyline: '',
          polylinePoints: <LatLng>[],
          distanceMeters: 1200,
          durationSeconds: 360,
          distanceText: '1.2 km',
          durationText: '6 mins',
        ),
        paymentMethod: const PassengerPaymentMethod(
          id: 'card-1',
          userId: passengerId,
          type: PassengerPaymentMethodType.card,
          label: 'Bank Card',
          accountName: 'Ana Reyes',
          accountReference: 'Xendit checkout',
          isDefault: false,
          createdAt: null,
          updatedAt: null,
        ),
      );

      await expectLater(
        service.updateRideStatus(
          bookingId: bookingId,
          status: RideStatus.completed,
          changedBy: 'driver-1',
        ),
        throwsA(isA<StateError>()),
      );

      final booking =
          (await firestore.collection('bookings').doc(bookingId).get()).data()!;

      expect(booking['status'], RideStatus.searching.firestoreValue);
      expect(booking['payment_status'], 'checkout_pending');
      expect(booking['payment_confirmed_by'], isNull);
    });

    test('paid cashless bookings can complete', () async {
      const passengerId = 'passenger-1';
      await firestore.collection('users').doc(passengerId).set(
        <String, dynamic>{
          'user_id': passengerId,
          'role': 'passenger',
          'is_verified': true,
        },
      );

      final bookingId = await service.createBooking(
        passengerId: passengerId,
        pickupLocation: const RideLocation(address: 'Pickup'),
        dropoffLocation: const RideLocation(address: 'Dropoff'),
        route: const RouteResult(
          encodedPolyline: '',
          polylinePoints: <LatLng>[],
          distanceMeters: 1200,
          durationSeconds: 360,
          distanceText: '1.2 km',
          durationText: '6 mins',
        ),
        paymentMethod: const PassengerPaymentMethod(
          id: 'gcash-1',
          userId: passengerId,
          type: PassengerPaymentMethodType.gcash,
          label: 'GCash',
          accountName: 'Ana Reyes',
          accountReference: 'Xendit checkout',
          isDefault: false,
          createdAt: null,
          updatedAt: null,
        ),
      );
      await firestore.collection('bookings').doc(bookingId).update(
        <String, dynamic>{'payment_status': 'paid'},
      );

      await service.updateRideStatus(
        bookingId: bookingId,
        status: RideStatus.completed,
        changedBy: 'driver-1',
      );

      final booking =
          (await firestore.collection('bookings').doc(bookingId).get()).data()!;

      expect(booking['status'], RideStatus.completed.firestoreValue);
      expect(booking['payment_status'], 'paid');
      expect(booking['payment_confirmed_by'], isNull);
    });

    test('cancelled cash bookings are not marked cash collected', () async {
      const passengerId = 'passenger-1';
      await firestore.collection('users').doc(passengerId).set(
        <String, dynamic>{
          'user_id': passengerId,
          'role': 'passenger',
          'is_verified': true,
        },
      );

      final bookingId = await service.createBooking(
        passengerId: passengerId,
        pickupLocation: const RideLocation(address: 'Pickup'),
        dropoffLocation: const RideLocation(address: 'Dropoff'),
        route: const RouteResult(
          encodedPolyline: '',
          polylinePoints: <LatLng>[],
          distanceMeters: 1200,
          durationSeconds: 360,
          distanceText: '1.2 km',
          durationText: '6 mins',
        ),
      );

      await service.updateRideStatus(
        bookingId: bookingId,
        status: RideStatus.cancelled,
        changedBy: passengerId,
      );

      final booking =
          (await firestore.collection('bookings').doc(bookingId).get()).data()!;

      expect(booking['status'], RideStatus.cancelled.firestoreValue);
      expect(booking['payment_status'], 'cash_cancelled');
      expect(booking['payment_cancelled_by'], passengerId);
      expect(booking['payment_confirmed_by'], isNull);
    });

    test(
      'driver availability cleanup clears busy marker after cancellation',
      () async {
        const passengerId = 'passenger-1';
        const driverId = 'driver-1';
        const bookingId = 'booking-1';

        await _seedVerifiedDriver(firestore, driverId);
        await firestore
            .collection('driver_locations')
            .doc(driverId)
            .set(<String, dynamic>{
              'driver_id': driverId,
              'latitude': 10.083,
              'longitude': 124.178,
              'geopoint': const GeoPoint(10.083, 124.178),
              'is_available': true,
              'active_booking_id': bookingId,
              'updated_at': Timestamp.now(),
            });
        await firestore
            .collection('bookings')
            .doc(bookingId)
            .set(<String, dynamic>{
              'booking_id': bookingId,
              'passenger_id': passengerId,
              'driver_id': driverId,
              'status': RideStatus.cancelled.firestoreValue,
              'cancelled_by': passengerId,
              'pickup_location': const RideLocation(
                address: 'Pickup',
              ).toFirestore(),
              'dropoff_location': const RideLocation(
                address: 'Dropoff',
              ).toFirestore(),
              'payment_provider': 'cash',
              'payment_status': 'cash_cancelled',
              'created_at': Timestamp.now(),
              'updated_at': Timestamp.now(),
            });

        await service.updateDriverAvailability(
          driverId: driverId,
          isAvailable: true,
        );

        final location =
            (await firestore.collection('driver_locations').doc(driverId).get())
                .data()!;

        expect(location['is_available'], true);
        expect(location['active_booking_id'], isNull);
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

    test(
      'lists active verified drivers from driver location records',
      () async {
        const driverId = 'driver-1';
        await firestore.collection('users').doc(driverId).set(<String, dynamic>{
          'user_id': driverId,
          'first_name': 'Ben',
          'last_name': 'Santos',
          'role': 'driver',
          'is_verified': true,
          'is_active': true,
          'is_banned': false,
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

        final drivers = await service.watchAvailableDrivers().first;

        expect(drivers, hasLength(1));
        expect(drivers.single.driverId, driverId);
        expect(drivers.single.fullName, 'Ben Santos');
        expect(drivers.single.isVerified, isTrue);
      },
    );

    test('hides busy active drivers from passenger discovery', () async {
      const driverId = 'driver-1';
      await firestore.collection('users').doc(driverId).set(<String, dynamic>{
        'user_id': driverId,
        'first_name': 'Ben',
        'last_name': 'Santos',
        'role': 'driver',
        'is_verified': true,
        'is_active': true,
        'is_banned': false,
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
            'active_booking_id': 'booking-1',
            'updated_at': Timestamp.now(),
          });

      final drivers = await service.watchAvailableDrivers().first;
      final activeStatus = await service
          .watchDriverActiveStatus(driverId)
          .first;
      final requestAvailability = await service
          .watchDriverAvailability(driverId)
          .first;

      expect(drivers, isEmpty);
      expect(activeStatus, isTrue);
      expect(requestAvailability, isFalse);
    });

    test('busy active drivers cannot accept another booking', () async {
      const passengerId = 'passenger-1';
      const driverId = 'driver-1';
      const bookingId = 'booking-1';

      await _seedVerifiedDriver(firestore, driverId);
      await firestore
          .collection('driver_locations')
          .doc(driverId)
          .set(<String, dynamic>{
            'driver_id': driverId,
            'latitude': 10.083,
            'longitude': 124.178,
            'geopoint': const GeoPoint(10.083, 124.178),
            'is_available': true,
            'active_booking_id': 'active-booking',
            'updated_at': Timestamp.now(),
          });
      await _seedOpenBooking(
        firestore,
        bookingId: bookingId,
        passengerId: passengerId,
      );

      await expectLater(
        service.acceptBooking(bookingId: bookingId, driverId: driverId),
        throwsA(isA<StateError>()),
      );

      final booking =
          (await firestore.collection('bookings').doc(bookingId).get()).data()!;

      expect(booking['driver_id'], isNull);
      expect(booking['status'], RideStatus.searching.firestoreValue);
    });

    test(
      'open booking stream rechecks requests when driver goes available',
      () async {
        const passengerId = 'passenger-1';
        const driverId = 'driver-1';

        await _seedVerifiedDriver(firestore, driverId);
        await _seedDriverLocation(
          firestore,
          driverId: driverId,
          isAvailable: false,
        );
        await _seedOpenBooking(
          firestore,
          bookingId: 'booking-1',
          passengerId: passengerId,
        );

        final emissions = <List<String>>[];
        final StreamSubscription<List<String>> subscription = service
            .watchOpenBookings(driverId: driverId)
            .map(
              (rides) =>
                  rides.map((ride) => ride.bookingId).toList(growable: false),
            )
            .listen(emissions.add);
        addTearDown(subscription.cancel);

        await pumpEventQueue(times: 4);
        expect(emissions, isNotEmpty);
        expect(emissions.last, isEmpty);

        await service.updateDriverAvailability(
          driverId: driverId,
          isAvailable: true,
        );

        await pumpEventQueue(times: 8);
        expect(emissions.last, <String>['booking-1']);
      },
    );

    test(
      'queue mode includes declined requests while home mode hides them',
      () async {
        const passengerId = 'passenger-1';
        const driverId = 'driver-1';

        await _seedVerifiedDriver(firestore, driverId);
        await _seedDriverLocation(
          firestore,
          driverId: driverId,
          isAvailable: true,
        );
        await _seedOpenBooking(
          firestore,
          bookingId: 'booking-1',
          passengerId: passengerId,
          declinedDriverIds: <String>[driverId],
        );

        final actionableRequests = await service
            .watchOpenBookings(driverId: driverId)
            .first;
        final queueRequests = await service
            .watchOpenBookings(driverId: driverId, includeDeclined: true)
            .first;

        expect(actionableRequests, isEmpty);
        expect(queueRequests, hasLength(1));
        expect(queueRequests.single.bookingId, 'booking-1');
      },
    );

    test('queue can accept a previously declined open request', () async {
      const passengerId = 'passenger-1';
      const driverId = 'driver-1';
      const bookingId = 'booking-1';

      await _seedVerifiedDriver(firestore, driverId);
      await _seedDriverLocation(
        firestore,
        driverId: driverId,
        isAvailable: true,
      );
      await _seedOpenBooking(
        firestore,
        bookingId: bookingId,
        passengerId: passengerId,
        declinedDriverIds: <String>[driverId],
      );

      await expectLater(
        service.acceptBooking(bookingId: bookingId, driverId: driverId),
        throwsA(isA<StateError>()),
      );

      await service.acceptBooking(
        bookingId: bookingId,
        driverId: driverId,
        allowDeclined: true,
      );

      final booking =
          (await firestore.collection('bookings').doc(bookingId).get()).data()!;
      final declinedDriverIds = (booking['declined_driver_ids'] as List? ?? [])
          .map((id) => id.toString())
          .toList();

      expect(booking['driver_id'], driverId);
      expect(booking['status'], RideStatus.accepted.firestoreValue);
      expect(declinedDriverIds, isNot(contains(driverId)));
    });
  });
}

Future<void> _seedVerifiedDriver(
  FakeFirebaseFirestore firestore,
  String driverId,
) {
  return firestore.collection('users').doc(driverId).set(<String, dynamic>{
    'user_id': driverId,
    'role': 'driver',
    'is_verified': true,
    'is_active': true,
    'is_banned': false,
  });
}

Future<void> _seedDriverLocation(
  FakeFirebaseFirestore firestore, {
  required String driverId,
  required bool isAvailable,
}) {
  return firestore
      .collection('driver_locations')
      .doc(driverId)
      .set(<String, dynamic>{
        'driver_id': driverId,
        'latitude': 10.083,
        'longitude': 124.178,
        'geopoint': const GeoPoint(10.083, 124.178),
        'is_available': isAvailable,
        'active_booking_id': null,
        'updated_at': Timestamp.now(),
      });
}

Future<void> _seedOpenBooking(
  FakeFirebaseFirestore firestore, {
  required String bookingId,
  required String passengerId,
  List<String> declinedDriverIds = const <String>[],
}) {
  return firestore.collection('bookings').doc(bookingId).set(<String, dynamic>{
    'booking_id': bookingId,
    'passenger_id': passengerId,
    'driver_id': null,
    'preferred_driver_id': null,
    'declined_driver_ids': declinedDriverIds,
    'status': RideStatus.searching.firestoreValue,
    'pickup_location': const RideLocation(address: 'Pickup').toFirestore(),
    'dropoff_location': const RideLocation(address: 'Dropoff').toFirestore(),
    'payment_provider': 'cash',
    'payment_status': 'cash_pending',
    'created_at': Timestamp.now(),
    'updated_at': Timestamp.now(),
  });
}
