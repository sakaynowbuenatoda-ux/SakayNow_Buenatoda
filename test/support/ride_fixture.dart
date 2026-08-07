import 'package:sakaynow_buenatoda/models/ride.dart';
import 'package:sakaynow_buenatoda/models/ride_location.dart';
import 'package:sakaynow_buenatoda/models/ride_status.dart';

Ride buildRideFixture({
  RideStatus status = RideStatus.searching,
  int? estimatedDistanceMeters = 3600,
  int? estimatedDurationSeconds = 900,
  int? driverToPickupDistanceMeters = 1200,
  int? driverToPickupDurationSeconds = 300,
  int? remainingRideDistanceMeters = 2400,
  int? remainingRideDurationSeconds = 480,
}) {
  return Ride(
    bookingId: 'booking-1',
    passengerId: 'passenger-1',
    driverId: 'driver-1',
    preferredDriverId: null,
    declinedDriverIds: const <String>[],
    status: status,
    pickupLocation: const RideLocation(
      address: 'Buenavista Plaza',
      latitude: 10.7000,
      longitude: 122.6260,
    ),
    dropoffLocation: const RideLocation(
      address: 'New Poblacion',
      latitude: 10.6800,
      longitude: 122.6400,
    ),
    route: null,
    driverLocation: null,
    estimatedDistanceMeters: estimatedDistanceMeters,
    estimatedDurationSeconds: estimatedDurationSeconds,
    driverToPickupDistanceMeters: driverToPickupDistanceMeters,
    driverToPickupDurationSeconds: driverToPickupDurationSeconds,
    remainingRideDistanceMeters: remainingRideDistanceMeters,
    remainingRideDurationSeconds: remainingRideDurationSeconds,
    createdAt: null,
    updatedAt: null,
    cancelledBy: null,
    cancelledAt: null,
    fareLabel: 'PHP 50',
    fareAmount: 50,
    fareRuleLabel: null,
    paymentMethod: 'cash',
    paymentMethodLabel: 'Cash',
    paymentMethodId: 'cash',
    paymentMethodType: 'cash',
    paymentProvider: 'cash',
    paymentStatus: 'cash_pending',
    xenditInvoiceId: null,
    checkoutUrl: null,
    driverPassengerReviewRating: null,
    passengerDriverReviewRating: null,
    passengerDriverReviewComment: null,
  );
}
