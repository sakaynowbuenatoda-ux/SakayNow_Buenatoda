import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/chat_conversation.dart';
import '../../models/ride.dart';
import '../../models/ride_status.dart';
import '../../controllers/ride_tracking_controller.dart';
import '../../services/chat_service.dart';
import '../../widgets/animated_tab_switcher.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/ride_tracking_service.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../rides/ride_monitoring_page.dart';
import '../settings/settings_page.dart';
import 'driver_dashboard.dart';
import 'driver_history.dart';
import 'driver_home.dart';
import 'driver_messages.dart';
import 'driver_queue.dart';

class DriverShell extends StatefulWidget {
  final String userId;
  final String firstName;
  final bool isVerified;
  final String? profileImageUrl;

  const DriverShell({
    super.key,
    required this.userId,
    required this.firstName,
    required this.isVerified,
    this.profileImageUrl,
  });

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> with WidgetsBindingObserver {
  static const int _messagesIndex = 2;

  int _currentIndex = 0;
  late final ValueNotifier<bool> _isActiveNotifier;
  late List<Widget> _pages;
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService.instance;
  final RideTrackingService _rideTrackingService = RideTrackingService();
  final LocationService _locationService = const LocationService();
  StreamSubscription<List<ChatConversation>>? _conversationSubscription;
  StreamSubscription<int>? _notificationSubscription;
  StreamSubscription<List<Ride>>? _rideCancellationSubscription;
  final Map<String, RideStatus> _knownRideStatuses = <String, RideStatus>{};
  Timer? _inactivityTimer;
  Timer? _foregroundIdleTimer;
  DateTime? _inactiveSince;
  int _messageUnreadCount = 0;
  int _notificationUnreadCount = 0;
  bool _isMarkingMessagesRead = false;
  bool _hasSeededRideStatuses = false;

  bool get isActive => _isActiveNotifier.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isActiveNotifier = ValueNotifier<bool>(false);
    _pages = _buildPages();
    _watchUnreadMessages();
    _watchUnreadNotifications();
    _watchRideCancellations();
  }

