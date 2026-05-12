import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteResult {
  final String encodedPolyline;
  final List<LatLng> polylinePoints;
  final int distanceMeters;
  final int durationSeconds;
  final String distanceText;
  final String durationText;
  final LatLngBounds? bounds;

  const RouteResult({
    required this.encodedPolyline,
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceText,
    required this.durationText,
    this.bounds,
  });

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'encoded_polyline': encodedPolyline,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'distance_text': distanceText,
      'duration_text': durationText,
      if (bounds != null)
        'bounds': <String, dynamic>{
          'northeast_latitude': bounds!.northeast.latitude,
          'northeast_longitude': bounds!.northeast.longitude,
          'southwest_latitude': bounds!.southwest.latitude,
          'southwest_longitude': bounds!.southwest.longitude,
        },
    };
  }

  factory RouteResult.fromMap(Object? value) {
    if (value is! Map) {
      return const RouteResult(
        encodedPolyline: '',
        polylinePoints: <LatLng>[],
        distanceMeters: 0,
        durationSeconds: 0,
        distanceText: '',
        durationText: '',
      );
    }

    final encodedPolyline = (value['encoded_polyline'] ?? '').toString();

    return RouteResult(
      encodedPolyline: encodedPolyline,
      polylinePoints: encodedPolyline.isEmpty
          ? <LatLng>[]
          : decodePolyline(encodedPolyline),
      distanceMeters: _readInt(value['distance_meters']),
      durationSeconds: _readInt(value['duration_seconds']),
      distanceText: (value['distance_text'] ?? '').toString(),
      durationText: (value['duration_text'] ?? '').toString(),
      bounds: _readBounds(value['bounds']),
    );
  }

  static List<LatLng> decodePolyline(String encodedPolyline) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encodedPolyline.length) {
      final latResult = _decodeNextValue(encodedPolyline, index);
      index = latResult.nextIndex;
      latitude += latResult.value;

      final lngResult = _decodeNextValue(encodedPolyline, index);
      index = lngResult.nextIndex;
      longitude += lngResult.value;

      points.add(LatLng(latitude / 1E5, longitude / 1E5));
    }

    return points;
  }

  static String encodePolyline(List<LatLng> points) {
    var previousLatitude = 0;
    var previousLongitude = 0;
    final buffer = StringBuffer();

    for (final point in points) {
      final latitude = (point.latitude * 1E5).round();
      final longitude = (point.longitude * 1E5).round();

      _encodeNextValue(latitude - previousLatitude, buffer);
      _encodeNextValue(longitude - previousLongitude, buffer);

      previousLatitude = latitude;
      previousLongitude = longitude;
    }

    return buffer.toString();
  }

  static _PolylineDecodeResult _decodeNextValue(String value, int startIndex) {
    var result = 0;
    var shift = 0;
    var index = startIndex;
    int byte;

    do {
      byte = value.codeUnitAt(index++) - 63;
      result |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);

    final coordinateChange = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    return _PolylineDecodeResult(coordinateChange, index);
  }

  static void _encodeNextValue(int value, StringBuffer buffer) {
    var encoded = value < 0 ? ~(value << 1) : value << 1;

    while (encoded >= 0x20) {
      buffer.writeCharCode((0x20 | (encoded & 0x1F)) + 63);
      encoded >>= 5;
    }

    buffer.writeCharCode(encoded + 63);
  }

  static int _readInt(Object? value) {
    if (value is num) {
      return value.round();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static LatLngBounds? _readBounds(Object? value) {
    if (value is! Map) {
      return null;
    }

    final northeastLat = _readDouble(value['northeast_latitude']);
    final northeastLng = _readDouble(value['northeast_longitude']);
    final southwestLat = _readDouble(value['southwest_latitude']);
    final southwestLng = _readDouble(value['southwest_longitude']);

    if (northeastLat == null ||
        northeastLng == null ||
        southwestLat == null ||
        southwestLng == null) {
      return null;
    }

    return LatLngBounds(
      southwest: LatLng(southwestLat, southwestLng),
      northeast: LatLng(northeastLat, northeastLng),
    );
  }

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}

class _PolylineDecodeResult {
  final int value;
  final int nextIndex;

  const _PolylineDecodeResult(this.value, this.nextIndex);
}
