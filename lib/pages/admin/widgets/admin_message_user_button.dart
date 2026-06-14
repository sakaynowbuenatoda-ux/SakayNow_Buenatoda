import 'package:flutter/material.dart';

import '../../../services/chat_service.dart';
import '../../messages/chat_page.dart';
import '../admin_models.dart';

class AdminMessageUserButton extends StatefulWidget {
  final String adminId;
  final AdminUserRecord user;
  final String label;
  final bool enabled;

  const AdminMessageUserButton({
    super.key,
    required this.adminId,
    required this.user,
    this.label = 'Message',
    this.enabled = true,
  });

  @override
  State<AdminMessageUserButton> createState() => _AdminMessageUserButtonState();
}

class _AdminMessageUserButtonState extends State<AdminMessageUserButton> {
  final ChatService _chatService = ChatService();
  bool _isOpening = false;

  bool get _canMessage {
    return widget.enabled &&
        !_isOpening &&
        widget.adminId.trim().isNotEmpty &&
        widget.user.isPassengerOrDriver &&
        !widget.user.isDeleted;
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _canMessage ? _openConversation : null,
      icon: _isOpening
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      label: Text(_isOpening ? 'Opening...' : widget.label),
    );
  }

  Future<void> _openConversation() async {
    if (_isOpening) {
      return;
    }

    setState(() => _isOpening = true);
    try {
      final conversationId = await _chatService.ensureSupportConversation(
        userId: widget.user.userId,
        userName: widget.user.fullName,
        userRole: widget.user.role,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            currentUserId: widget.adminId,
            currentUserRole: 'admin',
            title: widget.user.fullName,
            subtitle: '${widget.user.roleLabel} support',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open message: $error')));
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }
}
