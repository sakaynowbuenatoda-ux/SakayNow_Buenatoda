import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../config/map_config.dart';
import '../models/place_details.dart';
import '../models/place_prediction.dart';
import '../models/ride_location.dart';
import 'google_maps_api_exception.dart';

class GooglePlacesService {
  final http.Client _client;

  GooglePlacesService({http.Client? client})
    : _client = client ?? http.Client();

  Future<List<PlacePrediction>> autocomplete({
    required String input,
    LatLng? locationBias,
  }) async {
    final query = input.trim();
    if (query.length < 2) {
      return <PlacePrediction>[];
    }

    final apiKey = _requireApiKey();
    final parameters = <String, String>{
      'input': query,
      'key': apiKey,
      'components': 'country:ph',
      'types': 'geocode|establishment',
    };

    if (locationBias != null) {
      parameters['location'] =
          '${locationBias.latitude},${locationBias.longitude}';
      parameters['radius'] = '25000';
    }

    final uri = Uri.https(
      MapConfig.googleApisHost,
      '/maps/api/place/autocomplete/json',
      parameters,
    );
    final response = await _client.get(uri);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final status = (payload['status'] ?? '').toString();

    if (status == 'ZERO_RESULTS') {
      return <PlacePrediction>[];
    }

    if (response.statusCode != 200 || status != 'OK') {
      throw GoogleMapsApiException(
        (payload['error_message'] ?? 'Unable to load place suggestions.')
            .toString(),
        status: status,
      );
    }

    final predictions = payload['predictions'] as List<dynamic>? ?? <dynamic>[];
    return predictions
        .whereType<Map<String, dynamic>>()
        .map(PlacePrediction.fromJson)
        .where((prediction) => prediction.placeId.isNotEmpty)
        .toList(growable: false);
  }

  Future<PlaceDetails> fetchDetails(String placeId) async {
    final apiKey = _requireApiKey();
    final uri = Uri.https(
      MapConfig.googleApisHost,
      '/maps/api/place/details/json',
      <String, String>{
        'place_id': placeId,
        'fields': 'place_id,name,formatted_address,geometry',
        'key': apiKey,
      },
    );

    final response = await _client.get(uri);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final status = (payload['status'] ?? '').toString();

    if (response.statusCode != 200 || status != 'OK') {
      throw GoogleMapsApiException(
        (payload['error_message'] ?? 'Unable to load place details.')
            .toString(),
        status: status,
      );
    }

    return PlaceDetails.fromJson(
      payload['result'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<String> reverseGeocode(LatLng location) async {
    final apiKey = _requireApiKey();
    final uri = Uri.https(
      MapConfig.googleApisHost,
      '/maps/api/geocode/json',
      <String, String>{
        'latlng': '${location.latitude},${location.longitude}',
        'key': apiKey,
      },
    );

    final response = await _client.get(uri);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final status = (payload['status'] ?? '').toString();

    if (status == 'ZERO_RESULTS') {
      return '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
    }

    if (response.statusCode != 200 || status != 'OK') {
      throw GoogleMapsApiException(
        (payload['error_message'] ?? 'Unable to read pinned address.')
            .toString(),
        status: status,
      );
    }

    final results = payload['results'] as List<dynamic>? ?? <dynamic>[];
    final first = results.isNotEmpty
        ? results.first as Map<String, dynamic>
        : <String, dynamic>{};

    return (first['formatted_address'] ?? '').toString().trim();
  }

  Future<RideLocation?> nearestKnownPlace(LatLng location) async {
    final apiKey = _requireApiKey();
    final uri = Uri.https(
      MapConfig.googleApisHost,
      '/maps/api/place/nearbysearch/json',
      <String, String>{
        'location': '${location.latitude},${location.longitude}',
        'radius': '75',
        'key': apiKey,
      },
    );

    final response = await _client.get(uri);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final status = (payload['status'] ?? '').toString();

    if (status == 'ZERO_RESULTS') {
      return null;
    }

    if (response.statusCode != 200 || status != 'OK') {
      throw GoogleMapsApiException(
        (payload['error_message'] ?? 'Unable to read nearby place.').toString(),
        status: status,
      );
    }

    final results = payload['results'] as List<dynamic>? ?? <dynamic>[];
    if (results.isEmpty || results.first is! Map<String, dynamic>) {
      return null;
    }

    final place = _closestPlace(results, location);
    if (place == null) {
      return null;
    }

    final geometry = place['geometry'] is Map
        ? place['geometry'] as Map<String, dynamic>
        : <String, dynamic>{};
    final placeLocation = geometry['location'] is Map
        ? geometry['location'] as Map<String, dynamic>
        : <String, dynamic>{};
    final lat = (placeLocation['lat'] as num?)?.toDouble();
    final lng = (placeLocation['lng'] as num?)?.toDouble();
    final name = (place['name'] ?? '').toString().trim();

    if (lat == null || lng == null || name.isEmpty) {
      return null;
    }

    return RideLocation(
      address: (place['vicinity'] ?? name).toString().trim(),
      name: name,
      placeId: (place['place_id'] ?? '').toString(),
      latitude: lat,
      longitude: lng,
    );
  }

  Map<String, dynamic>? _closestPlace(List<dynamic> results, LatLng location) {
    Map<String, dynamic>? closest;
    double? closestDistance;

    for (final result in results) {
      if (result is! Map<String, dynamic>) {
        continue;
      }

      final geometry = result['geometry'] is Map
          ? result['geometry'] as Map<String, dynamic>
          : <String, dynamic>{};
      final placeLocation = geometry['location'] is Map
          ? geometry['location'] as Map<String, dynamic>
          : <String, dynamic>{};
      final lat = (placeLocation['lat'] as num?)?.toDouble();
      final lng = (placeLocation['lng'] as num?)?.toDouble();

      if (lat == null || lng == null) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        lat,
        lng,
      );

      if (closestDistance == null || distance < closestDistance) {
        closest = result;
        closestDistance = distance;
      }
    }

    return closest;
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
}
