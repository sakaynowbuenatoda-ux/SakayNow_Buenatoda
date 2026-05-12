import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'ride_driver_location.dart';
import 'ride_location.dart';
import 'ride_status.dart';
import 'route_result.dart';

class Ride {
  final String bookingId;
  final String passengerId;
  final String? driverId;
  final String? preferredDriverId;
  final RideStatus status;
  final RideLocation pickupLocation;
  final RideLocation dropoffLocation;
  final RouteResult? route;
  final RideDriverLocation? driverLocation;
  final int? estimatedDistanceMeters;
  final int? estimatedDurationSeconds;
  final int? driverToPickupDistanceMeters;
  final int? driverToPickupDurationSeconds;
  final int? remainingRideDistanceMeters;
  final int? remainingRideDurationSeconds;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? fareLabel;
  final int? driverPassengerReviewRating;
  final int? passengerDriverReviewRating;
  final String? passengerDriverReviewComment;

  const Ride({
    required this.bookingId,
    required this.passengerId,
    required this.driverId,
    required this.preferredDriverId,
    required this.status,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.route,
    required this.driverLocation,
    required this.estimatedDistanceMeters,
    required this.estimatedDurationSeconds,
    required this.driverToPickupDistanceMeters,
    required this.driverToPickupDurationSeconds,
    required this.remainingRideDistanceMeters,
    required this.remainingRideDurationSeconds,
    required this.createdAt,
    required this.updatedAt,
    required this.fareLabel,
    required this.driverPassengerReviewRating,
    required this.passengerDriverReviewRating,
    required this.passengerDriverReviewComment,
  });

  bool get hasDriver => driverId != null && driverId!.isNotEmpty;
  bool get isActive => !status.isTerminal;

  String get distanceLabel {
    final meters = _distanceMetersForStatus;
    if (meters == null || meters <= 0) {
      return 'Calculating';
    }

    if (meters < 1000) {
      return '$meters m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  int? get _distanceMetersForStatus {
    return switch (status) {
      RideStatus.searching => estimatedDistanceMeters,
      RideStatus.accepted || RideStatus.driverArriving || RideStatus.arrived =>
        driverToPickupDistanceMeters ??
            _directDistanceMeters(
              driverLocation?.latLng,
              pickupLocation.latLng,
            ),
      RideStatus.inProgress =>
        remainingRideDistanceMeters ??
            _directDistanceMeters(
              driverLocation?.latLng,
              dropoffLocation.latLng,
            ) ??
            estimatedDistanceMeters,
      RideStatus.completed || RideStatus.cancelled => estimatedDistanceMeters,
    };
  }

  String get etaLabel {
    final seconds = switch (status) {
      RideStatus.searching => estimatedDurationSeconds,
      RideStatus.accepted ||
      RideStatus.driverArriving ||
      RideStatus.arrived => driverToPickupDurationSeconds,
      RideStatus.inProgress => remainingRideDurationSeconds,
      RideStatus.completed || RideStatus.cancelled => null,
    };

    if (seconds == null || seconds <= 0) {
      return 'Calculating';
    }

    final minutes = (seconds / 60).ceil();
    return minutes <= 1 ? '1 min' : '$minutes mins';
  }

  factory Ride.fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? <String, dynamic>{};
    final eta = data['eta'] is Map ? data['eta'] as Map : <String, dynamic>{};

    RideDriverLocation? driverLocation;
    if (data['driver_location'] is Map) {
      driverLocation = RideDriverLocation.fromMap(data['driver_location']);
    }

    final routeData = data['route'];

    return Ride(
      bookingId: (data['booking_id'] ?? document.id).toString(),
      passengerId: (data['passenger_id'] ?? '').toString(),
      driverId: _readNullableString(data['driver_id']),
      preferredDriverId: _readNullableString(data['preferred_driver_id']),
      status: rideStatusFromString(data['status']),
      pickupLocation: RideLocation.fromMap(data['pickup_location']),
      dropoffLocation: RideLocation.fromMap(data['dropoff_location']),
      route: routeData is Map ? RouteResult.fromMap(routeData) : null,
      driverLocation: driverLocation,
      estimatedDistanceMeters: _readNullableInt(
        data['estimated_distance_meters'],
      ),
      estimatedDurationSeconds: _readNullableInt(
        data['estimated_duration_seconds'],
      ),
      driverToPickupDistanceMeters: _readNullableInt(
        eta['driver_to_pickup_distance_meters'],
      ),
      driverToPickupDurationSeconds: _readNullableInt(
        eta['driver_to_pickup_duration_seconds'],
      ),
      remainingRideDistanceMeters: _readNullableInt(
        eta['remaining_ride_distance_meters'],
      ),
      remainingRideDurationSeconds: _readNullableInt(
        eta['remaining_ride_duration_seconds'],
      ),
      createdAt: _readDate(data['created_at'] ?? data['timestamp']),
      updatedAt: _readDate(data['updated_at']),
      fareLabel: _readFare(data),
      driverPassengerReviewRating: _readReviewRating(
        data['driver_passenger_review'],
      ),
      passengerDriverReviewRating: _readReviewRating(
        data['passenger_driver_review'],
      ),
      passengerDriverReviewComment: _readReviewComment(
        data['passenger_driver_review'],
      ),
    );
  }

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _readNullableInt(Object? value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static int? _readReviewRating(Object? value) {
    if (value is Map) {
      final rating = _readNullableInt(value['rating']);
      if (rating != null && rating >= 1 && rating <= 5) {
        return rating;
      }
    }

    return null;
  }

  static String? _readReviewComment(Object? value) {
    if (value is Map) {
      final text =
          (value['comment'] ?? value['review'] ?? value['feedback'] ?? '')
              .toString()
              .trim();
      return text.isEmpty ? null : text;
    }

    return null;
  }

  static String? _readFare(Map<String, dynamic> data) {
    final candidates = <Object?>[
      data['fare'],
      data['fare_amount'],
      data['final_fare'],
      data['estimated_fare'],
    ];

    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }

      if (candidate is num) {
        return 'PHP ${candidate.toStringAsFixed(candidate % 1 == 0 ? 0 : 2)}';
      }

      final text = candidate.toString().trim();
      if (text.isNotEmpty) {
        return text.toUpperCase().startsWith('PHP') ? text : 'PHP $text';
      }
    }

    return null;
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

  static int? _directDistanceMeters(LatLng? origin, LatLng? destination) {
    if (origin == null || destination == null) {
      return null;
    }

    const earthRadiusMeters = 6371000.0;
    final originLatitude = _degreesToRadians(origin.latitude);
    final destinationLatitude = _degreesToRadians(destination.latitude);
    final latitudeDelta = _degreesToRadians(
      destination.latitude - origin.latitude,
    );
    final longitudeDelta = _degreesToRadians(
      destination.longitude - origin.longitude,
    );

    final haversine =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(originLatitude) *
            math.cos(destinationLatitude) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    final centralAngle =
        2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));

    return (earthRadiusMeters * centralAngle).round();
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
