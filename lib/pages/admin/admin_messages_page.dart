import 'package:flutter/material.dart';

import '../../models/chat_conversation.dart';
import '../../models/chat_participant_profile.dart';
import '../../services/chat_service.dart';
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
            stream: _chatService.watchAdminInbox(widget.adminId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _MessagesHeader(
                      searchController: _searchController,
                      unreadTotal: 0,
                      onNewAdminMessage: _openAdminStaffDirectory,
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
                      onNewAdminMessage: _openAdminStaffDirectory,
                    ),
                    const SizedBox(height: 16),
                    const AdminErrorCard(
                      message:
                          'Unable to load admin messages. Please try again.',
                    ),
                  ],
                );
              }

              final conversations = snapshot.data ?? <ChatConversation>[];
              final unreadTotal = conversations.fold<int>(
                0,
                (total, conversation) =>
                    total +
                    conversation.unreadCountFor(
                      currentUserId: widget.adminId,
                      currentUserRole: widget.adminRole,
                    ),
              );

              final header = _MessagesHeader(
                searchController: _searchController,
                unreadTotal: unreadTotal,
                onNewAdminMessage: _openAdminStaffDirectory,
              );

              if (conversations.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    header,
                    const SizedBox(height: 16),
                    const AdminEmptyCollection(
                      icon: Icons.support_agent_rounded,
                      title: 'No messages yet',
                      description:
                          'Support requests and admin staff conversations appear here.',
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
                    ...filteredConversations.asMap().entries.map((entry) {
                      final conversation = entry.value;
                      final targetUserId = _targetUserIdFor(conversation);

                      return Padding(
                        key: ValueKey<String>(
                          'admin_conversation_${conversation.conversationId}',
                        ),
                        padding: EdgeInsets.only(
                          bottom: entry.key == filteredConversations.length - 1
                              ? 0
                              : 12,
                        ),
                        child: _AdminConversationCard(
                          conversation: conversation,
                          adminId: widget.adminId,
                          adminRole: widget.adminRole,
                          avatarIdentity:
                              targetUserId ?? conversation.conversationId,
                          targetProfileFuture: _profileFutureForTarget(
                            targetUserId,
                          ),
                        ),
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

  Future<void> _openAdminStaffDirectory() async {
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

class _AdminConversationCard extends StatelessWidget {
  final ChatConversation conversation;
  final String adminId;
  final String adminRole;
  final String avatarIdentity;
  final Future<ChatParticipantProfile?>? targetProfileFuture;

  const _AdminConversationCard({
    required this.conversation,
    required this.adminId,
    required this.adminRole,
    required this.avatarIdentity,
    required this.targetProfileFuture,
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

    return AdminInteractiveCard(
      semanticLabel: 'Open conversation with $title',
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: conversation.conversationId,
              currentUserId: adminId,
              currentUserRole: adminRole,
              title: title,
              subtitle: conversation.isSupport ? 'Support request' : roleLabel,
            ),
          ),
        );
      },
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
                const SizedBox(height: 5),
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
