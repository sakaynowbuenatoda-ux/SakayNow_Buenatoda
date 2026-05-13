import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/chat_conversation.dart';
import '../../services/chat_service.dart';
import '../../widgets/animated_tab_switcher.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../settings/settings_page.dart';
import 'passenger_home.dart';
import 'passenger_messages.dart';
import 'passenger_history.dart';
import 'passenger_dashboard.dart';

class PassengerShell extends StatefulWidget {
  final String userId;
  final String firstName;
  final String passengerType;
  final bool isVerified;
  final String? profileImageUrl;

  const PassengerShell({
    super.key,
    required this.userId,
    required this.firstName,
    required this.passengerType,
    required this.isVerified,
    this.profileImageUrl,
  });

  @override
  State<PassengerShell> createState() => _PassengerShellState();
}

class _PassengerShellState extends State<PassengerShell> {
  static const int _messagesIndex = 1;

  int _currentIndex = 0;
  late List<Widget> _pages;
  final ChatService _chatService = ChatService();
  StreamSubscription<List<ChatConversation>>? _conversationSubscription;
  int _messageUnreadCount = 0;
  bool _isMarkingMessagesRead = false;

  @override
  void initState() {
    super.initState();
    _pages = _buildPages();
    _watchUnreadMessages();
  }

  @override
  void didUpdateWidget(covariant PassengerShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId ||
        oldWidget.firstName != widget.firstName ||
        oldWidget.passengerType != widget.passengerType ||
        oldWidget.isVerified != widget.isVerified) {
      _pages = _buildPages();
    }

    if (oldWidget.userId != widget.userId) {
      _messageUnreadCount = 0;
      _watchUnreadMessages();
    }
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    super.dispose();
  }

  void _handleProfileSelected(String value) {
    if (value == 'profile') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfilePage(userId: widget.userId)),
      );
    } else if (value == 'settings') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsPage(
            userId: widget.userId,
            role: 'passenger',
            isVerified: widget.isVerified,
            passengerType: widget.passengerType,
          ),
        ),
      );
    } else if (value == 'dashboard') {
      setState(() => _currentIndex = 3);
    } else if (value == 'home') {
      setState(() => _currentIndex = 0);
    } else if (value == 'messages') {
      _selectTab(_messagesIndex);
    } else if (value == 'history') {
      setState(() => _currentIndex = 2);
    }
  }

  Future<void> _handleRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  void _openNotifications() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
  }

  List<Widget> _buildPages() {
    return <Widget>[
      PassengerHomepage(
        userId: widget.userId,
        firstName: widget.firstName,
        passengerType: widget.passengerType,
        isVerified: widget.isVerified,
      ),
      PassengerMessages(
        userId: widget.userId,
        firstName: widget.firstName,
        passengerType: widget.passengerType,
      ),
      PassengerHistory(
        userId: widget.userId,
        firstName: widget.firstName,
        passengerType: widget.passengerType,
      ),
      PassengerDashboard(
        userId: widget.userId,
        firstName: widget.firstName,
        passengerType: widget.passengerType,
        isVerified: widget.isVerified,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBarWidget(
        firstName: widget.firstName,
        profileImageUrl: widget.profileImageUrl,
        isDriver: false,
        showVerifiedBadge: widget.isVerified,
        onNotificationsTap: _openNotifications,
        onProfileSelected: _handleProfileSelected,
      ),
      body: AnimatedTabSwitcher(
        index: _currentIndex,
        onRefresh: _handleRefresh,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavWidget(
        currentIndex: _currentIndex,
        messageUnreadCount: _messageUnreadCount,
        onTap: _selectTab,
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    if (index == _messagesIndex) {
      unawaited(_markMessagesRead());
    }
  }

  void _watchUnreadMessages() {
    unawaited(_conversationSubscription?.cancel());
    _conversationSubscription = _chatService
        .watchUserConversations(widget.userId)
        .listen(
          (conversations) {
            final unreadTotal = _unreadTotal(conversations);
            final visibleUnreadTotal = _currentIndex == _messagesIndex
                ? 0
                : unreadTotal;
            if (!mounted) {
              return;
            }

            if (visibleUnreadTotal != _messageUnreadCount) {
              setState(() => _messageUnreadCount = visibleUnreadTotal);
            }

            if (_currentIndex == _messagesIndex && unreadTotal > 0) {
              unawaited(_markMessagesRead());
            }
          },
          onError: (_) {
            if (mounted && _messageUnreadCount != 0) {
              setState(() => _messageUnreadCount = 0);
            }
          },
        );
  }

  int _unreadTotal(List<ChatConversation> conversations) {
    return conversations.fold<int>(
      0,
      (total, conversation) =>
          total +
          conversation.unreadCountFor(
            currentUserId: widget.userId,
            currentUserRole: 'passenger',
          ),
    );
  }

  Future<void> _markMessagesRead() async {
    if (_isMarkingMessagesRead) {
      return;
    }

    _isMarkingMessagesRead = true;
    if (mounted && _messageUnreadCount != 0) {
      setState(() => _messageUnreadCount = 0);
    }

    try {
      await _chatService.markUserConversationsRead(
        userId: widget.userId,
        userRole: 'passenger',
      );
    } on Exception {
      // Keep navigation responsive even when Firestore rejects a background read update.
    } finally {
      _isMarkingMessagesRead = false;
    }
  }
}
