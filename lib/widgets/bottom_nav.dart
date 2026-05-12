import 'package:flutter/material.dart';
import 'passenger_widgets/passenger_ui.dart';

class BottomNavWidget extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDriver;

  const BottomNavWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isDriver = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 390;

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
                ? const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.list_alt_outlined),
                      selectedIcon: Icon(Icons.list_alt_rounded),
                      label: 'Queue',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline_rounded),
                      selectedIcon: Icon(Icons.chat_bubble_rounded),
                      label: 'Messages',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_rounded),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: 'History',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: 'Dashboard',
                    ),
                  ]
                : const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline_rounded),
                      selectedIcon: Icon(Icons.chat_bubble_rounded),
                      label: 'Messages',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_rounded),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: 'History',
                    ),
                    NavigationDestination(
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
