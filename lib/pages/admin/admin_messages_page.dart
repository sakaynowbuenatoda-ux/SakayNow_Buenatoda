import 'package:flutter/material.dart';

import '../../models/chat_conversation.dart';
import '../../services/chat_service.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/time_ago_text.dart';
import '../messages/chat_page.dart';
import 'widgets/admin_shared.dart';

class AdminMessagesPage extends StatelessWidget {
  final String adminId;

  const AdminMessagesPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AdminSectionIntro(title: 'Messages'),
          const SizedBox(height: 16),
          StreamBuilder<List<ChatConversation>>(
            stream: chatService.watchAdminSupportConversations(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const PassengerSurfaceCard(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return AdminErrorCard(message: snapshot.error.toString());
              }

              final conversations = snapshot.data ?? <ChatConversation>[];
              if (conversations.isEmpty) {
                return const AdminEmptyCollection(
                  icon: Icons.support_agent_rounded,
                  title: 'No support messages yet',
                  description:
                      'Passenger and driver support requests appear here.',
                );
              }

              final unreadTotal = conversations.fold<int>(
                0,
                (total, conversation) => total + conversation.adminUnreadCount,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PassengerSurfaceCard(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Unread support messages',
                            style: PassengerUi.cardTitle,
                          ),
                        ),
                        PassengerStatusChip(
                          label: unreadTotal == 1
                              ? '1 new'
                              : '$unreadTotal new',
                          textColor: PassengerUi.accentBlue,
                          backgroundColor: PassengerUi.blueSoft,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...conversations.asMap().entries.map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key == conversations.length - 1 ? 0 : 12,
                      ),
                      child: _AdminSupportConversationCard(
                        conversation: entry.value,
                        adminId: adminId,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminSupportConversationCard extends StatelessWidget {
  final ChatConversation conversation;
  final String adminId;

  const _AdminSupportConversationCard({
    required this.conversation,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    final title = conversation.titleFor(
      currentUserId: adminId,
      currentUserRole: 'admin',
    );
    final unreadCount = conversation.adminUnreadCount;

    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: PassengerUi.cardRadius,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                conversationId: conversation.conversationId,
                currentUserId: adminId,
                currentUserRole: 'admin',
                title: title,
                subtitle: 'Support request',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: unreadCount > 0
                      ? PassengerUi.blueSoft
                      : PassengerUi.mutedSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
                  style: PassengerUi.cardTitle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PassengerUi.cardTitle.copyWith(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        TimeAgoText(
                          dateTime: conversation.latestActivityAt,
                          style: PassengerUi.bodyText.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        PassengerStatusChip(
                          label: 'Support',
                          textColor: PassengerUi.accentBlue,
                          backgroundColor: PassengerUi.blueSoft,
                        ),
                        if (unreadCount > 0)
                          PassengerStatusChip(
                            label: unreadCount > 99
                                ? '99+ unread'
                                : '$unreadCount unread',
                            textColor: PassengerUi.successText,
                            backgroundColor: PassengerUi.successBackground,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      conversation.previewFor(adminId),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PassengerUi.bodyText,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
