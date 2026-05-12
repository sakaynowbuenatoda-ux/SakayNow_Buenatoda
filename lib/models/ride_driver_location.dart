import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideDriverLocation {
  final String driverId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final DateTime? updatedAt;

  const RideDriverLocation({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
    this.updatedAt,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'driver_id': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'geopoint': GeoPoint(latitude, longitude),
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  factory RideDriverLocation.fromMap(Object? value) {
    if (value is! Map) {
      throw StateError('Driver location is missing.');
    }

    final geoPoint = value['geopoint'];

    return RideDriverLocation(
      driverId: (value['driver_id'] ?? '').toString(),
      latitude:
          _readDouble(value['latitude']) ??
          (geoPoint is GeoPoint ? geoPoint.latitude : null) ??
          0,
      longitude:
          _readDouble(value['longitude']) ??
          (geoPoint is GeoPoint ? geoPoint.longitude : null) ??
          0,
      heading: _readDouble(value['heading']),
      speed: _readDouble(value['speed']),
      accuracy: _readDouble(value['accuracy']),
      updatedAt: _readDate(value['updated_at']),
    );
  }

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
