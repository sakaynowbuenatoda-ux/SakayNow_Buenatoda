import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/route_result.dart';

bool get googleDirectionsWebApiSupported => false;

Future<RouteResult> fetchRouteWithGoogleDirectionsWeb({
  required LatLng origin,
  required LatLng destination,
}) {
  throw UnsupportedError(
    'Google Directions JavaScript API is only available on web.',
  );
}
