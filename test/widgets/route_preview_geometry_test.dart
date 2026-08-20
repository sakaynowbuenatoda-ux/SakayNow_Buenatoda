import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sakaynow_buenatoda/models/route_result.dart';
import 'package:sakaynow_buenatoda/widgets/maps/ride_location_preview_dialog.dart';

void main() {
  test(
    'uses the saved road route rather than a direct pickup-to-drop-off line',
    () {
      const route = RouteResult(
        encodedPolyline: '',
        polylinePoints: <LatLng>[
          LatLng(10.7000, 122.6260),
          LatLng(10.6960, 122.6310),
          LatLng(10.6800, 122.6400),
        ],
        distanceMeters: 3000,
        durationSeconds: 600,
        distanceText: '3 km',
        durationText: '10 mins',
      );

      expect(
        routePreviewPolylinePoints(route),
        orderedEquals(route.polylinePoints),
      );
    },
  );

  test('does not present the legacy two-point fallback as a road route', () {
    const straightLine = RouteResult(
      encodedPolyline: '',
      polylinePoints: <LatLng>[
        LatLng(10.7000, 122.6260),
        LatLng(10.6800, 122.6400),
      ],
      distanceMeters: 2500,
      durationSeconds: 500,
      distanceText: '2.5 km',
      durationText: '9 mins',
    );

    expect(routePreviewPolylinePoints(straightLine), isEmpty);
  });
}
