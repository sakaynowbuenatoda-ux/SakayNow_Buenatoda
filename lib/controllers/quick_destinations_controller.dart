import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/passenger/passenger_data.dart';

class QuickDestinationsController extends ChangeNotifier {
  QuickDestinationsController({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _firestore;

  bool isLoading = true;
  List<PassengerQuickDestination> destinations = <PassengerQuickDestination>[];

  String get _storageKey => 'quick_destinations_$userId';
  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(userId);

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    final localDestinations = await _loadLocal();
    destinations = _withoutPlaceholderDestinations(
      localDestinations ?? <PassengerQuickDestination>[],
    );

    isLoading = false;
    notifyListeners();

    try {
      final remoteDestinations = await _loadRemote();
      if (remoteDestinations != null) {
        destinations = _withoutPlaceholderDestinations(remoteDestinations);
        notifyListeners();
      }
    } on Exception {
      // SharedPreferences remains the offline fallback when Firestore is unavailable.
    }

    await _save();
  }

  Future<void> upsert(PassengerQuickDestination destination) async {
    final index = destinations.indexWhere(
      (entry) => entry.id == destination.id,
    );
    if (index == -1) {
      destinations = <PassengerQuickDestination>[...destinations, destination];
    } else {
      destinations = <PassengerQuickDestination>[...destinations]
        ..[index] = destination;
    }

    notifyListeners();
    await _save();
  }

  Future<void> remove(PassengerQuickDestination destination) async {
    destinations = destinations
        .where((entry) => entry.id != destination.id)
        .toList(growable: true);
    notifyListeners();
    await _save();
  }

  PassengerQuickDestination createCustom({
    required String label,
    required String address,
    required double latitude,
    required double longitude,
    String? pinName,
    String? pinPlaceId,
  }) {
    final color = _customColors[destinations.length % _customColors.length];
    return PassengerQuickDestination(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      address: address,
      pinName: pinName,
      pinPlaceId: pinPlaceId,
      icon: Icons.place_rounded,
      accentColor: color,
      backgroundColor: color.withValues(alpha: 0.12),
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> _save() async {
    await _saveLocal();
    try {
      await _saveRemote();
    } on Exception {
      // Keep local saved places intact if Firestore is temporarily unavailable.
    }
  }

  Future<List<PassengerQuickDestination>?> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_storageKey);
    if (rawItems == null) {
      return null;
    }

    return rawItems
        .map(_fromJson)
        .whereType<PassengerQuickDestination>()
        .toList(growable: true);
  }

  Future<List<PassengerQuickDestination>?> _loadRemote() async {
    if (userId.trim().isEmpty) {
      return null;
    }

    final snapshot = await _userDoc.get();
    final data = snapshot.data();
    final rawItems = data?['quick_destinations'];
    if (rawItems is! List) {
      return null;
    }

    final parsed = rawItems
        .map(_fromMap)
        .whereType<PassengerQuickDestination>()
        .toList(growable: true);
    return parsed.isEmpty ? null : parsed;
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      destinations.map(_toJson).toList(growable: false),
    );
  }

  Future<void> _saveRemote() async {
    if (userId.trim().isEmpty) {
      return;
    }

    await _userDoc.set(<String, dynamic>{
      'quick_destinations': destinations
          .map(_toFirestore)
          .toList(growable: false),
      'quick_destinations_updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<PassengerQuickDestination> _withoutPlaceholderDestinations(
    List<PassengerQuickDestination> items,
  ) {
    return items
        .where((destination) {
          if (!destination.isDefault) {
            return true;
          }

          return destination.hasCoordinates &&
              !_matchesLegacyPlaceholder(destination);
        })
        .toList(growable: true);
  }

  String _toJson(PassengerQuickDestination destination) {
    return jsonEncode(_toMap(destination));
  }

  Map<String, Object?> _toMap(PassengerQuickDestination destination) {
    return <String, Object?>{
      'id': destination.id,
      'label': destination.label,
      'address': destination.address,
      'pin_name': destination.pinName,
      'pin_place_id': destination.pinPlaceId,
      'icon': _iconKey(destination.icon),
      'custom_emoji': destination.customEmoji,
      'accent_color': destination.accentColor.toARGB32(),
      'background_color': destination.backgroundColor.toARGB32(),
      'latitude': destination.latitude,
      'longitude': destination.longitude,
      'is_default': destination.isDefault,
    };
  }

  Map<String, Object?> _toFirestore(PassengerQuickDestination destination) {
    return <String, Object?>{
      ..._toMap(destination),
      if (destination.hasCoordinates)
        'geopoint': GeoPoint(destination.latitude!, destination.longitude!),
    };
  }

  PassengerQuickDestination? _fromJson(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return _fromMap(data);
    } catch (_) {
      return null;
    }
  }

  PassengerQuickDestination? _fromMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }

