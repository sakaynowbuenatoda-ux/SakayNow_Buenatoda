import 'package:flutter/material.dart';
import '../../widgets/animated_tab_switcher.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../profile/profile_page.dart';
import '../settings/settings_page.dart';
import 'passenger_home.dart';
import 'passenger_messages.dart';
import 'passenger_history.dart';
import 'passenger_dashboard.dart';

class PassengerShell extends StatefulWidget {
  final String userId;
  final String firstName;
  final String passengerType;
  final bool isVerified;
  final String? profileImageUrl;

  const PassengerShell({
    super.key,
    required this.userId,
    required this.firstName,
    required this.passengerType,
    required this.isVerified,
    this.profileImageUrl,
  });

  @override
  State<PassengerShell> createState() => _PassengerShellState();
}

class _PassengerShellState extends State<PassengerShell> {
  int _currentIndex = 0;

  void _handleProfileSelected(String value) {
    if (value == 'profile') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfilePage(userId: widget.userId)),
      );
    } else if (value == 'settings') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsPage(
            role: 'passenger',
            isVerified: widget.isVerified,
            passengerType: widget.passengerType,
          ),
        ),
      );
    } else if (value == 'dashboard') {
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
    final pages = <Widget>[
      PassengerHomepage(
        userId: widget.userId,
        firstName: widget.firstName,
        passengerType: widget.passengerType,
        isVerified: widget.isVerified,
      ),
      PassengerMessages(
        userId: widget.userId,
        firstName: widget.firstName,
        passengerType: widget.passengerType,
      ),
      PassengerHistory(
        userId: widget.userId,
        firstName: widget.firstName,
        passengerType: widget.passengerType,
      ),
      PassengerDashboard(
        userId: widget.userId,
        firstName: widget.firstName,
        passengerType: widget.passengerType,
        isVerified: widget.isVerified,
      ),
    ];

    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBarWidget(
        firstName: widget.firstName,
        profileImageUrl: widget.profileImageUrl,
        isDriver: false,
        showVerifiedBadge: widget.isVerified,
        onNotificationsTap: () {},
        onProfileSelected: _handleProfileSelected,
      ),
      body: AnimatedTabSwitcher(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavWidget(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
