import 'package:flutter/material.dart';

import 'passenger_widgets/passenger_ui.dart';

class BottomNavWidget extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDriver;
  final int messageUnreadCount;
  final VoidCallback? onBookTap;
  final bool isDriverActive;
  final VoidCallback? onDriverAvailabilityTap;

  const BottomNavWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isDriver = false,
    this.messageUnreadCount = 0,
    this.onBookTap,
    this.isDriverActive = false,
    this.onDriverAvailabilityTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final deviceBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final minimumBottomMargin = compact ? 8.0 : 12.0;
    final bottomMargin = deviceBottomInset > minimumBottomMargin
        ? deviceBottomInset
        : minimumBottomMargin;
    final horizontalMargin = compact ? 10.0 : 16.0;
    const messageIndex = 1;
    final visibleMessageUnreadCount = currentIndex == messageIndex
        ? 0
        : messageUnreadCount;
    final selectedNavigationIndex = currentIndex < 2
        ? currentIndex
        : currentIndex + 1;

    final floatingShape = _CenteredFloatingBarShape(
      cornerRadius: compact ? 20 : 24,
      hasNotch: true,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalMargin,
        0,
        horizontalMargin,
        bottomMargin,
      ),
      child: BottomAppBar(
        color: PassengerUi.surface,
        surfaceTintColor: Colors.transparent,
        elevation: PassengerUi.isDarkMode ? 20 : 14,
        shadowColor: Colors.black.withValues(
          alpha: PassengerUi.isDarkMode ? 0.56 : 0.22,
        ),
        padding: EdgeInsets.zero,
        shape: floatingShape,
        notchMargin: 9,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: compact ? 62 : 66,
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: BottomNavigationBar(
              currentIndex: selectedNavigationIndex,
              onTap: (index) {
                if (index == 2) {
                  if (isDriver) {
                    onDriverAvailabilityTap?.call();
                  } else {
                    onBookTap?.call();
                  }
                  return;
                }

                onTap(index > 2 ? index - 1 : index);
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: PassengerUi.primary,
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
                      isActive: isDriverActive,
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
        label: 'Book Now',
        tooltip: 'Book a ride',
      ),
      _destination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
      ),
      _destination(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];
  }

  List<BottomNavigationBarItem> _driverDestinations({
    required int messageUnreadCount,
    required bool isActive,
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
      BottomNavigationBarItem(
        icon: const SizedBox(width: 42, height: 30),
        label: isActive ? 'Go Offline' : 'Go Active',
        tooltip: isActive ? 'Go offline' : 'Go active',
      ),
      _destination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
      ),
      _destination(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
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

class _CenteredFloatingBarShape extends NotchedShape {
  final double cornerRadius;
  final bool hasNotch;

  const _CenteredFloatingBarShape({
    required this.cornerRadius,
    required this.hasNotch,
  });

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    final roundedHost = Path()
      ..addRRect(RRect.fromRectAndRadius(host, Radius.circular(cornerRadius)));

    if (!hasNotch || guest == null || !host.overlaps(guest)) {
      return roundedHost;
    }

    final centeredGuest = Rect.fromCenter(
      center: Offset(host.center.dx, guest.center.dy),
      width: guest.width,
      height: guest.height,
    );
    final smoothlyNotchedHost = const CircularNotchedRectangle().getOuterPath(
      host,
      centeredGuest,
    );

    return Path.combine(
      PathOperation.intersect,
      roundedHost,
      smoothlyNotchedHost,
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
              child: const Center(
                child: Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DriverAvailabilityButton extends StatelessWidget {
  final bool isActive;
  final bool isLoading;
  final VoidCallback onPressed;

  const DriverAvailabilityButton({
    super.key,
    required this.isActive,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final diameter = compact ? 64.0 : 68.0;
    final actionColor = isActive ? PassengerUi.secondary : PassengerUi.dark;
    final actionLabel = isActive ? 'Go offline' : 'Go active';

    return Tooltip(
      message: actionLabel,
      child: Semantics(
        button: true,
        toggled: isActive,
        label: actionLabel,
        excludeSemantics: true,
        child: Container(
          width: diameter,
          height: diameter,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: PassengerUi.surface,
            shape: BoxShape.circle,
            border: Border.all(color: actionColor, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: actionColor.withValues(alpha: 0.25),
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
            color: actionColor,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isLoading ? null : onPressed,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.power_settings_new_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
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
          width: selected ? 38 : 36,
          height: 30,
          decoration: BoxDecoration(
            color: selected ? PassengerUi.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: PassengerUi.primary.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: selected ? 21 : 22,
            color: selected ? PassengerUi.onPrimary : PassengerUi.body,
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
