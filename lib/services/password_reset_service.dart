import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class PasswordResetSender {
  Future<void> sendResetLink(String email);
}

class PasswordResetService implements PasswordResetSender {
  final FirebaseAuth _auth;

  PasswordResetService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<void> sendResetLink(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        return;
      }

      rethrow;
    }
  }
}

class PasswordResetLimitSnapshot {
  final int attemptsToday;
  final int maxAttemptsPerDay;
  final Duration remainingCooldown;

  const PasswordResetLimitSnapshot({
    required this.attemptsToday,
    required this.maxAttemptsPerDay,
    required this.remainingCooldown,
  });

  int get remainingAttempts {
    final remaining = maxAttemptsPerDay - attemptsToday;
    if (remaining < 0) {
      return 0;
    }

    if (remaining > maxAttemptsPerDay) {
      return maxAttemptsPerDay;
    }

    return remaining;
  }

  bool get hasCooldown => remainingCooldown > Duration.zero;

  bool get hasReachedDailyLimit => remainingAttempts == 0;

  bool get canSend => !hasCooldown && !hasReachedDailyLimit;
}

class PasswordResetLimiter {
  static const int maxAttemptsPerDay = 5;
  static const Duration standardCooldown = Duration(minutes: 1);
  static const Duration longCooldown = Duration(minutes: 5);

  static const String _dateKey = 'password_reset_limit_date';
  static const String _attemptsKey = 'password_reset_attempts_today';
  static const String _lastAttemptMsKey = 'password_reset_last_attempt_ms';

  final Future<SharedPreferences> Function() _preferencesProvider;
  final DateTime Function() _now;

  PasswordResetLimiter({
    Future<SharedPreferences> Function()? preferencesProvider,
    DateTime Function()? now,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  Future<bool> canSend() async {
    return (await loadSnapshot()).canSend;
  }

  Future<Duration> remainingCooldown() async {
    return (await loadSnapshot()).remainingCooldown;
  }

  Future<int> remainingAttempts() async {
    return (await loadSnapshot()).remainingAttempts;
  }

  Future<PasswordResetLimitSnapshot> loadSnapshot() async {
    final preferences = await _preferencesProvider();
    return _snapshotFromPreferences(preferences, _now());
  }

  Future<PasswordResetLimitSnapshot> recordAttempt() async {
    final preferences = await _preferencesProvider();
    final now = _now();
    final current = _snapshotFromPreferences(preferences, now);
    final nextAttempts = current.attemptsToday >= maxAttemptsPerDay
        ? maxAttemptsPerDay
        : current.attemptsToday + 1;

    await preferences.setString(_dateKey, _dateKeyFor(now));
    await preferences.setInt(_attemptsKey, nextAttempts);
    await preferences.setInt(_lastAttemptMsKey, now.millisecondsSinceEpoch);

    return _snapshotFromPreferences(preferences, now);
  }

  PasswordResetLimitSnapshot _snapshotFromPreferences(
    SharedPreferences preferences,
    DateTime now,
  ) {
    final storedDate = preferences.getString(_dateKey);
    if (storedDate != _dateKeyFor(now)) {
      return const PasswordResetLimitSnapshot(
        attemptsToday: 0,
        maxAttemptsPerDay: maxAttemptsPerDay,
        remainingCooldown: Duration.zero,
      );
    }

    final attempts = preferences.getInt(_attemptsKey) ?? 0;
    final lastAttemptMs = preferences.getInt(_lastAttemptMsKey);
    final cooldown = _cooldownAfterAttempt(attempts);
    var remainingCooldown = Duration.zero;

    if (lastAttemptMs != null && cooldown > Duration.zero) {
      final lastAttempt = DateTime.fromMillisecondsSinceEpoch(lastAttemptMs);
      final nextAllowedAt = lastAttempt.add(cooldown);
      if (now.isBefore(nextAllowedAt)) {
        remainingCooldown = nextAllowedAt.difference(now);
      }
    }

    final normalizedAttempts = attempts < 0
        ? 0
        : attempts > maxAttemptsPerDay
        ? maxAttemptsPerDay
        : attempts;

    return PasswordResetLimitSnapshot(
      attemptsToday: normalizedAttempts,
      maxAttemptsPerDay: maxAttemptsPerDay,
      remainingCooldown: remainingCooldown,
    );
  }

  static Duration _cooldownAfterAttempt(int attemptsToday) {
    if (attemptsToday <= 0) {
      return Duration.zero;
    }

    return attemptsToday >= 4 ? longCooldown : standardCooldown;
  }

  static String _dateKeyFor(DateTime value) {
    final localDate = value.toLocal();
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');

    return '${localDate.year}-$month-$day';
  }
}
