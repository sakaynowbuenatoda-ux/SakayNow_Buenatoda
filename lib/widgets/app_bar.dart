import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/session/session_service.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String firstName;
  final VoidCallback onNotificationsTap;
  final ValueChanged<String>? onProfileSelected;

  final bool isDriver;
  final bool isActive;
  final ValueChanged<bool>? onStatusChanged;

  const AppBarWidget({
    super.key,
    required this.firstName,
    required this.onNotificationsTap,
    this.onProfileSelected,
    this.isDriver = false,
    this.isActive = false,
    this.onStatusChanged,
  });

  Future<void> _logout(BuildContext context) async {
    try {
      await SessionService.signOut();
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  //logout confiurmation dialog
  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _logout(context);
    }
  }

  void _handleMenuAction(BuildContext context, String value) {
    if (value == 'logout') {
      _showLogoutConfirmation(context);
    } else {
      onProfileSelected?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      toolbarHeight: 72,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 255, 255, 255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: const _AppLogo(),
      actions: [
        if (isDriver)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: _ActiveStatusToggle(
              value: isActive,
              onChanged: onStatusChanged ?? (_) {},
            ),
          ),
         _ModernIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: onNotificationsTap,
        ),
        _NameText(firstName: firstName),
        const SizedBox(width: 10),
        _ProfileAvatarMenu(
          firstName: firstName,
          onSelected: (value) => _handleMenuAction(context, value),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

//// ---------- INTERNAL WIDGETS BELOW ---------- ////

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.local_taxi_rounded,
            color: Color.fromARGB(255, 1, 96, 154),
          ),
          SizedBox(width: 8),
          Text(
            'SakayNow',
            style: GoogleFonts.luckiestGuy(
              color: const Color.fromARGB(255, 1, 96, 154),
            //  fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _NameText extends StatelessWidget {
  final String firstName;

  const _NameText({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstName.isNotEmpty ? firstName : 'User',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.archivoBlack(
            color: Color.fromARGB(255, 0, 0, 0),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ModernIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ModernIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              color: const Color.fromARGB(255, 0, 0, 0),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatarMenu extends StatelessWidget {
  final String firstName;
  final ValueChanged<String> onSelected;

  const _ProfileAvatarMenu({
    required this.firstName,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.person_outline_rounded),
            title: Text('Profile'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.75),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white,
          child: Text(
            initial,
            style: const TextStyle(
              color: Color.fromARGB(255, 0, 0, 0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveStatusToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ActiveStatusToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: value ? Colors.greenAccent : Colors.white54,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value ? 'Active' : 'Offline',
            style: const TextStyle(
              color: Color.fromARGB(255, 0, 0, 0),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color.fromARGB(255, 255, 255, 255),
              activeTrackColor: Colors.greenAccent.withOpacity(0.7),
              inactiveThumbColor: const Color.fromARGB(255, 132, 91, 91),
              inactiveTrackColor: Colors.white38,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
