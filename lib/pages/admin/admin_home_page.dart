import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/preferences/app_preferences_controller.dart';
import '../../core/session/session_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/animated_tab_switcher.dart';
import '../../widgets/admin_widgets/admin_appbar.dart';
import '../../widgets/firebase_storage_image.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../settings/settings_page.dart';
import 'widgets/admin_ui.dart';
import 'admin_account_management_page.dart';
import 'admin_insights_page.dart';
import 'admin_management_page.dart';
import 'admin_messages_page.dart';
import 'admin_monitoring_page.dart';
import 'admin_overview_page.dart';
import 'admin_reports_page.dart';

class AdminHomePage extends StatefulWidget {
  final String userId;
  final String firstName;
  final String? profileImageUrl;

  const AdminHomePage({
    super.key,
    required this.userId,
    required this.firstName,
    this.profileImageUrl,
  });

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService.instance;
  StreamSubscription<int>? _notificationSubscription;
  StreamSubscription<int>? _messageUnreadSubscription;
  int _currentIndex = 0;
  int _notificationUnreadCount = 0;
  int _messageUnreadCount = 0;
  _AdminUtilityDestination? _activeUtilityDestination;

  @override
  void initState() {
    super.initState();
    AppPreferencesController.instance.addListener(_handlePreferencesChanged);
    _watchUnreadNotifications();
    _watchUnreadMessages();
  }

  @override
  void dispose() {
    AppPreferencesController.instance.removeListener(_handlePreferencesChanged);
    _notificationSubscription?.cancel();
    _messageUnreadSubscription?.cancel();
    super.dispose();
  }

  void _handlePreferencesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Widget> _buildPages() {
    return <Widget>[
      AdminOverviewPage(adminId: widget.userId, firstName: widget.firstName),
      AdminMonitoringPage(adminId: widget.userId),
      AdminAccountManagementPage(adminId: widget.userId),
      AdminManagementPage(adminId: widget.userId),
      AdminMessagesPage(adminId: widget.userId),
      AdminInsightsPage(adminId: widget.userId),
      AdminReportsPage(adminId: widget.userId),
    ];
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await SessionService.signOut();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback: 'Unable to log out. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showLogoutConfirmation() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AdminUi.radius),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, size: 22),
              SizedBox(width: 8),
              Text('Confirm Logout'),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out of your admin account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: AdminUi.radius),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      if (!mounted) return;
      await _handleLogout(context);
    }
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
    final useDesktopLayout = MediaQuery.sizeOf(context).width >= 1024;
    final pages = _buildPages();
    final tabBody = _activeUtilityDestination == null
        ? AnimatedTabSwitcher(
            index: _currentIndex,
            onRefresh: _handleRefresh,
            children: pages,
          )
        : _utilityBody;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminUi.background,
      appBar: AdminAppBar(
        adminName: widget.firstName.isEmpty ? 'Admin' : widget.firstName,
        appName: 'SakayNow Admin',
        profileImageUrl: widget.profileImageUrl,
        showMenuButton: !useDesktopLayout,
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onBrandTap: () => _selectDestination(0),
        onNotificationsTap: _openNotifications,
        onProfileTap: () =>
            _selectUtilityDestination(_AdminUtilityDestination.profile),
        notificationUnreadCount: _notificationUnreadCount,
      ),
      drawer: useDesktopLayout
          ? null
          : _AdminDrawer(
              firstName: widget.firstName,
              profileImageUrl: widget.profileImageUrl,
              currentIndex: _currentIndex,
              activeUtilityDestination: _activeUtilityDestination,
              messageUnreadCount: _messageUnreadCount,
              onDestinationSelected: (index) {
                Navigator.of(context).pop();
                _selectDestination(index);
              },
              onOpenProfile: () {
                Navigator.of(context).pop();
                _selectUtilityDestination(_AdminUtilityDestination.profile);
              },
              onOpenSettings: () {
                Navigator.of(context).pop();
                _selectUtilityDestination(_AdminUtilityDestination.settings);
              },
              onLogout: () {
                Navigator.of(context).pop();
                _showLogoutConfirmation();
              },
            ),
      body: useDesktopLayout
          ? Row(
              children: [
                _AdminSidebar(
                  firstName: widget.firstName,
                  profileImageUrl: widget.profileImageUrl,
                  currentIndex: _currentIndex,
                  activeUtilityDestination: _activeUtilityDestination,
                  messageUnreadCount: _messageUnreadCount,
                  onDestinationSelected: (index) {
                    _selectDestination(index);
                  },
                  onOpenProfile: () => _selectUtilityDestination(
                    _AdminUtilityDestination.profile,
                  ),
                  onOpenSettings: () => _selectUtilityDestination(
                    _AdminUtilityDestination.settings,
                  ),
                  onLogout: _showLogoutConfirmation,
                ),
                Expanded(child: tabBody),
              ],
            )
          : tabBody,
    );
  }

  Widget get _utilityBody {
    return switch (_activeUtilityDestination) {
      _AdminUtilityDestination.profile => ProfilePage(
        userId: widget.userId,
        embeddedInAdmin: true,
      ),
      _AdminUtilityDestination.settings => SettingsPage(
        userId: widget.userId,
        role: 'admin',
        embeddedInAdmin: true,
      ),
      null => const SizedBox.shrink(),
    };
  }

  void _selectDestination(int index) {
    setState(() {
      _currentIndex = index;
      _activeUtilityDestination = null;
    });
  }

  void _selectUtilityDestination(_AdminUtilityDestination destination) {
    setState(() => _activeUtilityDestination = destination);
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

  void _watchUnreadMessages() {
    unawaited(_messageUnreadSubscription?.cancel());
    _messageUnreadSubscription = _chatService
        .watchAdminSupportUnreadCount()
        .listen(
          (count) {
            if (mounted && count != _messageUnreadCount) {
              setState(() => _messageUnreadCount = count);
            }
          },
          onError: (_) {
            if (mounted && _messageUnreadCount != 0) {
              setState(() => _messageUnreadCount = 0);
            }
          },
        );
  }
}

