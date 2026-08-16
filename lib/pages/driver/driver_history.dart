import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/trip_history_sort.dart';
import 'driver_home.dart';

class DriverHistoryPage extends StatefulWidget {
  final String driverId;

  const DriverHistoryPage({super.key, required this.driverId});

  @override
  State<DriverHistoryPage> createState() => _DriverHistoryPageState();
}

class _DriverHistoryPageState extends State<DriverHistoryPage> {
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
            DriverRecentTripsSection(
              driverId: widget.driverId,
              limit: null,
              sortOption: _sortOption,
            ),
          ],
        ),
      ),
    );
  }
}
