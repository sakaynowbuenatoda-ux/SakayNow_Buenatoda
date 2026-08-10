import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_assets.dart';
import '../core/session/session_service.dart';
import '../utils/user_facing_error_message.dart';
import 'passenger_widgets/passenger_ui.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String firstName;
  final String? profileImageUrl;
  final VoidCallback onNotificationsTap;
  final VoidCallback? onBrandTap;
  final int notificationUnreadCount;
  final ValueChanged<String>? onProfileSelected;

  final bool isDriver;
  final bool showVerifiedBadge;

  const AppBarWidget({
    super.key,
    required this.firstName,
    this.profileImageUrl,
    required this.onNotificationsTap,
    this.onBrandTap,
    this.notificationUnreadCount = 0,
    this.onProfileSelected,
    this.isDriver = false,
    this.showVerifiedBadge = false,
  });

  Future<void> _logout(BuildContext context) async {
    try {
      await SessionService.signOut();
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              e,
              fallback: 'Unable to log out. Please try again.',
            ),
          ),
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
        title: Text('Confirm Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      if (!context.mounted) return;
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
    final compact = PassengerUi.isCompactWidth(context);

    return AppBar(
      elevation: 0,
      toolbarHeight: compact ? 64 : 72,
      backgroundColor: PassengerUi.surface,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: compact ? 12 : 16,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: PassengerUi.surface.withValues(alpha: 0.96),
          border: Border(
            bottom: BorderSide(
              color: PassengerUi.border.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
      title: _AppLogo(
        compact: compact,
        showBrandText: !isDriver,
        onTap: onBrandTap,
      ),
      actions: [
        _ModernIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: onNotificationsTap,
          compact: compact,
          count: notificationUnreadCount,
        ),
        if (!compact) _NameText(firstName: firstName),
        SizedBox(width: compact ? 6 : 10),
        _ProfileAvatarMenu(
          firstName: firstName,
          profileImageUrl: profileImageUrl,
          showVerifiedBadge: showVerifiedBadge,
          onSelected: (value) => _handleMenuAction(context, value),
          compact: compact,
        ),
        SizedBox(width: compact ? 8 : 12),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

//// ---------- INTERNAL WIDGETS BELOW ---------- ////

class _AppLogo extends StatelessWidget {
  final bool compact;
  final bool showBrandText;
  final VoidCallback? onTap;

  const _AppLogo({
    required this.compact,
    required this.showBrandText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 10,
            vertical: compact ? 6 : 8,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 8 : 10),
                child: Image.asset(
                  AppAssets.logo,
                  width: compact ? 32 : 36,
                  height: compact ? 32 : 36,
                  fit: BoxFit.cover,
                ),
              ),
              if (showBrandText) ...[
                SizedBox(width: compact ? 6 : 8),
                Text(
                  'SakayNow',
                  style: GoogleFonts.poppins(
                    color: PassengerUi.primary,
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
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
          style: GoogleFonts.poppins(
            color: PassengerUi.title,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ModernIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  final int count;

  const _ModernIconButton({
    required this.icon,
    required this.onTap,
    required this.compact,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = count > 0;

    return Padding(
      padding: EdgeInsets.only(right: compact ? 4 : 8),
      child: Material(
        color: PassengerUi.mutedSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: compact ? 38 : 42,
            height: compact ? 38 : 42,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: PassengerUi.accentBlue,
                  size: compact ? 20 : 22,
                ),
                if (hasUnread)
                  Positioned(
                    top: compact ? 7 : 8,
                    right: compact ? 7 : 8,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: PassengerUi.primary,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: PassengerUi.surface,
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style: TextStyle(
                          color: PassengerUi.onPrimary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatarMenu extends StatelessWidget {
  final String firstName;
  final String? profileImageUrl;
  final bool showVerifiedBadge;
  final ValueChanged<String> onSelected;
  final bool compact;

  const _ProfileAvatarMenu({
    required this.firstName,
    required this.profileImageUrl,
    required this.showVerifiedBadge,
    required this.onSelected,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
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
            leading: Icon(Icons.logout_rounded, color: PassengerUi.primary),
            title: Text('Logout', style: TextStyle(color: PassengerUi.primary)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            margin: EdgeInsets.only(right: compact ? 2 : 4),
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: PassengerUi.primary.withValues(alpha: 0.22),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: compact ? 16 : 18,
              backgroundColor: PassengerUi.primary.withValues(alpha: 0.10),
              child: ClipOval(
                child: _StableProfileAvatarImage(
                  imageUrl: profileImageUrl,
                  width: compact ? 32 : 36,
                  height: compact ? 32 : 36,
                  fallback: _AvatarFallback(initial: initial),
                ),
              ),
            ),
          ),
          if (showVerifiedBadge)
            Positioned(
              right: compact ? -2 : 0,
              bottom: -1,
              child: Container(
                width: compact ? 14 : 16,
                height: compact ? 14 : 16,
                decoration: BoxDecoration(
                  color: PassengerUi.successText,
                  shape: BoxShape.circle,
                  border: Border.all(color: PassengerUi.surface, width: 2),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: compact ? 9 : 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StableProfileAvatarImage extends StatefulWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final Widget fallback;

  const _StableProfileAvatarImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fallback,
  });

  @override
  State<_StableProfileAvatarImage> createState() =>
      _StableProfileAvatarImageState();
}

class _StableProfileAvatarImageState extends State<_StableProfileAvatarImage> {
  String? _source;
  Future<String>? _downloadUrlFuture;

  @override
  void initState() {
    super.initState();
    _updateSource();
  }

  @override
  void didUpdateWidget(covariant _StableProfileAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.imageUrl != widget.imageUrl) {
      _updateSource();
    }
  }

  void _updateSource() {
    final nextSource = widget.imageUrl?.trim();
    if (nextSource == null || nextSource.isEmpty || nextSource == 'null') {
      _source = null;
      _downloadUrlFuture = null;
      return;
    }

    _source = nextSource;
    _downloadUrlFuture = _downloadUrlFor(nextSource);
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final downloadUrlFuture = _downloadUrlFuture;

    if (source == null || downloadUrlFuture == null) {
      return widget.fallback;
    }

    return FutureBuilder<String>(
      future: downloadUrlFuture,
      builder: (context, snapshot) {
        final resolvedUrl = snapshot.data;
        if (resolvedUrl == null || resolvedUrl.isEmpty || snapshot.hasError) {
          return widget.fallback;
        }

        return Image.network(
          resolvedUrl,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (context, error, stackTrace) => widget.fallback,
        );
      },
    );
  }

  static Future<String> _downloadUrlFor(String source) async {
    if (_isNetworkUrl(source)) {
      return source;
    }

    if (source.startsWith('gs://')) {
      return FirebaseStorage.instance.refFromURL(source).getDownloadURL();
    }

    if (_isLikelyStoragePath(source)) {
      return FirebaseStorage.instance.ref(source).getDownloadURL();
    }

    return source;
  }

  static bool _isNetworkUrl(String value) {
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:');
  }

  static bool _isLikelyStoragePath(String value) {
    return !value.startsWith('gs://') && !_isNetworkUrl(value);
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initial;

  const _AvatarFallback({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(color: PassengerUi.title, fontWeight: FontWeight.bold),
      ),
    );
  }
}
