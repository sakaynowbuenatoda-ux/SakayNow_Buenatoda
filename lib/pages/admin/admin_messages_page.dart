import 'package:flutter/material.dart';

import '../../models/chat_conversation.dart';
import '../../models/chat_participant_profile.dart';
import '../../services/chat_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/conversation_actions_dialog.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/time_ago_text.dart';
import '../messages/chat_page.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

class AdminMessagesPage extends StatefulWidget {
  final String adminId;
  final String adminRole;

  const AdminMessagesPage({
    super.key,
    required this.adminId,
    required this.adminRole,
  });

  @override
  State<AdminMessagesPage> createState() => _AdminMessagesPageState();
}

class _AdminMessagesPageState extends State<AdminMessagesPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Future<ChatParticipantProfile?>> _profileFutures =
      <String, Future<ChatParticipantProfile?>>{};
  String _query = '';
  String? _selectedConversationId;
  String _selectedConversationTitle = '';
  String _selectedConversationSubtitle = '';
  final Set<String> _deletingConversationIds = <String>{};

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopSplit =
            MediaQuery.sizeOf(context).width >= 1024 &&
            constraints.maxWidth >= 700;

        return StreamBuilder<List<ChatConversation>>(
          stream: _chatService.watchAdminInbox(widget.adminId),
          builder: (context, snapshot) => useDesktopSplit
              ? _buildDesktopInbox(
                  snapshot,
                  availableWidth: constraints.maxWidth,
                )
              : _buildMobileInbox(snapshot),
        );
      },
    );
  }

  Widget _buildMobileInbox(AsyncSnapshot<List<ChatConversation>> snapshot) {
    final conversations = snapshot.data ?? <ChatConversation>[];
    final header = _MessagesHeader(
      searchController: _searchController,
      unreadTotal: _unreadTotalFor(conversations),
      onNewAdminMessage: () => _openAdminStaffDirectory(useSplitView: false),
    );

    Widget content;
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      content = const AdminSurfaceCard(
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (snapshot.hasError) {
      content = const AdminErrorCard(
        message: 'Unable to load admin messages. Please try again.',
      );
    } else if (conversations.isEmpty) {
      content = const AdminEmptyCollection(
        icon: Icons.support_agent_rounded,
        title: 'No messages yet',
        description:
            'Support requests and admin staff conversations appear here.',
      );
    } else {
      final filteredConversations = conversations
          .where(_matchesConversationSearch)
          .toList(growable: false);
      content = filteredConversations.isEmpty
          ? const AdminEmptyCollection(
              icon: Icons.search_off_rounded,
              title: 'No matching users found',
              description:
                  'Try searching by user name, role, message, or conversation ID.',
            )
          : Column(
              children: filteredConversations
                  .asMap()
                  .entries
                  .map((entry) {
                    final conversation = entry.value;
                    final isLast =
                        entry.key == filteredConversations.length - 1;

                    return Column(
                      key: ValueKey<String>(
                        'admin_conversation_${conversation.conversationId}',
                      ),
                      children: <Widget>[
                        _conversationTile(
                          conversation,
                          selected: false,
                          onTap: () => _openConversationPage(conversation),
                        ),
                        if (!isLast) const _AdminConversationDivider(),
                      ],
                    );
                  })
                  .toList(growable: false),
            );
    }

    return AdminPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[header, const SizedBox(height: 16), content],
      ),
    );
  }

  Widget _buildDesktopInbox(
    AsyncSnapshot<List<ChatConversation>> snapshot, {
    required double availableWidth,
  }) {
    final conversations = snapshot.data ?? <ChatConversation>[];
    final filteredConversations = conversations
        .where(_matchesConversationSearch)
        .toList(growable: false);
    final hasSelectedConversation = _selectedConversationId != null;
    final inboxWidth = availableWidth < 1100 ? 320.0 : 390.0;
    final header = _DesktopMessagesHeader(
      searchController: _searchController,
      unreadTotal: _unreadTotalFor(conversations),
      onNewAdminMessage: () => _openAdminStaffDirectory(useSplitView: true),
    );

    final inboxPanel = _buildDesktopInboxPanel(
      snapshot: snapshot,
      conversations: conversations,
      filteredConversations: filteredConversations,
    );

    return ColoredBox(
      color: AdminUi.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: AdminUi.pagePadding(context).copyWith(bottom: 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AdminUi.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  header,
                  const SizedBox(height: 14),
                  Expanded(
                    child: hasSelectedConversation
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              SizedBox(width: inboxWidth, child: inboxPanel),
                              const SizedBox(width: 14),
                              Expanded(child: _buildSelectedConversation()),
                            ],
                          )
                        : inboxPanel,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopInboxPanel({
    required AsyncSnapshot<List<ChatConversation>> snapshot,
    required List<ChatConversation> conversations,
    required List<ChatConversation> filteredConversations,
  }) {
    Widget child;
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      child = const Center(child: CircularProgressIndicator());
    } else if (snapshot.hasError) {
      child = const Padding(
        padding: EdgeInsets.all(16),
        child: AdminErrorCard(
          message: 'Unable to load admin messages. Please try again.',
        ),
      );
    } else if (conversations.isEmpty) {
      child = const Padding(
        padding: EdgeInsets.all(16),
        child: AdminEmptyCollection(
          icon: Icons.support_agent_rounded,
          title: 'No messages yet',
          description:
              'Support requests and admin staff conversations appear here.',
        ),
      );
    } else if (filteredConversations.isEmpty) {
      child = const Padding(
        padding: EdgeInsets.all(16),
        child: AdminEmptyCollection(
          icon: Icons.search_off_rounded,
          title: 'No matching users found',
          description:
              'Try searching by user name, role, message, or conversation ID.',
        ),
      );
    } else {
      child = Scrollbar(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: filteredConversations.length,
          separatorBuilder: (_, _) => const _AdminConversationDivider(),
          itemBuilder: (context, index) {
            final conversation = filteredConversations[index];
            return _conversationTile(
              conversation,
              selected: conversation.conversationId == _selectedConversationId,
              onTap: () => _selectConversation(conversation),
            );
          },
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: AdminUi.cardRadius,
        border: Border.all(color: AdminUi.border),
      ),
      child: child,
    );
  }

  Widget _buildSelectedConversation() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: AdminUi.cardRadius,
        border: Border.all(color: AdminUi.border),
      ),
      child: ChatPage(
        key: ValueKey<String>(_selectedConversationId!),
        conversationId: _selectedConversationId!,
        currentUserId: widget.adminId,
        currentUserRole: widget.adminRole,
        title: _selectedConversationTitle,
        subtitle: _selectedConversationSubtitle,
        embedded: true,
        onClose: _closeSelectedConversation,
      ),
    );
  }

  _AdminConversationTile _conversationTile(
    ChatConversation conversation, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final targetUserId = _targetUserIdFor(conversation);
    return _AdminConversationTile(
      conversation: conversation,
      adminId: widget.adminId,
      adminRole: widget.adminRole,
      avatarIdentity: targetUserId ?? conversation.conversationId,
      targetProfileFuture: _profileFutureForTarget(targetUserId),
      selected: selected,
      onTap: onTap,
      isDeleting: _deletingConversationIds.contains(
        conversation.conversationId,
      ),
      onShowActions: () => _showConversationActions(conversation),
    );
  }

  Future<void> _showConversationActions(ChatConversation conversation) async {
    if (_deletingConversationIds.contains(conversation.conversationId)) {
      return;
    }

    final action = await showConversationActionsDialog(
      context,
      conversationTitle: conversation.titleFor(
        currentUserId: widget.adminId,
        currentUserRole: widget.adminRole,
      ),
    );
    if (!mounted) {
      return;
    }

    switch (action) {
      case ConversationAction.delete:
        await _deleteConversation(conversation);
      case null:
        return;
    }
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
      if (_selectedConversationId == conversationId) {
        _closeSelectedConversation();
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

  int _unreadTotalFor(List<ChatConversation> conversations) {
    return conversations.fold<int>(
      0,
      (total, conversation) =>
          total +
          conversation.unreadCountFor(
            currentUserId: widget.adminId,
            currentUserRole: widget.adminRole,
          ),
    );
  }

  String? _targetUserIdFor(ChatConversation conversation) {
    final targetUserId =
        conversation.supportUserId ??
        conversation.otherParticipantId(widget.adminId);
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
        currentUserRole: widget.adminRole,
      ),
      conversation.previewFor(widget.adminId),
      conversation.participantIds.join(' '),
      conversation.participantNames.values.join(' '),
      conversation.participantRoles.values.join(' '),
    ].join(' ').toLowerCase();

    return searchable.contains(_query);
  }

  void _selectConversation(ChatConversation conversation) {
    final title = conversation.titleFor(
      currentUserId: widget.adminId,
      currentUserRole: widget.adminRole,
    );
    final roleLabel = conversation.isSupport
        ? 'Support request'
        : conversation.tagFor(
            currentUserId: widget.adminId,
            currentUserRole: widget.adminRole,
          );

    setState(() {
      _selectedConversationId = conversation.conversationId;
      _selectedConversationTitle = title;
      _selectedConversationSubtitle = roleLabel;
    });
  }

  void _closeSelectedConversation() {
    setState(() {
      _selectedConversationId = null;
      _selectedConversationTitle = '';
      _selectedConversationSubtitle = '';
    });
  }

  Future<void> _openConversationPage(ChatConversation conversation) async {
    final title = conversation.titleFor(
      currentUserId: widget.adminId,
      currentUserRole: widget.adminRole,
    );
    final roleLabel = conversation.isSupport
        ? 'Support request'
        : conversation.tagFor(
            currentUserId: widget.adminId,
            currentUserRole: widget.adminRole,
          );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversation.conversationId,
          currentUserId: widget.adminId,
          currentUserRole: widget.adminRole,
          title: title,
          subtitle: roleLabel,
        ),
      ),
    );
  }

  Future<void> _openAdminStaffDirectory({required bool useSplitView}) async {
    final target = await showDialog<AdminUserRecord>(
      context: context,
      builder: (_) =>
          _AdminStaffDirectoryDialog(currentAdminId: widget.adminId),
    );
    if (target == null || !mounted) {
      return;
    }

    try {
      final conversationId = await _chatService.ensureAdminConversation(
        targetAdminId: target.userId,
      );
      if (!mounted) {
        return;
      }
      if (useSplitView) {
        setState(() {
          _selectedConversationId = conversationId;
          _selectedConversationTitle = target.fullName;
          _selectedConversationSubtitle = target.roleLabel;
        });
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: conversationId,
              currentUserId: widget.adminId,
              currentUserRole: widget.adminRole,
              title: target.fullName,
              subtitle: target.roleLabel,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open admin message: $error')),
      );
    }
  }
}

