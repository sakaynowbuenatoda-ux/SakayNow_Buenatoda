import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/chat_conversation.dart';
import '../../models/chat_participant_profile.dart';
import '../../services/chat_service.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/time_ago_text.dart';
import 'chat_page.dart';

class ConversationListPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole;
  final String title;
  final String emptyTitle;
  final String emptyDescription;

  const ConversationListPage({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
    required this.title,
    required this.emptyTitle,
    required this.emptyDescription,
  });

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Future<ChatParticipantProfile?>> _profileFutures =
      <String, Future<ChatParticipantProfile?>>{};
  bool _isOpeningSupport = false;
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
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StreamBuilder<List<ChatConversation>>(
            stream: _chatService.watchUserConversations(widget.currentUserId),
            builder: (context, snapshot) {
              final conversations = snapshot.data ?? <ChatConversation>[];
              final unreadTotal = conversations.fold<int>(
                0,
                (total, conversation) =>
                    total +
                    conversation.unreadCountFor(
                      currentUserId: widget.currentUserId,
                      currentUserRole: widget.currentUserRole,
                    ),
              );
              final header = _ConversationHeader(
                title: widget.title,
                searchController: _searchController,
                unreadTotal: unreadTotal,
                isOpeningSupport: _isOpeningSupport,
                onSupportTap: _openSupportConversation,
              );

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    header,
                    const SizedBox(height: 16),
                    const PassengerSurfaceCard(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    header,
                    const SizedBox(height: 16),
                    PassengerEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'Messages unavailable',
                      description: _messageErrorDescription(snapshot.error),
                    ),
                  ],
                );
              }

              if (conversations.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    header,
                    const SizedBox(height: 16),
                    PassengerEmptyState(
                      icon: Icons.mark_chat_unread_rounded,
                      title: widget.emptyTitle,
                      description: widget.emptyDescription,
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
                    PassengerEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching conversations',
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
                        child: _ConversationCard(
                          conversation: entry.value,
                          currentUserId: widget.currentUserId,
                          currentUserRole: widget.currentUserRole,
                          targetProfileFuture: _targetProfileFutureFor(
                            entry.value,
                          ),
                          onTap: () => _openConversation(entry.value),
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

  Future<void> _openSupportConversation() async {
    if (_isOpeningSupport) {
      return;
    }

    setState(() => _isOpeningSupport = true);
    try {
      final conversationId = await _chatService.ensureSupportConversation(
        userId: widget.currentUserId,
        userName: widget.currentUserName,
        userRole: widget.currentUserRole,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            currentUserId: widget.currentUserId,
            currentUserRole: widget.currentUserRole,
            title: 'SakayNow Support',
            subtitle: 'Admin',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open support: $error')));
    } finally {
      if (mounted) {
        setState(() => _isOpeningSupport = false);
      }
    }
  }

  void _openConversation(ChatConversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversation.conversationId,
          currentUserId: widget.currentUserId,
          currentUserRole: widget.currentUserRole,
          title: conversation.titleFor(
            currentUserId: widget.currentUserId,
            currentUserRole: widget.currentUserRole,
          ),
          subtitle: conversation.tagFor(
            currentUserId: widget.currentUserId,
            currentUserRole: widget.currentUserRole,
          ),
        ),
      ),
    );
  }

  String _messageErrorDescription(Object? error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Unable to load conversations. Please try again after message access is updated.';
    }

    return 'Unable to load conversations right now. Please try again later.';
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
        currentUserId: widget.currentUserId,
        currentUserRole: widget.currentUserRole,
      ),
      conversation.tagFor(
        currentUserId: widget.currentUserId,
        currentUserRole: widget.currentUserRole,
      ),
      conversation.previewFor(widget.currentUserId),
      conversation.participantIds.join(' '),
      conversation.participantNames.values.join(' '),
      conversation.participantRoles.values.join(' '),
    ].join(' ').toLowerCase();

    return searchable.contains(_query);
  }

  Future<ChatParticipantProfile?>? _targetProfileFutureFor(
    ChatConversation conversation,
  ) {
    if (conversation.isSupport && widget.currentUserRole != 'admin') {
      return null;
    }

    final targetUserId = conversation.isSupport
        ? conversation.supportUserId ??
              conversation.otherParticipantId(widget.currentUserId)
        : conversation.otherParticipantId(widget.currentUserId);
    if (targetUserId == null || targetUserId.trim().isEmpty) {
      return null;
    }

    return _profileFutures.putIfAbsent(
      targetUserId,
      () => _chatService.loadParticipantProfile(targetUserId),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  final String title;
  final TextEditingController searchController;
  final int unreadTotal;
  final bool isOpeningSupport;
  final VoidCallback onSupportTap;

  const _ConversationHeader({
    required this.title,
    required this.searchController,
    required this.unreadTotal,
    required this.isOpeningSupport,
    required this.onSupportTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final header = PassengerPageHeader(
          title: title,
          subtitle: '',
          icon: Icons.chat_bubble_rounded,
          accentColor: PassengerUi.accentBlue,
        );
        final search = _ConversationSearchField(controller: searchController);
        final unreadPill = _UnreadMessagePill(unreadTotal: unreadTotal);
        final supportButton = _SupportIconButton(
          isLoading: isOpeningSupport,
          onTap: onSupportTap,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 10),
                  unreadPill,
                  const SizedBox(width: 8),
                  supportButton,
                ],
              ),
              const SizedBox(height: 12),
              search,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: header),
            const SizedBox(width: 16),
            unreadPill,
            const SizedBox(width: 10),
            supportButton,
            const SizedBox(width: 12),
            SizedBox(width: 420, child: search),
          ],
        );
      },
    );
  }
}

