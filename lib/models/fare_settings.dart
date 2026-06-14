import 'package:cloud_firestore/cloud_firestore.dart';

class FareSettings {
  static const String defaultCurrency = 'PHP';
  static const int defaultOneBarangayFare = 25;
  static const int defaultBuenavistaFiveBarangayFare = 30;
  static const int defaultOutsideBuenavistaMinFare = 30;
  static const int defaultOutsideBuenavistaNineKmFare = 40;
  static const int defaultOutsideBuenavistaTwelveKmFare = 60;
  static const int defaultOutsideBuenavistaSixteenKmFare = 80;
  static const int defaultOutsideBuenavistaMaxFare = 100;
  static const double defaultStudentDiscountRate = 0.15;

  static const FareSettings defaults = FareSettings(
    currency: defaultCurrency,
    oneBarangayFare: defaultOneBarangayFare,
    buenavistaFiveBarangayFare: defaultBuenavistaFiveBarangayFare,
    outsideBuenavistaMinFare: defaultOutsideBuenavistaMinFare,
    outsideBuenavistaNineKmFare: defaultOutsideBuenavistaNineKmFare,
    outsideBuenavistaTwelveKmFare: defaultOutsideBuenavistaTwelveKmFare,
    outsideBuenavistaSixteenKmFare: defaultOutsideBuenavistaSixteenKmFare,
    outsideBuenavistaMaxFare: defaultOutsideBuenavistaMaxFare,
    studentDiscountRate: defaultStudentDiscountRate,
  );

  final String currency;
  final int oneBarangayFare;
  final int buenavistaFiveBarangayFare;
  final int outsideBuenavistaMinFare;
  final int outsideBuenavistaNineKmFare;
  final int outsideBuenavistaTwelveKmFare;
  final int outsideBuenavistaSixteenKmFare;
  final int outsideBuenavistaMaxFare;
  final double studentDiscountRate;
  final DateTime? updatedAt;
  final String? updatedBy;

  const FareSettings({
    this.currency = defaultCurrency,
    required this.oneBarangayFare,
    required this.buenavistaFiveBarangayFare,
    required this.outsideBuenavistaMinFare,
    required this.outsideBuenavistaNineKmFare,
    required this.outsideBuenavistaTwelveKmFare,
    required this.outsideBuenavistaSixteenKmFare,
    required this.outsideBuenavistaMaxFare,
    required this.studentDiscountRate,
    this.updatedAt,
    this.updatedBy,
  });

  factory FareSettings.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    if (!document.exists) {
      return defaults;
    }

