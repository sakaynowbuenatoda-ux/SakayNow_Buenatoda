import 'package:flutter/material.dart';

import 'admin_booking_history_page.dart';

class TripsInMotionPage extends StatelessWidget {
  const TripsInMotionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminBookingHistoryPage(
      initialSection: AdminBookingHistorySection.ongoing,
    );
  }
}