enum _AdminUtilityDestination { profile, settings }

class _AdminDestination {
  final IconData icon;
  final String label;

  const _AdminDestination({required this.icon, required this.label});
}

const List<_AdminDestination> _adminDestinations = <_AdminDestination>[
  _AdminDestination(icon: Icons.dashboard_customize_rounded, label: 'Overview'),
  _AdminDestination(icon: Icons.monitor_heart_rounded, label: 'Monitoring'),
  _AdminDestination(icon: Icons.manage_accounts_rounded, label: 'Accounts'),
  _AdminDestination(icon: Icons.tune_rounded, label: 'Management'),
  _AdminDestination(icon: Icons.chat_bubble_rounded, label: 'Messages'),
  _AdminDestination(icon: Icons.analytics_rounded, label: 'Insights'),
  _AdminDestination(icon: Icons.assessment_rounded, label: 'Reports'),
];

class _AdminSidebar extends StatelessWidget {
  final String firstName;
  final String? profileImageUrl;
  final int currentIndex;
  final _AdminUtilityDestination? activeUtilityDestination;
  final int messageUnreadCount;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  const _AdminSidebar({
    required this.firstName,
    required this.profileImageUrl,
    required this.currentIndex,
    required this.activeUtilityDestination,
    required this.messageUnreadCount,
    required this.onDestinationSelected,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AdminUi.sidebarWidth,
      decoration: BoxDecoration(
        color: AdminUi.surface,
        border: Border(right: BorderSide(color: AdminUi.border)),
      ),
      child: _AdminNavigationContent(
        firstName: firstName,
        profileImageUrl: profileImageUrl,
        currentIndex: currentIndex,
        activeUtilityDestination: activeUtilityDestination,
        messageUnreadCount: messageUnreadCount,
        onDestinationSelected: onDestinationSelected,
        onOpenProfile: onOpenProfile,
        onOpenSettings: onOpenSettings,
        onLogout: onLogout,
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final String firstName;
  final String? profileImageUrl;
  final int currentIndex;
  final _AdminUtilityDestination? activeUtilityDestination;
  final int messageUnreadCount;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  const _AdminDrawer({
    required this.firstName,
    required this.profileImageUrl,
    required this.currentIndex,
    required this.activeUtilityDestination,
    required this.messageUnreadCount,
    required this.onDestinationSelected,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AdminUi.surface,
      child: _AdminNavigationContent(
        firstName: firstName,
        profileImageUrl: profileImageUrl,
        currentIndex: currentIndex,
        activeUtilityDestination: activeUtilityDestination,
        messageUnreadCount: messageUnreadCount,
        onDestinationSelected: onDestinationSelected,
        onOpenProfile: onOpenProfile,
        onOpenSettings: onOpenSettings,
        onLogout: onLogout,
      ),
    );
  }
}

class _AdminNavigationContent extends StatelessWidget {
  final String firstName;
  final String? profileImageUrl;
  final int currentIndex;
  final _AdminUtilityDestination? activeUtilityDestination;
  final int messageUnreadCount;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  const _AdminNavigationContent({
    required this.firstName,
    required this.profileImageUrl,
    required this.currentIndex,
    required this.activeUtilityDestination,
    required this.messageUnreadCount,
    required this.onDestinationSelected,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final name = firstName.isEmpty ? 'Admin' : firstName;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Material(
              color: Colors.transparent,
              borderRadius: AdminUi.radius,
              child: InkWell(
                onTap: () => onDestinationSelected(0),
                borderRadius: AdminUi.radius,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                  child: Row(
                    children: [
                      _AdminNavAvatar(
                        name: name,
                        profileImageUrl: profileImageUrl,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Admin Console', style: AdminUi.cardTitle),
                            const SizedBox(height: 2),
                            Text(name, style: AdminUi.bodyText),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: AdminUi.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Text(
                    'WORKSPACE',
                    style: AdminUi.labelText.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                for (final entry in _adminDestinations.asMap().entries)
                  _AdminNavItem(
                    icon: entry.value.icon,
                    label: entry.value.label,
                    selected:
                        activeUtilityDestination == null &&
                        currentIndex == entry.key,
                    unreadCount: entry.value.label == 'Messages'
                        ? messageUnreadCount
                        : 0,
                    onTap: () => onDestinationSelected(entry.key),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AdminUi.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            child: Column(
              children: [
                _AdminNavAction(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  selected:
                      activeUtilityDestination ==
                      _AdminUtilityDestination.profile,
                  onTap: onOpenProfile,
                ),
                _AdminNavAction(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  selected:
                      activeUtilityDestination ==
                      _AdminUtilityDestination.settings,
                  onTap: onOpenSettings,
                ),
                _AdminNavAction(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  color: AdminUi.danger,
                  onTap: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavAvatar extends StatelessWidget {
  final String name;
  final String? profileImageUrl;

  const _AdminNavAvatar({required this.name, required this.profileImageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AdminUi.soft(AdminUi.accent),
        borderRadius: AdminUi.radius,
        border: Border.all(color: AdminUi.border),
      ),
      child: ClipRRect(
        borderRadius: AdminUi.radius,
        child: FirebaseStorageImage(
          imageUrl: profileImageUrl,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          fallback: Center(
            child: Text(
              name[0].toUpperCase(),
              style: AdminUi.cardTitle.copyWith(color: AdminUi.accent),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;

  const _AdminNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AdminUi.accent : AdminUi.body;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AdminUi.soft(AdminUi.accent) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AdminUi.radius,
          side: BorderSide(
            color: selected
                ? AdminUi.accent.withValues(alpha: 0.16)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AdminUi.radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? AdminUi.surface.withValues(
                            alpha: AdminUi.isDarkMode ? 0.10 : 0.72,
                          )
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 19, color: foreground),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminUi.bodyText.copyWith(
                      color: selected ? AdminUi.title : AdminUi.body,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  _AdminNavUnreadBadge(count: unreadCount),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNavUnreadBadge extends StatelessWidget {
  final int count;

  const _AdminNavUnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();

    return Semantics(
      label: count == 1 ? '1 unread message' : '$count unread messages',
      child: Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AdminUi.primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: AdminUi.cardShadow,
        ),
        child: Text(
          label,
          maxLines: 1,
          style: AdminUi.labelText.copyWith(
            color: AdminUi.onPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AdminNavAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _AdminNavAction({
    required this.icon,
    required this.label,
    this.color,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AdminUi.accent : color ?? AdminUi.body;

    return Material(
      color: selected ? AdminUi.soft(AdminUi.accent) : Colors.transparent,
      borderRadius: AdminUi.radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AdminUi.radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 19, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AdminUi.bodyText.copyWith(
                    color: selected ? AdminUi.title : color ?? AdminUi.title,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
