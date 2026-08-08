import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/services/driver_credential_service.dart';

void main() {
  group('DriverCredentialType', () {
    test('maps every credential to its stored URL and path fields', () {
      expect(
        DriverCredentialType.driversLicense.urlField,
        'drivers_license_url',
      );
      expect(
        DriverCredentialType.driversLicense.pathField,
        'drivers_license_path',
      );
      expect(DriverCredentialType.orCr.urlField, 'or_cr_url');
      expect(DriverCredentialType.orCr.pathField, 'or_cr_path');
      expect(DriverCredentialType.nbiClearance.urlField, 'nbi_clearance_url');
      expect(DriverCredentialType.selfie.urlField, 'selfie_url');
    });

    test('requires expiry dates only for license and OR/CR', () {
      expect(DriverCredentialType.driversLicense.requiresExpiry, isTrue);
      expect(DriverCredentialType.orCr.requiresExpiry, isTrue);
      expect(DriverCredentialType.nbiClearance.requiresExpiry, isFalse);
      expect(DriverCredentialType.selfie.requiresExpiry, isFalse);
    });
  });
}