    final data = Map<String, dynamic>.from(raw);
    final icon = _iconFromKey((data['icon'] ?? '').toString());
    final accentColor = Color(
      (data['accent_color'] as num?)?.round() ?? _customColors.first.toARGB32(),
    );
    final geoPoint = data['geopoint'];
    final latitude =
        (data['latitude'] as num?)?.toDouble() ??
        (geoPoint is GeoPoint ? geoPoint.latitude : null);
    final longitude =
        (data['longitude'] as num?)?.toDouble() ??
        (geoPoint is GeoPoint ? geoPoint.longitude : null);

    final id = (data['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      return null;
    }

    return PassengerQuickDestination(
      id: id,
      label: (data['label'] ?? 'Saved place').toString(),
      address: (data['address'] as String?)?.trim().isEmpty == true
          ? null
          : data['address'] as String?,
      pinName: _nullableString(
        data['pin_name'] ?? data['pinName'] ?? data['name'],
      ),
      pinPlaceId: _nullableString(
        data['pin_place_id'] ??
            data['pinPlaceId'] ??
            data['place_id'] ??
            data['placeId'],
      ),
      icon: icon,
      customEmoji: (data['custom_emoji'] as String?)?.trim().isEmpty == true
          ? null
          : data['custom_emoji'] as String?,
      accentColor: accentColor,
      backgroundColor: Color(
        (data['background_color'] as num?)?.round() ??
            accentColor.withValues(alpha: 0.12).toARGB32(),
      ),
      latitude: latitude,
      longitude: longitude,
      isDefault: data['is_default'] == true,
    );
  }

  String _iconKey(IconData icon) {
    if (icon == Icons.home_rounded) {
      return 'home';
    }
    if (icon == Icons.school_rounded) {
      return 'school';
    }
    if (icon == Icons.work_rounded) {
      return 'work';
    }
    if (icon == Icons.storefront_rounded) {
      return 'market';
    }
    if (icon == Icons.park_rounded) {
      return 'plaza';
    }
    if (icon == Icons.account_balance_rounded) {
      return 'municipal_hall';
    }
    if (icon == Icons.local_hospital_rounded) {
      return 'hospital';
    }
    return 'place';
  }

  IconData _iconFromKey(String key) {
    return switch (key) {
      'home' => Icons.home_rounded,
      'school' => Icons.school_rounded,
      'work' => Icons.work_rounded,
      'market' => Icons.storefront_rounded,
      'plaza' => Icons.park_rounded,
      'municipal_hall' => Icons.account_balance_rounded,
      'hospital' => Icons.local_hospital_rounded,
      _ => Icons.place_rounded,
    };
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

const Map<String, PassengerQuickDestination> _legacyDefaultLocations =
    <String, PassengerQuickDestination>{
      'home': PassengerQuickDestination(
        id: 'home',
        label: 'Home',
        address: 'Poblacion, Buenavista, Bohol',
        icon: Icons.home_rounded,
        accentColor: Color(0xFF030213),
        backgroundColor: Color(0xFFF3F4F6),
        latitude: 10.0839,
        longitude: 124.1781,
        isDefault: true,
      ),
      'school': PassengerQuickDestination(
        id: 'school',
        label: 'School',
        address: 'Buenavista Community College, Buenavista, Bohol',
        icon: Icons.school_rounded,
        accentColor: Color(0xFF047857),
        backgroundColor: Color(0xFFE7F8EF),
        latitude: 10.0874,
        longitude: 124.1812,
        isDefault: true,
      ),
    };

bool _sameLocation(
  PassengerQuickDestination destination,
  PassengerQuickDestination legacy,
) {
  const tolerance = 0.000001;
  final lat = destination.latitude;
  final lng = destination.longitude;
  final legacyLat = legacy.latitude;
  final legacyLng = legacy.longitude;

  if (lat == null || lng == null || legacyLat == null || legacyLng == null) {
    return false;
  }

  return (lat - legacyLat).abs() < tolerance &&
      (lng - legacyLng).abs() < tolerance;
}

bool _matchesLegacyPlaceholder(PassengerQuickDestination destination) {
  final legacyLocation = _legacyDefaultLocations[destination.id];
  if (legacyLocation == null) {
    return false;
  }

  return destination.address == legacyLocation.address &&
      _sameLocation(destination, legacyLocation);
}

const List<Color> _customColors = <Color>[
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFFEA580C),
  Color(0xFF0891B2),
];
