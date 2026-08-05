import 'package:cloud_firestore/cloud_firestore.dart';

enum DriverDocumentType { driversLicense, orCr }

extension DriverDocumentTypeX on DriverDocumentType {
  String get firestoreValue => switch (this) {
    DriverDocumentType.driversLicense => 'drivers_license',
    DriverDocumentType.orCr => 'or_cr',
  };

  String get label => switch (this) {
    DriverDocumentType.driversLicense => 'Driver\'s License',
    DriverDocumentType.orCr => 'OR/CR',
  };

  String get expiryField => switch (this) {
    DriverDocumentType.driversLicense => 'drivers_license_expiry',
    DriverDocumentType.orCr => 'or_cr_expiry',
  };

  String get documentUrlField => switch (this) {
    DriverDocumentType.driversLicense => 'drivers_license_url',
    DriverDocumentType.orCr => 'or_cr_url',
  };

  static DriverDocumentType? fromFirestore(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'drivers_license' => DriverDocumentType.driversLicense,
      'or_cr' => DriverDocumentType.orCr,
      _ => null,
    };
  }
}

enum DriverRenewalState {
  valid,
  expiringSoon,
  expired,
  pendingRenewal,
  rejected,
}

extension DriverRenewalStateX on DriverRenewalState {
  String get label => switch (this) {
    DriverRenewalState.valid => 'Valid',
    DriverRenewalState.expiringSoon => 'Expiring soon',
    DriverRenewalState.expired => 'Expired',
    DriverRenewalState.pendingRenewal => 'Pending renewal',
    DriverRenewalState.rejected => 'Renewal rejected',
  };

  String get description => switch (this) {
    DriverRenewalState.valid =>
      'Your required driver documents are current. You can receive bookings when active.',
    DriverRenewalState.expiringSoon =>
      'At least one required document expires within 30 days. Submit a replacement before it expires.',
    DriverRenewalState.expired =>
      'A required document has expired. You cannot go active or accept bookings until an admin approves its renewal.',
    DriverRenewalState.pendingRenewal =>
      'Your replacement document is waiting for admin review.',
    DriverRenewalState.rejected =>
      'The latest replacement was rejected. Review the admin note and submit a clearer or valid document.',
  };
}

class DriverDocumentStatus {
  static const Duration expiringSoonWindow = Duration(days: 30);

  final DateTime? driversLicenseExpiry;
  final DateTime? orCrExpiry;
  final String documentStatus;
  final String renewalStatus;
  final DriverDocumentType? renewalDocumentType;
  final String? renewalDocumentUrl;
  final String? renewalDocumentPath;
  final DateTime? renewalExpiry;
  final DateTime? renewalSubmittedAt;
  final DateTime? renewalReviewedAt;
  final String? renewalReviewedBy;
  final String? renewalRejectionReason;

  const DriverDocumentStatus({
    this.driversLicenseExpiry,
    this.orCrExpiry,
    this.documentStatus = '',
    this.renewalStatus = '',
    this.renewalDocumentType,
    this.renewalDocumentUrl,
    this.renewalDocumentPath,
    this.renewalExpiry,
    this.renewalSubmittedAt,
    this.renewalReviewedAt,
    this.renewalReviewedBy,
    this.renewalRejectionReason,
  });

  factory DriverDocumentStatus.fromMap(Map<String, dynamic> data) {
    return DriverDocumentStatus(
      driversLicenseExpiry: readDate(data['drivers_license_expiry']),
      orCrExpiry: readDate(data['or_cr_expiry']),
      documentStatus: _readString(data['document_status']).toLowerCase(),
      renewalStatus: _readString(data['renewal_status']).toLowerCase(),
      renewalDocumentType: DriverDocumentTypeX.fromFirestore(
        data['renewal_document_type'],
      ),
      renewalDocumentUrl: readOptionalString(data['renewal_document_url']),
      renewalDocumentPath: readOptionalString(data['renewal_document_path']),
      renewalExpiry: readDate(data['renewal_expiry']),
      renewalSubmittedAt: readDate(data['renewal_submitted_at']),
      renewalReviewedAt: readDate(data['renewal_reviewed_at']),
      renewalReviewedBy: readOptionalString(data['renewal_reviewed_by']),
      renewalRejectionReason: readOptionalString(
        data['renewal_rejection_reason'],
      ),
    );
  }

  bool get hasPendingRenewal => renewalStatus == 'pending_renewal';
  bool get wasRenewalRejected => renewalStatus == 'rejected';

  DateTime? get earliestExpiry {
    final license = driversLicenseExpiry;
    final orCr = orCrExpiry;
    if (license == null) return orCr;
    if (orCr == null) return license;
    return license.isBefore(orCr) ? license : orCr;
  }

  DriverRenewalState stateAt(DateTime now) {
    if (hasPendingRenewal) {
      return DriverRenewalState.pendingRenewal;
    }
    if (wasRenewalRejected) {
      return DriverRenewalState.rejected;
    }
    if (!isEligibleAt(now)) {
      return DriverRenewalState.expired;
    }

    final expiry = earliestExpiry;
    if (expiry != null && !expiry.isAfter(now.add(expiringSoonWindow))) {
      return DriverRenewalState.expiringSoon;
    }
    return DriverRenewalState.valid;
  }

  /// Missing expiry fields are treated as legacy data and remain eligible.
  /// New registrations always write both dates, while the scheduled function
  /// backfills a concrete document status once dates are present.
  bool isEligibleAt(DateTime now) {
    if (documentStatus == 'expired') {
      return false;
    }
    if (driversLicenseExpiry != null && !driversLicenseExpiry!.isAfter(now)) {
      return false;
    }
    if (orCrExpiry != null && !orCrExpiry!.isAfter(now)) {
      return false;
    }
    return true;
  }

  DateTime? expiryFor(DriverDocumentType type) => switch (type) {
    DriverDocumentType.driversLicense => driversLicenseExpiry,
    DriverDocumentType.orCr => orCrExpiry,
  };

  static DateTime? readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String? readOptionalString(Object? value) {
    final text = _readString(value);
    return text.isEmpty ? null : text;
  }

  static String _readString(Object? value) => value?.toString().trim() ?? '';
}
