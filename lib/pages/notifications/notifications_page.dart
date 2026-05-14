import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/time_ago_text.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService.instance;
  bool _isMarkingAllRead = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text('Notifications', style: PassengerUi.cardTitle),
        actions: [
          if (user != null)
            StreamBuilder<int>(
              stream: _notificationService.watchUnreadCount(user.uid),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                if (unreadCount == 0) {
                  return const SizedBox.shrink();
                }

                return TextButton(
                  onPressed: _isMarkingAllRead
                      ? null
                      : () => _markAllRead(user.uid),
                  child: Text(_isMarkingAllRead ? 'Saving' : 'Mark all read'),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: user == null
          ? const _NotificationsSignedOutState()
          : StreamBuilder<List<AppNotification>>(
              stream: _notificationService.watchNotifications(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _NotificationsErrorState(
                    message: snapshot.error.toString(),
                  );
                }

                final notifications =
                    snapshot.data ?? const <AppNotification>[];
                if (notifications.isEmpty) {
                  return const _NotificationsEmptyState();
                }

                return SafeArea(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      PassengerUi.horizontalPagePadding(context),
                      12,
                      PassengerUi.horizontalPagePadding(context),
                      24 + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _NotificationTile(
                        notification: notification,
                        onTap: () => _openNotification(notification),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _openNotification(AppNotification notification) async {
    try {
      await _notificationService.openNotification(
        notification,
        context: context,
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open notification: $error')),
      );
    }
  }

  Future<void> _markAllRead(String userId) async {
    setState(() => _isMarkingAllRead = true);

    try {
      await _notificationService.markAllNotificationsRead(userId);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update: $error')));
    } finally {
      if (mounted) {
        setState(() => _isMarkingAllRead = false);
      }
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(notification);
    final icon = _iconFor(notification);

    return Material(
      color: notification.isRead
          ? PassengerUi.surface
          : accent.withValues(alpha: PassengerUi.isDarkMode ? 0.16 : 0.08),
      borderRadius: PassengerUi.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: PassengerUi.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: PassengerUi.cardRadius,
            border: Border.all(
              color: notification.isRead
                  ? PassengerUi.border
                  : accent.withValues(alpha: 0.28),
            ),
            boxShadow: notification.isRead ? null : PassengerUi.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PassengerUi.cardTitle.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: PassengerUi.bodyText,
                    ),
                    const SizedBox(height: 8),
                    TimeAgoText(
                      dateTime: notification.createdAt,
                      style: PassengerUi.bodyText.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(AppNotification notification) {
    switch (notification.type) {
      case 'account_verified':
        return Icons.verified_rounded;
      case 'account_restricted':
        return Icons.block_rounded;
      case 'account_restored':
        return Icons.lock_open_rounded;
      case 'booking_request':
        return Icons.local_taxi_rounded;
      case 'booking_accepted':
        return Icons.check_circle_rounded;
      case 'booking_declined':
        return Icons.remove_circle_rounded;
      case 'booking_cancelled':
        return Icons.cancel_rounded;
      case 'driver_arriving':
      case 'driver_arrived':
        return Icons.near_me_rounded;
      case 'ride_started':
      case 'ride_completed':
        return Icons.route_rounded;
      case 'review_received':
        return Icons.star_rounded;
      case 'verification_request':
        return Icons.fact_check_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  static Color _accentColor(AppNotification notification) {
    switch (notification.channel) {
      case 'account':
        return notification.type == 'account_restricted'
            ? Colors.redAccent
            : PassengerUi.secondary;
      case 'booking':
        return PassengerUi.accentBlue;
      case 'review':
        return PassengerUi.highlightAmber;
      default:
        return PassengerUi.primary;
    }
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: PassengerUi.pagePadding(context, baseBottom: 24),
        child: const PassengerEmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'No notifications yet',
          description: 'Booking, account, and review updates will appear here.',
        ),
      ),
    );
  }
}

class _NotificationsSignedOutState extends StatelessWidget {
  const _NotificationsSignedOutState();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: PassengerUi.pagePadding(context, baseBottom: 24),
        child: const PassengerEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Sign in required',
          description: 'Please sign in again to view notifications.',
        ),
      ),
    );
  }
}

class _NotificationsErrorState extends StatelessWidget {
  final String message;

  const _NotificationsErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: PassengerUi.pagePadding(context, baseBottom: 24),
        child: PassengerEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load notifications',
          description: message,
        ),
      ),
    );
  }
}
