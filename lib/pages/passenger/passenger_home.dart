import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_booking_hero_card.dart';
import '../../widgets/passenger_widgets/passenger_fare_information_card.dart';
import '../../widgets/passenger_widgets/passenger_quick_destinations_section.dart';
import '../../widgets/passenger_widgets/passenger_recent_trips_section.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'passenger_data.dart';
import 'passenger_book_ride_page.dart';

class PassengerHomepage extends StatelessWidget {
  final String userId;
  final String firstName;
  final String role;

  const PassengerHomepage({
    super.key,
    required this.userId,
    required this.firstName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Welcome back, $firstName',
            style: PassengerUi.sectionTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            'Book faster, ride safer, and keep every trip transparent across Buenavista.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 18),
          PassengerBookingHeroCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PassengerBookRidePage()),
            ),
          ),
          const SizedBox(height: 24),
          PassengerQuickDestinationsSection(
            destinations: PassengerMockData.quickDestinations,
            onSeeAllTap: () => _showSnackBar(
              context,
              'Saved destinations will be connected to Firestore next.',
            ),
            onDestinationTap: (PassengerQuickDestination destination) =>
                _showSnackBar(context, 'Selected ${destination.label}.'),
          ),
          const SizedBox(height: 24),
          PassengerRecentTripsSection(
            trips: PassengerMockData.recentTrips.take(2).toList(),
            onViewAllTap: () => _showSnackBar(
              context,
              'Trip history is available in the History tab.',
            ),
            onTripTap: (PassengerTripSummary trip) =>
                _showSnackBar(context, 'Opened ${trip.destination}.'),
          ),
          const SizedBox(height: 20),
          const PassengerFareInformationCard(),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