class _DesktopMessagesHeader extends StatefulWidget {
  final TextEditingController searchController;
  final int unreadTotal;
  final VoidCallback onNewAdminMessage;

  const _DesktopMessagesHeader({
    required this.searchController,
    required this.unreadTotal,
    required this.onNewAdminMessage,
  });

  @override
  State<_DesktopMessagesHeader> createState() => _DesktopMessagesHeaderState();
}

class _DesktopMessagesHeaderState extends State<_DesktopMessagesHeader> {
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchExpanded = false;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _expandSearch() {
    setState(() => _searchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _collapseSearch() {
    widget.searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _searchExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Messages',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.pageTitle,
          ),
        ),
        const SizedBox(width: 16),
        Tooltip(
          message: widget.unreadTotal == 1
              ? '1 unread message'
              : '${widget.unreadTotal} unread messages',
          child: Semantics(
            label: widget.unreadTotal == 1
                ? '1 unread message'
                : '${widget.unreadTotal} unread messages',
            child: _DesktopHeaderIconSurface(
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Icon(Icons.forum_outlined, size: 20, color: AdminUi.title),
                  Positioned(
                    right: -9,
                    top: -9,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AdminUi.neutral,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AdminUi.surface, width: 1.5),
                      ),
                      child: Text(
                        widget.unreadTotal > 99
                            ? '99+'
                            : '${widget.unreadTotal}',
                        textAlign: TextAlign.center,
                        style: AdminUi.labelText.copyWith(
                          color: AdminUi.onPrimary,
                          fontSize: 9,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: widget.onNewAdminMessage,
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminUi.title,
              backgroundColor: AdminUi.surface,
              side: BorderSide(color: AdminUi.border),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: AdminUi.radius),
              textStyle: AdminUi.labelText.copyWith(
                color: AdminUi.title,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Message Admins'),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: _searchExpanded ? 280 : 44,
          height: 44,
          child: _searchExpanded
              ? TextField(
                  controller: widget.searchController,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  decoration:
                      AdminUi.inputDecoration(
                        hintText: 'Search all users',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AdminUi.title,
                        ),
                        suffixIcon: IconButton(
                          onPressed: _collapseSearch,
                          tooltip: 'Close search',
                          icon: const Icon(Icons.close_rounded, size: 19),
                        ),
                      ).copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AdminUi.radius,
                          borderSide: BorderSide(
                            color: AdminUi.title,
                            width: 1.4,
                          ),
                        ),
                      ),
                )
              : _DesktopHeaderIconSurface(
                  child: IconButton(
                    onPressed: _expandSearch,
                    tooltip: 'Search conversations',
                    padding: EdgeInsets.zero,
                    iconSize: 21,
                    color: AdminUi.title,
                    icon: const Icon(Icons.search_rounded),
                  ),
                ),
        ),
      ],
    );
  }
}

