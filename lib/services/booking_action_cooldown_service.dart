import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BookingActionCooldownTarget { passengerBooking, driverAccept }

class BookingActionCooldownService extends ChangeNotifier {
  BookingActionCooldownService._();

  static final BookingActionCooldownService instance =
      BookingActionCooldownService._();

  static const Duration firstCooldown = Duration(seconds: 15);
  static const Duration repeatCooldown = Duration(seconds: 30);

  SharedPreferences? _preferences;
  Timer? _ticker;
  final Map<String, DateTime> _endsAtByKey = <String, DateTime>{};
  final Set<String> _loadedKeys = <String>{};

  Future<void> loadForUser({
    required String userId,
    required Iterable<BookingActionCooldownTarget> targets,
  }) async {
    await Future.wait(
      targets.map((target) => _loadTarget(userId: userId, target: target)),
    );
  }

  Duration remainingFor({
    required String userId,
    required BookingActionCooldownTarget target,
  }) {
    final endsAt = _endsAtByKey[_cooldownKey(userId, target)];
    if (endsAt == null) {
      return Duration.zero;
    }

    final remaining = endsAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool isCoolingDown({
    required String userId,
    required BookingActionCooldownTarget target,
  }) {
    return remainingFor(userId: userId, target: target) > Duration.zero;
  }

  Future<Duration> startAfterCancellation({
    required String userId,
    required BookingActionCooldownTarget target,
  }) async {
    final preferences = await _prefs();
    final key = _cooldownKey(userId, target);
    final previousCount = preferences.getInt(_countKey(key)) ?? 0;
    final cooldown = previousCount == 0 ? firstCooldown : repeatCooldown;
    final endsAt = DateTime.now().add(cooldown);

    await Future.wait(<Future<Object?>>[
      preferences.setInt(_countKey(key), previousCount + 1),
      preferences.setInt(_endsAtKey(key), endsAt.millisecondsSinceEpoch),
    ]);

    _loadedKeys.add(key);
    _endsAtByKey[key] = endsAt;
    _syncTicker();
    notifyListeners();
    return cooldown;
  }

  static String formatRemaining(Duration duration) {
    final seconds = math.max(0, (duration.inMilliseconds / 1000).ceil());
    if (seconds < 60) {
      return '${seconds}s';
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '${minutes}m';
    }

    return '${minutes}m ${remainingSeconds}s';
  }

  Future<void> _loadTarget({
    required String userId,
    required BookingActionCooldownTarget target,
  }) async {
    final preferences = await _prefs();
    final key = _cooldownKey(userId, target);
    if (_loadedKeys.contains(key)) {
      return;
    }

    final endMs = preferences.getInt(_endsAtKey(key));
    if (endMs != null) {
      _endsAtByKey[key] = DateTime.fromMillisecondsSinceEpoch(endMs);
    }

    _loadedKeys.add(key);
    _syncTicker();
    notifyListeners();
  }

  Future<SharedPreferences> _prefs() async {
    final existing = _preferences;
    if (existing != null) {
      return existing;
    }

    final loaded = await SharedPreferences.getInstance();
    _preferences = loaded;
    return loaded;
  }

  void _syncTicker() {
    if (_hasActiveCooldown) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
        if (!_hasActiveCooldown) {
          _ticker?.cancel();
          _ticker = null;
          notifyListeners();
        }
      });
      return;
    }

    _ticker?.cancel();
    _ticker = null;
  }

  bool get _hasActiveCooldown {
    final now = DateTime.now();
    return _endsAtByKey.values.any((endsAt) => endsAt.isAfter(now));
  }

  String _cooldownKey(String userId, BookingActionCooldownTarget target) {
    final normalizedUserId = userId.trim().isEmpty ? 'unknown' : userId.trim();
    return '$normalizedUserId:${target.name}';
  }

  String _endsAtKey(String key) => 'booking_action_cooldown:$key:ends_at';

  String _countKey(String key) => 'booking_action_cooldown:$key:count';
}
