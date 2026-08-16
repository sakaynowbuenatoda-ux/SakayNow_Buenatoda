import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/session/user_roles.dart';

import '../../models/chat_conversation.dart';
import '../../models/chat_participant_profile.dart';
import '../../services/chat_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/confirmation_dialog.dart';
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
  final Set<String> _deletingConversationIds = <String>{};
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
                    ...filteredConversations.map((conversation) {
                      final targetUserId = _targetUserIdFor(conversation);

                      return Column(
                        key: ValueKey<String>(
                          'conversation_${conversation.conversationId}',
                        ),
                        children: <Widget>[
                          _ConversationTile(
                            conversation: conversation,
                            currentUserId: widget.currentUserId,
                            currentUserRole: widget.currentUserRole,
                            avatarIdentity:
                                targetUserId ?? conversation.conversationId,
                            targetProfileFuture: _profileFutureForTarget(
                              targetUserId,
                            ),
                            onTap: () => _openConversation(conversation),
                            isDeleting: _deletingConversationIds.contains(
                              conversation.conversationId,
                            ),
                            onDelete: () => _deleteConversation(conversation),
                          ),
                        ],
                      );
                    }),
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

  Future<void> _deleteConversation(ChatConversation conversation) async {
    final conversationId = conversation.conversationId;
    if (_deletingConversationIds.contains(conversationId)) {
      return;
    }

    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete conversation?',
      message:
          'This removes the conversation and its current message history only for you. It will reappear if a new message arrives.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
      icon: Icons.delete_outline_rounded,
      confirmColor: Colors.red.shade700,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _deletingConversationIds.add(conversationId));
    try {
      await _chatService.deleteConversationForMe(
        conversationId: conversationId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation deleted for you.')),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback: 'Unable to delete this conversation. Try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingConversationIds.remove(conversationId));
      }
    }
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

  String? _targetUserIdFor(ChatConversation conversation) {
    if (conversation.isSupport && !isAdminStaffRole(widget.currentUserRole)) {
      return null;
    }

    final targetUserId = conversation.isSupport
        ? conversation.supportUserId ??
              conversation.otherParticipantId(widget.currentUserId)
        : conversation.otherParticipantId(widget.currentUserId);
    final normalizedTargetUserId = targetUserId?.trim() ?? '';
    if (normalizedTargetUserId.isEmpty) {
      return null;
    }

    return normalizedTargetUserId;
  }

  Future<ChatParticipantProfile?>? _profileFutureForTarget(
    String? targetUserId,
  ) {
    final normalizedTargetUserId = targetUserId?.trim() ?? '';
    if (normalizedTargetUserId.isEmpty) {
      return null;
    }

    return _profileFutures.putIfAbsent(
      normalizedTargetUserId,
      () => _chatService.loadParticipantProfile(normalizedTargetUserId),
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
          subtitle: 'Stay close to ride updates, passengers, and support.',
          icon: Icons.chat_bubble_rounded,
          accentColor: PassengerUi.primary,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        unreadTotal > 99 ? '99+' : '$unreadTotal',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: PassengerUi.valueText.copyWith(
          color: PassengerUi.title,
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
          child: SizedBox(
            width: 42,
            height: 42,
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PassengerUi.primary,
                    ),
                  )
                : Icon(
                    Icons.headset_mic_rounded,
                    color: PassengerUi.primary,
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

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final String currentUserId;
  final String currentUserRole;
  final String avatarIdentity;
  final Future<ChatParticipantProfile?>? targetProfileFuture;
  final VoidCallback onTap;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.currentUserRole,
    required this.avatarIdentity,
    required this.targetProfileFuture,
    required this.onTap,
    required this.isDeleting,
    required this.onDelete,
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
    final roleLabel = conversation.tagFor(
      currentUserId: currentUserId,
      currentUserRole: currentUserRole,
    );

    return _ConversationTapTarget(
      semanticLabel: 'Open conversation with $title',
      highlighted: hasUnread,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: hasUnread
                  ? PassengerUi.mutedSurface
                  : PassengerUi.mutedSurface,
              shape: BoxShape.circle,
            ),
            child: _ConversationAvatar(
              key: ValueKey<String>('conversation_avatar_$avatarIdentity'),
              title: title,
              isSupport: conversation.isSupport,
              avatarIdentity: avatarIdentity,
              profileFuture: targetProfileFuture,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PassengerUi.cardTitle.copyWith(
                                color: PassengerUi.title,
                                fontSize: 15,
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ConversationRoleLabel(label: roleLabel),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    TimeAgoText(
                      dateTime: conversation.latestActivityAt,
                      style: PassengerUi.bodyText.copyWith(
                        fontSize: 12,
                        color: hasUnread ? PassengerUi.title : PassengerUi.body,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        conversation.previewFor(currentUserId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PassengerUi.bodyText.copyWith(
                          color: hasUnread
                              ? PassengerUi.title
                              : PassengerUi.body,
                          fontSize: 13,
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (hasUnread) ...<Widget>[
                      const SizedBox(width: 8),
                      _UnreadCountBadge(unreadCount: unreadCount),
                    ],
                    const SizedBox(width: 4),
                    if (isDeleting)
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      PopupMenuButton<String>(
                        tooltip: 'Conversation actions',
                        onSelected: (_) => onDelete(),
                        itemBuilder: (_) => const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: <Widget>[
                                Icon(Icons.delete_outline_rounded),
                                SizedBox(width: 10),
                                Text('Delete conversation'),
                              ],
                            ),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert_rounded, size: 20),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTapTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final String semanticLabel;
  final bool highlighted;

  const _ConversationTapTarget({
    required this.child,
    required this.onTap,
    required this.padding,
    required this.semanticLabel,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: highlighted
            ? PassengerUi.accentBlue.withValues(
                alpha: PassengerUi.isDarkMode ? 0.10 : 0.05,
              )
            : Colors.transparent,
        borderRadius: PassengerUi.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: PassengerUi.mutedSurface.withValues(alpha: 0.72),
          focusColor: PassengerUi.blueSoft,
          splashColor: PassengerUi.accentBlue.withValues(alpha: 0.08),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 70),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ConversationRoleLabel extends StatelessWidget {
  final String label;

  const _ConversationRoleLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: PassengerUi.bodyText.copyWith(
          color: PassengerUi.body,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class _UnreadCountBadge extends StatelessWidget {
  final int unreadCount;

  const _UnreadCountBadge({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: PassengerUi.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        unreadCount > 99 ? '99+' : '$unreadCount',
        textAlign: TextAlign.center,
        style: PassengerUi.bodyText.copyWith(
          color: PassengerUi.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  final String title;
  final bool isSupport;
  final String avatarIdentity;
  final Future<ChatParticipantProfile?>? profileFuture;

  const _ConversationAvatar({
    super.key,
    required this.title,
    required this.isSupport,
    required this.avatarIdentity,
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
      key: ValueKey<String>('conversation_profile_$avatarIdentity'),
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return fallback;
        }

        final profile = snapshot.data;
        return FirebaseStorageImage(
          key: ValueKey<String>('conversation_image_$avatarIdentity'),
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
        Icons.headset_mic_rounded,
        color: PassengerUi.primary,
        size: 21,
      );
    }

    return Center(
      child: Text(
        title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
        style: PassengerUi.cardTitle.copyWith(color: PassengerUi.primary),
      ),
    );
  }
}
