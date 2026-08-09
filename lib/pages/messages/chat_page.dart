import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session/user_roles.dart';

import '../../models/chat_conversation.dart';
import '../../models/chat_message.dart';
import '../../models/chat_participant_profile.dart';
import '../../services/chat_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/time_ago_text.dart';
import '../profile/view_user_profile.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String currentUserRole;
  final String title;
  final String subtitle;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.currentUserRole,
    required this.title,
    required this.subtitle,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, Future<ChatParticipantProfile?>> _profileFutures =
      <String, Future<ChatParticipantProfile?>>{};
  final Map<String, ChatParticipantProfile> _profileCache =
      <String, ChatParticipantProfile>{};
  final List<_PendingChatMessage> _pendingMessages = <_PendingChatMessage>[];
  int _pendingMessageSequence = 0;
  bool _isSending = false;
  bool _isMarkingRead = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleMessageTextChanged);
    unawaited(_markConversationRead());
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleMessageTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatConversation?>(
      stream: _chatService.watchConversation(widget.conversationId),
      builder: (context, conversationSnapshot) {
        final conversation = conversationSnapshot.data;
        final targetWithoutProfile = _targetFor(conversation, null);
        final cachedProfile = _cachedProfileFor(targetWithoutProfile.userId);

        if (cachedProfile != null) {
          return _buildChatScaffold(
            conversation: conversation,
            target: _targetFor(conversation, cachedProfile),
          );
        }

        return FutureBuilder<ChatParticipantProfile?>(
          future: _profileFutureFor(targetWithoutProfile.userId),
          builder: (context, profileSnapshot) {
            final target = _targetFor(conversation, profileSnapshot.data);

            return _buildChatScaffold(
              conversation: conversation,
              target: target,
            );
          },
        );
      },
    );
  }

  Widget _buildChatScaffold({
    required ChatConversation? conversation,
    required _ChatTarget target,
  }) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isAdminStaffRole(widget.currentUserRole)
          ? PassengerUi.mutedSurface
          : PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.background,
        surfaceTintColor: PassengerUi.background,
        titleSpacing: 0,
        title: _ChatHeader(target: target, onTap: _profileTapFor(target)),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: _ChatBodyFrame(
          maxContentWidth: isAdminStaffRole(widget.currentUserRole)
              ? PassengerUi.settingsContentWidth
              : null,
          child: Column(
            children: <Widget>[
              Expanded(
                child: _MessageList(
                  chatService: _chatService,
                  conversationId: widget.conversationId,
                  currentUserId: widget.currentUserId,
                  conversation: conversation,
                  target: target,
                  pendingMessages: List<_PendingChatMessage>.unmodifiable(
                    _pendingMessages,
                  ),
                  onPendingMessagesConfirmed: _removeConfirmedPendingMessages,
                  scrollController: _scrollController,
                  onMessagesRendered: () {
                    _scrollToBottom();
                    unawaited(_markConversationRead());
                  },
                ),
              ),
              _MessageComposer(
                controller: _messageController,
                isSending: _isSending,
                canSend: _hasText && !_isSending,
                onSend: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<ChatParticipantProfile?> _profileFutureFor(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return Future<ChatParticipantProfile?>.value(null);
    }

    return _profileFutures.putIfAbsent(userId, () async {
      final profile = await _chatService.loadParticipantProfile(userId);
      if (profile != null) {
        _profileCache[userId] = profile;
      }
      return profile;
    });
  }

  VoidCallback? _profileTapFor(_ChatTarget target) {
    final userId = target.userId?.trim() ?? '';
    if (!isAdminStaffRole(widget.currentUserRole) || userId.isEmpty) {
      return null;
    }

    return () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ViewUserProfilePage(
            adminId: widget.currentUserId,
            userId: userId,
          ),
        ),
      );
    };
  }

  ChatParticipantProfile? _cachedProfileFor(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return null;
    }

    return _profileCache[userId];
  }

  _ChatTarget _targetFor(
    ChatConversation? conversation,
    ChatParticipantProfile? profile,
  ) {
    final fallbackTitle = widget.title.trim().isEmpty
        ? 'Conversation'
        : widget.title.trim();
    final fallbackSubtitle = widget.subtitle.trim();

    if (conversation == null) {
      return _ChatTarget(
        userId: profile?.userId,
        name: profile?.displayName ?? fallbackTitle,
        subtitle: fallbackSubtitle,
        profileImageUrl: profile?.profileImageUrl,
        isSupport: fallbackTitle.toLowerCase().contains('support'),
      );
    }

    if (conversation.isSupport && !isAdminStaffRole(widget.currentUserRole)) {
      return _ChatTarget(
        userId: null,
        name: 'SakayNow Support',
        subtitle: 'Admin',
        profileImageUrl: null,
        isSupport: true,
      );
    }

    final targetUserId = conversation.isSupport
        ? conversation.supportUserId ??
              conversation.otherParticipantId(widget.currentUserId)
        : conversation.otherParticipantId(widget.currentUserId);
    final conversationName = conversation.titleFor(
      currentUserId: widget.currentUserId,
      currentUserRole: widget.currentUserRole,
    );
    final conversationRole = conversation.tagFor(
      currentUserId: widget.currentUserId,
      currentUserRole: widget.currentUserRole,
    );

    return _ChatTarget(
      userId: targetUserId,
      name: profile?.displayName ?? conversationName,
      subtitle: _roleLabel(profile?.role) ?? conversationRole,
      profileImageUrl: profile?.profileImageUrl,
      isSupport: conversation.isSupport,
    );
  }

  void _handleMessageTextChanged() {
    final nextHasText = _messageController.text.trim().isNotEmpty;
    if (nextHasText == _hasText) {
      return;
    }

    setState(() => _hasText = nextHasText);
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) {
      return;
    }

    if (message.length > ChatService.maxMessageLength) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message is too long.')));
      return;
    }

    final pendingMessage = _PendingChatMessage(
      clientMessageId: _nextClientMessageId(),
      text: message,
      createdAt: DateTime.now(),
      deliveryState: _PendingMessageDeliveryState.sending,
    );

    setState(() {
      _isSending = true;
      _pendingMessages.add(pendingMessage);
      _hasText = false;
    });
    _messageController.clear();
    _scheduleScrollToBottom();

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: widget.currentUserId,
        senderRole: widget.currentUserRole,
        text: message,
        clientMessageId: pendingMessage.clientMessageId,
      );
      if (mounted) {
        _updatePendingMessageState(
          pendingMessage.clientMessageId,
          _PendingMessageDeliveryState.sent,
        );
      }
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      _updatePendingMessageState(
        pendingMessage.clientMessageId,
        _PendingMessageDeliveryState.failed,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback: 'Unable to send this message. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _nextClientMessageId() {
    _pendingMessageSequence += 1;
    return '${widget.currentUserId}_${DateTime.now().microsecondsSinceEpoch}_$_pendingMessageSequence';
  }

  void _updatePendingMessageState(
    String clientMessageId,
    _PendingMessageDeliveryState deliveryState,
  ) {
    if (!mounted) {
      return;
    }

    final index = _pendingMessages.indexWhere(
      (message) => message.clientMessageId == clientMessageId,
    );
    if (index == -1) {
      return;
    }

    setState(() {
      _pendingMessages[index] = _pendingMessages[index].copyWith(
        deliveryState: deliveryState,
      );
    });
    _scheduleScrollToBottom();
  }

  void _removeConfirmedPendingMessages(Set<String> clientMessageIds) {
    if (!mounted || _pendingMessages.isEmpty || clientMessageIds.isEmpty) {
      return;
    }

    final hasConfirmedPending = _pendingMessages.any(
      (message) => clientMessageIds.contains(message.clientMessageId),
    );
    if (!hasConfirmedPending) {
      return;
    }

    setState(() {
      _pendingMessages.removeWhere(
        (message) => clientMessageIds.contains(message.clientMessageId),
      );
    });
  }

  Future<void> _markConversationRead() async {
    if (_isMarkingRead) {
      return;
    }

    _isMarkingRead = true;
    try {
      await _chatService.markConversationRead(
        conversationId: widget.conversationId,
        userId: widget.currentUserId,
        userRole: widget.currentUserRole,
      );
    } on Exception {
      // The inbox stream will keep unread counts accurate when marking fails.
    } finally {
      _isMarkingRead = false;
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToBottom();
      }
    });
  }

  static String? _roleLabel(String? role) {
    return switch (role?.trim().toLowerCase()) {
      'driver' => 'Driver',
      'admin' => 'Admin',
      'super_admin' => 'Super Admin',
      'passenger' || 'regular' || 'student' || 'senior_citizen' => 'Passenger',
      _ => null,
    };
  }
}

