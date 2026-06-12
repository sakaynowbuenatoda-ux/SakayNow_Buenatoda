import 'package:flutter/material.dart';
import 'passenger_widgets/passenger_ui.dart';

class BottomNavWidget extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDriver;
  final int messageUnreadCount;

  const BottomNavWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isDriver = false,
    this.messageUnreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 390;
    final int messageIndex = isDriver ? 2 : 1;
    final int visibleMessageUnreadCount = currentIndex == messageIndex
        ? 0
        : messageUnreadCount;

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(
          compact ? 8 : 10,
          0,
          compact ? 8 : 10,
          compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: PassengerUi.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(compact ? 16 : 18),
          border: Border.all(color: PassengerUi.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: PassengerUi.isDarkMode ? 0.28 : 0.10,
              ),
              blurRadius: compact ? 18 : 22,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 16 : 18),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            labelBehavior: compact
                ? NavigationDestinationLabelBehavior.onlyShowSelected
                : NavigationDestinationLabelBehavior.alwaysShow,
            destinations: isDriver
                ? [
                    const NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.list_alt_outlined),
                      selectedIcon: Icon(Icons.list_alt_rounded),
                      label: 'Queue',
                    ),
                    NavigationDestination(
                      icon: _NavIconWithBadge(
                        icon: Icons.chat_bubble_outline_rounded,
                        count: visibleMessageUnreadCount,
                      ),
                      selectedIcon: _NavIconWithBadge(
                        icon: Icons.chat_bubble_rounded,
                        count: visibleMessageUnreadCount,
                      ),
                      label: 'Messages',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.history_rounded),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: 'History',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: 'Dashboard',
                    ),
                  ]
                : [
                    const NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: _NavIconWithBadge(
                        icon: Icons.chat_bubble_outline_rounded,
                        count: visibleMessageUnreadCount,
                      ),
                      selectedIcon: _NavIconWithBadge(
                        icon: Icons.chat_bubble_rounded,
                        count: visibleMessageUnreadCount,
                      ),
                      label: 'Messages',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.history_rounded),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: 'History',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: 'Dashboard',
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

class _NavIconWithBadge extends StatelessWidget {
  final IconData icon;
  final int count;

  const _NavIconWithBadge({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    final hasUnread = count > 0;

    return SizedBox(
      width: 34,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Icon(icon),
          if (hasUnread)
            Positioned(
              top: 0,
              right: 1,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PassengerUi.accentBlue,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: PassengerUi.surface, width: 1.5),
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: TextStyle(
                    color: PassengerUi.onPrimary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
