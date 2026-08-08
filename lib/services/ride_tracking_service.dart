import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/distance_matrix_result.dart';
import '../models/driver_rating.dart';
import '../models/driver_document_status.dart';
import '../models/fare_estimate.dart';
import '../models/fare_settings.dart';
import '../models/passenger_payment_method.dart';
import '../models/ride.dart';
import '../models/ride_driver_location.dart';
import '../models/ride_earnings.dart';
import '../models/ride_location.dart';
import '../models/ride_status.dart';
import '../models/route_result.dart';
import 'fare_service.dart';
import 'fare_settings_service.dart';

class RideTrackingService {
  RideTrackingService({
    FirebaseFirestore? firestore,
    FareService? fareService,
    FareSettingsService? fareSettingsService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _fareService = fareService ?? const FareService(),
       _fareSettingsService =
           fareSettingsService ?? FareSettingsService(firestore: firestore);

  static const Duration driverAvailabilityTimeout = Duration(minutes: 15);
  static final List<String> _activeRideStatusValues = <String>[
    RideStatus.accepted.firestoreValue,
    RideStatus.driverArriving.firestoreValue,
    RideStatus.arrived.firestoreValue,
    RideStatus.inProgress.firestoreValue,
  ];

  final FirebaseFirestore _firestore;
  final FareService _fareService;
  final FareSettingsService _fareSettingsService;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _driverLocations =>
      _firestore.collection('driver_locations');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  Future<String> createBooking({
    required String passengerId,
    required RideLocation pickupLocation,
    required RideLocation dropoffLocation,
    required RouteResult route,
    DistanceMatrixResult? estimate,
    FareEstimate? fareEstimate,
    PassengerPaymentMethod? paymentMethod,
    String? preferredDriverId,
  }) async {
    final doc = _bookings.doc();
    final now = FieldValue.serverTimestamp();
    final selectedPaymentMethod =
        paymentMethod ?? PassengerPaymentMethod.cash(userId: passengerId);
    final paymentMethodType =
        selectedPaymentMethod.xenditPaymentMethodType ??
        selectedPaymentMethod.type.firestoreValue;
    final paymentStatus = selectedPaymentMethod.usesOnlineCheckout
        ? 'checkout_pending'
        : 'cash_pending';
    final passengerFareProfile = await loadPassengerFareProfile(passengerId);
    final fareSettings = await _fareSettingsService.loadSettings();
    final driverToPickupDistanceMeters = await _driverToPickupDistanceMetersFor(
      driverId: preferredDriverId,
      pickupLocation: pickupLocation,
    );
    final bookingFareEstimate = _fareService.estimateFare(
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      distanceMeters: estimate?.distanceMeters ?? route.distanceMeters,
      passengerType: passengerFareProfile.passengerType,
      passengerIsVerified: passengerFareProfile.isVerified,
      settings: fareSettings,
      driverToPickupDistanceMeters: driverToPickupDistanceMeters,
    );

    await doc.set(<String, dynamic>{
      'booking_id': doc.id,
      'passenger_id': passengerId,
      'passenger_type': passengerFareProfile.passengerType,
      'passenger_is_verified': passengerFareProfile.isVerified,
      'driver_id': null,
      'preferred_driver_id': preferredDriverId,
      'status': RideStatus.searching.firestoreValue,
      'pickup_location': pickupLocation.toFirestore(),
      'dropoff_location': dropoffLocation.toFirestore(),
      'route': route.toFirestore(),
      'estimated_distance_meters':
          estimate?.distanceMeters ?? route.distanceMeters,
      'estimated_duration_seconds':
          estimate?.durationSeconds ?? route.durationSeconds,
      'estimated_distance_text': estimate?.distanceText ?? route.distanceText,
      'estimated_duration_text': estimate?.durationText ?? route.durationText,
      ..._bookingFareFields(
        fareEstimate: bookingFareEstimate,
        fareSettings: fareSettings,
      ),
      'payment_method': selectedPaymentMethod.type.firestoreValue,
      'payment_method_label': selectedPaymentMethod.displayLabel,
      'payment_method_id': selectedPaymentMethod.isCash
          ? null
          : selectedPaymentMethod.id,
      'payment_method_type': paymentMethodType,
      'payment_provider': selectedPaymentMethod.provider,
      'payment_status': paymentStatus,
      'xendit_invoice_id': null,
      'xendit_checkout_url': null,
      'checkout_url': null,
      'timestamp': now,
      'created_at': now,
      'updated_at': now,
      'status_history': <Map<String, dynamic>>[
        <String, dynamic>{
          'status': RideStatus.searching.firestoreValue,
          'changed_by': passengerId,
          'changed_at': Timestamp.now(),
        },
      ],
    });

    return doc.id;
  }

  Future<void> updateBookingPaymentMethod({
    required String bookingId,
    required String passengerId,
    required PassengerPaymentMethod paymentMethod,
  }) async {
    final bookingRef = _bookings.doc(bookingId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(bookingRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      if (!snapshot.exists) {
        throw StateError('Booking was not found.');
      }

      if (_readNullableString(data['passenger_id']) != passengerId) {
        throw StateError('Only the passenger can change this payment method.');
      }

      final status = rideStatusFromString(data['status']);
      if (status.isTerminal) {
        throw StateError('Payment method can no longer be changed.');
      }

      final paymentStatus = (data['payment_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (_isPaymentSettled(paymentStatus)) {
        throw StateError('Payment is already completed.');
      }

      final updates = _paymentMethodUpdateFields(paymentMethod);
      final driverId = _readNullableString(data['driver_id']);
      if (paymentMethod.usesOnlineCheckout && driverId != null) {
        final driverSnapshot = await transaction.get(_users.doc(driverId));
        final driverData = driverSnapshot.data() ?? <String, dynamic>{};
        if (driverData['accepts_online_payments'] != true) {
          throw StateError('This driver cannot accept cashless payments.');
        }

        updates.addAll(<String, dynamic>{
          'driver_payout_status': 'awaiting_payment',
          'driver_payout_account_id': driverData['default_payout_account_id'],
          'driver_accepts_online_payments': true,
        });
      } else if (!paymentMethod.usesOnlineCheckout) {
        updates.addAll(<String, dynamic>{
          'driver_payout_status': 'cash_collection_pending',
          'driver_payout_account_id': null,
          'driver_accepts_online_payments': null,
        });
      }

      transaction.update(bookingRef, updates);
    });
  }

  Map<String, dynamic> _bookingFareFields({
    required FareEstimate fareEstimate,
    required FareSettings fareSettings,
  }) {
    return <String, dynamic>{
      'fare': fareEstimate.amount,
      'base_fare': fareEstimate.baseAmount,
      'estimated_fare': fareEstimate.amount,
      'estimated_fare_amount': fareEstimate.amount,
      'estimated_fare_currency': fareEstimate.currency,
      'final_fare': fareEstimate.amount,
      'fare_rule': fareEstimate.ruleLabel,
      'fare_rule_code': fareEstimate.ruleCode,
      'fare_settings_id': FareSettingsService.currentDocumentId,
      if (fareSettings.updatedAt != null)
        'fare_settings_updated_at': Timestamp.fromDate(fareSettings.updatedAt!),
      'fare_details': fareEstimate.toFirestore(),
      'fare_discount_applied': fareEstimate.hasDiscount,
      'fare_discount_amount': fareEstimate.discountAmount,
      'fare_discount_rate': fareEstimate.discountRate,
      'driver_pickup_surcharge': fareEstimate.driverPickupSurcharge,
      'driver_to_pickup_distance_meters':
          fareEstimate.driverToPickupDistanceMeters,
      'driver_pickup_barangay_hop_estimate':
          fareEstimate.driverPickupBarangayHopEstimate,
      if (fareEstimate.discountCode != null)
        'fare_discount_code': fareEstimate.discountCode,
      if (fareEstimate.discountLabel != null)
        'fare_discount_label': fareEstimate.discountLabel,
    };
  }

  Map<String, dynamic> _paymentMethodUpdateFields(
    PassengerPaymentMethod paymentMethod,
  ) {
    final paymentMethodType =
        paymentMethod.xenditPaymentMethodType ??
        paymentMethod.type.firestoreValue;
    return <String, dynamic>{
      'payment_method': paymentMethod.type.firestoreValue,
      'payment_method_label': paymentMethod.displayLabel,
      'payment_method_id': paymentMethod.isCash ? null : paymentMethod.id,
      'payment_method_type': paymentMethodType,
      'payment_provider': paymentMethod.provider,
      'payment_status': paymentMethod.usesOnlineCheckout
          ? 'checkout_pending'
          : 'cash_pending',
      'xendit_invoice_id': null,
      'xendit_checkout_url': null,
      'checkout_url': null,
      'xendit_invoice_status': null,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  Future<int?> _driverToPickupDistanceMetersFor({
    required String? driverId,
    required RideLocation pickupLocation,
  }) async {
    final pickup = pickupLocation.latLng;
    final normalizedDriverId = driverId?.trim();
    if (normalizedDriverId == null ||
        normalizedDriverId.isEmpty ||
        pickup == null) {
      return null;
    }

    final snapshot = await _driverLocations.doc(normalizedDriverId).get();
    final data = snapshot.data() ?? <String, dynamic>{};
    return _driverToPickupDistanceMetersFromData(
      driverLocationData: data,
      pickupLocation: pickupLocation,
      driverId: normalizedDriverId,
    );
  }

  int? _driverToPickupDistanceMetersFromData({
    required Map<String, dynamic> driverLocationData,
    required RideLocation pickupLocation,
    required String driverId,
  }) {
    final pickup = pickupLocation.latLng;
    if (pickup == null || !_hasCoordinates(driverLocationData)) {
      return null;
    }

    final driverLocation = RideDriverLocation.fromMap(<String, dynamic>{
      ...driverLocationData,
      'driver_id': driverId,
    });

    return Geolocator.distanceBetween(
      driverLocation.latitude,
      driverLocation.longitude,
      pickup.latitude,
      pickup.longitude,
    ).round();
  }

  FareEstimate? _fareEstimateForBookingData({
    required Map<String, dynamic> bookingData,
    required FareSettings fareSettings,
    int? driverToPickupDistanceMeters,
  }) {
    final pickupLocation = RideLocation.fromMap(bookingData['pickup_location']);
    final dropoffLocation = RideLocation.fromMap(
      bookingData['dropoff_location'],
    );
    final distanceMeters = _readRouteDistanceMeters(bookingData);
    if (distanceMeters == null) {
      return null;
    }

    return _fareService.estimateFare(
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      distanceMeters: distanceMeters,
      passengerType: _passengerTypeForFare(bookingData),
      passengerIsVerified: bookingData['passenger_is_verified'] == true,
      settings: fareSettings,
      driverToPickupDistanceMeters: driverToPickupDistanceMeters,
    );
  }

  int? _readRouteDistanceMeters(Map<String, dynamic> bookingData) {
    final explicitDistance = _readInt(bookingData['estimated_distance_meters']);
    if (explicitDistance != null) {
      return explicitDistance;
    }

    final route = bookingData['route'];
    if (route is Map) {
      return _readInt(route['distance_meters']);
    }

    return null;
  }

  String _passengerTypeForFare(Map<String, dynamic> bookingData) {
    return switch ((bookingData['passenger_type'] ?? bookingData['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase()) {
      'student' => 'student',
      'senior_citizen' => 'senior_citizen',
      _ => 'regular',
    };
  }

  Future<PassengerFareProfile> loadPassengerFareProfile(
    String passengerId,
  ) async {
    final snapshot = await _users.doc(passengerId).get();
    if (!snapshot.exists) {
      throw StateError('Passenger profile not found.');
    }

    return PassengerFareProfile.fromData(
      userId: passengerId,
      data: snapshot.data() ?? <String, dynamic>{},
    );
  }

  Stream<Ride?> watchPassengerActiveRide(String passengerId) {
    return _bookings
        .where('passenger_id', isEqualTo: passengerId)
        .snapshots()
        .map((snapshot) {
          final rides = snapshot.docs
              .map(Ride.fromDocument)
              .where((ride) => ride.isActive)
              .toList();
          rides.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

          return rides.isEmpty ? null : rides.first;
        });
  }

  Future<Ride?> findPassengerActiveRide(String passengerId) async {
    final snapshot = await _bookings
        .where('passenger_id', isEqualTo: passengerId)
        .get();
    final rides = snapshot.docs
        .map(Ride.fromDocument)
        .where((ride) => ride.isActive)
        .toList();
    rides.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return rides.isEmpty ? null : rides.first;
  }

  Stream<List<Ride>> watchPassengerRides(String passengerId) {
    return _bookings
        .where('passenger_id', isEqualTo: passengerId)
        .snapshots()
        .map((snapshot) {
          final rides = snapshot.docs.map(Ride.fromDocument).toList();
          rides.sort(_compareRidesByLatestActivity);
          return rides;
        });
  }

  Stream<List<AvailableDriver>> watchAvailableDrivers() {
    return _driverLocations
        .where('is_available', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final drivers = <AvailableDriver>[];

          for (final document in snapshot.docs) {
            final locationData = document.data();
            if (!_isAvailableDriverLocation(locationData)) {
              continue;
            }

            final location = RideDriverLocation.fromMap(locationData);
            final driverId = location.driverId.isNotEmpty
                ? location.driverId
                : document.id;
            final DocumentSnapshot<Map<String, dynamic>> userDoc;
            try {
              userDoc = await _users.doc(driverId).get();
            } on FirebaseException catch (error) {
              if (error.code == 'permission-denied') {
                continue;
              }

              rethrow;
            }
            final userData = userDoc.data() ?? <String, dynamic>{};
            final isVerified = _isVerifiedFlag(userData);
            final isBanned = _isBannedFlag(userData);

            if (!userDoc.exists ||
                !_isDriverRole(userData) ||
                !isVerified ||
                isBanned) {
              continue;
            }

            // Passenger clients cannot read other drivers' active bookings.
            // Public availability is represented by driver_locations instead.
            drivers.add(
              AvailableDriver.fromData(
                driverId: driverId,
                location: location,
                userData: userData,
              ),
            );
          }

          drivers.sort((a, b) => a.fullName.compareTo(b.fullName));
          return drivers;
        });
  }

  static bool _hasCoordinates(Map<String, dynamic> data) {
    if (data['geopoint'] is GeoPoint) {
      return true;
    }

    return data['latitude'] != null && data['longitude'] != null;
  }

  static bool _isStaleDriverLocation(Map<String, dynamic> data) {
    final updatedAt = _readDate(data['updated_at']);
    if (updatedAt == null) {
      return true;
    }

    return DateTime.now().difference(updatedAt) > driverAvailabilityTimeout;
  }

  static bool _hasActiveBookingMarker(Map<String, dynamic> data) {
    return _readNullableString(data['active_booking_id']) != null;
  }

  static bool _isActiveDriverLocation(Map<String, dynamic> data) {
    return data['is_available'] == true &&
        _hasCoordinates(data) &&
        !_isStaleDriverLocation(data);
  }

  static bool _isAvailableDriverLocation(Map<String, dynamic> data) {
    return _isActiveDriverLocation(data) && !_hasActiveBookingMarker(data);
  }

  Stream<Ride?> watchRide(String bookingId) {
    return _bookings.doc(bookingId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return Ride.fromDocument(snapshot);
    });
  }

  Stream<List<Ride>> watchOpenBookings({
    String? driverId,
    bool includeDeclined = false,
    bool requireDriverAvailability = true,
  }) {
    final bookingsStream = _bookings
        .where('status', isEqualTo: RideStatus.searching.firestoreValue)
        .snapshots();

    if (driverId == null || !requireDriverAvailability) {
      return bookingsStream.map(
        (snapshot) => _visibleOpenBookings(
          snapshot.docs,
          driverId: driverId,
          includeDeclined: includeDeclined,
        ),
      );
    }

    return _watchReceivableOpenBookings(
      driverId: driverId,
      bookingsStream: bookingsStream,
      includeDeclined: includeDeclined,
    );
  }

  Stream<int> watchOpenBookingCount({
    String? driverId,
    bool includeDeclined = false,
    bool requireDriverAvailability = true,
  }) {
    return watchOpenBookings(
      driverId: driverId,
      includeDeclined: includeDeclined,
      requireDriverAvailability: requireDriverAvailability,
    ).map((rides) => rides.length).distinct();
  }

  Stream<List<Ride>> _watchReceivableOpenBookings({
    required String driverId,
    required Stream<QuerySnapshot<Map<String, dynamic>>> bookingsStream,
    required bool includeDeclined,
  }) {
    late final StreamController<List<Ride>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    bookingsSubscription;
    StreamSubscription<bool>? availabilitySubscription;
    QuerySnapshot<Map<String, dynamic>>? latestBookingSnapshot;
    bool? latestAvailability;
    var emissionToken = 0;

    Future<void> emitVisibleBookings() async {
      final snapshot = latestBookingSnapshot;
      final isAvailable = latestAvailability;
      if (snapshot == null || isAvailable == null || controller.isClosed) {
        return;
      }

      final currentToken = ++emissionToken;
      if (!isAvailable) {
        controller.add(<Ride>[]);
        return;
      }

      try {
        final activeRide = await findDriverActiveRide(driverId);
        if (controller.isClosed || currentToken != emissionToken) {
          return;
        }

        if (activeRide != null) {
          controller.add(<Ride>[]);
          return;
        }

        controller.add(
          _visibleOpenBookings(
            snapshot.docs,
            driverId: driverId,
            includeDeclined: includeDeclined,
          ),
        );
      } catch (error, stackTrace) {
        if (!controller.isClosed && currentToken == emissionToken) {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller = StreamController<List<Ride>>(
      onListen: () {
        bookingsSubscription = bookingsStream.listen((snapshot) {
          latestBookingSnapshot = snapshot;
          unawaited(emitVisibleBookings());
        }, onError: controller.addError);
        availabilitySubscription = watchDriverAvailability(driverId).listen((
          isAvailable,
        ) {
          latestAvailability = isAvailable;
          unawaited(emitVisibleBookings());
        }, onError: controller.addError);
      },
      onCancel: () async {
        await bookingsSubscription?.cancel();
        await availabilitySubscription?.cancel();
      },
    );

    return controller.stream;
  }

  List<Ride> _visibleOpenBookings(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String? driverId,
    required bool includeDeclined,
  }) {
    final rides = docs.map(Ride.fromDocument).where((ride) {
      final preferredDriverId = ride.preferredDriverId;
      if (driverId == null) {
        return true;
      }

      if (!includeDeclined && ride.declinedDriverIds.contains(driverId)) {
        return false;
      }

      return preferredDriverId == null || preferredDriverId == driverId;
    }).toList();

    rides.sort((a, b) {
      if (driverId != null) {
        final aPreferred = a.preferredDriverId == driverId;
        final bPreferred = b.preferredDriverId == driverId;
        if (aPreferred != bPreferred) {
          return aPreferred ? -1 : 1;
        }

        final aDeclined = a.declinedDriverIds.contains(driverId);
        final bDeclined = b.declinedDriverIds.contains(driverId);
        if (aDeclined != bDeclined) {
          return aDeclined ? 1 : -1;
        }
      }

      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });

    return rides;
  }

  Stream<List<Ride>> watchDriverActiveRides(String driverId) {
    return _bookings
        .where('driver_id', isEqualTo: driverId)
        .where('status', whereIn: _activeRideStatusValues)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Ride.fromDocument).toList());
  }

  Stream<List<Ride>> watchDriverRides(String driverId) {
    return _bookings.where('driver_id', isEqualTo: driverId).snapshots().map((
      snapshot,
    ) {
      final rides = snapshot.docs.map(Ride.fromDocument).toList();
      rides.sort(_compareRidesByLatestActivity);
      return rides;
    });
  }

  Stream<RideDriverLocation?> watchDriverLocation(String driverId) {
    return _driverLocations.doc(driverId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      if (!_hasCoordinates(data)) {
        return null;
      }

      return RideDriverLocation.fromMap(<String, dynamic>{
        ...data,
        'driver_id': driverId,
      });
    });
  }

  Stream<bool> watchDriverAvailability(String driverId) {
    return _driverLocations.doc(driverId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return false;
      }

      return _isAvailableDriverLocation(snapshot.data() ?? <String, dynamic>{});
    });
  }

  Stream<bool> watchDriverActiveStatus(String driverId) {
    return _driverLocations.doc(driverId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return false;
      }

      return _isActiveDriverLocation(snapshot.data() ?? <String, dynamic>{});
    });
  }

