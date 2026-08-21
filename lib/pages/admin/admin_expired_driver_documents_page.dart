import 'package:flutter/material.dart';

import 'admin_record_list_page.dart';

class AdminExpiredDriverDocumentsPage extends StatelessWidget {
  final String adminId;

  const AdminExpiredDriverDocumentsPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return AdminRecordListPage(
      adminId: adminId,
      listType: AdminRecordListType.expiredDriverDocuments,
    );
  }
}
