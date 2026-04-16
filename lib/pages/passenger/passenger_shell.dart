import 'package:flutter/material.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/bottom_nav.dart';
import 'passenger_home.dart';
import 'passenger_messages.dart';
import 'passenger_history.dart';
import 'passenger_dashboard.dart';

class PassengerShell extends StatefulWidget {
  final String userId;
  final String firstName;
  final String role;

  const PassengerShell({
    super.key,
    required this.userId,
    required this.firstName,
    required this.role,
  });

  @override
  State<PassengerShell> createState() => _PassengerShellState();
}

class _PassengerShellState extends State<PassengerShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      PassengerHomepage(
        userId: widget.userId,
        firstName: widget.firstName,
        role: widget.role,
      ),
      PassengerMessages(
        userId: widget.userId,
        firstName: widget.firstName,
        role: widget.role,
      ),
      PassengerHistory(
        userId: widget.userId,
        firstName: widget.firstName,
        role: widget.role,
      ),
      PassengerDashboard(
        userId: widget.userId,
        firstName: widget.firstName,
        role: widget.role,
      ),
    ];
  }

  void _handleProfileSelected(String value) {
    if (value == 'dashboard') {
      setState(() => _currentIndex = 3);
    } else if (value == 'home') {
      setState(() => _currentIndex = 0);
    } else if (value == 'messages') {
      setState(() => _currentIndex = 1);
    } else if (value == 'history') {
      setState(() => _currentIndex = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FBFF),
      appBar: AppBarWidget(
        firstName: widget.firstName,
        isDriver: false,
        onNotificationsTap: () {},
        onProfileSelected: _handleProfileSelected,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavWidget(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
