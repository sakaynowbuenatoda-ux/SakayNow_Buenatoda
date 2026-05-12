import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/distance_matrix_result.dart';
import '../models/ride.dart';
import '../models/ride_driver_location.dart';
import '../models/ride_location.dart';
import '../models/ride_status.dart';
import '../models/route_result.dart';

class RideTrackingService {
  RideTrackingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
    String paymentMethod = 'cash',
    String? preferredDriverId,
  }) async {
    final doc = _bookings.doc();
    final now = FieldValue.serverTimestamp();

    await doc.set(<String, dynamic>{
      'booking_id': doc.id,
      'passenger_id': passengerId,
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
      'payment_method': paymentMethod,
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
            return driverId == null ||
                preferredDriverId == null ||
                preferredDriverId == driverId;
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

  Stream<List<DriverReviewRecord>> watchDriverReviews(String driverId) {
    return _firestore
        .collection('reviews')
        .where('reviewee_id', isEqualTo: driverId)
        .snapshots()
        .asyncMap((snapshot) async {
          final reviews = <DriverReviewRecord>[];

          for (final document in snapshot.docs) {
            final data = document.data();
            final reviewerId = (data['reviewer_id'] ?? '').toString().trim();
            var reviewerName = 'Passenger';

            if (reviewerId.isNotEmpty) {
              final reviewerDoc = await _users.doc(reviewerId).get();
              final reviewerData = reviewerDoc.data() ?? <String, dynamic>{};
              reviewerName = _fullNameFromData(
                reviewerData,
                fallback: 'Passenger',
              );
            }

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
      final driverSnapshot = await transaction.get(driverRef);
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
      final now = FieldValue.serverTimestamp();

      transaction.set(reviewRef, <String, dynamic>{
        'review_id': reviewId,
        'booking_id': bookingId,
        'reviewer_id': passengerId,
        'reviewer_role': 'passenger',
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
    final passengerRef = _users.doc(passengerId);

    await _firestore.runTransaction((transaction) async {
      final existingReview = await transaction.get(reviewRef);
      final passengerSnapshot = await transaction.get(passengerRef);
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
      final now = FieldValue.serverTimestamp();

      transaction.set(reviewRef, <String, dynamic>{
        'review_id': reviewId,
        'booking_id': bookingId,
        'reviewer_id': driverId,
        'reviewer_role': 'driver',
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

      transaction.update(doc, <String, dynamic>{
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
      });
      transaction.set(driverLocationDoc, <String, dynamic>{
        'driver_id': driverId,
        'is_available': false,
        'active_booking_id': bookingId,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> updateRideStatus({
    required String bookingId,
    required RideStatus status,
    required String changedBy,
  }) async {
    await _bookings.doc(bookingId).update(<String, dynamic>{
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

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
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

  const PassengerReviewProfile({
    required this.userId,
    required this.fullName,
    required this.passengerType,
    required this.isVerified,
    required this.profileImageUrl,
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
    );
  }

  String get roleLabel => passengerType == 'student' ? 'Student' : 'Regular';

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
  final double rating;
  final RideDriverLocation location;

  const AvailableDriver({
    required this.driverId,
    required this.fullName,
    required this.profileImageUrl,
    required this.isVerified,
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
