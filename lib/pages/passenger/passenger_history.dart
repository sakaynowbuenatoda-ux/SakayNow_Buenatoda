import 'package:flutter/material.dart';

import '../../controllers/quick_destinations_controller.dart';
import '../../widgets/passenger_widgets/passenger_recent_trips_section.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/trip_history_sort.dart';

class PassengerHistory extends StatefulWidget {
  final String userId;
  final String firstName;
  final String passengerType;
  final QuickDestinationsController quickDestinationsController;

  const PassengerHistory({
    super.key,
    required this.userId,
    required this.firstName,
    required this.passengerType,
    required this.quickDestinationsController,
  });

  @override
  State<PassengerHistory> createState() => _PassengerHistoryState();
}

class _PassengerHistoryState extends State<PassengerHistory> {
  TripHistorySortOption _sortOption = TripHistorySortOption.newest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        title: Text('Trip History', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TripHistorySortControl(
              value: _sortOption,
              onChanged: (next) => setState(() => _sortOption = next),
            ),
            const SizedBox(height: 16),
            PassengerRecentTripsSection(
              passengerId: widget.userId,
              limit: null,
              title: 'Trips',
              actionLabel: '',
              quickDestinationsController: widget.quickDestinationsController,
              sortOption: _sortOption,
            ),
          ],
        ),
      ),
    );
  }
}
