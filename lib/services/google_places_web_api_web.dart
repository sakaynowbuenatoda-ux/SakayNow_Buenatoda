// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:js' as js;
import 'dart:js_util' as js_util;

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web/web.dart' as web;

import '../config/app_environment.dart';
import '../models/place_details.dart';
import '../models/place_prediction.dart';
import '../models/ride_location.dart';
import 'google_maps_api_exception.dart';
import 'google_maps_web_loader.dart';

bool get googlePlacesWebApiSupported => true;

Future<List<PlacePrediction>> autocompleteWithGooglePlacesWeb({
  required String input,
  LatLng? locationBias,
  required int radiusMeters,
}) async {
  await ensureGoogleMapsWebSdkLoaded(AppEnvironment.googleMapsWebApiKey);

  final service = js_util.callConstructor<Object>(
    _placesConstructor('AutocompleteService'),
    <Object>[],
  );
  final request = <String, Object?>{
    'input': input,
    'componentRestrictions': <String, String>{'country': 'ph'},
    'types': <String>['geocode', 'establishment'],
  };

  final bias = locationBias;
  if (bias != null) {
    request['bounds'] = _boundsAround(bias, radiusMeters);
    request['strictBounds'] = true;
  }

  final completer = Completer<List<PlacePrediction>>();
  js_util.callMethod<void>(service, 'getPlacePredictions', <Object?>[
    js_util.jsify(request),
    js.allowInterop((Object? predictions, Object? status) {
      final statusText = _statusText(status);
      if (statusText == 'ZERO_RESULTS') {
        completer.complete(<PlacePrediction>[]);
        return;
      }

      if (statusText != 'OK') {
        completer.completeError(
          GoogleMapsApiException(
            'Unable to load place suggestions.',
            status: statusText,
          ),
        );
        return;
      }

      final predictionList = js_util.dartify(predictions) as List<dynamic>?;
      completer.complete(
        (predictionList ?? <dynamic>[])
            .map(_predictionFromWeb)
            .where((prediction) => prediction.placeId.isNotEmpty)
            .toList(growable: false),
      );
    }),
  ]);

  return completer.future;
}

Future<PlaceDetails> fetchPlaceDetailsWithGooglePlacesWeb(
  String placeId,
) async {
  await ensureGoogleMapsWebSdkLoaded(AppEnvironment.googleMapsWebApiKey);

  final service = js_util.callConstructor<Object>(
    _placesConstructor('PlacesService'),
    <Object>[web.document.createElement('div')],
  );
  final completer = Completer<PlaceDetails>();
  js_util.callMethod<void>(service, 'getDetails', <Object?>[
    js_util.jsify(<String, Object?>{
      'placeId': placeId,
      'fields': <String>['place_id', 'name', 'formatted_address', 'geometry'],
    }),
    js.allowInterop((Object? place, Object? status) {
      final statusText = _statusText(status);
      if (statusText != 'OK' || place == null) {
        completer.completeError(
          GoogleMapsApiException(
            'Unable to load place details.',
            status: statusText,
          ),
        );
        return;
      }

      completer.complete(_placeDetailsFromWeb(place));
    }),
  ]);

  return completer.future;
}

Future<String> reverseGeocodeWithGoogleMapsWeb(LatLng location) async {
  await ensureGoogleMapsWebSdkLoaded(AppEnvironment.googleMapsWebApiKey);

  final geocoder = js_util.callConstructor<Object>(
    _mapsConstructor('Geocoder'),
    <Object>[],
  );
  final completer = Completer<String>();
  js_util.callMethod<void>(geocoder, 'geocode', <Object?>[
    js_util.jsify(<String, Object?>{'location': _latLng(location)}),
    js.allowInterop((Object? results, Object? status) {
      final statusText = _statusText(status);
      if (statusText == 'ZERO_RESULTS') {
        completer.complete(
          '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
        );
        return;
      }

      if (statusText != 'OK') {
        completer.completeError(
          GoogleMapsApiException(
            'Unable to read pinned address.',
            status: statusText,
          ),
        );
        return;
      }

      final resultList = js_util.dartify(results) as List<dynamic>?;
      final first = resultList?.isNotEmpty == true
          ? resultList!.first as Map<dynamic, dynamic>
          : <dynamic, dynamic>{};
      completer.complete((first['formatted_address'] ?? '').toString());
    }),
  ]);

  return completer.future;
}

Future<RideLocation?> nearestKnownPlaceWithGooglePlacesWeb(
  LatLng location,
) async {
  final places = await nearbyKnownPlacesWithGooglePlacesWeb(location, limit: 1);
  return places.isEmpty ? null : places.first;
}

