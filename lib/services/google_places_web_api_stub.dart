import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/place_details.dart';
import '../models/place_prediction.dart';
import '../models/ride_location.dart';

bool get googlePlacesWebApiSupported => false;

Future<List<PlacePrediction>> autocompleteWithGooglePlacesWeb({
  required String input,
  LatLng? locationBias,
  required int radiusMeters,
}) {
  throw UnsupportedError(
    'Google Places JavaScript API is only available on web.',
  );
}

Future<PlaceDetails> fetchPlaceDetailsWithGooglePlacesWeb(String placeId) {
  throw UnsupportedError(
    'Google Places JavaScript API is only available on web.',
  );
}

Future<String> reverseGeocodeWithGoogleMapsWeb(LatLng location) {
  throw UnsupportedError(
    'Google Maps JavaScript API is only available on web.',
  );
}

Future<RideLocation?> nearestKnownPlaceWithGooglePlacesWeb(LatLng location) {
  throw UnsupportedError(
    'Google Places JavaScript API is only available on web.',
  );
}

Future<List<RideLocation>> nearbyKnownPlacesWithGooglePlacesWeb(
  LatLng location, {
  int limit = 5,
}) {
  throw UnsupportedError(
    'Google Places JavaScript API is only available on web.',
  );
}
