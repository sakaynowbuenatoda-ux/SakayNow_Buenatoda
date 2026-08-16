import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/controllers/quick_destinations_controller.dart';
import 'package:sakaynow_buenatoda/models/ride_location.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('adds a ride drop-off to the one-tap destination list', () async {
    final firestore = FakeFirebaseFirestore();
    final controller = QuickDestinationsController(
      userId: 'passenger-1',
      firestore: firestore,
    );
    addTearDown(controller.dispose);

    final destination = await controller.addRideDestination(
      const RideLocation(
        name: 'Buenavista Municipal Hall',
        address: 'Poblacion, Buenavista, Bohol',
        placeId: 'municipal-hall-place',
        latitude: 10.0801,
        longitude: 124.1762,
      ),
    );

    expect(destination.label, 'Buenavista Municipal Hall');
    expect(destination.pinPlaceId, 'municipal-hall-place');
    expect(controller.destinations, hasLength(1));

    final user = await firestore.collection('users').doc('passenger-1').get();
    final savedDestinations = user.data()?['quick_destinations'] as List;
    expect(savedDestinations, hasLength(1));
    expect(savedDestinations.single['label'], 'Buenavista Municipal Hall');
  });

  test('does not add the same ride destination more than once', () async {
    final controller = QuickDestinationsController(
      userId: 'passenger-1',
      firestore: FakeFirebaseFirestore(),
    );
    addTearDown(controller.dispose);

    const firstRide = RideLocation(
      name: 'Buenavista Community College',
      address: 'Cangawa, Buenavista, Bohol',
      placeId: 'bcc-place',
      latitude: 10.0874,
      longitude: 124.1812,
    );
    const repeatRide = RideLocation(
      name: 'BCC',
      address: 'Cangawa, Buenavista, Bohol',
      placeId: 'bcc-place',
      latitude: 10.0875,
      longitude: 124.1813,
    );

    final first = await controller.addRideDestination(firstRide);
    final repeated = await controller.addRideDestination(repeatRide);

    expect(repeated.id, first.id);
    expect(controller.destinations, hasLength(1));
    expect(controller.destinationForRideLocation(repeatRide), same(first));
  });
}