    return FareSettings.fromMap(document.data() ?? <String, dynamic>{});
  }

  factory FareSettings.fromMap(Map<String, dynamic> data) {
    return FareSettings(
      currency: _readString(data['currency'], defaultCurrency),
      oneBarangayFare: _readInt(
        data['one_barangay_fare'],
        defaultOneBarangayFare,
      ),
      buenavistaFiveBarangayFare: _readInt(
        data['buenavista_five_barangay_fare'],
        defaultBuenavistaFiveBarangayFare,
      ),
      outsideBuenavistaMinFare: _readInt(
        data['outside_buenavista_min_fare'],
        defaultOutsideBuenavistaMinFare,
      ),
      outsideBuenavistaNineKmFare: _readInt(
        data['outside_buenavista_9km_fare'],
        defaultOutsideBuenavistaNineKmFare,
      ),
      outsideBuenavistaTwelveKmFare: _readInt(
        data['outside_buenavista_12km_fare'],
        defaultOutsideBuenavistaTwelveKmFare,
      ),
      outsideBuenavistaSixteenKmFare: _readInt(
        data['outside_buenavista_16km_fare'],
        defaultOutsideBuenavistaSixteenKmFare,
      ),
      outsideBuenavistaMaxFare: _readInt(
        data['outside_buenavista_max_fare'],
        defaultOutsideBuenavistaMaxFare,
      ),
      studentDiscountRate: _readDouble(
        data['student_discount_rate'],
        defaultStudentDiscountRate,
      ),
      updatedAt: _readDate(data['updated_at']),
      updatedBy: _readNullableString(data['updated_by']),
    ).normalized();
  }

  FareSettings copyWith({
    String? currency,
    int? oneBarangayFare,
    int? buenavistaFiveBarangayFare,
    int? outsideBuenavistaMinFare,
    int? outsideBuenavistaNineKmFare,
    int? outsideBuenavistaTwelveKmFare,
    int? outsideBuenavistaSixteenKmFare,
    int? outsideBuenavistaMaxFare,
    double? studentDiscountRate,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return FareSettings(
      currency: currency ?? this.currency,
      oneBarangayFare: oneBarangayFare ?? this.oneBarangayFare,
      buenavistaFiveBarangayFare:
          buenavistaFiveBarangayFare ?? this.buenavistaFiveBarangayFare,
      outsideBuenavistaMinFare:
          outsideBuenavistaMinFare ?? this.outsideBuenavistaMinFare,
      outsideBuenavistaNineKmFare:
          outsideBuenavistaNineKmFare ?? this.outsideBuenavistaNineKmFare,
      outsideBuenavistaTwelveKmFare:
          outsideBuenavistaTwelveKmFare ?? this.outsideBuenavistaTwelveKmFare,
      outsideBuenavistaSixteenKmFare:
          outsideBuenavistaSixteenKmFare ?? this.outsideBuenavistaSixteenKmFare,
      outsideBuenavistaMaxFare:
          outsideBuenavistaMaxFare ?? this.outsideBuenavistaMaxFare,
      studentDiscountRate: studentDiscountRate ?? this.studentDiscountRate,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  FareSettings normalized() {
    final oneBarangay = _positiveOrDefault(
      oneBarangayFare,
      defaultOneBarangayFare,
    );
    final fiveBarangays = _atLeast(
      _positiveOrDefault(
        buenavistaFiveBarangayFare,
        defaultBuenavistaFiveBarangayFare,
      ),
      oneBarangay,
    );
    final minFare = _positiveOrDefault(
      outsideBuenavistaMinFare,
      defaultOutsideBuenavistaMinFare,
    );
    final nineKmFare = _atLeast(
      _positiveOrDefault(
        outsideBuenavistaNineKmFare,
        defaultOutsideBuenavistaNineKmFare,
      ),
      minFare,
    );
    final twelveKmFare = _atLeast(
      _positiveOrDefault(
        outsideBuenavistaTwelveKmFare,
        defaultOutsideBuenavistaTwelveKmFare,
      ),
      nineKmFare,
    );
    final sixteenKmFare = _atLeast(
      _positiveOrDefault(
        outsideBuenavistaSixteenKmFare,
        defaultOutsideBuenavistaSixteenKmFare,
      ),
      twelveKmFare,
    );
    final maxFare = _atLeast(
      _positiveOrDefault(
        outsideBuenavistaMaxFare,
        defaultOutsideBuenavistaMaxFare,
      ),
      sixteenKmFare,
    );

    return FareSettings(
      currency: currency.trim().isEmpty ? defaultCurrency : currency.trim(),
      oneBarangayFare: oneBarangay,
      buenavistaFiveBarangayFare: fiveBarangays,
      outsideBuenavistaMinFare: minFare,
      outsideBuenavistaNineKmFare: nineKmFare,
      outsideBuenavistaTwelveKmFare: twelveKmFare,
      outsideBuenavistaSixteenKmFare: sixteenKmFare,
      outsideBuenavistaMaxFare: maxFare,
      studentDiscountRate: studentDiscountRate.clamp(0.0, 1.0).toDouble(),
      updatedAt: updatedAt,
      updatedBy: updatedBy,
    );
  }

  int get minimumRegularFare {
    var minimum = oneBarangayFare;
    if (buenavistaFiveBarangayFare < minimum) {
      minimum = buenavistaFiveBarangayFare;
    }
    if (outsideBuenavistaMinFare < minimum) {
      minimum = outsideBuenavistaMinFare;
    }
    return minimum;
  }

  int get minimumStudentDiscountedFare {
    final discounted = (minimumRegularFare * (1 - studentDiscountRate))
        .round()
        .clamp(1, minimumRegularFare);
    return discounted.toInt();
  }

  String get oneBarangayFareLabel => amountLabel(oneBarangayFare);
  String get buenavistaFiveBarangayFareLabel =>
      amountLabel(buenavistaFiveBarangayFare);
  String get outsideBuenavistaRangeLabel =>
      '${amountLabel(outsideBuenavistaMinFare)}-${amountLabel(outsideBuenavistaMaxFare)}';
  String get studentDiscountLabel =>
      '${(studentDiscountRate * 100).round()}% student discount';
  String get passengerFareGuideDescription =>
      'Base fare starts at $oneBarangayFareLabel, up to 5 barangays is $buenavistaFiveBarangayFareLabel, and extended routes are $outsideBuenavistaRangeLabel.';
  String get passengerStudentDiscountDescription =>
      'Verified students receive ${(studentDiscountRate * 100).round()}% off eligible rides.';

  String amountLabel(int amount) => '$currency $amount';

  Map<String, dynamic> toFirestore({required String updatedBy}) {
    final settings = normalized();
    return <String, dynamic>{
      'currency': settings.currency,
      'one_barangay_fare': settings.oneBarangayFare,
      'buenavista_five_barangay_fare': settings.buenavistaFiveBarangayFare,
      'outside_buenavista_min_fare': settings.outsideBuenavistaMinFare,
      'outside_buenavista_9km_fare': settings.outsideBuenavistaNineKmFare,
      'outside_buenavista_12km_fare': settings.outsideBuenavistaTwelveKmFare,
      'outside_buenavista_16km_fare': settings.outsideBuenavistaSixteenKmFare,
      'outside_buenavista_max_fare': settings.outsideBuenavistaMaxFare,
      'student_discount_rate': settings.studentDiscountRate,
      'updated_by': updatedBy,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  static String _readString(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int _readInt(Object? value, int fallback) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _readDouble(Object? value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
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

  static int _positiveOrDefault(int value, int fallback) {
    return value > 0 ? value : fallback;
  }

  static int _atLeast(int value, int minimum) {
    return value < minimum ? minimum : value;
  }
}
