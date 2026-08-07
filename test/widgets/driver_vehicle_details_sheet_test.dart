import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/models/ride_driver_location.dart';
import 'package:sakaynow_buenatoda/services/ride_tracking_service.dart';
import 'package:sakaynow_buenatoda/widgets/driver_vehicle_details_sheet.dart';

void main() {
  group('DriverVehicleInfoCard & Models Test Suite', () {
    testWidgets(
      'renders fallback text when vehicle details are null or empty',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DriverVehicleInfoCard(
                vehicleType: null,
                tricycleColor: '',
                plateNumber: null,
                tricycleFrontUrl: null,
                tricycleBackUrl: null,
              ),
            ),
          ),
        );

        expect(find.text('Tricycle & Vehicle Identity'), findsOneWidget);
        expect(find.text('Vehicle Type'), findsOneWidget);
        expect(find.text('Tricycle Color'), findsOneWidget);
        expect(find.text('Plate / Franchise No.'), findsOneWidget);
        expect(find.text('Not specified'), findsNWidgets(3));

        // Check photo fallbacks
        expect(find.text('Front photo not available'), findsOneWidget);
        expect(find.text('Back photo not available'), findsOneWidget);
        expect(
          find.byIcon(Icons.image_not_supported_outlined),
          findsNWidgets(2),
        );
      },
    );

    testWidgets('renders explicit vehicle specifications when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DriverVehicleInfoCard(
              vehicleType: 'E-Tricycle / Bao-bao',
              tricycleColor: 'Vibrant Red',
              plateNumber: 'T-889900',
              tricycleFrontUrl: 'https://example.com/front.jpg',
              tricycleBackUrl: 'https://example.com/back.jpg',
            ),
          ),
        ),
      );

      expect(find.text('E-Tricycle / Bao-bao'), findsOneWidget);
      expect(find.text('Vibrant Red'), findsOneWidget);
      expect(find.text('T-889900'), findsOneWidget);
    });

    test(
      'AvailableDriver and DriverReviewProfile parse vehicle data and generate summary',
      () {
        final userData = <String, dynamic>{
          'first_name': 'Juan',
          'last_name': 'Dela Cruz',
          'vehicle_type': 'Traditional Tricycle',
          'tricycle_color': 'Blue',
          'plate_number': 'BUENA-101',
          'tricycle_front_url': 'https://storage.example/front.jpg',
          'tricycle_back_url': 'https://storage.example/back.jpg',
        };

        final location = RideDriverLocation(
          driverId: 'drv-1',
          latitude: 14.0,
          longitude: 121.0,
          accuracy: 5.0,
          updatedAt: DateTime.now(),
        );

        final availableDriver = AvailableDriver.fromData(
          driverId: 'drv-1',
          location: location,
          userData: userData,
        );

        expect(availableDriver.vehicleType, 'Traditional Tricycle');
        expect(availableDriver.tricycleColor, 'Blue');
        expect(availableDriver.plateNumber, 'BUENA-101');
        expect(availableDriver.hasVehicleInfo, isTrue);
        expect(
          availableDriver.vehicleSummary,
          'Traditional Tricycle • Blue • BUENA-101',
        );

        final profile = DriverReviewProfile.fromData(
          driverId: 'drv-1',
          data: userData,
        );

        expect(profile.vehicleType, 'Traditional Tricycle');
        expect(profile.tricycleColor, 'Blue');
        expect(profile.plateNumber, 'BUENA-101');
        expect(profile.hasVehicleInfo, isTrue);
        expect(
          profile.vehicleSummary,
          'Traditional Tricycle • Blue • BUENA-101',
        );
      },
    );
  });
}