class _DesktopHeaderIconSurface extends StatelessWidget {
  final Widget child;

  const _DesktopHeaderIconSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: AdminUi.radius,
        border: Border.all(color: AdminUi.border),
      ),
      child: child,
    );
  }
}

class _MessagesHeader extends StatelessWidget {
  final TextEditingController searchController;
  final int unreadTotal;
  final VoidCallback onNewAdminMessage;

  const _MessagesHeader({
    required this.searchController,
    required this.unreadTotal,
    required this.onNewAdminMessage,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final title = AdminSectionIntro(title: 'Messages');
        final unreadPill = _UnreadSupportPill(unreadTotal: unreadTotal);
        final search = _MessagesSearchField(controller: searchController);
        final newMessage = ElevatedButton.icon(
          onPressed: onNewAdminMessage,
          icon: const Icon(Icons.add_comment_rounded, size: 18),
          label: const Text('New admin message'),
        );

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
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: newMessage),
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
            newMessage,
            const SizedBox(width: 10),
            SizedBox(width: 320, child: search),
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
          Icon(Icons.forum_rounded, size: 16, color: AdminUi.accentBlue),
          const SizedBox(width: 7),
          Text(
            unreadTotal == 1 ? '1 unread' : '$unreadTotal unread',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.labelText.copyWith(
              color: AdminUi.title,
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

class _AdminConversationDivider extends StatelessWidget {
  const _AdminConversationDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AdminUi.border.withValues(alpha: 0.72),
      ),
    );
  }
}

class _AdminConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final String adminId;
  final String adminRole;
  final String avatarIdentity;
  final Future<ChatParticipantProfile?>? targetProfileFuture;
  final bool selected;
  final VoidCallback onTap;
  final bool isDeleting;
  final VoidCallback onShowActions;

