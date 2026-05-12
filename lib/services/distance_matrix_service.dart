import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../config/map_config.dart';
import '../models/distance_matrix_result.dart';
import 'google_maps_api_exception.dart';

class DistanceMatrixService {
  final http.Client _client;

  DistanceMatrixService({http.Client? client})
    : _client = client ?? http.Client();

  Future<DistanceMatrixResult> estimate({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final apiKey = _requireApiKey();
    final uri = Uri.https(
      MapConfig.googleApisHost,
      '/maps/api/distancematrix/json',
      <String, String>{
        'origins': '${origin.latitude},${origin.longitude}',
        'destinations': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'units': 'metric',
        'key': apiKey,
      },
    );

    final response = await _client.get(uri);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final status = (payload['status'] ?? '').toString();

    if (response.statusCode != 200 || status != 'OK') {
      throw GoogleMapsApiException(
        (payload['error_message'] ?? 'Unable to estimate travel time.')
            .toString(),
        status: status,
      );
    }

    final rows = payload['rows'] as List<dynamic>? ?? <dynamic>[];
    final elements = rows.isNotEmpty
        ? (rows.first as Map<String, dynamic>)['elements'] as List<dynamic>? ??
              <dynamic>[]
        : <dynamic>[];
    final element = elements.isNotEmpty
        ? elements.first as Map<String, dynamic>
        : <String, dynamic>{};
    final elementStatus = (element['status'] ?? '').toString();

    if (elementStatus != 'OK') {
      throw GoogleMapsApiException(
        'Unable to estimate travel time for this route.',
        status: elementStatus,
      );
    }

    return DistanceMatrixResult(
      distanceMeters: _readValue(element['distance']),
      durationSeconds: _readValue(element['duration']),
      distanceText: _readText(element['distance']),
      durationText: _readText(element['duration']),
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
    if (value is Map && value['value'] is num) {
      return (value['value'] as num).round();
    }

    return 0;
  }

  static String _readText(Object? value) {
    if (value is Map) {
      return (value['text'] ?? '').toString();
    }

    return '';
  }
}
