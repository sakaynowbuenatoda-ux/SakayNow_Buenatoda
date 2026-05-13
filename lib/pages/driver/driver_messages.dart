import 'package:flutter/material.dart';

import '../messages/conversation_list_page.dart';

class DriverMessagesPage extends StatelessWidget {
  final String userId;
  final String firstName;

  const DriverMessagesPage({
    super.key,
    required this.userId,
    required this.firstName,
  });

  @override
  Widget build(BuildContext context) {
    return ConversationListPage(
      currentUserId: userId,
      currentUserName: firstName,
      currentUserRole: 'driver',
      title: 'Messages',
      emptyTitle: 'No conversations yet',
      emptyDescription: 'Passenger and support conversations will appear here.',
    );
  }
}
