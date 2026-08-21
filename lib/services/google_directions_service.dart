import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../config/map_config.dart';
import '../models/route_result.dart';
import 'google_directions_web_api.dart';
import 'google_maps_api_exception.dart';

class GoogleDirectionsService {
  final http.Client _client;

  GoogleDirectionsService({http.Client? client})
    : _client = client ?? http.Client();

  Future<RouteResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (googleDirectionsWebApiSupported) {
      return fetchRouteWithGoogleDirectionsWeb(
        origin: origin,
        destination: destination,
      );
    }

    final apiKey = _requireApiKey();
    final uri = Uri.https(
      MapConfig.googleApisHost,
      '/maps/api/directions/json',
      <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': apiKey,
      },
    );

    final response = await _client.get(uri);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final status = (payload['status'] ?? '').toString();

    if (response.statusCode != 200 || status != 'OK') {
      throw GoogleMapsApiException(
        (payload['error_message'] ?? 'Unable to load route directions.')
            .toString(),
        status: status,
      );
    }

    final routes = payload['routes'] as List<dynamic>? ?? <dynamic>[];
    if (routes.isEmpty) {
      throw const GoogleMapsApiException('No route was found.');
    }

    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>? ?? <dynamic>[];
    final leg = legs.isNotEmpty
        ? legs.first as Map<String, dynamic>
        : <String, dynamic>{};
    final encodedPolyline =
        ((route['overview_polyline'] as Map<String, dynamic>?)?['points'] ?? '')
            .toString();

    return RouteResult(
      encodedPolyline: encodedPolyline,
      polylinePoints: encodedPolyline.isEmpty
          ? <LatLng>[]
          : RouteResult.decodePolyline(encodedPolyline),
      distanceMeters: _readValue(leg['distance']),
      durationSeconds: _readValue(leg['duration']),
      distanceText: _readText(leg['distance']),
      durationText: _readText(leg['duration']),
      bounds: _readBounds(route['bounds']),
    );
  }

  String _requireApiKey() {
    final apiKey = AppEnvironment.googleServicesApiKey;
    if (apiKey.isEmpty) {
      throw const GoogleMapsApiException(
        'Missing GOOGLE_SERVICES_API_KEY. Run Flutter with --dart-define-from-file=../.env or provide a bundled .env.',
      );
    }

    return apiKey;
  }

  static int _readValue(Object? value) {
    if (value is Map) {
      final rawValue = value['value'];
      if (rawValue is num) {
        return rawValue.round();
      }
    }

    return 0;
  }

  static String _readText(Object? value) {
    if (value is Map) {
      return (value['text'] ?? '').toString();
    }

    return '';
  }

  static LatLngBounds? _readBounds(Object? value) {
    if (value is! Map) {
      return null;
    }

    final northeast = value['northeast'];
    final southwest = value['southwest'];
    if (northeast is! Map || southwest is! Map) {
      return null;
    }

    return LatLngBounds(
      southwest: LatLng(
        (southwest['lat'] as num).toDouble(),
        (southwest['lng'] as num).toDouble(),
      ),
      northeast: LatLng(
        (northeast['lat'] as num).toDouble(),
        (northeast['lng'] as num).toDouble(),
      ),
    );
  }
}
