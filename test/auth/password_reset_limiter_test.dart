import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/services/password_reset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PasswordResetLimiter', () {
    late DateTime now;

    PasswordResetLimiter createLimiter() {
      return PasswordResetLimiter(now: () => now);
    }

    Future<void> recordAfterCooldown(PasswordResetLimiter limiter) async {
      final snapshot = await limiter.loadSnapshot();
      now = now.add(snapshot.remainingCooldown + const Duration(seconds: 1));
      await limiter.recordAttempt();
    }

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      now = DateTime(2026, 6, 12, 9);
    });

    test('starts each day with five available attempts', () async {
      final limiter = createLimiter();

      final snapshot = await limiter.loadSnapshot();

      expect(snapshot.canSend, isTrue);
      expect(snapshot.remainingAttempts, 5);
      expect(snapshot.remainingCooldown, Duration.zero);
    });

    test('uses one minute cooldown through the first two retries', () async {
      final limiter = createLimiter();

      await limiter.recordAttempt();
      var snapshot = await limiter.loadSnapshot();
      expect(snapshot.attemptsToday, 1);
      expect(snapshot.remainingCooldown, PasswordResetLimiter.standardCooldown);

      await recordAfterCooldown(limiter);
      snapshot = await limiter.loadSnapshot();
      expect(snapshot.attemptsToday, 2);
      expect(snapshot.remainingCooldown, PasswordResetLimiter.standardCooldown);

      await recordAfterCooldown(limiter);
      snapshot = await limiter.loadSnapshot();
      expect(snapshot.attemptsToday, 3);
      expect(snapshot.remainingCooldown, PasswordResetLimiter.standardCooldown);
    });

    test('uses five minute cooldown starting on the third retry', () async {
      final limiter = createLimiter();

      await limiter.recordAttempt();
      await recordAfterCooldown(limiter);
      await recordAfterCooldown(limiter);
      await recordAfterCooldown(limiter);

      final snapshot = await limiter.loadSnapshot();
      expect(snapshot.attemptsToday, 4);
      expect(snapshot.remainingCooldown, PasswordResetLimiter.longCooldown);
    });

    test('caps reset sends at five per day', () async {
      final limiter = createLimiter();

      await limiter.recordAttempt();
      await recordAfterCooldown(limiter);
      await recordAfterCooldown(limiter);
      await recordAfterCooldown(limiter);
      await recordAfterCooldown(limiter);

      final snapshot = await limiter.loadSnapshot();
      expect(snapshot.attemptsToday, 5);
      expect(snapshot.remainingAttempts, 0);
      expect(snapshot.canSend, isFalse);
    });

    test('resets attempts on a new local day', () async {
      final limiter = createLimiter();

      await limiter.recordAttempt();
      now = DateTime(2026, 6, 13, 8);

      final snapshot = await limiter.loadSnapshot();
      expect(snapshot.attemptsToday, 0);
      expect(snapshot.remainingAttempts, 5);
      expect(snapshot.canSend, isTrue);
    });
  });
}
