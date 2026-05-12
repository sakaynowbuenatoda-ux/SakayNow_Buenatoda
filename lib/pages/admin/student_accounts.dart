import 'package:flutter/material.dart';

import 'admin_record_list_page.dart';

class StudentAccountsPage extends StatelessWidget {
  final String adminId;

  const StudentAccountsPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return AdminRecordListPage(
      adminId: adminId,
      listType: AdminRecordListType.studentAccounts,
    );
  }
}
