import 'package:flutter/material.dart';

import '../../models/chat_conversation.dart';
import '../../models/chat_participant_profile.dart';
import '../../services/chat_service.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/time_ago_text.dart';
import '../messages/chat_page.dart';
import 'widgets/admin_shared.dart';

class AdminMessagesPage extends StatefulWidget {
  final String adminId;

  const AdminMessagesPage({super.key, required this.adminId});

  @override
  State<AdminMessagesPage> createState() => _AdminMessagesPageState();
}

class _AdminMessagesPageState extends State<AdminMessagesPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Future<ChatParticipantProfile?>> _profileFutures =
      <String, Future<ChatParticipantProfile?>>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StreamBuilder<List<ChatConversation>>(
            stream: _chatService.watchAdminSupportConversations(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _MessagesHeader(
                      searchController: _searchController,
                      unreadTotal: 0,
                    ),
                    const SizedBox(height: 16),
                    const AdminSurfaceCard(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _MessagesHeader(
                      searchController: _searchController,
                      unreadTotal: 0,
                    ),
                    const SizedBox(height: 16),
                    AdminErrorCard(message: snapshot.error.toString()),
                  ],
                );
              }

              final conversations = snapshot.data ?? <ChatConversation>[];
              final unreadTotal = conversations.fold<int>(
                0,
                (total, conversation) => total + conversation.adminUnreadCount,
              );

              final header = _MessagesHeader(
                searchController: _searchController,
                unreadTotal: unreadTotal,
              );

              if (conversations.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    header,
                    const SizedBox(height: 16),
                    const AdminEmptyCollection(
                      icon: Icons.support_agent_rounded,
                      title: 'No support messages yet',
                      description:
                          'Passenger and driver support requests appear here.',
                    ),
                  ],
                );
              }
              final filteredConversations = conversations
                  .where(_matchesConversationSearch)
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  header,
                  const SizedBox(height: 16),
                  if (filteredConversations.isEmpty)
                    AdminEmptyCollection(
                      icon: Icons.search_off_rounded,
                      title: 'No matching users found',
                      description:
                          'Try searching by user name, role, message, or conversation ID.',
                    )
                  else
                    ...filteredConversations.asMap().entries.map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == filteredConversations.length - 1
                              ? 0
                              : 12,
                        ),
                        child: _AdminSupportConversationCard(
                          conversation: entry.value,
                          adminId: widget.adminId,
                          targetProfileFuture: _targetProfileFutureFor(
                            entry.value,
                          ),
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

  Future<ChatParticipantProfile?>? _targetProfileFutureFor(
    ChatConversation conversation,
  ) {
    final targetUserId =
        conversation.supportUserId ??
        conversation.otherParticipantId(widget.adminId);
    if (targetUserId == null || targetUserId.trim().isEmpty) {
      return null;
    }

    return _profileFutures.putIfAbsent(
      targetUserId,
      () => _chatService.loadParticipantProfile(targetUserId),
    );
  }

  bool _matchesConversationSearch(ChatConversation conversation) {
    if (_query.isEmpty) {
      return true;
    }

    final searchable = <String>[
      conversation.conversationId,
      conversation.supportUserId ?? '',
      conversation.bookingId ?? '',
      conversation.titleFor(
        currentUserId: widget.adminId,
        currentUserRole: 'admin',
      ),
      conversation.previewFor(widget.adminId),
      conversation.participantIds.join(' '),
      conversation.participantNames.values.join(' '),
      conversation.participantRoles.values.join(' '),
    ].join(' ').toLowerCase();

    return searchable.contains(_query);
  }
}

class _MessagesHeader extends StatelessWidget {
  final TextEditingController searchController;
  final int unreadTotal;

  const _MessagesHeader({
    required this.searchController,
    required this.unreadTotal,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final title = AdminSectionIntro(title: 'Messages');
        final unreadPill = _UnreadSupportPill(unreadTotal: unreadTotal);
        final search = _MessagesSearchField(controller: searchController);

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              title,
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  unreadPill,
                  const SizedBox(width: 10),
                  Expanded(child: search),
                ],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: title),
            const SizedBox(width: 16),
            unreadPill,
            const SizedBox(width: 10),
            SizedBox(width: 420, child: search),
          ],
        );
      },
    );
  }
}

class _UnreadSupportPill extends StatelessWidget {
  final int unreadTotal;

  const _UnreadSupportPill({required this.unreadTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AdminUi.blueSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminUi.accentBlue.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.mark_chat_unread_rounded,
            size: 16,
            color: AdminUi.accentBlue,
          ),
          const SizedBox(width: 7),
          Text(
            unreadTotal == 1 ? '1 unread' : '$unreadTotal unread',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.labelText.copyWith(
              color: AdminUi.accentBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesSearchField extends StatelessWidget {
  final TextEditingController controller;

  const _MessagesSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: AdminUi.inputDecoration(
        hintText: 'Search all users',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}

class _AdminSupportConversationCard extends StatelessWidget {
  final ChatConversation conversation;
  final String adminId;
  final Future<ChatParticipantProfile?>? targetProfileFuture;

  const _AdminSupportConversationCard({
    required this.conversation,
    required this.adminId,
    required this.targetProfileFuture,
  });

  @override
  Widget build(BuildContext context) {
    final title = conversation.titleFor(
      currentUserId: adminId,
      currentUserRole: 'admin',
    );
    final unreadCount = conversation.adminUnreadCount;

    return AdminSurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AdminUi.cardRadius,
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
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: unreadCount > 0
                      ? AdminUi.blueSoft
                      : AdminUi.mutedSurface,
                  shape: BoxShape.circle,
                ),
                child: _AdminConversationAvatar(
                  title: title,
                  profileFuture: targetProfileFuture,
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
                            style: AdminUi.cardTitle.copyWith(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        TimeAgoText(
                          dateTime: conversation.latestActivityAt,
                          style: AdminUi.bodyText.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        AdminStatusChip(
                          label: 'Support',
                          textColor: AdminUi.accentBlue,
                          backgroundColor: AdminUi.blueSoft,
                        ),
                        if (unreadCount > 0)
                          AdminStatusChip(
                            label: unreadCount > 99
                                ? '99+ unread'
                                : '$unreadCount unread',
                            textColor: AdminUi.successText,
                            backgroundColor: AdminUi.successBackground,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      conversation.previewFor(adminId),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AdminUi.bodyText,
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

class _AdminConversationAvatar extends StatelessWidget {
  final String title;
  final Future<ChatParticipantProfile?>? profileFuture;

  const _AdminConversationAvatar({
    required this.title,
    required this.profileFuture,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = _AdminConversationAvatarFallback(title: title);
    final future = profileFuture;
    if (future == null) {
      return fallback;
    }

    return FutureBuilder<ChatParticipantProfile?>(
      future: future,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return FirebaseStorageImage(
          imageUrl: profile?.profileImageUrl,
          fallback: fallback,
        );
      },
    );
  }
}

class _AdminConversationAvatarFallback extends StatelessWidget {
  final String title;

  const _AdminConversationAvatarFallback({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
        style: AdminUi.cardTitle,
      ),
    );
  }
}
