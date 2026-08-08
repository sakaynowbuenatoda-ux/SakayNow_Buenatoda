import 'dart:math' as math;

import '../config/map_config.dart';
import '../models/fare_estimate.dart';
import '../models/fare_settings.dart';
import '../models/ride_location.dart';

class FareService {
  const FareService();

  static const int oneBarangayFare = FareSettings.defaultOneBarangayFare;
  static const int buenavistaFiveBarangayFare =
      FareSettings.defaultBuenavistaFiveBarangayFare;
  static const int outsideBuenavistaMinFare =
      FareSettings.defaultOutsideBuenavistaMinFare;
  static const int outsideBuenavistaMaxFare =
      FareSettings.defaultOutsideBuenavistaMaxFare;
  static const double barangayHopDistanceMeters = 1700;
  static const int oneBarangayRangeMeters = 2500;
  static const int driverPickupSurchargePerExtraBarangay =
      FareSettings.defaultDriverPickupSurchargePerExtraBarangay;
  static const int maxDriverPickupSurcharge =
      FareSettings.defaultMaxDriverPickupSurcharge;

  static const List<String> buenavistaBarangays = <String>[
    'Anonang',
    'Asinan',
    'Bago',
    'Baluarte',
    'Bantuan',
    'Bato',
    'Bonotbonot',
    'Bugaong',
    'Cambuhat',
    'Cambus-oc',
    'Cangawa',
    'Cantomugcad',
    'Cantores',
    'Cantuba',
    'Catigbian',
    'Cawag',
    'Cruz',
    'Dait',
    'Eastern Cabul-an',
    'Hunan',
    'Lapacan Norte',
    'Lapacan Sur',
    'Lubang',
    'Lusong',
    'Magkaya',
    'Merryland',
    'Nueva Granada',
    'Nueva Montana',
    'Overland',
    'Panghagban',
    'Poblacion',
    'Puting Bato',
    'Rufo Hill',
    'Sweetland',
    'Western Cabul-an',
  ];

