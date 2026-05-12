import 'package:flutter/material.dart';

import 'admin_record_list_page.dart';

class TripsInMotionPage extends StatelessWidget {
  const TripsInMotionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminRecordListPage(
      adminId: '',
      listType: AdminRecordListType.activeTrips,
    );
  }
}