  Stream<List<DriverRecentTrip>> watchDriverRecentTrips(
    String driverId, {
    int limit = 8,
  }) {
    return _bookings
        .where('driver_id', isEqualTo: driverId)
        .snapshots()
        .asyncMap((snapshot) async {
          final rides = snapshot.docs
              .map(Ride.fromDocument)
              .where((ride) => ride.status.isTerminal)
              .toList();
          rides.sort((a, b) {
            final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
            final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });

          final recentRides = rides.take(limit).toList(growable: false);
          final trips = <DriverRecentTrip>[];

          for (final ride in recentRides) {
            final passengerDoc = await _users.doc(ride.passengerId).get();
            final passengerData = passengerDoc.data() ?? <String, dynamic>{};
            trips.add(
              DriverRecentTrip(
                ride: ride,
                passenger: PassengerReviewProfile.fromData(
                  userId: ride.passengerId,
                  data: passengerData,
                ),
              ),
            );
          }

          return trips;
        });
  }

  Stream<List<PassengerRecentTrip>> watchPassengerRecentTrips(
    String passengerId, {
    int limit = 8,
  }) {
    return _bookings
        .where('passenger_id', isEqualTo: passengerId)
        .snapshots()
        .asyncMap((snapshot) async {
          final rides = snapshot.docs
              .map(Ride.fromDocument)
              .where((ride) => ride.status.isTerminal && ride.hasDriver)
              .toList();
          rides.sort((a, b) {
            final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
            final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });

          final recentRides = rides.take(limit).toList(growable: false);
          final trips = <PassengerRecentTrip>[];

          for (final ride in recentRides) {
            final driverId = ride.driverId;
            if (driverId == null || driverId.trim().isEmpty) {
              continue;
            }

            final driverDoc = await _users.doc(driverId).get();
            final driverData = driverDoc.data() ?? <String, dynamic>{};
            trips.add(
              PassengerRecentTrip(
                ride: ride,
                driver: DriverReviewProfile.fromData(
                  driverId: driverId,
                  data: driverData,
                ),
              ),
            );
          }

          return trips;
        });
  }

