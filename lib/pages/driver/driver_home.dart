import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'driver_data.dart';

class DriverHomePage extends StatelessWidget {
  final String userId;
  final String firstName;
  final bool isActive;

  const DriverHomePage({
    super.key,
    required this.userId,
    required this.firstName,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Driver Home',
            style: PassengerUi.sectionTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage bookings, stay visible to passengers, and keep trips moving safely.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 18),
          DriverStatusHeroCard(
            firstName: firstName,
            isActive: isActive,
          ),
          const SizedBox(height: 20),
          const PassengerSectionHeader(title: 'Incoming Requests'),
          const SizedBox(height: 12),
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

class DriverStatusHeroCard extends StatelessWidget {
  final String firstName;
  final bool isActive;

  const DriverStatusHeroCard({
    super.key,
    required this.firstName,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F3FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.two_wheeler_rounded, color: PassengerUi.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Welcome, $firstName', style: PassengerUi.cardTitle.copyWith(fontSize: 18)),
                    const SizedBox(height: 6),
                    Text(
                      isActive
                          ? 'You are visible to passengers and ready to accept requests.'
                          : 'Go active to receive new bookings around Buenavista.',
                      style: PassengerUi.bodyText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PassengerStatusChip(
            label: isActive ? 'Active for bookings' : 'Currently offline',
            textColor: isActive ? const Color(0xFF166534) : const Color(0xFF92400E),
            backgroundColor: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
          ),
        ],
      ),
    );
  }
}

class DriverQueueCard extends StatelessWidget {
  final DriverQueueItem item;

  const DriverQueueCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(item.passengerName, style: PassengerUi.cardTitle),
              ),
              PassengerStatusChip(
                label: item.status == 'new' ? 'New request' : 'Queued',
                textColor: item.status == 'new'
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF166534),
                backgroundColor: item.status == 'new'
                    ? const Color(0xFFDBEAFE)
                    : const Color(0xFFDCFCE7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Pickup: ${item.pickup}', style: PassengerUi.bodyText),
          const SizedBox(height: 4),
          Text('Drop-off: ${item.dropoff}', style: PassengerUi.bodyText),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(item.requestedAt, style: PassengerUi.bodyText.copyWith(fontSize: 13)),
              const Spacer(),
              Text(item.fare, style: PassengerUi.valueText),
            ],
          ),
        ],
      ),
    );
  }
}