  const _AdminConversationTile({
    required this.conversation,
    required this.adminId,
    required this.adminRole,
    required this.avatarIdentity,
    required this.targetProfileFuture,
    required this.selected,
    required this.onTap,
    required this.isDeleting,
    required this.onShowActions,
  });

  @override
  Widget build(BuildContext context) {
    final title = conversation.titleFor(
      currentUserId: adminId,
      currentUserRole: adminRole,
    );
    final unreadCount = conversation.unreadCountFor(
      currentUserId: adminId,
      currentUserRole: adminRole,
    );
    final hasUnread = unreadCount > 0;
    final roleLabel = conversation.isSupport
        ? 'Support'
        : conversation.tagFor(
            currentUserId: adminId,
            currentUserRole: adminRole,
          );

    return _AdminConversationTapTarget(
      semanticLabel: 'Open conversation with $title',
      highlighted: hasUnread,
      selected: selected,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      onLongPress: isDeleting ? null : onShowActions,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AdminUi.mutedSurface,
              shape: BoxShape.circle,
            ),
            child: _AdminConversationAvatar(
              key: ValueKey<String>('admin_avatar_$avatarIdentity'),
              title: title,
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
                              style: AdminUi.cardTitle.copyWith(
                                color: AdminUi.title,
                                fontSize: 15,
                                fontWeight: hasUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AdminConversationRoleLabel(label: roleLabel),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    TimeAgoText(
                      dateTime: conversation.latestActivityAt,
                      style: AdminUi.bodyText.copyWith(
                        color: hasUnread ? AdminUi.title : AdminUi.body,
                        fontSize: 12,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: hasUnread ? AdminUi.title : AdminUi.body,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        conversation.previewFor(adminId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdminUi.bodyText.copyWith(
                          color: hasUnread ? AdminUi.title : AdminUi.body,
                          fontSize: 13,
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (hasUnread) ...<Widget>[
                      const SizedBox(width: 8),
                      _AdminUnreadCountBadge(unreadCount: unreadCount),
                    ],
                    if (isDeleting)
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
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

class _AdminConversationTapTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final String semanticLabel;
  final bool highlighted;
  final bool selected;

  const _AdminConversationTapTarget({
    required this.child,
    required this.onTap,
    required this.onLongPress,
    required this.padding,
    required this.semanticLabel,
    required this.highlighted,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      hint: onLongPress == null ? null : 'Long press for conversation options',
      child: Material(
        color: selected
            ? AdminUi.blueSoft
            : highlighted
            ? AdminUi.soft(AdminUi.accentBlue, alpha: 0.045)
            : Colors.transparent,
        borderRadius: AdminUi.radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          hoverColor: AdminUi.mutedSurface.withValues(alpha: 0.72),
          focusColor: AdminUi.blueSoft,
          splashColor: AdminUi.accentBlue.withValues(alpha: 0.08),
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

class _AdminStaffDirectoryDialog extends StatelessWidget {
  final String currentAdminId;

  const _AdminStaffDirectoryDialog({required this.currentAdminId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Message admin staff'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: StreamBuilder<List<AdminUserRecord>>(
          stream: AdminService.watchActiveAdminStaff(
            excludingUserId: currentAdminId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const AdminErrorCard(
                message: 'Unable to load active admin staff.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final staff = snapshot.data!;
            if (staff.isEmpty) {
              return const AdminEmptyCollection(
                icon: Icons.admin_panel_settings_outlined,
                title: 'No other active admins',
                description: 'Active admin staff will appear here.',
              );
            }

            return ListView.separated(
              itemCount: staff.length,
              separatorBuilder: (_, _) => Divider(color: AdminUi.border),
              itemBuilder: (context, index) {
                final admin = staff[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: AdminUi.mutedSurface,
                    foregroundColor: AdminUi.primary,
                    child: Text(
                      admin.fullName.isEmpty
                          ? 'A'
                          : admin.fullName.substring(0, 1).toUpperCase(),
                    ),
                  ),
                  title: Text(admin.fullName, style: AdminUi.cardTitle),
                  subtitle: Text(
                    '${admin.roleLabel} • ${admin.email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminUi.bodyText,
                  ),
                  trailing: const Icon(Icons.chat_bubble_outline_rounded),
                  onTap: () => Navigator.of(context).pop(admin),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _AdminConversationRoleLabel extends StatelessWidget {
  final String label;

  const _AdminConversationRoleLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AdminUi.mutedSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminUi.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AdminUi.bodyText.copyWith(
          color: AdminUi.body,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class _AdminUnreadCountBadge extends StatelessWidget {
  final int unreadCount;

  const _AdminUnreadCountBadge({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AdminUi.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        unreadCount > 99 ? '99+' : '$unreadCount',
        textAlign: TextAlign.center,
        style: AdminUi.bodyText.copyWith(
          color: AdminUi.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

class _AdminConversationAvatar extends StatelessWidget {
  final String title;
  final String avatarIdentity;
  final Future<ChatParticipantProfile?>? profileFuture;

  const _AdminConversationAvatar({
    super.key,
    required this.title,
    required this.avatarIdentity,
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
      key: ValueKey<String>('admin_profile_$avatarIdentity'),
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return fallback;
        }

        final profile = snapshot.data;
        return FirebaseStorageImage(
          key: ValueKey<String>('admin_image_$avatarIdentity'),
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
        style: AdminUi.cardTitle.copyWith(color: AdminUi.primary),
      ),
    );
  }
}
