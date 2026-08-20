import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_assets.dart';
import '../../core/preferences/app_preferences_controller.dart';
import '../../core/session/session_service.dart';
import '../../core/session/user_roles.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/animated_tab_switcher.dart';
import '../../widgets/admin_widgets/admin_appbar.dart';
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
  final String role;
  final String? profileImageUrl;

  const AdminHomePage({
    super.key,
    required this.userId,
    required this.firstName,
    required this.role,
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
  bool _isSidebarCollapsed = false;
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
      AdminMessagesPage(adminId: widget.userId, adminRole: widget.role),
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
        roleLabel: adminStaffRoleLabel(widget.role),
        appName: 'SakayNow Buenatoda',
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
                  collapsed: _isSidebarCollapsed,
                  firstName: widget.firstName,
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
                  onToggleCollapsed: () => setState(
                    () => _isSidebarCollapsed = !_isSidebarCollapsed,
                  ),
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
        role: widget.role,
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
        .watchAdminInboxUnreadCount(
          adminId: widget.userId,
          adminRole: widget.role,
        )
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
  final bool collapsed;
  final String firstName;
  final int currentIndex;
  final _AdminUtilityDestination? activeUtilityDestination;
  final int messageUnreadCount;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;
  final VoidCallback onToggleCollapsed;

  const _AdminSidebar({
    required this.collapsed,
    required this.firstName,
    required this.currentIndex,
    required this.activeUtilityDestination,
    required this.messageUnreadCount,
    required this.onDestinationSelected,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onLogout,
    required this.onToggleCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: collapsed ? AdminUi.collapsedSidebarWidth : AdminUi.sidebarWidth,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AdminUi.surface,
        border: Border(right: BorderSide(color: AdminUi.strongBorder)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AdminUi.isDarkMode ? 0.18 : 0.045,
            ),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: _AdminNavigationContent(
        firstName: firstName,
        currentIndex: currentIndex,
        activeUtilityDestination: activeUtilityDestination,
        messageUnreadCount: messageUnreadCount,
        onDestinationSelected: onDestinationSelected,
        onOpenProfile: onOpenProfile,
        onOpenSettings: onOpenSettings,
        onLogout: onLogout,
        sidebarCollapsed: collapsed,
        onToggleSidebar: onToggleCollapsed,
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final String firstName;
  final int currentIndex;
  final _AdminUtilityDestination? activeUtilityDestination;
  final int messageUnreadCount;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;

  const _AdminDrawer({
    required this.firstName,
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
  final int currentIndex;
  final _AdminUtilityDestination? activeUtilityDestination;
  final int messageUnreadCount;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;
  final bool sidebarCollapsed;
  final VoidCallback? onToggleSidebar;

  const _AdminNavigationContent({
    required this.firstName,
    required this.currentIndex,
    required this.activeUtilityDestination,
    required this.messageUnreadCount,
    required this.onDestinationSelected,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onLogout,
    this.sidebarCollapsed = false,
    this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final name = firstName.isEmpty ? 'Admin' : firstName;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 180;

          return Column(
            children: [
              _AdminSidebarHeader(
                adminName: name,
                compact: compact,
                collapsed: sidebarCollapsed,
                onHomeTap: () => onDestinationSelected(0),
                onToggleSidebar: onToggleSidebar,
              ),
              Divider(height: 1, color: AdminUi.strongBorder),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 10 : 12,
                    compact ? 12 : 14,
                    compact ? 10 : 12,
                    14,
                  ),
                  children: [
                    if (!compact)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: Text(
                          'WORKSPACE',
                          style: AdminUi.labelText.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                            color: AdminUi.title.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    for (final entry in _adminDestinations.asMap().entries)
                      _AdminNavItem(
                        icon: entry.value.icon,
                        label: entry.value.label,
                        compact: compact,
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
              Divider(height: 1, color: AdminUi.strongBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  children: [
                    _AdminNavAction(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                      compact: compact,
                      selected:
                          activeUtilityDestination ==
                          _AdminUtilityDestination.profile,
                      onTap: onOpenProfile,
                    ),
                    _AdminNavAction(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      compact: compact,
                      selected:
                          activeUtilityDestination ==
                          _AdminUtilityDestination.settings,
                      onTap: onOpenSettings,
                    ),
                    _AdminNavAction(
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      compact: compact,
                      color: AdminUi.danger,
                      onTap: onLogout,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminSidebarHeader extends StatelessWidget {
  final String adminName;
  final bool compact;
  final bool collapsed;
  final VoidCallback onHomeTap;
  final VoidCallback? onToggleSidebar;

  const _AdminSidebarHeader({
    required this.adminName,
    required this.compact,
    required this.collapsed,
    required this.onHomeTap,
    required this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 6 : 12, 12, compact ? 6 : 10, 10),
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: compact
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            if (compact) ...[
              Expanded(
                child: Center(
                  child: Tooltip(
                    message: 'Admin overview',
                    child: _AdminSidebarBrandMark(onTap: onHomeTap),
                  ),
                ),
              ),
            ] else ...[
              Tooltip(
                message: 'Admin overview',
                child: _AdminSidebarBrandMark(onTap: onHomeTap),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Console',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminUi.cardTitle.copyWith(
                        color: AdminUi.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      adminName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminUi.labelText.copyWith(
                        color: AdminUi.title.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (onToggleSidebar != null) ...[
              if (!compact) const SizedBox(width: 8),
              Tooltip(
                message: collapsed ? 'Open sidebar' : 'Close sidebar',
                child: Material(
                  color: AdminUi.subtleSurface,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: onToggleSidebar,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.view_sidebar_outlined,
                        size: 19,
                        color: AdminUi.title,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;

  const _AdminNavItem({
    required this.icon,
    required this.label,
    this.compact = false,
    required this.selected,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AdminUi.accent
        : AdminUi.title.withValues(alpha: AdminUi.isDarkMode ? 0.90 : 0.82);
    final control = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? AdminUi.soft(AdminUi.accent, alpha: 0.15) : null,
        borderRadius: AdminUi.radius,
        border: Border.all(
          color: selected
              ? AdminUi.accent.withValues(
                  alpha: AdminUi.isDarkMode ? 0.48 : 0.28,
                )
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AdminUi.radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AdminUi.radius,
          splashColor: AdminUi.accent.withValues(alpha: 0.10),
          hoverColor: AdminUi.accent.withValues(alpha: 0.055),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 4 : 0,
                height: compact ? 48 : 50,
                decoration: BoxDecoration(
                  color: AdminUi.accent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(4),
                  ),
                ),
              ),
              Expanded(
                child: compact
                    ? SizedBox(
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(icon, size: 21, color: foreground),
                            if (unreadCount > 0)
                              Positioned(
                                top: 5,
                                right: 5,
                                child: _AdminNavUnreadBadge(
                                  count: unreadCount,
                                  compact: true,
                                ),
                              ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AdminUi.accent.withValues(alpha: 0.13)
                                    : AdminUi.subtleSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, size: 19, color: foreground),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AdminUi.bodyText.copyWith(
                                  color: foreground,
                                  fontSize: 13.5,
                                  height: 1.2,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
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
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: compact
          ? Tooltip(
              message: label,
              waitDuration: const Duration(milliseconds: 350),
              child: control,
            )
          : control,
    );
  }
}

class _AdminNavUnreadBadge extends StatelessWidget {
  final int count;
  final bool compact;

  const _AdminNavUnreadBadge({required this.count, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();

    return Semantics(
      label: count == 1 ? '1 unread message' : '$count unread messages',
      child: Container(
        constraints: BoxConstraints(
          minWidth: compact ? 16 : 22,
          minHeight: compact ? 16 : 22,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 3 : 7,
          vertical: compact ? 2 : 3,
        ),
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
            fontSize: compact ? 8.5 : 11,
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
  final bool compact;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _AdminNavAction({
    required this.icon,
    required this.label,
    this.compact = false,
    this.color,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AdminUi.accent
        : color ??
              AdminUi.title.withValues(alpha: AdminUi.isDarkMode ? 0.90 : 0.82);
    final control = Material(
      color: selected
          ? AdminUi.soft(AdminUi.accent, alpha: 0.15)
          : Colors.transparent,
      borderRadius: AdminUi.radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AdminUi.radius,
        child: compact
            ? SizedBox(
                height: 44,
                child: Icon(icon, size: 20, color: foreground),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selected
                            ? AdminUi.accent.withValues(alpha: 0.13)
                            : AdminUi.subtleSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 19, color: foreground),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: AdminUi.bodyText.copyWith(
                          color: foreground,
                          fontSize: 13.5,
                          height: 1.2,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );

    return compact
        ? Tooltip(
            message: label,
            waitDuration: const Duration(milliseconds: 350),
            child: control,
          )
        : control;
  }
}

class _AdminSidebarBrandMark extends StatelessWidget {
  final VoidCallback onTap;

  const _AdminSidebarBrandMark({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: AdminUi.subtleSurface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AdminUi.strongBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(AppAssets.logo, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
