import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'driver_data.dart';
import 'driver_home.dart';

class DriverQueuePage extends StatelessWidget {
  const DriverQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Booking Queue', style: PassengerUi.sectionTitle.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            'Review incoming passenger requests and prioritize efficient pickups.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 18),
          ...DriverMockData.queue.asMap().entries.map(
            (MapEntry<int, DriverQueueItem> entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == DriverMockData.queue.length - 1 ? 0 : 12,
              ),
              child: DriverQueueCard(item: entry.value),
            ),
          ),
        ],
      ),
    );
  }
}