  Future<DriverReviewProfile> loadDriverProfile(String driverId) async {
    final snapshot = await _users.doc(driverId).get();
    if (!snapshot.exists) {
      throw StateError('Driver profile not found.');
    }

    return DriverReviewProfile.fromData(
      driverId: driverId,
      data: snapshot.data() ?? <String, dynamic>{},
    );
  }

  Stream<DriverReviewProfile> watchDriverProfile(String driverId) {
    return _users.doc(driverId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw StateError('Driver profile not found.');
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      return DriverReviewProfile.fromData(driverId: driverId, data: data);
    });
  }

  Future<Ride?> findPendingPassengerDriverReviewRide({
    required String passengerId,
    required String driverId,
    String? preferredBookingId,
  }) async {
    final preferredId = preferredBookingId?.trim();
    if (preferredId != null && preferredId.isNotEmpty) {
      final snapshot = await _bookings.doc(preferredId).get();
      final ride = snapshot.exists ? Ride.fromDocument(snapshot) : null;
      if (_isPendingPassengerDriverReviewRide(
        ride,
        passengerId: passengerId,
        driverId: driverId,
      )) {
        return ride;
      }
    }

    final snapshot = await _bookings
        .where('passenger_id', isEqualTo: passengerId)
        .get();
    final rides = snapshot.docs
        .map(Ride.fromDocument)
        .where(
          (ride) => _isPendingPassengerDriverReviewRide(
            ride,
            passengerId: passengerId,
            driverId: driverId,
          ),
        )
        .toList(growable: false);

    rides.sort(_compareRidesByLatestActivity);
    return rides.isEmpty ? null : rides.first;
  }

  bool _isPendingPassengerDriverReviewRide(
    Ride? ride, {
    required String passengerId,
    required String driverId,
  }) {
    return ride != null &&
        ride.passengerId == passengerId &&
        ride.driverId == driverId &&
        ride.canPassengerReviewDriver;
  }

  Stream<List<DriverReviewProfile>> watchTopDrivers({int limit = 5}) {
    final safeLimit = limit <= 0 ? DriverRating.leaderboardLimit : limit;

    return _users
        .where('role', isEqualTo: 'driver')
        .where('is_verified', isEqualTo: true)
        .where('is_banned', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final drivers = snapshot.docs
              .map(
                (document) => DriverReviewProfile.fromData(
                  driverId: document.id,
                  data: document.data(),
                ),
              )
              .where((driver) => driver.reviewCount > 0)
              .toList();

          drivers.sort(_compareDriverLeaderboardProfiles);

          return drivers.take(safeLimit).toList(growable: false);
        });
  }

  int _compareDriverLeaderboardProfiles(
    DriverReviewProfile a,
    DriverReviewProfile b,
  ) {
    final weightedComparison = b.weightedRating.compareTo(a.weightedRating);
    if (weightedComparison != 0) {
      return weightedComparison;
    }

    final reviewComparison = b.reviewCount.compareTo(a.reviewCount);
    if (reviewComparison != 0) {
      return reviewComparison;
    }

    final ratingComparison = b.averageRating.compareTo(a.averageRating);
    if (ratingComparison != 0) {
      return ratingComparison;
    }

    return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
  }

  Stream<PassengerReviewProfile> watchPassengerProfile(String passengerId) {
    return _users.doc(passengerId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw StateError('Passenger profile not found.');
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      return PassengerReviewProfile.fromData(userId: passengerId, data: data);
    });
  }

  Future<PassengerReviewProfile> loadPassengerProfile(
    String passengerId,
  ) async {
    final snapshot = await _users.doc(passengerId).get();
    if (!snapshot.exists) {
      throw StateError('Passenger profile not found.');
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    return PassengerReviewProfile.fromData(userId: passengerId, data: data);
  }

  Stream<List<DriverReviewRecord>> watchDriverReviews(String driverId) {
    return watchUserReviews(driverId);
  }

  Stream<List<DriverReviewRecord>> watchUserReviews(String userId) {
    return _firestore
        .collection('reviews')
        .where('reviewee_id', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          final reviews = <DriverReviewRecord>[];

          for (final document in snapshot.docs) {
            final data = document.data();
            final reviewerName =
                _reviewerNameFromReviewData(data) ??
                _reviewerFallbackName(data);

            reviews.add(
              DriverReviewRecord.fromData(
                reviewId: document.id,
                data: data,
                reviewerName: reviewerName,
              ),
            );
          }

          reviews.sort((a, b) {
            final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
            final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });

          return reviews;
        });
  }

  Future<void> savePassengerDriverReview({
    required String bookingId,
    required String passengerId,
    required String driverId,
    required int rating,
    required String comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Rating must be 1 to 5.');
    }

    final trimmedComment = comment.trim();
    if (trimmedComment.length > 600) {
      throw ArgumentError.value(
        comment,
        'comment',
        'Review must be 600 characters or fewer.',
      );
    }

    final reviewId = '${bookingId}_passenger_${passengerId}_driver_$driverId';
    final reviewRef = _firestore.collection('reviews').doc(reviewId);
    final bookingRef = _bookings.doc(bookingId);
    final passengerRef = _users.doc(passengerId);

    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);
      final bookingData = bookingSnapshot.data() ?? <String, dynamic>{};
      final bookingRide = bookingSnapshot.exists
          ? Ride.fromDocument(bookingSnapshot)
          : null;

      if (!bookingSnapshot.exists ||
          bookingData['passenger_id'] != passengerId ||
          bookingData['driver_id'] != driverId ||
          bookingRide?.status != RideStatus.completed) {
        throw StateError('Only completed trips can be reviewed.');
      }

      final existingReview = await transaction.get(reviewRef);
      if (existingReview.exists ||
          bookingRide?.hasPassengerDriverReview == true) {
        throw StateError('This ride already has a driver review.');
      }

      final passengerSnapshot = await transaction.get(passengerRef);
      final passengerData = passengerSnapshot.data() ?? <String, dynamic>{};
      final reviewerName = _fullNameFromData(
        passengerData,
        fallback: 'Passenger',
      );
      final now = FieldValue.serverTimestamp();

      transaction.set(reviewRef, <String, dynamic>{
        'review_id': reviewId,
        'booking_id': bookingId,
        'reviewer_id': passengerId,
        'reviewer_role': 'passenger',
        'reviewer_name': reviewerName,
        'reviewee_id': driverId,
        'reviewee_role': 'driver',
        'rating': rating,
        'comment': trimmedComment,
        'created_at': now,
        'updated_at': now,
      });

      transaction.update(bookingRef, <String, dynamic>{
        'passenger_driver_review': <String, dynamic>{
          'review_id': reviewId,
          'rating': rating,
          'comment': trimmedComment,
          'reviewer_id': passengerId,
          'reviewee_id': driverId,
          'created_at': Timestamp.now(),
          'updated_at': Timestamp.now(),
        },
        'updated_at': now,
      });
    });
  }

  Future<void> reportDriver({
    required String bookingId,
    required String passengerId,
    required String driverId,
    required String reason,
    required String details,
  }) async {
    final bookingSnapshot = await _bookings.doc(bookingId).get();
    final bookingData = bookingSnapshot.data() ?? <String, dynamic>{};
    if (!bookingSnapshot.exists ||
        bookingData['passenger_id'] != passengerId ||
        bookingData['driver_id'] != driverId) {
      throw StateError('Reports must be connected to your driver trip.');
    }

    await _submitUserReport(
      bookingId: bookingId,
      reporterId: passengerId,
      reporterRole: 'passenger',
      reportedUserId: driverId,
      reportedUserRole: 'driver',
      reason: reason,
      details: details,
    );
  }

  Future<void> reportPassenger({
    required String bookingId,
    required String driverId,
    required String passengerId,
    required String reason,
    required String details,
  }) async {
    final bookingSnapshot = await _bookings.doc(bookingId).get();
    final bookingData = bookingSnapshot.data() ?? <String, dynamic>{};
    final currentStatus = rideStatusFromString(bookingData['status']);
    final assignedDriverId = _readNullableString(bookingData['driver_id']);
    final preferredDriverId = _readNullableString(
      bookingData['preferred_driver_id'],
    );
    final declinedDriverIds = _readStringList(
      bookingData['declined_driver_ids'],
    );
    final isAssignedToDriver = assignedDriverId == driverId;
    final isVisibleOpenRequest =
        assignedDriverId == null &&
        currentStatus == RideStatus.searching &&
        !declinedDriverIds.contains(driverId) &&
        (preferredDriverId == null || preferredDriverId == driverId);

    if (!bookingSnapshot.exists ||
        bookingData['passenger_id'] != passengerId ||
        (!isAssignedToDriver && !isVisibleOpenRequest)) {
      throw StateError('Reports must be connected to your passenger booking.');
    }

    await _submitUserReport(
      bookingId: bookingId,
      reporterId: driverId,
      reporterRole: 'driver',
      reportedUserId: passengerId,
      reportedUserRole: 'passenger',
      reason: reason,
      details: details,
    );
  }

  Future<void> saveDriverPassengerReview({
    required String bookingId,
    required String driverId,
    required String passengerId,
    required int rating,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Rating must be 1 to 5.');
    }

    final reviewId = '${bookingId}_driver_${driverId}_passenger_$passengerId';
    final reviewRef = _firestore.collection('reviews').doc(reviewId);
    final bookingRef = _bookings.doc(bookingId);
    final driverRef = _users.doc(driverId);

    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);
      final bookingData = bookingSnapshot.data() ?? <String, dynamic>{};
      final bookingRide = bookingSnapshot.exists
          ? Ride.fromDocument(bookingSnapshot)
          : null;

      if (!bookingSnapshot.exists ||
          bookingData['passenger_id'] != passengerId ||
          bookingData['driver_id'] != driverId ||
          bookingRide?.status != RideStatus.completed) {
        throw StateError('Only completed trips can be reviewed.');
      }

      final existingReview = await transaction.get(reviewRef);
      if (existingReview.exists ||
          bookingRide?.hasDriverPassengerReview == true) {
        throw StateError('This ride already has a passenger review.');
      }

      final driverSnapshot = await transaction.get(driverRef);
      final driverData = driverSnapshot.data() ?? <String, dynamic>{};
      final reviewerName = _fullNameFromData(driverData, fallback: 'Driver');
      final now = FieldValue.serverTimestamp();

      transaction.set(reviewRef, <String, dynamic>{
        'review_id': reviewId,
        'booking_id': bookingId,
        'reviewer_id': driverId,
        'reviewer_role': 'driver',
        'reviewer_name': reviewerName,
        'reviewee_id': passengerId,
        'reviewee_role': 'passenger',
        'rating': rating,
        'created_at': now,
        'updated_at': now,
      });

      transaction.update(bookingRef, <String, dynamic>{
        'driver_passenger_review': <String, dynamic>{
          'review_id': reviewId,
          'rating': rating,
          'reviewer_id': driverId,
          'reviewee_id': passengerId,
          'created_at': Timestamp.now(),
          'updated_at': Timestamp.now(),
        },
        'updated_at': now,
      });
    });
  }

  Future<void> acceptBooking({
    required String bookingId,
    required String driverId,
    bool allowDeclined = false,
  }) async {
    final doc = _bookings.doc(bookingId);
    final driverDoc = _firestore.collection('users').doc(driverId);
    final driverLocationDoc = _driverLocations.doc(driverId);

    await _firestore.runTransaction((transaction) async {
      final driverSnapshot = await transaction.get(driverDoc);
      final driverData = driverSnapshot.data() ?? <String, dynamic>{};
      final isVerifiedDriver =
          driverSnapshot.exists &&
          _isDriverRole(driverData) &&
          _isVerifiedFlag(driverData) &&
          _hasCurrentDriverDocuments(driverData) &&
          !_isBannedFlag(driverData);

      if (!isVerifiedDriver) {
        throw StateError('Only verified drivers can accept bookings.');
      }

      final driverLocationSnapshot = await transaction.get(driverLocationDoc);
      final driverLocationData =
          driverLocationSnapshot.data() ?? <String, dynamic>{};
      if (!_isAvailableDriverLocation(driverLocationData)) {
        throw StateError(
          'You are unavailable or already handling an active booking.',
        );
      }

      final snapshot = await transaction.get(doc);
      final data = snapshot.data() ?? <String, dynamic>{};
      final currentStatus = rideStatusFromString(data['status']);

      if (!snapshot.exists || currentStatus != RideStatus.searching) {
        throw StateError('This booking is no longer available.');
      }

      final preferredDriverId = _readNullableString(
        data['preferred_driver_id'],
      );
      if (preferredDriverId != null && preferredDriverId != driverId) {
        throw StateError('This booking is reserved for another driver.');
      }

      final declinedDriverIds = _readStringList(data['declined_driver_ids']);
      final wasDeclinedByDriver = declinedDriverIds.contains(driverId);
      if (wasDeclinedByDriver && !allowDeclined) {
        throw StateError('You already declined this booking.');
      }

      final paymentProvider = (data['payment_provider'] ?? 'cash')
          .toString()
          .trim()
          .toLowerCase();
      final paymentStatus = (data['payment_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (paymentProvider == 'xendit' &&
          driverData['accepts_online_payments'] != true) {
        throw StateError(
          'Add a driver payout account before accepting online payments.',
        );
      }

      final fareSettingsRef = _firestore
          .collection(FareSettingsService.collectionPath)
          .doc(FareSettingsService.currentDocumentId);
      final fareSettingsSnapshot = await transaction.get(fareSettingsRef);
      final fareSettings = FareSettings.fromDocument(fareSettingsSnapshot);
      final pickupLocation = RideLocation.fromMap(data['pickup_location']);
      final driverToPickupDistanceMeters =
          _driverToPickupDistanceMetersFromData(
            driverLocationData: driverLocationData,
            pickupLocation: pickupLocation,
            driverId: driverId,
          );
      final acceptedFareEstimate = _fareEstimateForBookingData(
        bookingData: data,
        fareSettings: fareSettings,
        driverToPickupDistanceMeters: driverToPickupDistanceMeters,
      );

      final hasDriverLocation = _hasCoordinates(driverLocationData);
      final driverLocation = hasDriverLocation
          ? RideDriverLocation.fromMap(<String, dynamic>{
              ...driverLocationData,
              'driver_id': driverId,
            }).toFirestore()
          : null;
      final bookingUpdates = <String, dynamic>{
        'driver_id': driverId,
        'status': RideStatus.accepted.firestoreValue,
        'driver_location': ?driverLocation,
        'accepted_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        if (wasDeclinedByDriver)
          'declined_driver_ids': FieldValue.arrayRemove(<String>[driverId]),
        'status_history': FieldValue.arrayUnion(<Map<String, dynamic>>[
          <String, dynamic>{
            'status': RideStatus.accepted.firestoreValue,
            'changed_by': driverId,
            'changed_at': Timestamp.now(),
          },
        ]),
      };

      if (acceptedFareEstimate != null) {
        bookingUpdates.addAll(
          _bookingFareFields(
            fareEstimate: acceptedFareEstimate,
            fareSettings: fareSettings,
          ),
        );
      }

      final grossFare =
          acceptedFareEstimate?.amount ?? _readBookingFareAmount(data);
      if (grossFare != null) {
        bookingUpdates.addAll(
          RideEarningsBreakdown.calculate(
            grossFare: grossFare,
            commissionRate: fareSettings.commissionRate,
          ).toFirestore(),
        );
      }

      if (paymentProvider == 'xendit') {
        bookingUpdates.addAll(<String, dynamic>{
          'driver_payout_status': paymentStatus == 'paid'
              ? 'pending'
              : 'awaiting_payment',
          'driver_payout_account_id': driverData['default_payout_account_id'],
          'driver_accepts_online_payments': true,
        });
      } else {
        bookingUpdates.addAll(<String, dynamic>{
          'driver_payout_status': 'cash_collection_pending',
          'driver_payout_account_id': null,
        });
      }

      transaction.update(doc, bookingUpdates);
      transaction.set(driverLocationDoc, <String, dynamic>{
        'driver_id': driverId,
        'is_available': true,
        'active_booking_id': bookingId,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> declineBooking({
    required String bookingId,
    required String driverId,
  }) async {
    final bookingRef = _bookings.doc(bookingId);
    final driverRef = _users.doc(driverId);

    await _firestore.runTransaction((transaction) async {
      final driverSnapshot = await transaction.get(driverRef);
      final driverData = driverSnapshot.data() ?? <String, dynamic>{};
      final isVerifiedDriver =
          driverSnapshot.exists &&
          _isDriverRole(driverData) &&
          _isVerifiedFlag(driverData) &&
          !_isBannedFlag(driverData);

      if (!isVerifiedDriver) {
        throw StateError('Only verified drivers can decline bookings.');
      }

      final bookingSnapshot = await transaction.get(bookingRef);
      final data = bookingSnapshot.data() ?? <String, dynamic>{};
      final currentStatus = rideStatusFromString(data['status']);

      if (!bookingSnapshot.exists || currentStatus != RideStatus.searching) {
        throw StateError('This booking is no longer available.');
      }

      final preferredDriverId = _readNullableString(
        data['preferred_driver_id'],
      );
      if (preferredDriverId != null && preferredDriverId != driverId) {
        throw StateError('This booking is reserved for another driver.');
      }

      transaction.update(bookingRef, <String, dynamic>{
        'preferred_driver_id': null,
        'declined_driver_ids': FieldValue.arrayUnion(<String>[driverId]),
        'last_declined_driver_id': driverId,
        'declined_at': FieldValue.serverTimestamp(),
        'status': RideStatus.searching.firestoreValue,
        'updated_at': FieldValue.serverTimestamp(),
        'status_history': FieldValue.arrayUnion(<Map<String, dynamic>>[
          <String, dynamic>{
            'status': RideStatus.searching.firestoreValue,
            'event': 'driver_declined',
            'changed_by': driverId,
            'changed_at': Timestamp.now(),
          },
        ]),
      });
    });
  }

  Future<void> updateRideStatus({
    required String bookingId,
    required RideStatus status,
    required String changedBy,
  }) async {
    final bookingRef = _bookings.doc(bookingId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(bookingRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      if (!snapshot.exists) {
        throw StateError('Booking was not found.');
      }

      final paymentProvider = (data['payment_provider'] ?? 'cash')
          .toString()
          .trim()
          .toLowerCase();
      final paymentStatus = (data['payment_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final isPaymentSettled = _isPaymentSettled(paymentStatus);
      if (status == RideStatus.completed &&
          paymentProvider != 'cash' &&
          !isPaymentSettled) {
        throw StateError(
          'Complete checkout before marking this ride completed.',
        );
      }

      final updates = <String, dynamic>{
        'status': status.firestoreValue,
        'updated_at': FieldValue.serverTimestamp(),
        _statusTimestampField(status): FieldValue.serverTimestamp(),
        'status_history': FieldValue.arrayUnion(<Map<String, dynamic>>[
          <String, dynamic>{
            'status': status.firestoreValue,
            'changed_by': changedBy,
            'changed_at': Timestamp.now(),
          },
        ]),
      };

      if (status == RideStatus.completed && paymentProvider == 'cash') {
        updates['driver_payout_status'] = 'cash_collected';
        if (paymentStatus != 'cash_collected') {
          updates.addAll(<String, dynamic>{
            'payment_status': 'cash_collected',
            'payment_confirmed_by': changedBy,
            'payment_confirmed_at': FieldValue.serverTimestamp(),
          });
        }
      } else if (status == RideStatus.completed && paymentProvider != 'cash') {
        updates['driver_payout_status'] = 'pending';
      }

      if (status == RideStatus.cancelled) {
        updates.addAll(<String, dynamic>{
          'cancelled_by': changedBy,
          'cancelled_at': FieldValue.serverTimestamp(),
          'driver_payout_status': isPaymentSettled && paymentProvider != 'cash'
              ? 'review_required'
              : 'cancelled',
        });

        if (!isPaymentSettled) {
          updates.addAll(<String, dynamic>{
            'payment_status': paymentProvider == 'xendit'
                ? 'checkout_cancelled'
                : 'cash_cancelled',
            'payment_cancelled_by': changedBy,
            'payment_cancelled_at': FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.update(bookingRef, updates);

      final terminalDriverId = status.isTerminal
          ? _readNullableString(data['driver_id'])
          : null;
      if (terminalDriverId != null && changedBy == terminalDriverId) {
        transaction
            .set(_driverLocations.doc(terminalDriverId), <String, dynamic>{
              'driver_id': terminalDriverId,
              'is_available': true,
              'active_booking_id': null,
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    });
  }

  bool _isPaymentSettled(String paymentStatus) {
    return paymentStatus == 'paid' || paymentStatus == 'cash_collected';
  }

  int? _readBookingFareAmount(Map<String, dynamic> data) {
    final candidates = <Object?>[
      data['gross_fare'],
      data['final_fare'],
      data['estimated_fare_amount'],
      data['estimated_fare'],
      data['fare_amount'],
      data['fare'],
    ];

    for (final candidate in candidates) {
      if (candidate is num) {
        return candidate.round();
      }

      final text = candidate?.toString().trim() ?? '';
      if (text.isEmpty) {
        continue;
      }

      final amount = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
      if (amount != null) {
        return amount;
      }
    }

    return null;
  }

  Future<void> updateDriverAvailability({
    required String driverId,
    required bool isAvailable,
    String? activeBookingId,
  }) async {
    if (isAvailable) {
      await _ensureVerifiedDriver(driverId);
      final activeRide = await findDriverActiveRide(driverId);
      activeBookingId = activeRide?.bookingId;
    }

    await _driverLocations.doc(driverId).set(<String, dynamic>{
      'driver_id': driverId,
      'is_available': isAvailable,
      'active_booking_id': activeBookingId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markDriverUnavailable({required String driverId}) {
    return updateDriverAvailability(driverId: driverId, isAvailable: false);
  }

  Future<void> updateDriverLocation({
    required String driverId,
    required Position position,
    String? activeBookingId,
    bool isAvailable = true,
  }) async {
    if (isAvailable) {
      await _ensureVerifiedDriver(driverId);
      final activeRide = await findDriverActiveRide(driverId);
      if (activeRide != null) {
        activeBookingId = activeRide.bookingId;
      }
    }

    final driverLocation = RideDriverLocation(
      driverId: driverId,
      latitude: position.latitude,
      longitude: position.longitude,
      heading: position.heading.isNaN ? null : position.heading,
      speed: position.speed.isNaN ? null : position.speed,
      accuracy: position.accuracy.isNaN ? null : position.accuracy,
    );
    final locationData = driverLocation.toFirestore();
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    batch.set(_driverLocations.doc(driverId), <String, dynamic>{
      ...locationData,
      'is_available': isAvailable,
      'active_booking_id': activeBookingId,
      'updated_at': now,
    }, SetOptions(merge: true));

    if (activeBookingId != null && activeBookingId.isNotEmpty) {
      batch.update(_bookings.doc(activeBookingId), <String, dynamic>{
        'driver_location': locationData,
        'updated_at': now,
      });
    }

    await batch.commit();
  }

  Future<Ride?> findDriverActiveRide(String driverId) async {
    final snapshot = await _bookings
        .where('driver_id', isEqualTo: driverId)
        .where('status', whereIn: _activeRideStatusValues)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return Ride.fromDocument(snapshot.docs.first);
  }

  Future<void> _ensureVerifiedDriver(String driverId) async {
    final snapshot = await _firestore.collection('users').doc(driverId).get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final isVerifiedDriver =
        snapshot.exists &&
        _isDriverRole(data) &&
        _isVerifiedFlag(data) &&
        _hasCurrentDriverDocuments(data) &&
        !_isBannedFlag(data);

    if (!isVerifiedDriver) {
      throw StateError('Only verified drivers can go active.');
    }
  }

  Future<void> updateRideEta({
    required String bookingId,
    DistanceMatrixResult? driverToPickup,
    DistanceMatrixResult? remainingRide,
  }) {
    return _bookings.doc(bookingId).update(<String, dynamic>{
      if (driverToPickup != null) ...<String, dynamic>{
        'eta.driver_to_pickup_distance_meters': driverToPickup.distanceMeters,
        'eta.driver_to_pickup_duration_seconds': driverToPickup.durationSeconds,
        'eta.driver_to_pickup_distance_text': driverToPickup.distanceText,
        'eta.driver_to_pickup_duration_text': driverToPickup.durationText,
      },
      if (remainingRide != null) ...<String, dynamic>{
        'eta.remaining_ride_distance_meters': remainingRide.distanceMeters,
        'eta.remaining_ride_duration_seconds': remainingRide.durationSeconds,
        'eta.remaining_ride_distance_text': remainingRide.distanceText,
        'eta.remaining_ride_duration_text': remainingRide.durationText,
      },
      'eta.updated_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  static int? _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static bool _isVerifiedFlag(Map<String, dynamic> data) {
    return (data['is_verified'] ??
            data['isVerified'] ??
            data['isVerrified'] ??
            false) ==
        true;
  }

  static String _normalizedRole(Map<String, dynamic> data) {
    return (data['role'] ?? '').toString().trim().toLowerCase();
  }

  static bool _isDriverRole(Map<String, dynamic> data) {
    return _normalizedRole(data) == 'driver';
  }

  static bool _isBannedFlag(Map<String, dynamic> data) {
    return (data['is_banned'] ?? data['isBanned'] ?? false) == true;
  }

  static bool _hasCurrentDriverDocuments(Map<String, dynamic> data) {
    return DriverDocumentStatus.fromMap(data).isEligibleAt(DateTime.now());
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
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

  static int _compareRidesByLatestActivity(Ride a, Ride b) {
    final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
    final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
    return bDate.compareTo(aDate);
  }

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  static String? _profileImageUrlFromData(Map<String, dynamic> data) {
    final candidates = <Object?>[
      data['profile_picture_url'],
      data['profile_image_url'],
      data['selfie_url'],
    ];

    for (final candidate in candidates) {
      final imageUrl = _readNullableString(candidate);
      if (imageUrl != null) {
        return imageUrl;
      }
    }

    return null;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty && entry != 'null')
        .toList(growable: false);
  }

  static String _fullNameFromData(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final firstName = (data['first_name'] ?? '').toString().trim();
    final lastName = (data['last_name'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? fallback : fullName;
  }

  static String? _reviewerNameFromReviewData(Map<String, dynamic> data) {
    final candidates = <Object?>[
      data['reviewer_name'],
      data['reviewer_full_name'],
      data['reviewer_display_name'],
      data['reviewerName'],
    ];

    for (final candidate in candidates) {
      final name = _readNullableString(candidate);
      if (name != null) {
        return name;
      }
    }

    return null;
  }

  static String _reviewerFallbackName(Map<String, dynamic> data) {
    final role = (data['reviewer_role'] ?? '').toString().trim().toLowerCase();
    return role == 'driver' ? 'Driver' : 'Passenger';
  }

  Future<void> _submitUserReport({
    required String bookingId,
    required String reporterId,
    required String reporterRole,
    required String reportedUserId,
    required String reportedUserRole,
    required String reason,
    required String details,
  }) async {
    final trimmedReporterId = reporterId.trim();
    final trimmedReportedUserId = reportedUserId.trim();
    final trimmedReason = reason.trim();
    final trimmedDetails = details.trim();

    if (trimmedReporterId.isEmpty || trimmedReportedUserId.isEmpty) {
      throw StateError('Report users are missing.');
    }

    if (trimmedReporterId == trimmedReportedUserId) {
      throw StateError('You cannot report your own account.');
    }

    if (trimmedReason.isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'Please choose a reason.');
    }

    if (trimmedDetails.length > 800) {
      throw ArgumentError.value(
        details,
        'details',
        'Report details must be 800 characters or fewer.',
      );
    }

    final dateKey = _reportDateKey(DateTime.now());
    final reportId = _dailyReportId(
      dateKey: dateKey,
      reporterId: trimmedReporterId,
      reportedUserId: trimmedReportedUserId,
    );
    final reportRef = _reports.doc(reportId);
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final existingReport = await transaction.get(reportRef);
      if (existingReport.exists) {
        throw StateError('You can only report this user once per day.');
      }

      transaction.set(reportRef, <String, dynamic>{
        'report_id': reportId,
        'booking_id': bookingId,
        'reporter_id': trimmedReporterId,
        'reporter_role': reporterRole,
        'reported_user_id': trimmedReportedUserId,
        'reported_user_role': reportedUserRole,
        'reason': trimmedReason,
        'details': trimmedDetails,
        'report_date_key': dateKey,
        'status': 'open',
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  static String _dailyReportId({
    required String dateKey,
    required String reporterId,
    required String reportedUserId,
  }) {
    return [
      'daily',
      dateKey,
      _reportIdPart(reporterId),
      _reportIdPart(reportedUserId),
    ].join('_');
  }

  static String _reportDateKey(DateTime value) {
    final localDate = value.toLocal();
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '${localDate.year}$month$day';
  }

  static String _reportIdPart(String value) {
    return base64Url.encode(utf8.encode(value.trim())).replaceAll('=', '');
  }

  String _statusTimestampField(RideStatus status) {
    switch (status) {
      case RideStatus.searching:
        return 'searching_at';
      case RideStatus.accepted:
        return 'accepted_at';
      case RideStatus.driverArriving:
        return 'driver_arriving_at';
      case RideStatus.arrived:
        return 'arrived_at';
      case RideStatus.inProgress:
        return 'started_at';
      case RideStatus.completed:
        return 'completed_at';
      case RideStatus.cancelled:
        return 'cancelled_at';
    }
  }
}

class DriverRecentTrip {
  final Ride ride;
  final PassengerReviewProfile passenger;

  const DriverRecentTrip({required this.ride, required this.passenger});
}

class PassengerFareProfile {
  final String userId;
  final String passengerType;
  final bool isVerified;

  const PassengerFareProfile({
    required this.userId,
    required this.passengerType,
    required this.isVerified,
  });

  factory PassengerFareProfile.fromData({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    final rawRole = (data['role'] ?? '').toString().trim().toLowerCase();
    final rawPassengerType = (data['passenger_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final passengerType = rawPassengerType.isNotEmpty
        ? rawPassengerType
        : switch (rawRole) {
            'student' => 'student',
            'senior_citizen' => 'senior_citizen',
            _ => 'regular',
          };

    return PassengerFareProfile(
      userId: userId,
      passengerType: switch (passengerType) {
        'student' => 'student',
        'senior_citizen' => 'senior_citizen',
        _ => 'regular',
      },
      isVerified:
          (data['is_verified'] ??
              data['isVerified'] ??
              data['isVerrified'] ??
              false) ==
          true,
    );
  }

  bool get isStudent => passengerType == 'student';
  bool get isSeniorCitizen => passengerType == 'senior_citizen';
  bool get isVerifiedStudent => isStudent && isVerified;
  bool get isVerifiedSeniorCitizen => isSeniorCitizen && isVerified;
}

class PassengerRecentTrip {
  final Ride ride;
  final DriverReviewProfile driver;

  const PassengerRecentTrip({required this.ride, required this.driver});
}

class DriverReviewProfile {
  final String driverId;
  final String fullName;
  final bool isVerified;
  final bool isActive;
  final bool isBanned;
  final String? profileImageUrl;
  final double averageRating;
  final int reviewCount;
  final double weightedRating;
  final int? ratingRank;
  final String ratingBadge;
  final String? vehicleType;
  final String? tricycleColor;
  final String? plateNumber;
  final String? tricycleFrontUrl;
  final String? tricycleBackUrl;

  const DriverReviewProfile({
    required this.driverId,
    required this.fullName,
    required this.isVerified,
    required this.isActive,
    required this.isBanned,
    required this.profileImageUrl,
    required this.averageRating,
    required this.reviewCount,
    required this.weightedRating,
    required this.ratingRank,
    required this.ratingBadge,
    this.vehicleType,
    this.tricycleColor,
    this.plateNumber,
    this.tricycleFrontUrl,
    this.tricycleBackUrl,
  });

  factory DriverReviewProfile.fromData({
    required String driverId,
    required Map<String, dynamic> data,
  }) {
    final reviewCount =
        RideTrackingService._readInt(
          data['driver_review_count'] ?? data['review_count'],
        ) ??
        0;
    final ratingTotal =
        RideTrackingService._readInt(
          data['driver_review_rating_total'] ?? data['review_rating_total'],
        ) ??
        0;
    final averageRating = RideTrackingService._readDouble(
      data['driver_average_rating'] ??
          data['average_rating'] ??
          data['rating'] ??
          data['ratings'],
    );
    final storedWeightedRating = RideTrackingService._readDouble(
      data['driver_weighted_rating'],
    );
    final weightedRating = storedWeightedRating > 0
        ? storedWeightedRating
        : DriverRating.weightedScore(
            ratingTotal: ratingTotal,
            reviewCount: reviewCount,
          );
    final ratingRank = RideTrackingService._readInt(data['driver_rating_rank']);
    final computedBadge = DriverRating.badgeLabel(
      reviewCount: reviewCount,
      averageRating: averageRating,
      rank: ratingRank,
    );

    return DriverReviewProfile(
      driverId: driverId,
      fullName: RideTrackingService._fullNameFromData(data, fallback: 'Driver'),
      isVerified: RideTrackingService._isVerifiedFlag(data),
      isActive: (data['is_active'] ?? data['isActive'] ?? false) == true,
      isBanned: RideTrackingService._isBannedFlag(data),
      profileImageUrl: RideTrackingService._profileImageUrlFromData(data),
      averageRating: averageRating,
      reviewCount: reviewCount,
      weightedRating: weightedRating,
      ratingRank: ratingRank,
      ratingBadge:
          RideTrackingService._readNullableString(
            data['driver_rating_badge'],
          ) ??
          computedBadge,
      vehicleType: RideTrackingService._readNullableString(
        data['vehicle_type'],
      ),
      tricycleColor: RideTrackingService._readNullableString(
        data['tricycle_color'],
      ),
      plateNumber: RideTrackingService._readNullableString(
        data['plate_number'],
      ),
      tricycleFrontUrl: RideTrackingService._readNullableString(
        data['tricycle_front_url'],
      ),
      tricycleBackUrl: RideTrackingService._readNullableString(
        data['tricycle_back_url'],
      ),
    );
  }

  String get vehicleSummary {
    final parts = <String>[
      if (vehicleType != null && vehicleType!.trim().isNotEmpty)
        vehicleType!.trim(),
      if (tricycleColor != null && tricycleColor!.trim().isNotEmpty)
        tricycleColor!.trim(),
      if (plateNumber != null && plateNumber!.trim().isNotEmpty)
        plateNumber!.trim(),
    ];
    if (parts.isEmpty) return 'Tricycle details unassigned';
    return parts.join(' • ');
  }

  bool get hasVehicleInfo =>
      (vehicleType != null && vehicleType!.trim().isNotEmpty) ||
      (tricycleColor != null && tricycleColor!.trim().isNotEmpty) ||
      (plateNumber != null && plateNumber!.trim().isNotEmpty) ||
      (tricycleFrontUrl != null && tricycleFrontUrl!.trim().isNotEmpty) ||
      (tricycleBackUrl != null && tricycleBackUrl!.trim().isNotEmpty);

  String get ratingLabel =>
      reviewCount == 0 ? 'No ratings yet' : averageRating.toStringAsFixed(1);

  String get weightedRatingLabel =>
      reviewCount == 0 ? 'Not ranked' : weightedRating.toStringAsFixed(2);

  String get reviewCountLabel =>
      '$reviewCount review${reviewCount == 1 ? '' : 's'}';

  String get displayBadge => ratingBadge.isNotEmpty
      ? ratingBadge
      : DriverRating.badgeLabel(
          reviewCount: reviewCount,
          averageRating: averageRating,
          rank: ratingRank,
        );

  bool get hasRank => ratingRank != null && ratingRank! >= 1;
}

class DriverReviewRecord {
  final String reviewId;
  final String bookingId;
  final String reviewerName;
  final int rating;
  final String comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverReviewRecord({
    required this.reviewId,
    required this.bookingId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverReviewRecord.fromData({
    required String reviewId,
    required Map<String, dynamic> data,
    required String reviewerName,
  }) {
    return DriverReviewRecord(
      reviewId: (data['review_id'] ?? reviewId).toString(),
      bookingId: (data['booking_id'] ?? '').toString().trim(),
      reviewerName: reviewerName,
      rating: (RideTrackingService._readInt(data['rating']) ?? 0).clamp(0, 5),
      comment: _readComment(data),
      createdAt: RideTrackingService._readDate(data['created_at']),
      updatedAt: RideTrackingService._readDate(data['updated_at']),
    );
  }

  static String _readComment(Map<String, dynamic> data) {
    final candidates = <Object?>[
      data['comment'],
      data['review'],
      data['review_text'],
      data['feedback'],
      data['message'],
    ];

    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }
}

class PassengerReviewProfile {
  final String userId;
  final String fullName;
  final String passengerType;
  final bool isVerified;
  final String? profileImageUrl;
  final double averageRating;
  final int reviewCount;

  const PassengerReviewProfile({
    required this.userId,
    required this.fullName,
    required this.passengerType,
    required this.isVerified,
    required this.profileImageUrl,
    required this.averageRating,
    required this.reviewCount,
  });

  factory PassengerReviewProfile.fromData({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    final firstName = (data['first_name'] ?? '').toString().trim();
    final lastName = (data['last_name'] ?? '').toString().trim();
    final rawRole = (data['role'] ?? '').toString().trim().toLowerCase();
    final passengerType = (data['passenger_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final resolvedType = passengerType.isNotEmpty
        ? passengerType
        : switch (rawRole) {
            'student' => 'student',
            'senior_citizen' => 'senior_citizen',
            _ => 'regular',
          };
    final reviewCount =
        RideTrackingService._readInt(
          data['passenger_review_count'] ?? data['review_count'],
        ) ??
        0;
    final ratingTotal = RideTrackingService._readDouble(
      data['passenger_review_rating_total'] ?? data['review_rating_total'],
    );
    final averageRating = RideTrackingService._readDouble(
      data['passenger_average_rating'] ??
          data['average_rating'] ??
          data['rating'] ??
          data['ratings'],
    );

    return PassengerReviewProfile(
      userId: userId,
      fullName: '$firstName $lastName'.trim().isEmpty
          ? 'Passenger'
          : '$firstName $lastName'.trim(),
      passengerType: switch (resolvedType) {
        'student' => 'student',
        'senior_citizen' => 'senior_citizen',
        _ => 'regular',
      },
      isVerified: RideTrackingService._isVerifiedFlag(data),
      profileImageUrl: RideTrackingService._profileImageUrlFromData(data),
      averageRating: averageRating > 0
          ? averageRating
          : reviewCount == 0
          ? 0
          : ratingTotal / reviewCount,
      reviewCount: reviewCount,
    );
  }

  String get roleLabel => switch (passengerType) {
    'student' => 'Student',
    'senior_citizen' => 'Senior Citizen',
    _ => 'Regular',
  };

  String get ratingLabel =>
      reviewCount == 0 ? 'No ratings yet' : averageRating.toStringAsFixed(1);
}

class AvailableDriver {
  final String driverId;
  final String fullName;
  final String? profileImageUrl;
  final bool isVerified;
  final bool supportsOnlinePayments;
  final double rating;
  final int reviewCount;
  final double weightedRating;
  final int? ratingRank;
  final String ratingBadge;
  final RideDriverLocation location;
  final String? vehicleType;
  final String? tricycleColor;
  final String? plateNumber;
  final String? tricycleFrontUrl;
  final String? tricycleBackUrl;

  const AvailableDriver({
    required this.driverId,
    required this.fullName,
    required this.profileImageUrl,
    required this.isVerified,
    required this.supportsOnlinePayments,
    required this.rating,
    required this.reviewCount,
    required this.weightedRating,
    required this.ratingRank,
    required this.ratingBadge,
    required this.location,
    this.vehicleType,
    this.tricycleColor,
    this.plateNumber,
    this.tricycleFrontUrl,
    this.tricycleBackUrl,
  });

  factory AvailableDriver.fromData({
    required String driverId,
    required RideDriverLocation location,
    required Map<String, dynamic> userData,
  }) {
    final firstName = (userData['first_name'] ?? '').toString().trim();
    final lastName = (userData['last_name'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();
    final reviewCount =
        RideTrackingService._readInt(
          userData['driver_review_count'] ?? userData['review_count'],
        ) ??
        0;
    final ratingTotal =
        RideTrackingService._readInt(
          userData['driver_review_rating_total'] ??
              userData['review_rating_total'],
        ) ??
        0;
    final rating = _readRating(
      userData['driver_average_rating'] ??
          userData['average_rating'] ??
          userData['rating'] ??
          userData['ratings'],
    );
    final storedWeightedRating = RideTrackingService._readDouble(
      userData['driver_weighted_rating'],
    );
    final weightedRating = storedWeightedRating > 0
        ? storedWeightedRating
        : DriverRating.weightedScore(
            ratingTotal: ratingTotal,
            reviewCount: reviewCount,
          );
    final ratingRank = RideTrackingService._readInt(
      userData['driver_rating_rank'],
    );
    final computedBadge = DriverRating.badgeLabel(
      reviewCount: reviewCount,
      averageRating: rating,
      rank: ratingRank,
    );

    return AvailableDriver(
      driverId: driverId,
      fullName: fullName.isEmpty ? 'Verified driver' : fullName,
      profileImageUrl: RideTrackingService._profileImageUrlFromData(userData),
      isVerified: RideTrackingService._isVerifiedFlag(userData),
      supportsOnlinePayments: userData['accepts_online_payments'] == true,
      rating: rating,
      reviewCount: reviewCount,
      weightedRating: weightedRating,
      ratingRank: ratingRank,
      ratingBadge:
          RideTrackingService._readNullableString(
            userData['driver_rating_badge'],
          ) ??
          computedBadge,
      location: location,
      vehicleType: RideTrackingService._readNullableString(
        userData['vehicle_type'],
      ),
      tricycleColor: RideTrackingService._readNullableString(
        userData['tricycle_color'],
      ),
      plateNumber: RideTrackingService._readNullableString(
        userData['plate_number'],
      ),
      tricycleFrontUrl: RideTrackingService._readNullableString(
        userData['tricycle_front_url'],
      ),
      tricycleBackUrl: RideTrackingService._readNullableString(
        userData['tricycle_back_url'],
      ),
    );
  }

  String get vehicleSummary {
    final parts = <String>[
      if (vehicleType != null && vehicleType!.trim().isNotEmpty)
        vehicleType!.trim(),
      if (tricycleColor != null && tricycleColor!.trim().isNotEmpty)
        tricycleColor!.trim(),
      if (plateNumber != null && plateNumber!.trim().isNotEmpty)
        plateNumber!.trim(),
    ];
    if (parts.isEmpty) return 'Tricycle details unassigned';
    return parts.join(' • ');
  }

  bool get hasVehicleInfo =>
      (vehicleType != null && vehicleType!.trim().isNotEmpty) ||
      (tricycleColor != null && tricycleColor!.trim().isNotEmpty) ||
      (plateNumber != null && plateNumber!.trim().isNotEmpty) ||
      (tricycleFrontUrl != null && tricycleFrontUrl!.trim().isNotEmpty) ||
      (tricycleBackUrl != null && tricycleBackUrl!.trim().isNotEmpty);

  String get ratingLabel =>
      reviewCount == 0 ? 'No ratings' : rating.toStringAsFixed(1);

  String get reviewCountLabel =>
      '$reviewCount review${reviewCount == 1 ? '' : 's'}';

  String get displayBadge => ratingBadge.isNotEmpty
      ? ratingBadge
      : DriverRating.badgeLabel(
          reviewCount: reviewCount,
          averageRating: rating,
          rank: ratingRank,
        );

  static double _readRating(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
