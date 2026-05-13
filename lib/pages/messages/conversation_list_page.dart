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
  final Map<String, Future<ChatParticipantProfile?>> _profileFutures =
      <String, Future<ChatParticipantProfile?>>{};
  bool _isOpeningSupport = false;

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: widget.title,
            subtitle: '',
            icon: Icons.chat_bubble_rounded,
            accentColor: PassengerUi.accentBlue,
          ),
          const SizedBox(height: 16),
          _SupportConversationCard(
            isLoading: _isOpeningSupport,
            onTap: _openSupportConversation,
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<ChatConversation>>(
            stream: _chatService.watchUserConversations(widget.currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const PassengerSurfaceCard(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return PassengerEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Messages unavailable',
                  description: _messageErrorDescription(snapshot.error),
                );
              }

              final conversations = snapshot.data ?? <ChatConversation>[];
              if (conversations.isEmpty) {
                return PassengerEmptyState(
                  icon: Icons.mark_chat_unread_rounded,
                  title: widget.emptyTitle,
                  description: widget.emptyDescription,
                );
              }

              final unreadTotal = conversations.fold<int>(
                0,
                (total, conversation) =>
                    total +
                    conversation.unreadCountFor(
                      currentUserId: widget.currentUserId,
                      currentUserRole: widget.currentUserRole,
                    ),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PassengerSurfaceCard(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Unread conversations',
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

class _SupportConversationCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _SupportConversationCard({
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: PassengerUi.cardRadius,
        onTap: isLoading ? null : onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: PassengerUi.blueSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.support_agent_rounded,
                color: PassengerUi.accentBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('SakayNow Support', style: PassengerUi.cardTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Contact admin',
                    style: PassengerUi.bodyText.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PassengerUi.accentBlue,
                    ),
                  )
                : Icon(Icons.chevron_right_rounded, color: PassengerUi.body),
          ],
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