class _UnreadMessagePill extends StatelessWidget {
  final int unreadTotal;

  const _UnreadMessagePill({required this.unreadTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PassengerUi.blueSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: PassengerUi.accentBlue.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        unreadTotal > 99 ? '99+' : '$unreadTotal',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: PassengerUi.valueText.copyWith(
          color: PassengerUi.accentBlue,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SupportIconButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _SupportIconButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Contact admin',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PassengerUi.blueSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: PassengerUi.accentBlue.withValues(alpha: 0.14),
              ),
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PassengerUi.accentBlue,
                    ),
                  )
                : Icon(
                    Icons.support_agent_rounded,
                    color: PassengerUi.accentBlue,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ConversationSearchField extends StatelessWidget {
  final TextEditingController controller;

  const _ConversationSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search conversations',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: PassengerUi.surface,
        hintStyle: PassengerUi.bodyText.copyWith(color: PassengerUi.body),
        border: OutlineInputBorder(
          borderRadius: PassengerUi.cardRadius,
          borderSide: BorderSide(color: PassengerUi.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PassengerUi.cardRadius,
          borderSide: BorderSide(color: PassengerUi.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PassengerUi.cardRadius,
          borderSide: BorderSide(color: PassengerUi.accentBlue, width: 1.4),
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final ChatConversation conversation;
  final String currentUserId;
  final String currentUserRole;
  final Future<ChatParticipantProfile?>? targetProfileFuture;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.currentUserId,
    required this.currentUserRole,
    required this.targetProfileFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = conversation.titleFor(
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
    );
    final unreadCount = conversation.unreadCountFor(
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
    );
    final hasUnread = unreadCount > 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: PassengerUi.cardRadius,
        border: hasUnread
            ? Border.all(color: PassengerUi.accentBlue, width: 1.4)
            : null,
        boxShadow: hasUnread
            ? <BoxShadow>[
                BoxShadow(
                  color: PassengerUi.accentBlue.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: PassengerSurfaceCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: PassengerUi.cardRadius,
          onTap: onTap,
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
                    color: hasUnread
                        ? PassengerUi.blueSoft
                        : PassengerUi.mutedSurface,
                    shape: BoxShape.circle,
                  ),
                  child: _ConversationAvatar(
                    title: title,
                    isSupport: conversation.isSupport,
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
                              style: PassengerUi.cardTitle.copyWith(
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          TimeAgoText(
                            dateTime: conversation.latestActivityAt,
                            style: PassengerUi.bodyText.copyWith(
                              fontSize: 12,
                              color: hasUnread
                                  ? PassengerUi.accentBlue
                                  : PassengerUi.body,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          PassengerStatusChip(
                            label: conversation.tagFor(
                              currentUserId: currentUserId,
                              currentUserRole: currentUserRole,
                            ),
                            textColor: PassengerUi.accentBlue,
                            backgroundColor: PassengerUi.blueSoft,
                          ),
                          if (hasUnread)
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
                        conversation.previewFor(currentUserId),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PassengerUi.bodyText.copyWith(
                          color: hasUnread
                              ? PassengerUi.title
                              : PassengerUi.body,
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  final String title;
  final bool isSupport;
  final Future<ChatParticipantProfile?>? profileFuture;

  const _ConversationAvatar({
    required this.title,
    required this.isSupport,
    required this.profileFuture,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = _ConversationAvatarFallback(
      title: title,
      isSupport: isSupport,
    );

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

class _ConversationAvatarFallback extends StatelessWidget {
  final String title;
  final bool isSupport;

  const _ConversationAvatarFallback({
    required this.title,
    required this.isSupport,
  });

  @override
  Widget build(BuildContext context) {
    if (isSupport) {
      return Icon(
        Icons.support_agent_rounded,
        color: PassengerUi.accentBlue,
        size: 23,
      );
    }

    return Center(
      child: Text(
        title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
        style: PassengerUi.cardTitle,
      ),
    );
  }
}
