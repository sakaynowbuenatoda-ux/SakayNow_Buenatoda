import 'package:flutter/material.dart';
import '../../widgets/animated_tab_switcher.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../services/location_service.dart';
import '../../services/ride_tracking_service.dart';
import '../profile/profile_page.dart';
import '../settings/settings_page.dart';
import 'driver_dashboard.dart';
import 'driver_history.dart';
import 'driver_home.dart';
import 'driver_messages.dart';
import 'driver_queue.dart';

class DriverShell extends StatefulWidget {
  final String userId;
  final String firstName;
  final bool isVerified;
  final String? profileImageUrl;

  const DriverShell({
    super.key,
    required this.userId,
    required this.firstName,
    required this.isVerified,
    this.profileImageUrl,
  });

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _currentIndex = 0;
  bool isActive = false;
  final RideTrackingService _rideTrackingService = RideTrackingService();
  final LocationService _locationService = const LocationService();

  void _handleProfileSelected(String value) {
    if (value == 'profile') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfilePage(userId: widget.userId)),
      );
    } else if (value == 'settings') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsPage(
            userId: widget.userId,
            role: 'driver',
            isVerified: widget.isVerified,
          ),
        ),
      );
    } else if (value == 'home') {
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
      backgroundColor: PassengerUi.background,
      appBar: AppBarWidget(
        firstName: widget.firstName,
        profileImageUrl: widget.profileImageUrl,
        isDriver: true,
        showVerifiedBadge: widget.isVerified,
        isActive: isActive,
        onStatusChanged: _handleAvailabilityChanged,
        onNotificationsTap: () {},
        onProfileSelected: _handleProfileSelected,
      ),
      body: AnimatedTabSwitcher(
        index: _currentIndex,
        children: <Widget>[
          DriverHomePage(
            userId: widget.userId,
            firstName: widget.firstName,
            isActive: isActive,
            isVerified: widget.isVerified,
            onOpenQueue: () => setState(() => _currentIndex = 1),
          ),
          DriverQueuePage(
            driverId: widget.userId,
            isVerified: widget.isVerified,
          ),
          DriverMessagesPage(),
          DriverHistoryPage(driverId: widget.userId),
          DriverDashboardPage(isVerified: widget.isVerified),
        ],
      ),
      bottomNavigationBar: BottomNavWidget(
        currentIndex: _currentIndex,
        isDriver: true,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  Future<void> _handleAvailabilityChanged(bool value) async {
    if (value && !widget.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin verification is required before going active.'),
        ),
      );
      return;
    }

    setState(() => isActive = value);

    try {
      if (value) {
        final position = await _locationService.getCurrentPosition();
        await _rideTrackingService.updateDriverLocation(
          driverId: widget.userId,
          position: position,
        );
      } else {
        await _rideTrackingService.updateDriverAvailability(
          driverId: widget.userId,
          isAvailable: false,
        );
      }
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => isActive = !value);
    }
  }
}
