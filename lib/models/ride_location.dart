import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideLocation {
  final String address;
  final String? name;
  final String? placeId;
  final double? latitude;
  final double? longitude;

  const RideLocation({
    required this.address,
    this.name,
    this.placeId,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  String? get googlePinDisplayLabel {
    final hasGooglePlaceId = placeId?.trim().isNotEmpty == true;
    if (!hasGooglePlaceId) {
      return null;
    }

    final trimmedName = name?.trim();
    if (trimmedName != null &&
        trimmedName.isNotEmpty &&
        trimmedName != 'Pinned location') {
      return trimmedName;
    }

    return placeId!.trim();
  }

  String get displayLabel {
    final googlePinLabel = googlePinDisplayLabel;
    if (googlePinLabel != null) {
      return googlePinLabel;
    }

    final trimmedName = name?.trim();
    if (trimmedName != null &&
        trimmedName.isNotEmpty &&
        trimmedName != 'Pinned location') {
      return trimmedName;
    }

    return address;
  }

  String get publicDisplayLabel {
    final googlePinLabel = googlePinDisplayLabel;
    if (googlePinLabel != null) {
      return googlePinLabel;
    }

    final trimmedName = name?.trim();
    final trimmedAddress = address.trim();
    if (_isPublicAddress(trimmedAddress, trimmedName)) {
      return trimmedAddress;
    }

    return coordinateLabel ??
        (trimmedAddress.isNotEmpty
            ? trimmedAddress
            : trimmedName?.isNotEmpty == true
            ? trimmedName!
            : 'Unknown location');
  }

  String? get coordinateLabel {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      return null;
    }

    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  LatLng? get latLng {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      return null;
    }

    return LatLng(lat, lng);
  }

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'address': address,
      'name': name,
      'place_id': placeId,
      'latitude': latitude,
      'longitude': longitude,
    };

    if (hasCoordinates) {
      data['geopoint'] = GeoPoint(latitude!, longitude!);
    }

    return data;
  }

  factory RideLocation.fromMap(
    Object? value, {
    String fallbackAddress = 'Unknown location',
  }) {
    if (value is GeoPoint) {
      return RideLocation(
        address: fallbackAddress,
        latitude: value.latitude,
        longitude: value.longitude,
      );
    }

    if (value is Map) {
      final geoPoint = value['geopoint'];
      final lat =
          _readDouble(value['latitude']) ??
          _readDouble(value['lat']) ??
          (geoPoint is GeoPoint ? geoPoint.latitude : null);
      final lng =
          _readDouble(value['longitude']) ??
          _readDouble(value['lng']) ??
          (geoPoint is GeoPoint ? geoPoint.longitude : null);
      final address = _readString(value['address']);
      final name = _readNullableString(value['name']);

      return RideLocation(
        address: address.isNotEmpty
            ? address
            : (name?.isNotEmpty == true ? name! : fallbackAddress),
        name: name,
        placeId: _readNullableString(value['place_id'] ?? value['placeId']),
        latitude: lat,
        longitude: lng,
      );
    }

    final text = value?.toString().trim() ?? '';
    return RideLocation(address: text.isEmpty ? fallbackAddress : text);
  }

  static String _readString(Object? value) => value?.toString().trim() ?? '';

  static String? _readNullableString(Object? value) {
    final text = _readString(value);
    return text.isEmpty ? null : text;
  }

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  bool _isPublicAddress(String address, String? locationName) {
    if (address.isEmpty || address == 'Pinned location') {
      return false;
    }

    if (hasCoordinates &&
        placeId?.trim().isNotEmpty != true &&
        locationName != null &&
        locationName.isNotEmpty &&
        address.toLowerCase() == locationName.toLowerCase()) {
      return false;
    }

    return true;
  }
}
