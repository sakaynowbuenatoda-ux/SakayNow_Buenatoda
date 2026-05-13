import 'package:flutter/material.dart';

import '../../models/ride.dart';
import '../../services/chat_service.dart';
import 'chat_page.dart';

Future<void> openRideChat({
  required BuildContext context,
  required Ride ride,
  required String currentUserId,
  required String currentUserRole,
}) async {
  try {
    final conversationId = await ChatService()
        .createRideConversationFromBooking(ride.bookingId);
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          currentUserId: currentUserId,
          currentUserRole: currentUserRole,
          title: currentUserRole == 'driver' ? 'Passenger' : 'Driver',
          subtitle: 'Ride chat',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Unable to open ride chat: $error')));
  }
}
