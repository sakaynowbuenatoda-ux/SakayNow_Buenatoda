// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:js' as js;
import 'dart:js_util' as js_util;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web/web.dart' as web;

import '../config/app_environment.dart';
import '../models/route_result.dart';
import 'google_maps_api_exception.dart';
import 'google_maps_web_loader.dart';

bool get googleDirectionsWebApiSupported => true;

Future<RouteResult> fetchRouteWithGoogleDirectionsWeb({
  required LatLng origin,
  required LatLng destination,
}) async {
  await ensureGoogleMapsWebSdkLoaded(AppEnvironment.googleMapsWebApiKey);

  final service = js_util.callConstructor<Object>(
    _mapsConstructor('DirectionsService'),
    <Object>[],
  );
  final completer = Completer<RouteResult>();

  js_util.callMethod<void>(service, 'route', <Object?>[
    js_util.jsify(<String, Object?>{
      'origin': _latLng(origin),
      'destination': _latLng(destination),
      'travelMode': 'DRIVING',
      'provideRouteAlternatives': false,
    }),
    js.allowInterop((Object? result, Object? status) {
      final statusText = (status ?? '').toString();
      if (statusText != 'OK' || result == null) {
        completer.completeError(
          GoogleMapsApiException(
            'Unable to load route directions.',
            status: statusText,
          ),
        );
        return;
      }

      try {
        completer.complete(_routeResultFromWeb(result));
      } on Exception catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } catch (error, stackTrace) {
        completer.completeError(
          const GoogleMapsApiException('Unable to read route directions.'),
          stackTrace,
        );
      }
    }),
  ]);

  return completer.future;
}

RouteResult _routeResultFromWeb(Object result) {
  final routes = js_util.getProperty<Object?>(result, 'routes');
  final route = routes == null ? null : _firstItem(routes);
  if (route == null) {
    throw const GoogleMapsApiException('No route was found.');
  }

  final overviewPath = js_util.getProperty<Object?>(route, 'overview_path');
  final points = overviewPath == null
      ? <LatLng>[]
      : _latLngListFromWeb(overviewPath);
  if (points.length < 2) {
    throw const GoogleMapsApiException(
      'The route is missing its road geometry.',
    );
  }

  final legs = js_util.getProperty<Object?>(route, 'legs');
  final leg = legs == null ? null : _firstItem(legs);
  final distance = leg == null
      ? null
      : js_util.getProperty<Object?>(leg, 'distance');
  final duration = leg == null
      ? null
      : js_util.getProperty<Object?>(leg, 'duration');
  final encodedPolyline = RouteResult.encodePolyline(points);

  return RouteResult(
    encodedPolyline: encodedPolyline,
    polylinePoints: points,
    distanceMeters: _metricValue(distance),
    durationSeconds: _metricValue(duration),
    distanceText: _metricText(distance),
    durationText: _metricText(duration),
    bounds: _boundsFromWeb(js_util.getProperty<Object?>(route, 'bounds')),
  );
}

List<LatLng> _latLngListFromWeb(Object values) {
  final length = (js_util.getProperty<num?>(values, 'length') ?? 0).toInt();
  return List<LatLng>.generate(
    length,
    (index) => _latLngFromWeb(js_util.getProperty<Object>(values, index)),
    growable: false,
  );
}

Object? _firstItem(Object values) {
  final length = (js_util.getProperty<num?>(values, 'length') ?? 0).toInt();
  return length == 0 ? null : js_util.getProperty<Object?>(values, 0);
}

LatLng _latLngFromWeb(Object value) {
  final latitude = js_util.callMethod<num>(value, 'lat', <Object>[]);
  final longitude = js_util.callMethod<num>(value, 'lng', <Object>[]);
  return LatLng(latitude.toDouble(), longitude.toDouble());
}

LatLngBounds? _boundsFromWeb(Object? value) {
  if (value == null) {
    return null;
  }

  final southwest = js_util.callMethod<Object>(
    value,
    'getSouthWest',
    <Object>[],
  );
  final northeast = js_util.callMethod<Object>(
    value,
    'getNorthEast',
    <Object>[],
  );
  return LatLngBounds(
    southwest: _latLngFromWeb(southwest),
    northeast: _latLngFromWeb(northeast),
  );
}

int _metricValue(Object? metric) {
  if (metric == null) {
    return 0;
  }

  return (js_util.getProperty<num?>(metric, 'value') ?? 0).round();
}

String _metricText(Object? metric) {
  if (metric == null) {
    return '';
  }

  return (js_util.getProperty<Object?>(metric, 'text') ?? '').toString();
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

Object get _maps {
  final google = js_util.getProperty<Object>(web.window, 'google');
  return js_util.getProperty<Object>(google, 'maps');
}
