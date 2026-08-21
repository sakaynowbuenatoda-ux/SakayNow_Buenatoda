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

  test('accepts saved geometry only when it matches the preview trip', () {
    const pickup = LatLng(10.0812, 124.1128);
    const dropoff = LatLng(10.0965, 124.1214);
    const route = RouteResult(
      encodedPolyline: '',
      polylinePoints: <LatLng>[
        LatLng(10.0813, 124.1129),
        LatLng(10.0870, 124.1170),
        LatLng(10.0964, 124.1215),
      ],
      distanceMeters: 2400,
      durationSeconds: 480,
      distanceText: '2.4 km',
      durationText: '8 mins',
    );

    expect(
      routeMatchesPreviewTrip(route, pickup: pickup, dropoff: dropoff),
      isTrue,
    );
  });

  test('rejects saved geometry with endpoints from another trip', () {
    const route = RouteResult(
      encodedPolyline: '',
      polylinePoints: <LatLng>[
        LatLng(10.2000, 124.2000),
        LatLng(10.1900, 124.1900),
        LatLng(10.1800, 124.1800),
      ],
      distanceMeters: 3000,
      durationSeconds: 600,
      distanceText: '3 km',
      durationText: '10 mins',
    );

    expect(
      routeMatchesPreviewTrip(
        route,
        pickup: const LatLng(10.0812, 124.1128),
        dropoff: const LatLng(10.0965, 124.1214),
      ),
      isFalse,
    );
  });

  test('rejects an abnormal route line even when its endpoints match', () {
    const pickup = LatLng(10.0812, 124.1128);
    const dropoff = LatLng(10.0965, 124.1214);
    const route = RouteResult(
      encodedPolyline: '',
      polylinePoints: <LatLng>[pickup, LatLng(14.5995, 120.9842), dropoff],
      distanceMeters: 2400,
      durationSeconds: 480,
      distanceText: '2.4 km',
      durationText: '8 mins',
    );

    expect(
      routeMatchesPreviewTrip(route, pickup: pickup, dropoff: dropoff),
      isFalse,
    );
  });
}
