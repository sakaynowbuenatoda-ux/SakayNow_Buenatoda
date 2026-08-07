import 'package:flutter/material.dart';

import 'passenger_widgets/passenger_ui.dart';

class BottomNavWidget extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDriver;
  final int messageUnreadCount;
  final int queueRequestCount;

  const BottomNavWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isDriver = false,
    this.messageUnreadCount = 0,
    this.queueRequestCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final messageIndex = isDriver ? 2 : 1;
    final visibleMessageUnreadCount = currentIndex == messageIndex
        ? 0
        : messageUnreadCount;
    final selectedNavigationIndex = isDriver
        ? currentIndex
        : currentIndex < 2
        ? currentIndex
        : currentIndex + 1;

    return BottomAppBar(
      color: PassengerUi.surface,
      surfaceTintColor: Colors.transparent,
      elevation: PassengerUi.isDarkMode ? 18 : 12,
      shadowColor: Colors.black.withValues(
        alpha: PassengerUi.isDarkMode ? 0.48 : 0.18,
      ),
      padding: EdgeInsets.zero,
      shape: isDriver ? null : const CircularNotchedRectangle(),
      notchMargin: 9,
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: compact ? 3 : 5),
        child: SizedBox(
          height: compact ? 62 : 66,
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: BottomNavigationBar(
              currentIndex: selectedNavigationIndex,
              onTap: (index) {
                if (isDriver) {
                  onTap(index);
                  return;
                }

                if (index == 2) {
                  return;
                }

                onTap(index > 2 ? index - 1 : index);
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: PassengerUi.title,
              unselectedItemColor: PassengerUi.body,
              selectedFontSize: compact ? 9.5 : 10.5,
              unselectedFontSize: compact ? 9.5 : 10.5,
              selectedLabelStyle: const TextStyle(
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
              showSelectedLabels: true,
              showUnselectedLabels: true,
              items: isDriver
                  ? _driverDestinations(
                      messageUnreadCount: visibleMessageUnreadCount,
                      queueRequestCount: queueRequestCount,
                    )
                  : _passengerDestinations(
                      messageUnreadCount: visibleMessageUnreadCount,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  List<BottomNavigationBarItem> _passengerDestinations({
    required int messageUnreadCount,
  }) {
    return <BottomNavigationBarItem>[
      _destination(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _destination(
        label: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
        selectedIcon: Icons.chat_bubble_rounded,
        badgeCount: messageUnreadCount,
      ),
      const BottomNavigationBarItem(
        icon: SizedBox(width: 42, height: 30),
        label: '',
        tooltip: 'Book a ride',
      ),
      _destination(
        label: 'History',
        icon: Icons.history_rounded,
        selectedIcon: Icons.history_rounded,
      ),
      _destination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
      ),
    ];
  }

  List<BottomNavigationBarItem> _driverDestinations({
    required int messageUnreadCount,
    required int queueRequestCount,
  }) {
    return <BottomNavigationBarItem>[
      _destination(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _destination(
        label: 'Queue',
        icon: Icons.list_alt_outlined,
        selectedIcon: Icons.list_alt_rounded,
        badgeCount: queueRequestCount,
      ),
      _destination(
        label: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
        selectedIcon: Icons.chat_bubble_rounded,
        badgeCount: messageUnreadCount,
      ),
      _destination(
        label: 'History',
        icon: Icons.history_rounded,
        selectedIcon: Icons.history_rounded,
      ),
      _destination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
      ),
    ];
  }

  BottomNavigationBarItem _destination({
    required String label,
    required IconData icon,
    required IconData selectedIcon,
    int badgeCount = 0,
  }) {
    return BottomNavigationBarItem(
      icon: _ModernNavIcon(icon: icon, badgeCount: badgeCount),
      activeIcon: _ModernNavIcon(
        icon: selectedIcon,
        badgeCount: badgeCount,
        selected: true,
      ),
      label: label,
      tooltip: label,
    );
  }
}

class PassengerBookingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const PassengerBookingButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final diameter = compact ? 64.0 : 68.0;

    return Tooltip(
      message: 'Book a ride',
      child: Semantics(
        button: true,
        label: 'Book a ride',
        excludeSemantics: true,
        child: Container(
          width: diameter,
          height: diameter,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: PassengerUi.surface,
            shape: BoxShape.circle,
            border: Border.all(color: PassengerUi.dark, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: PassengerUi.isDarkMode ? 0.34 : 0.14,
                ),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: PassengerUi.dark,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.local_taxi_rounded, color: Colors.white, size: 25),
                  SizedBox(height: 1),
                  Text(
                    'Book',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernNavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final int badgeCount;

  const _ModernNavIcon({
    required this.icon,
    this.selected = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: selected ? 42 : 36,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: selected ? 25 : 22,
            color: selected ? PassengerUi.title : PassengerUi.body,
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -3,
            right: -7,
            child: _NavigationBadge(count: badgeCount),
          ),
      ],
    );
  }
}

class _NavigationBadge extends StatelessWidget {
  final int count;

  const _NavigationBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PassengerUi.accentBlue,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PassengerUi.surface, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