class _ChatBodyFrame extends StatelessWidget {
  final double? maxContentWidth;
  final Widget child;

  const _ChatBodyFrame({required this.maxContentWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    final maxWidth = maxContentWidth;
    if (maxWidth == null) {
      return child;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PassengerUi.background,
            border: Border.symmetric(
              vertical: BorderSide(color: PassengerUi.border),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final ChatService chatService;
  final String conversationId;
  final String currentUserId;
  final ChatConversation? conversation;
  final _ChatTarget target;
  final List<_PendingChatMessage> pendingMessages;
  final ValueChanged<Set<String>> onPendingMessagesConfirmed;
  final ScrollController scrollController;
  final VoidCallback onMessagesRendered;

  const _MessageList({
    required this.chatService,
    required this.conversationId,
    required this.currentUserId,
    required this.conversation,
    required this.target,
    required this.pendingMessages,
    required this.onPendingMessagesConfirmed,
    required this.scrollController,
    required this.onMessagesRendered,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessage>>(
      stream: chatService.watchMessages(conversationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            pendingMessages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: PassengerEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Conversation unavailable',
              description:
                  'Unable to load this conversation. Please try again.',
            ),
          );
        }

        final messages = snapshot.data ?? <ChatMessage>[];
        final confirmedClientMessageIds = <String>{
          for (final message in messages)
            if (message.clientMessageId != null &&
                message.clientMessageId!.isNotEmpty)
              message.clientMessageId!,
        };
        final visiblePendingMessages = pendingMessages
            .where(
              (message) =>
                  !confirmedClientMessageIds.contains(message.clientMessageId),
            )
            .toList(growable: false);
        final hasConfirmedPending = pendingMessages.any(
          (message) =>
              confirmedClientMessageIds.contains(message.clientMessageId),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (hasConfirmedPending) {
            onPendingMessagesConfirmed(confirmedClientMessageIds);
          }
          onMessagesRendered();
        });

        if (messages.isEmpty && visiblePendingMessages.isEmpty) {
          return _EmptyConversation(target: target);
        }

        final itemCount = messages.length + visiblePendingMessages.length;
        return ListView.builder(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            PassengerUi.isCompactWidth(context) ? 12 : 18,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= messages.length) {
              final pendingMessage =
                  visiblePendingMessages[index - messages.length];
              return _MessageBubble(
                key: ValueKey<String>(
                  'pending_${pendingMessage.clientMessageId}',
                ),
                text: pendingMessage.text,
                createdAt: pendingMessage.createdAt,
                isMine: true,
                target: target,
                status: pendingMessage.status,
              );
            }

            final message = messages[index];
            final isMine = message.isMine(currentUserId);
            return _MessageBubble(
              key: ValueKey<String>('message_${message.messageId}'),
              text: message.text,
              createdAt: message.createdAt,
              isMine: isMine,
              target: target,
              status: isMine
                  ? _messageStatus(
                      message: message,
                      currentUserId: currentUserId,
                      conversation: conversation,
                      target: target,
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  _MessageStatus _messageStatus({
    required ChatMessage message,
    required String currentUserId,
    required ChatConversation? conversation,
    required _ChatTarget target,
  }) {
    final createdAt = message.createdAt;
    if (createdAt == null) {
      return const _MessageStatus(label: 'Sent', type: _MessageStatusType.sent);
    }

    final receiptUserIds = <String>[
      if (target.userId != null && target.userId != currentUserId)
        target.userId!,
      if (target.userId == null && conversation != null)
        ...conversation.participantIds.where((id) => id != currentUserId),
    ];

    final isSeen = receiptUserIds.any((userId) {
      if (message.readBy[userId] == true) {
        return true;
      }

      final lastReadAt = conversation?.lastReadAt[userId];
      return lastReadAt != null && !lastReadAt.isBefore(createdAt);
    });

    return _MessageStatus(
      label: isSeen ? 'Seen' : 'Sent',
      type: isSeen ? _MessageStatusType.seen : _MessageStatusType.sent,
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final _ChatTarget target;
  final VoidCallback? onTap;

  const _ChatHeader({required this.target, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: <Widget>[
        _ChatAvatar(target: target, size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                target.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PassengerUi.cardTitle.copyWith(fontSize: 17),
              ),
              if (target.subtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 1),
                Text(
                  target.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.bodyText.copyWith(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: <Widget>[
              Expanded(child: content),
              const SizedBox(width: 6),
              Icon(
                Icons.open_in_new_rounded,
                size: 17,
                color: PassengerUi.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  final _ChatTarget target;

  const _EmptyConversation({required this.target});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ChatAvatar(target: target, size: 78),
            const SizedBox(height: 14),
            Text(
              target.name,
              textAlign: TextAlign.center,
              style: PassengerUi.sectionTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              'No messages yet',
              textAlign: TextAlign.center,
              style: PassengerUi.cardTitle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start the conversation when ready.',
              textAlign: TextAlign.center,
              style: PassengerUi.bodyText,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final DateTime? createdAt;
  final bool isMine;
  final _ChatTarget target;
  final _MessageStatus? status;

  const _MessageBubble({
    super.key,
    required this.text,
    required this.createdAt,
    required this.isMine,
    required this.target,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isMine ? PassengerUi.dark : PassengerUi.surface;
    final foregroundColor = isMine ? Colors.white : PassengerUi.title;
    final detailColor = isMine
        ? Colors.white.withValues(alpha: 0.72)
        : PassengerUi.body;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMine ? 16 : 5),
      bottomRight: Radius.circular(isMine ? 5 : 16),
    );
    final bubble = LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = constraints.maxWidth * 0.72;

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
              border: isMine ? null : Border.all(color: PassengerUi.border),
              boxShadow: isMine ? null : PassengerUi.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  text,
                  style: PassengerUi.bodyText.copyWith(
                    color: foregroundColor,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                _MessageMeta(
                  timeLabel: TimeAgo.format(createdAt),
                  color: detailColor,
                  status: status,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (isMine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _ChatAvatar(target: target, size: 30),
          const SizedBox(width: 8),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _MessageMeta extends StatelessWidget {
  final String timeLabel;
  final Color color;
  final _MessageStatus? status;

  const _MessageMeta({
    required this.timeLabel,
    required this.color,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          timeLabel,
          style: PassengerUi.bodyText.copyWith(color: color, fontSize: 11),
        ),
        if (status != null) ...<Widget>[
          const SizedBox(width: 6),
          _MessageStatusIcon(status: status!, color: color),
          const SizedBox(width: 2),
          Text(
            status!.label,
            style: PassengerUi.bodyText.copyWith(
              color: status!.colorFor(color),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _MessageStatusIcon extends StatelessWidget {
  final _MessageStatus status;
  final Color color;

  const _MessageStatusIcon({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final statusColor = status.colorFor(color);
    if (status.type == _MessageStatusType.sending) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 1.6, color: statusColor),
      );
    }

    return Icon(status.icon, size: 14, color: statusColor);
  }
}

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool canSend;
  final VoidCallback onSend;

  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.canSend,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardOpen = mediaQuery.viewInsets.bottom > 0;
    final bottomPadding = keyboardOpen
        ? 12.0
        : mediaQuery.viewPadding.bottom + 14;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PassengerUi.surface,
        border: Border(top: BorderSide(color: PassengerUi.border, width: 1.2)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 10, 14, bottomPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                decoration: BoxDecoration(
                  color: PassengerUi.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PassengerUi.primary, width: 1.4),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  style: PassengerUi.bodyText.copyWith(
                    color: PassengerUi.title,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    hintStyle: PassengerUi.bodyText.copyWith(
                      color: PassengerUi.accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 52,
              height: 52,
              child: IconButton(
                onPressed: canSend ? onSend : null,
                style: IconButton.styleFrom(
                  backgroundColor: canSend
                      ? PassengerUi.primary
                      : PassengerUi.mutedSurface,
                  foregroundColor: canSend ? Colors.white : PassengerUi.body,
                  disabledBackgroundColor: PassengerUi.mutedSurface,
                  disabledForegroundColor: PassengerUi.body,
                  shape: const CircleBorder(),
                ),
                icon: isSending
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PassengerUi.surface,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  final _ChatTarget target;
  final double size;

  const _ChatAvatar({required this.target, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = _AvatarFallback(
      initials: target.initials,
      isSupport: target.isSupport,
      size: size,
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: FirebaseStorageImage(
          imageUrl: target.profileImageUrl,
          width: size,
          height: size,
          fallback: fallback,
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;
  final bool isSupport;
  final double size;

  const _AvatarFallback({
    required this.initials,
    required this.isSupport,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PassengerUi.blueSoft,
        shape: BoxShape.circle,
      ),
      child: isSupport
          ? Icon(
              Icons.support_agent_rounded,
              color: PassengerUi.accentBlue,
              size: size * 0.52,
            )
          : Text(
              initials,
              style: PassengerUi.valueText.copyWith(
                color: PassengerUi.accentBlue,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _ChatTarget {
  final String? userId;
  final String name;
  final String subtitle;
  final String? profileImageUrl;
  final bool isSupport;

  const _ChatTarget({
    required this.userId,
    required this.name,
    required this.subtitle,
    required this.profileImageUrl,
    required this.isSupport,
  });

  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

enum _PendingMessageDeliveryState { sending, sent, failed }

class _PendingChatMessage {
  final String clientMessageId;
  final String text;
  final DateTime createdAt;
  final _PendingMessageDeliveryState deliveryState;

  const _PendingChatMessage({
    required this.clientMessageId,
    required this.text,
    required this.createdAt,
    required this.deliveryState,
  });

  _PendingChatMessage copyWith({_PendingMessageDeliveryState? deliveryState}) {
    return _PendingChatMessage(
      clientMessageId: clientMessageId,
      text: text,
      createdAt: createdAt,
      deliveryState: deliveryState ?? this.deliveryState,
    );
  }

  _MessageStatus get status {
    return switch (deliveryState) {
      _PendingMessageDeliveryState.sending => const _MessageStatus(
        label: 'Sending',
        type: _MessageStatusType.sending,
      ),
      _PendingMessageDeliveryState.sent => const _MessageStatus(
        label: 'Sent',
        type: _MessageStatusType.sent,
      ),
      _PendingMessageDeliveryState.failed => const _MessageStatus(
        label: 'Failed',
        type: _MessageStatusType.failed,
      ),
    };
  }
}

enum _MessageStatusType { sending, sent, seen, failed }

class _MessageStatus {
  final String label;
  final _MessageStatusType type;

  const _MessageStatus({required this.label, required this.type});

  IconData get icon {
    return switch (type) {
      _MessageStatusType.seen => Icons.done_all_rounded,
      _MessageStatusType.failed => Icons.error_outline_rounded,
      _ => Icons.done_rounded,
    };
  }

  Color colorFor(Color fallback) {
    return switch (type) {
      _MessageStatusType.failed => Colors.redAccent,
      _ => fallback,
    };
  }
}
