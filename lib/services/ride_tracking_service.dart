import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/distance_matrix_result.dart';
import '../models/fare_estimate.dart';
import '../models/passenger_payment_method.dart';
import '../models/ride.dart';
import '../models/ride_driver_location.dart';
import '../models/ride_location.dart';
import '../models/ride_status.dart';
import '../models/route_result.dart';
import 'fare_service.dart';

class RideTrackingService {
  RideTrackingService({FirebaseFirestore? firestore, FareService? fareService})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _fareService = fareService ?? const FareService();

  static const Duration driverAvailabilityTimeout = Duration(minutes: 15);

  final FirebaseFirestore _firestore;
  final FareService _fareService;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _driverLocations =>
      _firestore.collection('driver_locations');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

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
    final paymentStatus = selectedPaymentMethod.usesOnlineCheckout
        ? 'checkout_pending'
        : 'cash_pending';
    final passengerFareProfile = await loadPassengerFareProfile(passengerId);
    final bookingFareEstimate = _fareService.estimateFare(
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      distanceMeters: estimate?.distanceMeters ?? route.distanceMeters,
      studentDiscountEligible: passengerFareProfile.isVerifiedStudent,
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
      'fare': bookingFareEstimate.amount,
      'base_fare': bookingFareEstimate.baseAmount,
      'estimated_fare': bookingFareEstimate.amount,
      'estimated_fare_amount': bookingFareEstimate.amount,
      'estimated_fare_currency': bookingFareEstimate.currency,
      'final_fare': bookingFareEstimate.amount,
      'fare_rule': bookingFareEstimate.ruleLabel,
      'fare_rule_code': bookingFareEstimate.ruleCode,
      'fare_details': bookingFareEstimate.toFirestore(),
      'fare_discount_applied': bookingFareEstimate.hasDiscount,
      'fare_discount_amount': bookingFareEstimate.discountAmount,
      'fare_discount_rate': bookingFareEstimate.discountRate,
      if (bookingFareEstimate.discountCode != null)
        'fare_discount_code': bookingFareEstimate.discountCode,
      if (bookingFareEstimate.discountLabel != null)
        'fare_discount_label': bookingFareEstimate.discountLabel,
      'payment_method': selectedPaymentMethod.type.firestoreValue,
      'payment_method_label': selectedPaymentMethod.displayLabel,
      'payment_method_id': selectedPaymentMethod.isCash
          ? null
          : selectedPaymentMethod.id,
      'payment_provider': selectedPaymentMethod.provider,
      'payment_status': paymentStatus,
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
            if (!_hasCoordinates(locationData)) {
              continue;
            }

            if (_isStaleDriverLocation(locationData)) {
              continue;
            }

            final location = RideDriverLocation.fromMap(locationData);
            final driverId = location.driverId.isNotEmpty
                ? location.driverId
                : document.id;
            final userDoc = await _users.doc(driverId).get();
            final userData = userDoc.data() ?? <String, dynamic>{};
            final isVerified =
                (userData['is_verified'] ?? userData['isVerified'] ?? false) ==
                true;
            final isBanned =
                (userData['is_banned'] ?? userData['isBanned'] ?? false) ==
                true;

            if (!userDoc.exists ||
                userData['role'] != 'driver' ||
                !isVerified ||
                isBanned) {
              continue;
            }

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

  Stream<Ride?> watchRide(String bookingId) {
    return _bookings.doc(bookingId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return Ride.fromDocument(snapshot);
    });
  }

  Stream<List<Ride>> watchOpenBookings({String? driverId}) {
    return _bookings
        .where('status', isEqualTo: RideStatus.searching.firestoreValue)
        .snapshots()
        .map((snapshot) {
          final rides = snapshot.docs.map(Ride.fromDocument).where((ride) {
            final preferredDriverId = ride.preferredDriverId;
            if (driverId == null) {
              return true;
            }

            if (ride.declinedDriverIds.contains(driverId)) {
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
            }

            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return aDate.compareTo(bDate);
          });
          return rides;
        });
  }

