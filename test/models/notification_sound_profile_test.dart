import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/notification_sound_profile.dart';

void main() {
  group('NotificationSoundProfile', () {
    test('maps the four custom notification event types', () {
      expect(
        NotificationSoundProfile.fromPayload(const {'type': 'chat_message'}),
        same(NotificationSoundProfile.message),
      );
      expect(
        NotificationSoundProfile.fromPayload(const {
          'type': 'booking_accepted',
        }),
        same(NotificationSoundProfile.bookingAccepted),
      );
      expect(
        NotificationSoundProfile.fromPayload(const {'type': 'driver_arrived'}),
        same(NotificationSoundProfile.driverArrived),
      );
      expect(
        NotificationSoundProfile.fromPayload(const {'type': 'booking_request'}),
        same(NotificationSoundProfile.bookingRequest),
      );
    });

    test('honors an explicit sound key and normalizes separators', () {
      final profile = NotificationSoundProfile.fromPayload(const {
        'type': 'system_update',
        'notification_sound': 'driver-arrived',
      });

      expect(profile, same(NotificationSoundProfile.driverArrived));
      expect(profile.payloadValue, 'driver_arrived');
      expect(profile.androidChannelId, 'sakaynow_driver_arrived_sound_v1');
      expect(profile.androidSoundResource, 'sakaynow_driver_arrived');
      expect(profile.appleSoundFile, 'sakaynow_driver_arrived.wav');
    });

    test('uses existing default notification behavior for other events', () {
      final profile = NotificationSoundProfile.fromPayload(const {
        'type': 'account_verified',
        'channel': 'account',
      });

      expect(profile, same(NotificationSoundProfile.standard));
      expect(profile.usesCustomSound, isFalse);
      expect(profile.androidChannelId, isNull);
      expect(profile.androidSoundResource, isNull);
      expect(profile.appleSoundFile, 'default');
    });

    test('bundles valid non-empty PCM wave resources for Android and iOS', () {
      const resources = <String>[
        NotificationSoundProfile.messageSoundResource,
        NotificationSoundProfile.bookingAcceptedSoundResource,
        NotificationSoundProfile.driverArrivedSoundResource,
        NotificationSoundProfile.bookingRequestSoundResource,
      ];

      for (final resource in resources) {
        final android = File('android/app/src/main/res/raw/$resource.wav');
        final ios = File('ios/Runner/Sounds/$resource.wav');
        expect(android.existsSync(), isTrue, reason: android.path);
        expect(ios.existsSync(), isTrue, reason: ios.path);
        expect(android.lengthSync(), greaterThan(1024), reason: android.path);
        expect(ios.readAsBytesSync(), android.readAsBytesSync());
        expect(
          android.readAsBytesSync().take(4),
          orderedEquals('RIFF'.codeUnits),
        );
      }

      final iosProject = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      for (final resource in resources) {
        expect(
          iosProject,
          contains('$resource.wav in Resources'),
          reason: '$resource.wav must be copied into the iOS app bundle',
        );
      }
    });
  });
}