  @override
  void didUpdateWidget(covariant DriverShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId ||
        oldWidget.firstName != widget.firstName ||
        oldWidget.isVerified != widget.isVerified) {
      _pages = _buildPages();
    }

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
    WidgetsBinding.instance.removeObserver(this);
    _conversationSubscription?.cancel();
    _notificationSubscription?.cancel();
    _rideCancellationSubscription?.cancel();
    _inactivityTimer?.cancel();
    _foregroundIdleTimer?.cancel();
    _isActiveNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _startInactivityTimer();
        return;
      case AppLifecycleState.detached:
        unawaited(_setDriverUnavailable());
        return;
    }
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
            role: 'driver',
            isVerified: widget.isVerified,
          ),
        ),
      );
    } else if (value == 'home') {
      setState(() => _currentIndex = 0);
    } else if (value == 'messages') {
      _selectTab(_messagesIndex);
    } else if (value == 'history') {
      setState(() => _currentIndex = 3);
    } else if (value == 'dashboard') {
      setState(() => _currentIndex = 4);
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
      ValueListenableBuilder<bool>(
        valueListenable: _isActiveNotifier,
        builder: (context, isActive, _) {
          return DriverHomePage(
            userId: widget.userId,
            firstName: widget.firstName,
            isActive: isActive,
            isVerified: widget.isVerified,
            onOpenQueue: () => setState(() => _currentIndex = 1),
          );
        },
      ),
      DriverQueuePage(driverId: widget.userId, isVerified: widget.isVerified),
      DriverMessagesPage(userId: widget.userId, firstName: widget.firstName),
      DriverHistoryPage(driverId: widget.userId),
      DriverDashboardPage(
        driverId: widget.userId,
        isVerified: widget.isVerified,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _recordDriverActivity(),
      onPointerMove: (_) => _recordDriverActivity(),
      onPointerSignal: (_) => _recordDriverActivity(),
      child: Scaffold(
        backgroundColor: PassengerUi.background,
        appBar: AppBarWidget(
          firstName: widget.firstName,
          profileImageUrl: widget.profileImageUrl,
          isDriver: true,
          showVerifiedBadge: widget.isVerified,
          isActive: isActive,
          notificationUnreadCount: _notificationUnreadCount,
          onStatusChanged: _handleAvailabilityChanged,
          onNotificationsTap: _openNotifications,
          onBrandTap: () => _selectTab(0),
          onProfileSelected: _handleProfileSelected,
        ),
        body: AnimatedTabSwitcher(
          index: _currentIndex,
          onRefresh: _handleRefresh,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavWidget(
          currentIndex: _currentIndex,
          isDriver: true,
          messageUnreadCount: _messageUnreadCount,
          onTap: _selectTab,
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
        .watchDriverRides(widget.userId)
        .listen(
          _handleRideCancellationSnapshot,
          onError: (_) {
            // Dashboard/history already surface ride read errors when needed.
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
        content: const Text('The passenger cancelled this ride.'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RideMonitoringPage(
                  bookingId: ride.bookingId,
                  userId: widget.userId,
                  viewerRole: RideViewerRole.driver,
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
            currentUserRole: 'driver',
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
        userRole: 'driver',
      );
    } on Exception {
      // Keep navigation responsive even when Firestore rejects a background read update.
    } finally {
      _isMarkingMessagesRead = false;
    }
  }

  Future<void> _handleAvailabilityChanged(bool value) async {
    if (value && !widget.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin verification is required before going active.'),
        ),
      );
      return;
    }

    _cancelBackgroundInactivityTimer();
    _cancelForegroundIdleTimer();
    setState(() => _isActiveNotifier.value = value);

    try {
      if (value) {
        final position = await _locationService.getCurrentPosition();
        await _rideTrackingService.updateDriverLocation(
          driverId: widget.userId,
          position: position,
        );
      } else {
        await _rideTrackingService.updateDriverAvailability(
          driverId: widget.userId,
          isAvailable: false,
        );
      }

      if (value) {
        _resetForegroundIdleTimer();
      } else {
        _cancelForegroundIdleTimer();
      }
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _isActiveNotifier.value = !value);
      if (!value) {
        _resetForegroundIdleTimer();
      } else {
        _cancelForegroundIdleTimer();
      }
    }
  }

  void _startInactivityTimer() {
    if (!isActive) {
      return;
    }

    _cancelForegroundIdleTimer();
    _inactiveSince ??= DateTime.now();
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
      RideTrackingService.driverAvailabilityTimeout,
      () => unawaited(_setDriverUnavailable()),
    );
  }

  void _handleAppResumed() {
    final inactiveSince = _inactiveSince;
    _cancelBackgroundInactivityTimer();

    if (inactiveSince == null || !isActive) {
      return;
    }

    final inactiveDuration = DateTime.now().difference(inactiveSince);
    if (inactiveDuration >= RideTrackingService.driverAvailabilityTimeout) {
      unawaited(_setDriverUnavailable());
    } else {
      _resetForegroundIdleTimer();
    }
  }

  void _cancelBackgroundInactivityTimer() {
    _inactiveSince = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _recordDriverActivity() {
    if (!isActive) {
      return;
    }

    _resetForegroundIdleTimer();
  }

  void _resetForegroundIdleTimer() {
    _foregroundIdleTimer?.cancel();
    _foregroundIdleTimer = Timer(
      RideTrackingService.driverAvailabilityTimeout,
      () => unawaited(_setDriverUnavailable()),
    );
  }

  void _cancelForegroundIdleTimer() {
    _foregroundIdleTimer?.cancel();
    _foregroundIdleTimer = null;
  }

  Future<void> _setDriverUnavailable() async {
    _cancelBackgroundInactivityTimer();
    _cancelForegroundIdleTimer();

    if (mounted) {
      if (isActive) {
        setState(() => _isActiveNotifier.value = false);
      } else {
        _isActiveNotifier.value = false;
      }
    }

    try {
      await _rideTrackingService.markDriverUnavailable(driverId: widget.userId);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update driver status: $error')),
      );
    }
  }
}
