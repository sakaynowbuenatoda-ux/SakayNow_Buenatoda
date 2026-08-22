import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/notification_destination.dart';

void main() {
  group('resolveNotificationDestination', () {
    test('opens review content instead of its associated booking', () {
      expect(
        resolveNotificationDestination(
          data: const <String, String>{
            'type': 'review_received',
            'booking_id': 'booking-1',
            'review_id': 'review-1',
          },
          currentUserRole: 'passenger',
        ),
        NotificationDestination.profile,
      );
    });

    test('routes every booking update to actionable ride content', () {
      const rideTypes = <String>[
        'booking_accepted',
        'booking_declined',
        'booking_cancelled',
        'driver_arriving',
        'driver_arrived',
        'ride_started',
        'ride_completed',
      ];

      for (final type in rideTypes) {
        expect(
          resolveNotificationDestination(
            data: <String, String>{'type': type, 'booking_id': 'booking-1'},
            currentUserRole: 'passenger',
          ),
          NotificationDestination.ride,
          reason: type,
        );
      }

      expect(
        resolveNotificationDestination(
          data: const <String, String>{
            'type': 'booking_request',
            'booking_id': 'booking-1',
          },
          currentUserRole: 'driver',
        ),
        NotificationDestination.driverQueue,
      );
    });

    test('routes admin verification and document submissions to review', () {
      const adminTypes = <String>[
        'verification_request',
        'driver_renewal_submitted',
        'document_review_submitted',
        'driver_documents_expired_admin',
      ];

      for (final type in adminTypes) {
        expect(
          resolveNotificationDestination(
            data: <String, String>{'type': type, 'user_id': 'user-1'},
            currentUserRole: 'admin',
          ),
          NotificationDestination.adminUserReview,
          reason: type,
        );
      }

      expect(
        resolveNotificationDestination(
          data: const <String, String>{
            'type': 'verification_request',
            'user_id': 'user-1',
          },
          currentUserRole: 'Super Admin',
        ),
        NotificationDestination.adminUserReview,
      );
    });

    test('routes driver document updates to the Driver Info Hub', () {
      const driverTypes = <String>[
        'driver_documents_expiring',
        'driver_documents_expired',
        'driver_renewal_approved',
        'driver_renewal_rejected',
      ];

      for (final type in driverTypes) {
        expect(
          resolveNotificationDestination(
            data: <String, String>{'type': type},
            currentUserRole: 'driver',
          ),
          NotificationDestination.driverInfoHub,
          reason: type,
        );
      }
    });

    test('routes review decisions according to the recipient role', () {
      expect(
        resolveNotificationDestination(
          data: const <String, String>{
            'type': 'document_review_approved',
            'role': 'driver',
          },
          currentUserRole: 'driver',
        ),
        NotificationDestination.driverInfoHub,
      );
      expect(
        resolveNotificationDestination(
          data: const <String, String>{
            'type': 'document_review_rejected',
            'role': 'passenger',
          },
          currentUserRole: 'passenger',
        ),
        NotificationDestination.passengerVerification,
      );
    });

    test('keeps unknown system updates readable', () {
      expect(
        resolveNotificationDestination(
          data: const <String, String>{'type': 'future_system_update'},
          currentUserRole: 'passenger',
        ),
        NotificationDestination.details,
      );
    });
  });
}
