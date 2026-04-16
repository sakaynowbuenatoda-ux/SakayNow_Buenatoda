import 'package:flutter/material.dart';
import '../../widgets/admin_widgets/admin_appbar.dart';
import '../../core/session/session_service.dart';

class AdminHomePage extends StatelessWidget {
  final String userId;
  final String firstName;
  
  const AdminHomePage({super.key, required this.userId, required this.firstName});
  

  Future<void> _handleLogout(BuildContext context) async {
    await SessionService.signOut();
  }

  void _openProfileSettings(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile settings tapped')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdminAppBar(
        adminName: 'Admin',
        appName: 'SakayNow',
        onMenuTap: () {
          Scaffold.of(context).openDrawer();
        },
        onProfileSettingsTap: () => _openProfileSettings(context),
        onLogout: _handleLogout,
      ),
      drawer: const Drawer(
        child: Center(child: Text('Admin Sidebar')),
      ),
      body: const Center(
        child: Text('Admin Dashboard'),
      ),
    );
  }
}
