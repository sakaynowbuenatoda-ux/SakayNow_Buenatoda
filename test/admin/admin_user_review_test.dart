import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/driver_document_status.dart';
import 'package:sakaynow_buenatoda/pages/admin/admin_models.dart';
import 'package:sakaynow_buenatoda/pages/admin/widgets/admin_shared.dart';

void main() {
  AdminUserRecord buildUser({
    required String role,
    bool isVerified = false,
    String? vehicleType = 'Traditional Tricycle',
    String? tricycleColor = 'Blue',
    String? plateNumber = 'T-1234',
    String? selfieUrl = 'https://example.com/selfie.jpg',
    String? nbiClearanceUrl = 'https://example.com/nbi.jpg',
    String? driversLicenseUrl = 'https://example.com/license.jpg',
    String? orCrUrl = 'https://example.com/or_cr.jpg',
    String? tricycleFrontUrl = 'https://example.com/front.jpg',
    String? tricycleBackUrl = 'https://example.com/back.jpg',
    String documentReviewStatus = '',
    Map<String, dynamic> pendingDocumentReview = const <String, dynamic>{},
    DriverDocumentStatus? driverDocumentStatus,
  }) {
    return AdminUserRecord(
      userId: 'test-user-id',
      firstName: 'Jose',
      lastName: 'Rizal',
      email: 'jose@example.com',
      role: role,
      passengerType: 'regular',
      gender: 'male',
      age: '30',
      isVerified: isVerified,
      isActive: false,
      isBanned: false,
      isDeactivated: false,
      isDeleted: false,
      accountStatus: 'active',
      createdAt: DateTime(2026, 1, 1),
      reviewedAt: null,
      deactivatedAt: null,
      deactivationRestoreDeadline: null,
      deactivationPurgeAfter: null,
      accountAnonymizedAt: null,
      profilePictureUrl: null,
      idImageUrl: null,
      selfieUrl: selfieUrl,
      nbiClearanceUrl: nbiClearanceUrl,
      driversLicenseUrl: driversLicenseUrl,
      vehicleType: vehicleType,
      tricycleColor: tricycleColor,
      plateNumber: plateNumber,
      orCrUrl: orCrUrl,
      tricycleFrontUrl: tricycleFrontUrl,
      tricycleBackUrl: tricycleBackUrl,
      documentReviewStatus: documentReviewStatus,
      pendingDocumentReview: pendingDocumentReview,
      driverDocumentStatus:
          driverDocumentStatus ??
          DriverDocumentStatus(
            driversLicenseExpiry: DateTime(2028, 1, 1),
            orCrExpiry: DateTime(2028, 1, 1),
            documentStatus: 'valid',
          ),
      averageRating: 5.0,
      reviewCount: 1,
    );
  }

  group('AdminUserRecord verification validation and gating', () {
    test('distinguishes regular and super admin records explicitly', () {
      final regularAdmin = buildUser(role: 'admin', isVerified: true);
      final superAdmin = buildUser(role: 'super_admin', isVerified: true);

      expect(regularAdmin.isAdminStaff, isTrue);
      expect(regularAdmin.isRegularAdmin, isTrue);
      expect(regularAdmin.isSuperAdmin, isFalse);
      expect(superAdmin.isAdminStaff, isTrue);
      expect(superAdmin.isRegularAdmin, isFalse);
      expect(superAdmin.isSuperAdmin, isTrue);
      expect(superAdmin.roleLabel, 'Super Admin');
    });

    test(
      'complete driver profile returns isDriverVerificationComplete=true and canBeApproved=true',
      () {
        final driver = buildUser(role: 'driver', isVerified: false);
        expect(driver.isPendingVerification, isTrue);
        expect(driver.hasDriverDocuments, isTrue);
        expect(driver.isDriverVerificationComplete, isTrue);
        expect(driver.canBeApproved, isTrue);
      },
    );

    test(
      'admin can override missing OR/CR while the profile remains flagged',
      () {
        final driver = buildUser(
          role: 'driver',
          isVerified: false,
          orCrUrl: null,
        );
        expect(driver.isPendingVerification, isTrue);
        expect(driver.hasDriverDocuments, isFalse);
        expect(driver.isDriverVerificationComplete, isFalse);
        expect(driver.canBeApproved, isTrue);
      },
    );

    test(
      'admin can override a missing plate number while it remains flagged',
      () {
        final driver = buildUser(
          role: 'driver',
          isVerified: false,
          plateNumber: null,
        );
        expect(driver.isPendingVerification, isTrue);
        expect(driver.isDriverVerificationComplete, isFalse);
        expect(driver.canBeApproved, isTrue);
      },
    );

    test('expiry dates use an exact calendar date', () {
      expect(formatDate(DateTime(2028, 7, 9)), 'Jul 9, 2028');
      expect(formatDate(null), 'Not recorded');
    });

    test('passenger does not require vehicle data to be approved', () {
      final passenger = buildUser(
        role: 'passenger',
        isVerified: false,
        vehicleType: null,
        tricycleColor: null,
        plateNumber: null,
        orCrUrl: null,
        tricycleFrontUrl: null,
        tricycleBackUrl: null,
      );
      expect(passenger.isPendingVerification, isTrue);
      expect(passenger.canBeApproved, isTrue);
    });

    test('pending driver renewal is surfaced for admin review', () {
      final driver = buildUser(
        role: 'driver',
        isVerified: true,
        driverDocumentStatus: DriverDocumentStatus(
          driversLicenseExpiry: DateTime(2026, 1, 1),
          orCrExpiry: DateTime(2028, 1, 1),
          documentStatus: 'expired',
          renewalStatus: 'pending_renewal',
          renewalDocumentType: DriverDocumentType.driversLicense,
          renewalDocumentUrl: 'https://example.com/license-renewal.jpg',
          renewalExpiry: DateTime(2029, 1, 1),
        ),
      );

      expect(driver.isPendingRenewal, isTrue);
      expect(driver.hasReviewOnlySubmission, isTrue);
      expect(driver.needsApproval, isTrue);
      expect(driver.canReceiveBookings, isFalse);
      expect(driver.statusLabel, 'Pending renewal');
    });

    test('verified account document updates stay verified while pending', () {
      final driver = buildUser(
        role: 'driver',
        isVerified: true,
        documentReviewStatus: 'pending',
        pendingDocumentReview: <String, dynamic>{
          'kind': 'driver_credential',
          'credential_type': 'drivers_license',
          'document_url': 'https://example.com/new-license.jpg',
          'expiry': DateTime(2029, 1, 1),
        },
      );

      expect(driver.isVerified, isTrue);
      expect(driver.isPendingVerification, isFalse);
      expect(driver.hasPendingDocumentReview, isTrue);
      expect(driver.hasReviewOnlySubmission, isTrue);
      expect(driver.needsApproval, isTrue);
      expect(driver.statusLabel, 'Document review pending');
      expect(
        driver.effectiveDriversLicenseUrl,
        'https://example.com/new-license.jpg',
      );
      expect(driver.effectiveDriversLicenseExpiry, DateTime(2029, 1, 1));
    });

    test(
      'unverified accounts stay in initial verification even with staged documents',
      () {
        final passenger = buildUser(
          role: 'passenger',
          isVerified: false,
          documentReviewStatus: 'pending',
          pendingDocumentReview: const <String, dynamic>{
            'kind': 'passenger_identity',
            'id_image_url': 'https://example.com/new-id.jpg',
          },
        );

        expect(passenger.isPendingVerification, isTrue);
        expect(passenger.hasPendingDocumentReview, isTrue);
        expect(passenger.hasReviewOnlySubmission, isFalse);
        expect(passenger.needsApproval, isTrue);
      },
    );
  });
}