  Stream<List<Ride>> watchDriverActiveRides(String driverId) {
    return _bookings
        .where('driver_id', isEqualTo: driverId)
        .where(
          'status',
          whereIn: <String>[
            RideStatus.accepted.firestoreValue,
            RideStatus.driverArriving.firestoreValue,
            RideStatus.arrived.firestoreValue,
            RideStatus.inProgress.firestoreValue,
          ],
        )
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

  Stream<List<DriverRecentTrip>> watchDriverRecentTrips(String driverId) {
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

          final recentRides = rides.take(8).toList(growable: false);
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

  Stream<DriverReviewProfile> watchDriverProfile(String driverId) {
    return _users.doc(driverId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw StateError('Driver profile not found.');
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      return DriverReviewProfile.fromData(driverId: driverId, data: data);
    });
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
          bookingRide?.status.isTerminal != true) {
        throw StateError('Only completed or cancelled trips can be reviewed.');
      }

      final existingReview = await transaction.get(reviewRef);
      final passengerSnapshot = await transaction.get(passengerRef);
      final driverSnapshot = await transaction.get(driverRef);
      final passengerData = passengerSnapshot.data() ?? <String, dynamic>{};
      final driverData = driverSnapshot.data() ?? <String, dynamic>{};
      final previousRating = existingReview.exists
          ? _readInt(existingReview.data()?['rating'])
          : null;
      final currentTotal =
          _readInt(driverData['driver_review_rating_total']) ??
          _readInt(driverData['review_rating_total']) ??
          0;
      final currentCount =
          _readInt(driverData['driver_review_count']) ??
          _readInt(driverData['review_count']) ??
          0;
      final nextTotal = currentTotal - (previousRating ?? 0) + rating;
      final nextCount = previousRating == null
          ? currentCount + 1
          : currentCount;
      final nextAverage = nextCount == 0 ? 0 : nextTotal / nextCount;
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
        'updated_at': now,
        if (!existingReview.exists) 'created_at': now,
      }, SetOptions(merge: true));

      transaction.update(bookingRef, <String, dynamic>{
        'passenger_driver_review': <String, dynamic>{
          'rating': rating,
          'comment': trimmedComment,
          'reviewer_id': passengerId,
          'reviewee_id': driverId,
          'updated_at': Timestamp.now(),
        },
        'updated_at': now,
      });

      transaction.set(driverRef, <String, dynamic>{
        'driver_review_rating_total': nextTotal,
        'driver_review_count': nextCount,
        'driver_average_rating': nextAverage,
        'review_rating_total': nextTotal,
        'review_count': nextCount,
        'average_rating': nextAverage,
        'updated_at': now,
      }, SetOptions(merge: true));
    });
  }

  Future<void> reportDriver({
    required String bookingId,
    required String passengerId,
    required String driverId,
    required String reason,
    required String details,
  }) async {
    final trimmedReason = reason.trim();
    final trimmedDetails = details.trim();

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

    final bookingSnapshot = await _bookings.doc(bookingId).get();
    final bookingData = bookingSnapshot.data() ?? <String, dynamic>{};
    if (!bookingSnapshot.exists ||
        bookingData['passenger_id'] != passengerId ||
        bookingData['driver_id'] != driverId) {
      throw StateError('Reports must be connected to your driver trip.');
    }

    final reportRef = _firestore.collection('reports').doc();
    final now = FieldValue.serverTimestamp();
    await reportRef.set(<String, dynamic>{
      'report_id': reportRef.id,
      'booking_id': bookingId,
      'reporter_id': passengerId,
      'reporter_role': 'passenger',
      'reported_user_id': driverId,
      'reported_user_role': 'driver',
      'reason': trimmedReason,
      'details': trimmedDetails,
      'status': 'open',
      'created_at': now,
      'updated_at': now,
    });
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
    final passengerRef = _users.doc(passengerId);

    await _firestore.runTransaction((transaction) async {
      final existingReview = await transaction.get(reviewRef);
      final driverSnapshot = await transaction.get(driverRef);
      final passengerSnapshot = await transaction.get(passengerRef);
      final driverData = driverSnapshot.data() ?? <String, dynamic>{};
      final passengerData = passengerSnapshot.data() ?? <String, dynamic>{};
      final previousRating = existingReview.exists
          ? _readInt(existingReview.data()?['rating'])
          : null;
      final currentTotal = _readInt(passengerData['review_rating_total']) ?? 0;
      final currentCount = _readInt(passengerData['review_count']) ?? 0;
      final nextTotal = currentTotal - (previousRating ?? 0) + rating;
      final nextCount = previousRating == null
          ? currentCount + 1
          : currentCount;
      final nextAverage = nextCount == 0 ? 0 : nextTotal / nextCount;
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
        'updated_at': now,
        if (!existingReview.exists) 'created_at': now,
      }, SetOptions(merge: true));

      transaction.update(bookingRef, <String, dynamic>{
        'driver_passenger_review': <String, dynamic>{
          'rating': rating,
          'reviewer_id': driverId,
          'reviewee_id': passengerId,
          'updated_at': Timestamp.now(),
        },
        'updated_at': now,
      });

      transaction.set(passengerRef, <String, dynamic>{
        'review_rating_total': nextTotal,
        'review_count': nextCount,
        'average_rating': nextAverage,
        'passenger_average_rating': nextAverage,
        'passenger_review_count': nextCount,
        'updated_at': now,
      }, SetOptions(merge: true));
    });
  }

  Future<void> acceptBooking({
    required String bookingId,
    required String driverId,
  }) async {
    final doc = _bookings.doc(bookingId);
    final driverDoc = _firestore.collection('users').doc(driverId);
    final driverLocationDoc = _driverLocations.doc(driverId);

    await _firestore.runTransaction((transaction) async {
      final driverSnapshot = await transaction.get(driverDoc);
      final driverData = driverSnapshot.data() ?? <String, dynamic>{};
      final isVerifiedDriver =
          driverSnapshot.exists &&
          driverData['role'] == 'driver' &&
          (driverData['is_verified'] ?? driverData['isVerified'] ?? false) ==
              true &&
          (driverData['is_banned'] ?? driverData['isBanned'] ?? false) != true;

      if (!isVerifiedDriver) {
        throw StateError('Only verified drivers can accept bookings.');
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
      if (declinedDriverIds.contains(driverId)) {
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
      if ((paymentProvider == 'paymongo' || paymentProvider == 'xendit') &&
          driverData['accepts_online_payments'] != true) {
        throw StateError(
          'Add a driver payout account before accepting online payments.',
        );
      }

      final driverLocationSnapshot = await transaction.get(driverLocationDoc);
      final driverLocationData =
          driverLocationSnapshot.data() ?? <String, dynamic>{};
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
        'status_history': FieldValue.arrayUnion(<Map<String, dynamic>>[
          <String, dynamic>{
            'status': RideStatus.accepted.firestoreValue,
            'changed_by': driverId,
            'changed_at': Timestamp.now(),
          },
        ]),
      };

      if (paymentProvider == 'paymongo' || paymentProvider == 'xendit') {
        bookingUpdates.addAll(<String, dynamic>{
          'driver_payout_status': paymentStatus == 'paid'
              ? 'pending'
              : 'awaiting_payment',
          'driver_payout_account_id': driverData['default_payout_account_id'],
          'driver_accepts_online_payments': true,
        });
      }

      transaction.update(doc, bookingUpdates);
      transaction.set(driverLocationDoc, <String, dynamic>{
        'driver_id': driverId,
        'is_available': false,
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
          driverData['role'] == 'driver' &&
          (driverData['is_verified'] ?? driverData['isVerified'] ?? false) ==
              true &&
          (driverData['is_banned'] ?? driverData['isBanned'] ?? false) != true;

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

      if (status == RideStatus.completed &&
          paymentProvider == 'cash' &&
          paymentStatus != 'cash_collected') {
        updates.addAll(<String, dynamic>{
          'payment_status': 'cash_collected',
          'payment_confirmed_by': changedBy,
          'payment_confirmed_at': FieldValue.serverTimestamp(),
        });
      }

      if (status == RideStatus.cancelled) {
        updates.addAll(<String, dynamic>{
          'cancelled_by': changedBy,
          'cancelled_at': FieldValue.serverTimestamp(),
        });
      }

      transaction.update(bookingRef, updates);
    });
  }

  Future<void> updateDriverAvailability({
    required String driverId,
    required bool isAvailable,
    String? activeBookingId,
  }) async {
    if (isAvailable) {
      await _ensureVerifiedDriver(driverId);
    }

    return _driverLocations.doc(driverId).set(<String, dynamic>{
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
    final driverLocation = RideDriverLocation(
      driverId: driverId,
      latitude: position.latitude,
      longitude: position.longitude,
      heading: position.heading.isNaN ? null : position.heading,
      speed: position.speed.isNaN ? null : position.speed,
      accuracy: position.accuracy.isNaN ? null : position.accuracy,
    );
    final locationData = driverLocation.toFirestore();
    final batch = _firestore.batch();

    batch.set(_driverLocations.doc(driverId), <String, dynamic>{
      ...locationData,
      'is_available': isAvailable,
      'active_booking_id': activeBookingId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (activeBookingId != null && activeBookingId.isNotEmpty) {
      batch.update(_bookings.doc(activeBookingId), <String, dynamic>{
        'driver_location': locationData,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> _ensureVerifiedDriver(String driverId) async {
    final snapshot = await _firestore.collection('users').doc(driverId).get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final isVerifiedDriver =
        snapshot.exists &&
        data['role'] == 'driver' &&
        (data['is_verified'] ?? data['isVerified'] ?? false) == true &&
        (data['is_banned'] ?? data['isBanned'] ?? false) != true;

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
        : rawRole == 'student'
        ? 'student'
        : 'regular';

    return PassengerFareProfile(
      userId: userId,
      passengerType: passengerType == 'student' ? 'student' : 'regular',
      isVerified:
          (data['is_verified'] ??
              data['isVerified'] ??
              data['isVerrified'] ??
              false) ==
          true,
    );
  }

  bool get isStudent => passengerType == 'student';
  bool get isVerifiedStudent => isStudent && isVerified;
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

  const DriverReviewProfile({
    required this.driverId,
    required this.fullName,
    required this.isVerified,
    required this.isActive,
    required this.isBanned,
    required this.profileImageUrl,
    required this.averageRating,
    required this.reviewCount,
  });

  factory DriverReviewProfile.fromData({
    required String driverId,
    required Map<String, dynamic> data,
  }) {
    return DriverReviewProfile(
      driverId: driverId,
      fullName: RideTrackingService._fullNameFromData(data, fallback: 'Driver'),
      isVerified: (data['is_verified'] ?? data['isVerified'] ?? false) == true,
      isActive: (data['is_active'] ?? data['isActive'] ?? false) == true,
      isBanned: (data['is_banned'] ?? data['isBanned'] ?? false) == true,
      profileImageUrl: RideTrackingService._readNullableString(
        data['selfie_url'] ?? data['profile_image_url'],
      ),
      averageRating: RideTrackingService._readDouble(
        data['driver_average_rating'] ??
            data['average_rating'] ??
            data['rating'] ??
            data['ratings'],
      ),
      reviewCount:
          RideTrackingService._readInt(
            data['driver_review_count'] ?? data['review_count'],
          ) ??
          0,
    );
  }

  String get ratingLabel =>
      reviewCount == 0 ? 'No ratings yet' : averageRating.toStringAsFixed(1);
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
        : rawRole == 'student'
        ? 'student'
        : 'regular';
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
      passengerType: resolvedType == 'student' ? 'student' : 'regular',
      isVerified: (data['is_verified'] ?? data['isVerified'] ?? false) == true,
      profileImageUrl: _readNullableString(
        data['selfie_url'] ?? data['id_image_url'],
      ),
      averageRating: averageRating > 0
          ? averageRating
          : reviewCount == 0
          ? 0
          : ratingTotal / reviewCount,
      reviewCount: reviewCount,
    );
  }

  String get roleLabel => passengerType == 'student' ? 'Student' : 'Regular';

  String get ratingLabel =>
      reviewCount == 0 ? 'No ratings yet' : averageRating.toStringAsFixed(1);

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }
}

class AvailableDriver {
  final String driverId;
  final String fullName;
  final String? profileImageUrl;
  final bool isVerified;
  final bool supportsOnlinePayments;
  final double rating;
  final RideDriverLocation location;

  const AvailableDriver({
    required this.driverId,
    required this.fullName,
    required this.profileImageUrl,
    required this.isVerified,
    required this.supportsOnlinePayments,
    required this.rating,
    required this.location,
  });

  factory AvailableDriver.fromData({
    required String driverId,
    required RideDriverLocation location,
    required Map<String, dynamic> userData,
  }) {
    final firstName = (userData['first_name'] ?? '').toString().trim();
    final lastName = (userData['last_name'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();

    return AvailableDriver(
      driverId: driverId,
      fullName: fullName.isEmpty ? 'Verified driver' : fullName,
      profileImageUrl: _readNullableString(userData['selfie_url']),
      isVerified:
          (userData['is_verified'] ?? userData['isVerified'] ?? false) == true,
      supportsOnlinePayments: userData['accepts_online_payments'] == true,
      rating: _readRating(
        userData['driver_average_rating'] ??
            userData['average_rating'] ??
            userData['rating'] ??
            userData['ratings'],
      ),
      location: location,
    );
  }

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double _readRating(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 5.0;
  }
}
