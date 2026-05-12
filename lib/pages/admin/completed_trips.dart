import 'package:flutter/material.dart';

import 'admin_record_list_page.dart';

class CompletedTripsPage extends StatelessWidget {
  const CompletedTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminRecordListPage(
      adminId: '',
      listType: AdminRecordListType.completedTrips,
    );
  }
}
