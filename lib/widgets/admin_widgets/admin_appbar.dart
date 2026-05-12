import 'package:flutter/material.dart';
import '../../config/app_assets.dart';
import '../passenger_widgets/passenger_ui.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String adminName;
  final String appName;
  final String? logoAssetPath;
  final VoidCallback onMenuTap;
  final VoidCallback onProfileSettingsTap;
  final Future<void> Function(BuildContext context) onLogout;

  const AdminAppBar({
    super.key,
    required this.adminName,
    required this.appName,
    required this.onMenuTap,
    required this.onProfileSettingsTap,
    required this.onLogout,
    this.logoAssetPath = AppAssets.logo,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Icon(Icons.logout_rounded, size: 22),
              SizedBox(width: 8),
              Text('Confirm Logout'),
            ],
          ),
          content: Text(
            'Are you sure you want to log out of your admin account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      if (!context.mounted) return;
      await onLogout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: PassengerUi.surface,
      surfaceTintColor: PassengerUi.surface,
      toolbarHeight: 72,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            IconButton(
              onPressed: onMenuTap,
              icon: Icon(
                Icons.menu_rounded,
                color: PassengerUi.title,
                size: 28,
              ),
              tooltip: 'Open menu',
            ),
            SizedBox(width: 4),

            // Logo
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: PassengerUi.mutedSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: logoAssetPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(logoAssetPath!, fit: BoxFit.cover),
                    )
                  : Icon(
                      Icons.directions_bus_rounded,
                      color: PassengerUi.primary,
                      size: 24,
                    ),
            ),

            SizedBox(width: 10),

            // App name
            Expanded(
              child: Text(
                appName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: PassengerUi.title,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: PopupMenuButton<String>(
            offset: Offset(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) async {
              if (value == 'settings') {
                onProfileSettingsTap();
              } else if (value == 'logout') {
                await _showLogoutConfirmation(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Account Settings'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: PassengerUi.primary,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: TextStyle(color: PassengerUi.primary),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: PassengerUi.mutedSurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: PassengerUi.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: PassengerUi.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Text(
                      adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                      style: TextStyle(
                        color: PassengerUi.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 120),
                    child: Text(
                      adminName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PassengerUi.title,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: PassengerUi.accentBlue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
