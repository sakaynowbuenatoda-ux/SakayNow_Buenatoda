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
import 'google_places_web_api.dart' as web_places;

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
    final requests = MapConfig.mentionsSupportedServiceArea(query)
        ? <_PlacesAutocompleteRequest>[
            _PlacesAutocompleteRequest(
              input: query,
              locationBias: locationBias ?? MapConfig.serviceAreaCenter,
              radiusMeters: _serviceAreaRadiusMeters,
            ),
          ]
        : MapConfig.supportedServiceAreas
              .map(
                (area) => _PlacesAutocompleteRequest(
                  input: '$query ${area.name} Bohol',
                  locationBias: area.center,
                  radiusMeters: area.searchRadiusMeters,
                ),
              )
              .toList(growable: false);

    final predictionGroups = await Future.wait(
      requests.map((request) => _fetchAutocomplete(apiKey, request)),
    );

    return _dedupePredictions(
      predictionGroups.expand((predictions) => predictions),
    );
  }

  Future<List<PlacePrediction>> _fetchAutocomplete(
    String apiKey,
    _PlacesAutocompleteRequest request,
  ) async {
    if (web_places.googlePlacesWebApiSupported) {
      return web_places.autocompleteWithGooglePlacesWeb(
        input: request.input,
        locationBias: request.locationBias,
        radiusMeters: request.radiusMeters,
      );
    }

    final parameters = <String, String>{
      'input': request.input,
      'key': apiKey,
      'components': 'country:ph',
      'types': 'geocode|establishment',
      'strictbounds': 'true',
    };

    final locationBias = request.locationBias;
    if (locationBias != null) {
      parameters['location'] =
          '${locationBias.latitude},${locationBias.longitude}';
      parameters['radius'] = request.radiusMeters.toString();
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
    if (web_places.googlePlacesWebApiSupported) {
      final details = await web_places.fetchPlaceDetailsWithGooglePlacesWeb(
        placeId,
      );
      _validateSupportedServiceArea(details.latLng);
      return details;
    }

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

    final details = PlaceDetails.fromJson(
      payload['result'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    _validateSupportedServiceArea(details.latLng);
    return details;
  }

  Future<String> reverseGeocode(LatLng location) async {
    if (web_places.googlePlacesWebApiSupported) {
      return web_places.reverseGeocodeWithGoogleMapsWeb(location);
    }

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
    _validateSupportedServiceArea(location);

    if (web_places.googlePlacesWebApiSupported) {
      return web_places.nearestKnownPlaceWithGooglePlacesWeb(location);
    }

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

  bool isWithinSupportedServiceArea(LatLng location) {
    for (final area in MapConfig.supportedServiceAreas) {
      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        area.center.latitude,
        area.center.longitude,
      );
      if (distance <= area.searchRadiusMeters) {
        return true;
      }
    }

    return false;
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

  List<PlacePrediction> _dedupePredictions(
    Iterable<PlacePrediction> predictions,
  ) {
    final byId = <String, PlacePrediction>{};
    for (final prediction in predictions) {
      byId.putIfAbsent(prediction.placeId, () => prediction);
    }

    return byId.values.take(8).toList(growable: false);
  }

  void _validateSupportedServiceArea(LatLng location) {
    if (isWithinSupportedServiceArea(location)) {
      return;
    }

    throw GoogleMapsApiException(
      'Select a location in ${MapConfig.supportedServiceAreaLabel} only.',
    );
  }

  int get _serviceAreaRadiusMeters {
    var radius = 0;
    for (final area in MapConfig.supportedServiceAreas) {
      if (area.searchRadiusMeters > radius) {
        radius = area.searchRadiusMeters;
      }
    }

    return radius * 2;
  }
}

class _PlacesAutocompleteRequest {
  final String input;
  final LatLng? locationBias;
  final int radiusMeters;

  const _PlacesAutocompleteRequest({
    required this.input,
    required this.locationBias,
    required this.radiusMeters,
  });
}
