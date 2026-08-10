import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/preferences/app_preferences_controller.dart';
import '../../models/chat_conversation.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../controllers/ride_tracking_controller.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../widgets/animated_tab_switcher.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../rides/ride_monitoring_page.dart';
import '../settings/settings_page.dart';
import 'passenger_home.dart';
import 'passenger_messages.dart';
import 'passenger_history.dart';
import 'passenger_dashboard.dart';
import 'passenger_book_ride_page.dart';

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
  static const int _dashboardIndex = 2;
  static const int _profileIndex = 3;

  int _currentIndex = 0;
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService.instance;
  final RideTrackingService _rideTrackingService = RideTrackingService();
  StreamSubscription<List<ChatConversation>>? _conversationSubscription;
  StreamSubscription<int>? _notificationSubscription;
  StreamSubscription<List<Ride>>? _rideCancellationSubscription;
  final Map<String, RideStatus> _knownRideStatuses = <String, RideStatus>{};
  int _messageUnreadCount = 0;
  int _notificationUnreadCount = 0;
  bool _isMarkingMessagesRead = false;
  bool _hasSeededRideStatuses = false;

  @override
  void initState() {
    super.initState();
    AppPreferencesController.instance.addListener(_handlePreferencesChanged);
    _watchUnreadMessages();
    _watchUnreadNotifications();
    _watchRideCancellations();
  }

  @override
  void didUpdateWidget(covariant PassengerShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _messageUnreadCount = 0;
      _notificationUnreadCount = 0;
      _watchUnreadMessages();
      _watchUnreadNotifications();
      _watchRideCancellations();
    }
  }

  @override
  void dispose() {
    AppPreferencesController.instance.removeListener(_handlePreferencesChanged);
    _conversationSubscription?.cancel();
    _notificationSubscription?.cancel();
    _rideCancellationSubscription?.cancel();
    super.dispose();
  }

  void _handlePreferencesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleProfileSelected(String value) {
    if (value == 'profile') {
      _selectTab(_profileIndex);
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
      _selectTab(_dashboardIndex);
    } else if (value == 'home') {
      setState(() => _currentIndex = 0);
    } else if (value == 'messages') {
      _selectTab(_messagesIndex);
    } else if (value == 'history') {
      _openHistory();
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
        onOpenHistory: _openHistory,
      ),
      PassengerMessages(
        userId: widget.userId,
        firstName: widget.firstName,
        passengerType: widget.passengerType,
      ),
      PassengerDashboard(
        userId: widget.userId,
        firstName: widget.firstName,
        passengerType: widget.passengerType,
        isVerified: widget.isVerified,
        onOpenHistory: _openHistory,
      ),
      ProfilePage(userId: widget.userId, embedded: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return Scaffold(
      extendBody: true,
      backgroundColor: PassengerUi.background,
      appBar: AppBarWidget(
        firstName: widget.firstName,
        profileImageUrl: widget.profileImageUrl,
        isDriver: false,
        showVerifiedBadge: widget.isVerified,
        notificationUnreadCount: _notificationUnreadCount,
        onNotificationsTap: _openNotifications,
        onBrandTap: () => _selectTab(0),
        onProfileSelected: _handleProfileSelected,
      ),
      body: AnimatedTabSwitcher(
        index: _currentIndex,
        onRefresh: _handleRefresh,
        children: pages,
      ),
      floatingActionButton: PassengerBookingButton(onPressed: _openBooking),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavWidget(
        currentIndex: _currentIndex,
        messageUnreadCount: _messageUnreadCount,
        onBookTap: _openBooking,
        onTap: _selectTab,
      ),
    );
  }

  void _openBooking() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PassengerBookRidePage(
          passengerId: widget.userId,
          passengerType: widget.passengerType,
          isVerified: widget.isVerified,
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PassengerHistory(
          userId: widget.userId,
          firstName: widget.firstName,
          passengerType: widget.passengerType,
        ),
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

  void _watchUnreadNotifications() {
    unawaited(_notificationSubscription?.cancel());
    _notificationSubscription = _notificationService
        .watchUnreadCount(widget.userId)
        .listen(
          (count) {
            if (mounted && count != _notificationUnreadCount) {
              setState(() => _notificationUnreadCount = count);
            }
          },
          onError: (_) {
            if (mounted && _notificationUnreadCount != 0) {
              setState(() => _notificationUnreadCount = 0);
            }
          },
        );
  }

  void _watchRideCancellations() {
    unawaited(_rideCancellationSubscription?.cancel());
    _knownRideStatuses.clear();
    _hasSeededRideStatuses = false;
    _rideCancellationSubscription = _rideTrackingService
        .watchPassengerRides(widget.userId)
        .listen(
          _handleRideCancellationSnapshot,
          onError: (_) {
            // Ride history widgets surface read errors; this listener is only for notices.
          },
        );
  }

  void _handleRideCancellationSnapshot(List<Ride> rides) {
    if (!_hasSeededRideStatuses) {
      for (final ride in rides) {
        _knownRideStatuses[ride.bookingId] = ride.status;
      }
      _hasSeededRideStatuses = true;
      return;
    }

    for (final ride in rides) {
      final previousStatus = _knownRideStatuses[ride.bookingId];
      _knownRideStatuses[ride.bookingId] = ride.status;

      if (ride.status == RideStatus.cancelled &&
          previousStatus != null &&
          previousStatus != RideStatus.cancelled &&
          ride.hasDriver &&
          !ride.wasCancelledBy(widget.userId)) {
        _showRideCancelledNotice(ride);
      }
    }
  }

  void _showRideCancelledNotice(Ride ride) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Your ride was cancelled by the driver.'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RideMonitoringPage(
                  bookingId: ride.bookingId,
                  userId: widget.userId,
                  viewerRole: RideViewerRole.passenger,
                ),
              ),
            );
          },
        ),
      ),
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