  FareEstimate estimateFare({
    required RideLocation pickupLocation,
    required RideLocation dropoffLocation,
    required int distanceMeters,
    String passengerType = 'regular',
    bool passengerIsVerified = false,
    bool studentDiscountEligible = false,
    FareSettings settings = FareSettings.defaults,
    int? driverToPickupDistanceMeters,
  }) {
    final activeSettings = settings.normalized();
    final activePassengerType = studentDiscountEligible
        ? 'student'
        : _normalizePassengerType(passengerType);
    final normalizedDistance = distanceMeters < 0 ? 0 : distanceMeters;
    final normalizedDriverDistance =
        driverToPickupDistanceMeters == null || driverToPickupDistanceMeters < 0
        ? null
        : driverToPickupDistanceMeters;
    final driverPickupHopEstimate = driverPickupBarangayHopsForDistance(
      normalizedDriverDistance,
    );
    final driverPickupSurcharge = driverPickupSurchargeForDistance(
      normalizedDriverDistance,
      settings: activeSettings,
    );
    final pickupBarangay = detectBuenavistaBarangay(pickupLocation);
    final dropoffBarangay = detectBuenavistaBarangay(dropoffLocation);
    final outsideBuenavista =
        !_isBuenavistaLocation(pickupLocation, pickupBarangay) ||
        !_isBuenavistaLocation(dropoffLocation, dropoffBarangay);
    final hopEstimate = _estimateBarangayHops(
      distanceMeters: normalizedDistance,
      pickupBarangay: pickupBarangay,
      dropoffBarangay: dropoffBarangay,
      outsideBuenavista: outsideBuenavista,
    );

    if (!outsideBuenavista && hopEstimate <= 1) {
      return _applyDiscounts(
        FareEstimate(
          amount: activeSettings.oneBarangayFare + driverPickupSurcharge,
          currency: activeSettings.currency,
          ruleCode: 'buenavista_one_barangay',
          ruleLabel: 'Buenavista 1 barangay',
          distanceMeters: normalizedDistance,
          barangayHopEstimate: hopEstimate,
          isOutsideBuenavista: false,
          pickupBarangay: pickupBarangay,
          dropoffBarangay: dropoffBarangay,
          driverPickupSurcharge: driverPickupSurcharge,
          driverToPickupDistanceMeters: normalizedDriverDistance,
          driverPickupBarangayHopEstimate: driverPickupHopEstimate,
        ),
        studentDiscountEligible: studentDiscountEligible,
        passengerType: activePassengerType,
        passengerIsVerified: passengerIsVerified,
        settings: activeSettings,
      );
    }

    if (!outsideBuenavista && hopEstimate <= 5) {
      return _applyDiscounts(
        FareEstimate(
          amount:
              activeSettings.buenavistaFiveBarangayFare + driverPickupSurcharge,
          currency: activeSettings.currency,
          ruleCode: 'buenavista_up_to_five_barangays',
          ruleLabel: 'Buenavista up to 5 barangays',
          distanceMeters: normalizedDistance,
          barangayHopEstimate: hopEstimate,
          isOutsideBuenavista: false,
          pickupBarangay: pickupBarangay,
          dropoffBarangay: dropoffBarangay,
          driverPickupSurcharge: driverPickupSurcharge,
          driverToPickupDistanceMeters: normalizedDriverDistance,
          driverPickupBarangayHopEstimate: driverPickupHopEstimate,
        ),
        studentDiscountEligible: studentDiscountEligible,
        passengerType: activePassengerType,
        passengerIsVerified: passengerIsVerified,
        settings: activeSettings,
      );
    }

    return _applyDiscounts(
      FareEstimate(
        amount:
            _distanceFare(normalizedDistance, activeSettings) +
            driverPickupSurcharge,
        currency: activeSettings.currency,
        ruleCode: outsideBuenavista
            ? 'outside_buenavista_distance'
            : 'buenavista_extended_distance',
        ruleLabel: outsideBuenavista
            ? 'Outside Buenavista distance fare'
            : 'Buenavista extended distance fare',
        distanceMeters: normalizedDistance,
        barangayHopEstimate: hopEstimate,
        isOutsideBuenavista: outsideBuenavista,
        pickupBarangay: pickupBarangay,
        dropoffBarangay: dropoffBarangay,
        driverPickupSurcharge: driverPickupSurcharge,
        driverToPickupDistanceMeters: normalizedDriverDistance,
        driverPickupBarangayHopEstimate: driverPickupHopEstimate,
      ),
      studentDiscountEligible: studentDiscountEligible,
      passengerType: activePassengerType,
      passengerIsVerified: passengerIsVerified,
      settings: activeSettings,
    );
  }

  FareEstimate _applyDiscounts(
    FareEstimate estimate, {
    required bool studentDiscountEligible,
    required String passengerType,
    required bool passengerIsVerified,
    required FareSettings settings,
  }) {
    final discount = switch (passengerType) {
      'student' => (
        isEligible: studentDiscountEligible || passengerIsVerified,
        rate: settings.studentDiscountRate,
        code: FareEstimate.studentDiscountCode,
        label: 'student',
      ),
      'senior_citizen' => (
        isEligible: passengerIsVerified,
        rate: settings.seniorCitizenDiscountRate,
        code: FareEstimate.seniorCitizenDiscountCode,
        label: 'senior citizen',
      ),
      _ => (
        isEligible: true,
        rate: settings.regularPassengerDiscountRate,
        code: FareEstimate.regularPassengerDiscountCode,
        label: 'regular passenger',
      ),
    };

    return estimate.applyDiscount(
      isEligible: discount.isEligible,
      discountRate: discount.rate,
      discountCode: discount.code,
      discountLabel:
          '${_formatDiscountPercent(discount.rate)}% ${discount.label} discount',
    );
  }

