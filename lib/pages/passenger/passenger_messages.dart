import 'package:flutter/material.dart';

import '../messages/conversation_list_page.dart';

class PassengerMessages extends StatelessWidget {
  final String userId;
  final String firstName;
  final String passengerType;

  const PassengerMessages({
    super.key,
    required this.userId,
    required this.firstName,
    required this.passengerType,
  });

  @override
  Widget build(BuildContext context) {
    return ConversationListPage(
      currentUserId: userId,
      currentUserName: firstName,
      currentUserRole: 'passenger',
      title: 'Messages',
      emptyTitle: 'No conversations yet',
      emptyDescription: 'Driver and support conversations will appear here.',
    );
  }
}