Future<List<RideLocation>> nearbyKnownPlacesWithGooglePlacesWeb(
  LatLng location, {
  int limit = 5,
}) async {
  await ensureGoogleMapsWebSdkLoaded(AppEnvironment.googleMapsWebApiKey);

  final service = js_util.callConstructor<Object>(
    _placesConstructor('PlacesService'),
    <Object>[web.document.createElement('div')],
  );
  final completer = Completer<List<RideLocation>>();
  js_util.callMethod<void>(service, 'nearbySearch', <Object?>[
    js_util.jsify(<String, Object?>{
      'location': _latLng(location),
      'radius': 250,
    }),
    js.allowInterop((Object? results, Object? status, Object? _) {
      final statusText = _statusText(status);
      if (statusText == 'ZERO_RESULTS') {
        completer.complete(<RideLocation>[]);
        return;
      }

      if (statusText != 'OK') {
        completer.completeError(
          GoogleMapsApiException(
            'Unable to read nearby place.',
            status: statusText,
          ),
        );
        return;
      }

      final resultList = js_util.dartify(results) as List<dynamic>?;
      completer.complete(
        _placesFromResults(
          resultList ?? <dynamic>[],
          location,
        ).take(limit).toList(),
      );
    }),
  ]);

  return completer.future;
}

PlacePrediction _predictionFromWeb(Object? value) {
  final prediction = value as Map<dynamic, dynamic>;
  final formatting =
      prediction['structured_formatting'] as Map<dynamic, dynamic>? ??
      <dynamic, dynamic>{};

  return PlacePrediction(
    placeId: (prediction['place_id'] ?? '').toString(),
    description: (prediction['description'] ?? '').toString(),
    mainText: (formatting['main_text'] ?? prediction['description'] ?? '')
        .toString(),
    secondaryText: (formatting['secondary_text'] ?? '').toString(),
  );
}

PlaceDetails _placeDetailsFromWeb(Object place) {
  final location = _placeLocation(place);

  return PlaceDetails(
    placeId: _property(place, 'place_id'),
    name: _property(place, 'name'),
    formattedAddress: _property(place, 'formatted_address'),
    latitude: location.latitude,
    longitude: location.longitude,
  );
}

List<RideLocation> _placesFromResults(List<dynamic> results, LatLng location) {
  final candidates = <_NearbyPlaceCandidate>[];

  for (final result in results) {
    if (result is! Map<dynamic, dynamic>) {
      continue;
    }

    final latLng = _mapPlaceLocation(result);
    if (latLng == null) {
      continue;
    }

    final name = (result['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      continue;
    }

    final distance = Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      latLng.latitude,
      latLng.longitude,
    );

    candidates.add(
      _NearbyPlaceCandidate(
        distanceMeters: distance,
        place: RideLocation(
          address: (result['vicinity'] ?? name).toString().trim(),
          name: name,
          placeId: (result['place_id'] ?? '').toString(),
          latitude: latLng.latitude,
          longitude: latLng.longitude,
        ),
      ),
    );
  }

  candidates.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

  return candidates.map((candidate) => candidate.place).toList();
}

class _NearbyPlaceCandidate {
  final double distanceMeters;
  final RideLocation place;

  const _NearbyPlaceCandidate({
    required this.distanceMeters,
    required this.place,
  });
}

LatLng? _mapPlaceLocation(Map<dynamic, dynamic> place) {
  final geometry = place['geometry'];
  if (geometry is! Map<dynamic, dynamic>) {
    return null;
  }

  final location = geometry['location'];
  if (location is! Map<dynamic, dynamic>) {
    return null;
  }

  final lat = location['lat'];
  final lng = location['lng'];
  if (lat is! num || lng is! num) {
    return null;
  }

  return LatLng(lat.toDouble(), lng.toDouble());
}

LatLng _placeLocation(Object place) {
  final geometry = js_util.getProperty<Object?>(place, 'geometry');
  if (geometry == null) {
    throw const GoogleMapsApiException('Place details are missing geometry.');
  }

  final location = js_util.getProperty<Object?>(geometry, 'location');
  if (location == null) {
    throw const GoogleMapsApiException(
      'Place details are missing coordinates.',
    );
  }

  final lat = js_util.callMethod<num>(location, 'lat', <Object>[]);
  final lng = js_util.callMethod<num>(location, 'lng', <Object>[]);

  return LatLng(lat.toDouble(), lng.toDouble());
}

Object _boundsAround(LatLng center, int radiusMeters) {
  final degreeOffset = radiusMeters / 111320;
  return js_util.callConstructor<Object>(
    _mapsConstructor('LatLngBounds'),
    <Object>[
      _latLng(
        LatLng(center.latitude - degreeOffset, center.longitude - degreeOffset),
      ),
      _latLng(
        LatLng(center.latitude + degreeOffset, center.longitude + degreeOffset),
      ),
    ],
  );
}

Object _latLng(LatLng location) {
  return js_util.callConstructor<Object>(_mapsConstructor('LatLng'), <Object>[
    location.latitude,
    location.longitude,
  ]);
}

Object _mapsConstructor(String name) {
  return js_util.getProperty<Object>(_maps, name);
}

Object _placesConstructor(String name) {
  return js_util.getProperty<Object>(_places, name);
}

Object get _maps {
  final google = js_util.getProperty<Object>(web.window, 'google');
  return js_util.getProperty<Object>(google, 'maps');
}

Object get _places {
  return js_util.getProperty<Object>(_maps, 'places');
}

String _property(Object object, String name) {
  return (js_util.getProperty<Object?>(object, name) ?? '').toString().trim();
}

String _statusText(Object? status) => (status ?? '').toString();