  String? detectBuenavistaBarangay(RideLocation location) {
    final searchable = <String>[
      location.name ?? '',
      location.address,
      location.displayLabel,
    ].join(' ').toLowerCase();

    for (final barangay in buenavistaBarangays) {
      if (searchable.contains(_normalize(barangay))) {
        return barangay;
      }
    }

    return null;
  }

  bool _isBuenavistaLocation(RideLocation location, String? barangay) {
    if (barangay != null) {
      return true;
    }

    final label = '${location.name ?? ''} ${location.address}'.toLowerCase();
    if (label.contains('buenavista')) {
      return true;
    }

    final coordinates = location.latLng;
    if (coordinates == null) {
      return false;
    }

    return MapConfig.supportedServiceAreas
        .where((area) => area.name.toLowerCase() == 'buenavista')
        .any(
          (area) =>
              _distanceBetweenMeters(
                coordinates.latitude,
                coordinates.longitude,
                area.center.latitude,
                area.center.longitude,
              ) <=
              area.searchRadiusMeters,
        );
  }

  int _estimateBarangayHops({
    required int distanceMeters,
    required String? pickupBarangay,
    required String? dropoffBarangay,
    required bool outsideBuenavista,
  }) {
    if (!outsideBuenavista &&
        pickupBarangay != null &&
        pickupBarangay == dropoffBarangay) {
      return 1;
    }

    return _estimateDistanceBarangayHops(distanceMeters);
  }

  int driverPickupSurchargeForDistance(
    int? distanceMeters, {
    FareSettings settings = FareSettings.defaults,
  }) {
    final extraBarangayHops =
        driverPickupBarangayHopsForDistance(distanceMeters) - 1;
    if (extraBarangayHops <= 0) {
      return 0;
    }

    return math.min(
      extraBarangayHops * settings.driverPickupSurchargePerExtraBarangay,
      settings.maxDriverPickupSurcharge,
    );
  }

  int driverPickupBarangayHopsForDistance(int? distanceMeters) {
    if (distanceMeters == null || distanceMeters <= 0) {
      return 1;
    }

    return _estimateDistanceBarangayHops(distanceMeters);
  }

  int _estimateDistanceBarangayHops(int distanceMeters) {
    if (distanceMeters <= oneBarangayRangeMeters) {
      return 1;
    }

    return (distanceMeters / barangayHopDistanceMeters).ceil().clamp(1, 99);
  }

  int _distanceFare(int distanceMeters, FareSettings settings) {
    if (distanceMeters <= 6000) {
      return settings.outsideBuenavistaMinFare;
    }

    if (distanceMeters <= 9000) {
      return settings.outsideBuenavistaNineKmFare;
    }

    if (distanceMeters <= 12000) {
      return settings.outsideBuenavistaTwelveKmFare;
    }

    if (distanceMeters <= 16000) {
      return settings.outsideBuenavistaSixteenKmFare;
    }

    return settings.outsideBuenavistaMaxFare;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizePassengerType(String value) {
    return switch (value.trim().toLowerCase()) {
      'student' => 'student',
      'senior' || 'senior citizen' || 'senior_citizen' => 'senior_citizen',
      _ => 'regular',
    };
  }

  String _formatDiscountPercent(double rate) {
    final percent = rate.clamp(0.0, 1.0).toDouble() * 100;
    return percent % 1 == 0
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
  }

  double _distanceBetweenMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadiusMeters = 6371000.0;
    final startLat = _degreesToRadians(startLatitude);
    final endLat = _degreesToRadians(endLatitude);
    final latitudeDelta = _degreesToRadians(endLatitude - startLatitude);
    final longitudeDelta = _degreesToRadians(endLongitude - startLongitude);
    final haversine =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(startLat) *
            math.cos(endLat) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    final centralAngle =
        2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
    return earthRadiusMeters * centralAngle;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
