import 'package:flutter/material.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/bottom_nav.dart';
import 'driver_dashboard.dart';
import 'driver_history.dart';
import 'driver_home.dart';
import 'driver_messages.dart';
import 'driver_queue.dart';

class DriverShell extends StatefulWidget {
  final String userId;
  final String firstName;

  const DriverShell({super.key, required this.userId, required this.firstName});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _currentIndex = 0;
  bool isActive = false;

  void _handleProfileSelected(String value) {
    if (value == 'home') {
      setState(() => _currentIndex = 0);
    } else if (value == 'messages') {
      setState(() => _currentIndex = 2);
    } else if (value == 'history') {
      setState(() => _currentIndex = 3);
    } else if (value == 'dashboard') {
      setState(() => _currentIndex = 4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FBFF),
      appBar: AppBarWidget(
        firstName: widget.firstName,
        isDriver: true,
        isActive: isActive,
        onStatusChanged: (val) {
          setState(() => isActive = val);
        },
        onNotificationsTap: () {},
        onProfileSelected: _handleProfileSelected,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: <Widget>[
          DriverHomePage(
            userId: widget.userId,
            firstName: widget.firstName,
            isActive: isActive,
          ),
          const DriverQueuePage(),
          const DriverMessagesPage(),
          const DriverHistoryPage(),
          const DriverDashboardPage(),
        ],
      ),
      bottomNavigationBar: BottomNavWidget(
        currentIndex: _currentIndex,
        isDriver: true,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
