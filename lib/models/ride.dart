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
  final List<String> declinedDriverIds;
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
  final DateTime? completedAt;
  final String? cancelledBy;
  final DateTime? cancelledAt;
  final String? fareLabel;
  final int? fareAmount;
  final String? fareRuleLabel;
  final int? grossFare;
  final double? commissionRate;
  final int? commissionAmount;
  final int? driverNetEarnings;
  final String? driverPayoutStatus;
  final String paymentMethod;
  final String? paymentMethodLabel;
  final String? paymentMethodId;
  final String? paymentMethodType;
  final String paymentProvider;
  final String paymentStatus;
  final String? xenditInvoiceId;
  final String? checkoutUrl;
  final int? driverPassengerReviewRating;
  final int? passengerDriverReviewRating;
  final String? passengerDriverReviewComment;

  const Ride({
    required this.bookingId,
    required this.passengerId,
    required this.driverId,
    required this.preferredDriverId,
    required this.declinedDriverIds,
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
    required this.completedAt,
    required this.cancelledBy,
    required this.cancelledAt,
    required this.fareLabel,
    required this.fareAmount,
    required this.fareRuleLabel,
    required this.grossFare,
    required this.commissionRate,
    required this.commissionAmount,
    required this.driverNetEarnings,
    required this.driverPayoutStatus,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.paymentMethodId,
    required this.paymentMethodType,
    required this.paymentProvider,
    required this.paymentStatus,
    required this.xenditInvoiceId,
    required this.checkoutUrl,
    required this.driverPassengerReviewRating,
    required this.passengerDriverReviewRating,
    required this.passengerDriverReviewComment,
  });

  bool get hasDriver => driverId != null && driverId!.isNotEmpty;
  bool get isActive => !status.isTerminal;
  bool get hasPassengerDriverReview => passengerDriverReviewRating != null;
  bool get hasDriverPassengerReview => driverPassengerReviewRating != null;
  bool get canPassengerReviewDriver =>
      status == RideStatus.completed && hasDriver && !hasPassengerDriverReview;
  bool get canDriverReviewPassenger =>
      status == RideStatus.completed && !hasDriverPassengerReview;

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
    if (status == RideStatus.arrived) {
      return 'Arrived';
    }

    if (status == RideStatus.completed || status == RideStatus.cancelled) {
      return status.label;
    }

    final seconds = switch (status) {
      RideStatus.searching => estimatedDurationSeconds,
      RideStatus.accepted ||
      RideStatus.driverArriving => driverToPickupDurationSeconds,
      RideStatus.inProgress => remainingRideDurationSeconds,
      RideStatus.arrived ||
      RideStatus.completed ||
      RideStatus.cancelled => null,
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
      declinedDriverIds: _readStringList(data['declined_driver_ids']),
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
      completedAt: _readDate(data['completed_at']),
      cancelledBy: _readNullableString(data['cancelled_by']),
      cancelledAt: _readDate(data['cancelled_at']),
      fareLabel: _readFare(data),
      fareAmount: _readFareAmount(data),
      fareRuleLabel: _readNullableString(
        data['fare_rule'] ?? data['fare_rule_label'],
      ),
      grossFare: _readNullableInt(data['gross_fare']),
      commissionRate: _readNullableDouble(data['commission_rate']),
      commissionAmount: _readNullableInt(data['commission_amount']),
      driverNetEarnings: _readNullableInt(data['driver_net_earnings']),
      driverPayoutStatus: _readNullableString(data['driver_payout_status']),
      paymentMethod: _readNullableString(data['payment_method']) ?? 'cash',
      paymentMethodLabel: _readNullableString(data['payment_method_label']),
      paymentMethodId: _readNullableString(data['payment_method_id']),
      paymentMethodType: _readNullableString(data['payment_method_type']),
      paymentProvider: _readNullableString(data['payment_provider']) ?? 'cash',
      paymentStatus:
          _readNullableString(data['payment_status']) ?? 'cash_pending',
      xenditInvoiceId: _readNullableString(data['xendit_invoice_id']),
      checkoutUrl: _readNullableString(
        data['checkout_url'] ??
            data['xendit_checkout_url'] ??
            data['paymongo_checkout_url'],
      ),
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

  static List<String> _readStringList(Object? value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  static int? _readNullableInt(Object? value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static double? _readNullableDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
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

  static int? _readFareAmount(Map<String, dynamic> data) {
    final candidates = <Object?>[
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

  String get paymentMethodDisplayLabel {
    final label = paymentMethodLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }

    return switch (paymentMethod) {
      'gcash' => 'GCash',
      'maya' || 'paymaya' => 'Maya',
      'card' => 'Card',
      _ => 'Cash',
    };
  }

  String? get xenditPaymentMethodType {
    final explicitType = paymentMethodType?.trim();
    if (explicitType != null && explicitType.isNotEmpty) {
      return explicitType;
    }

    return switch (paymentMethod.trim().toLowerCase()) {
      'gcash' => 'GCASH',
      'maya' || 'paymaya' => 'PAYMAYA',
      'card' => 'CREDIT_CARD',
      _ => null,
    };
  }

  String get paymentStatusLabel {
    if (status == RideStatus.cancelled && paymentStatus != 'paid') {
      return 'No payment collected';
    }

    return switch (paymentStatus) {
      'paid' => 'Paid',
      'cash_collected' => 'Cash collected',
      'cash_cancelled' => 'No payment collected',
      'checkout_pending' => 'Checkout pending',
      'checkout_failed' => 'Checkout failed',
      'checkout_cancelled' => 'Checkout cancelled',
      'payment_cancelled' => 'Payment cancelled',
      'cash_pending' => 'Cash pending',
      _ => paymentStatus.replaceAll('_', ' '),
    };
  }

  bool get usesOnlineCheckout => paymentProvider == 'xendit';
  bool get isPaymentPaid =>
      paymentStatus == 'paid' || paymentStatus == 'cash_collected';

  int get grossEarningsAmount => grossFare ?? fareAmount ?? 0;

  double get appliedCommissionRate =>
      (commissionRate ?? 0).clamp(0.0, 1.0).toDouble();

  int get commissionDeductionAmount {
    final stored = commissionAmount;
    if (stored != null) {
      return stored.clamp(0, grossEarningsAmount);
    }

    return (grossEarningsAmount * appliedCommissionRate).round().clamp(
      0,
      grossEarningsAmount,
    );
  }

  int get netEarningsAmount =>
      driverNetEarnings ?? grossEarningsAmount - commissionDeductionAmount;

  String get grossEarningsLabel => 'PHP $grossEarningsAmount';
  String get commissionDeductionLabel => 'PHP $commissionDeductionAmount';
  String get netEarningsLabel => 'PHP $netEarningsAmount';

  String get commissionRateLabel {
    final percent = appliedCommissionRate * 100;
    final value = percent % 1 == 0
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
    return '$value%';
  }

  String get driverPayoutStatusLabel {
    final normalized = driverPayoutStatus?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'awaiting_payment' => 'Awaiting passenger payment',
      'awaiting_driver' => 'Awaiting driver assignment',
      'pending' => 'Payout pending',
      'processing' => 'Payout processing',
      'paid_out' || 'completed' => 'Paid out',
      'cash_collection_pending' => 'Collect cash from passenger',
      'cash_collected' => 'Cash collected',
      'cancelled' => 'No payout',
      'review_required' => 'Payout review required',
      _ when usesOnlineCheckout => 'Payout status unavailable',
      _ => isPaymentPaid ? 'Cash collected' : 'Cash ride',
    };
  }

  bool get isCashlessPayoutPending =>
      usesOnlineCheckout &&
      driverPayoutStatus != 'paid_out' &&
      driverPayoutStatus != 'completed' &&
      driverPayoutStatus != 'cancelled';

  bool wasCancelledBy(String userId) {
    final normalizedUserId = userId.trim();
    return normalizedUserId.isNotEmpty && cancelledBy == normalizedUserId;
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
