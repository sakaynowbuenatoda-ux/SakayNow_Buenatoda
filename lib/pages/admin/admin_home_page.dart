import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session/session_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/animated_tab_switcher.dart';
import '../../widgets/admin_widgets/admin_appbar.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../settings/settings_page.dart';
import 'admin_insights_page.dart';
import 'admin_messages_page.dart';
import 'admin_monitoring_page.dart';
import 'admin_operations_page.dart';
import 'admin_overview_page.dart';
import 'admin_reports_page.dart';
import 'admin_verification_page.dart';

class AdminHomePage extends StatefulWidget {
  final String userId;
  final String firstName;

  const AdminHomePage({
    super.key,
    required this.userId,
    required this.firstName,
  });

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final NotificationService _notificationService = NotificationService.instance;
  StreamSubscription<int>? _notificationSubscription;
  int _currentIndex = 0;
  int _notificationUnreadCount = 0;

  late final List<Widget> _pages = <Widget>[
    AdminOverviewPage(adminId: widget.userId, firstName: widget.firstName),
    AdminMonitoringPage(adminId: widget.userId),
    AdminVerificationPage(adminId: widget.userId),
    AdminOperationsPage(adminId: widget.userId),
    AdminInsightsPage(adminId: widget.userId),
    AdminMessagesPage(adminId: widget.userId),
    AdminReportsPage(adminId: widget.userId),
  ];

  @override
  void initState() {
    super.initState();
    _watchUnreadNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await SessionService.signOut();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $error')));
    }
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SettingsPage(role: 'admin')));
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilePage(userId: widget.userId)),
    );
  }

  void _openNotifications() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
  }

  Future<void> _handleRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PassengerUi.background,
      appBar: AdminAppBar(
        adminName: widget.firstName.isEmpty ? 'Admin' : widget.firstName,
        appName: 'SakayNow Admin',
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onNotificationsTap: _openNotifications,
        notificationUnreadCount: _notificationUnreadCount,
        onProfileSettingsTap: _openSettings,
        onLogout: _handleLogout,
      ),
      drawer: _AdminDrawer(
        firstName: widget.firstName,
        currentIndex: _currentIndex,
        onDestinationSelected: (index) {
          Navigator.of(context).pop();
          setState(() => _currentIndex = index);
        },
        onOpenProfile: () {
          Navigator.of(context).pop();
          _openProfile();
        },
        onOpenSettings: () {
          Navigator.of(context).pop();
          _openSettings();
        },
      ),
      body: AnimatedTabSwitcher(
        index: _currentIndex,
        onRefresh: _handleRefresh,
        children: _pages,
      ),
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
}

class _AdminDrawer extends StatelessWidget {
  final String firstName;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;

  const _AdminDrawer({
    required this.firstName,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onOpenProfile,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label})>[
      (icon: Icons.dashboard_customize_rounded, label: 'Overview'),
      (icon: Icons.monitor_heart_rounded, label: 'Monitoring'),
      (icon: Icons.fact_check_rounded, label: 'Verification'),
      (icon: Icons.route_rounded, label: 'Operations'),
      (icon: Icons.analytics_rounded, label: 'Insights'),
      (icon: Icons.chat_bubble_rounded, label: 'Messages'),
      (icon: Icons.assessment_rounded, label: 'Reports'),
    ];

    return Drawer(
      backgroundColor: PassengerUi.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(gradient: PassengerUi.signalGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    child: Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : 'A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'SakayNow Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Hello, ${firstName.isEmpty ? 'Admin' : firstName}',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            for (final entry in items.asMap().entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ListTile(
                  leading: Icon(
                    entry.value.icon,
                    color: currentIndex == entry.key
                        ? PassengerUi.primary
                        : PassengerUi.body,
                  ),
                  title: Text(
                    entry.value.label,
                    style: TextStyle(
                      color: currentIndex == entry.key
                          ? PassengerUi.primary
                          : PassengerUi.title,
                      fontWeight: currentIndex == entry.key
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  selected: currentIndex == entry.key,
                  selectedTileColor: PassengerUi.primary.withValues(
                    alpha: 0.10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () => onDestinationSelected(entry.key),
                ),
              ),
            Divider(height: 28),
            ListTile(
              leading: Icon(
                Icons.person_outline_rounded,
                color: PassengerUi.accentBlue,
              ),
              title: Text(
                'Profile',
                style: TextStyle(color: PassengerUi.title),
              ),
              onTap: onOpenProfile,
            ),
            ListTile(
              leading: Icon(
                Icons.settings_outlined,
                color: PassengerUi.accentBlue,
              ),
              title: Text(
                'Settings',
                style: TextStyle(color: PassengerUi.title),
              ),
              onTap: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}
