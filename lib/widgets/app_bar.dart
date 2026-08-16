import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_assets.dart';
import 'passenger_widgets/passenger_ui.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String firstName;
  final String? profileImageUrl;
  final VoidCallback? onLeaderboardTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback? onBrandTap;
  final int notificationUnreadCount;
  final VoidCallback? onProfileTap;

  final bool isDriver;
  final bool showVerifiedBadge;

  const AppBarWidget({
    super.key,
    required this.firstName,
    this.profileImageUrl,
    this.onLeaderboardTap,
    required this.onNotificationsTap,
    this.onBrandTap,
    this.notificationUnreadCount = 0,
    this.onProfileTap,
    this.isDriver = false,
    this.showVerifiedBadge = false,
  });

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
        if (onLeaderboardTap != null)
          _LeaderboardIconButton(onTap: onLeaderboardTap!, compact: compact),
        _ModernIconButton(
          onTap: onNotificationsTap,
          compact: compact,
          count: notificationUnreadCount,
        ),
        if (!compact) _NameText(firstName: firstName),
        SizedBox(width: compact ? 6 : 10),
        _ProfileAvatarButton(
          firstName: firstName,
          profileImageUrl: profileImageUrl,
          showVerifiedBadge: showVerifiedBadge,
          onTap: onProfileTap,
          compact: compact,
        ),
        SizedBox(width: compact ? 8 : 12),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

class HomeMapHeader extends StatelessWidget {
  final String firstName;
  final String? profileImageUrl;
  final String greeting;
  final VoidCallback? onLeaderboardTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback? onBrandTap;
  final int notificationUnreadCount;
  final VoidCallback? onProfileTap;
  final bool isDriver;
  final bool showVerifiedBadge;

  const HomeMapHeader({
    super.key,
    required this.firstName,
    this.profileImageUrl,
    required this.greeting,
    this.onLeaderboardTap,
    required this.onNotificationsTap,
    this.onBrandTap,
    this.notificationUnreadCount = 0,
    this.onProfileTap,
    this.isDriver = false,
    this.showVerifiedBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final edgePadding = compact ? 6.0 : 8.0;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(edgePadding, 4, edgePadding, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: compact ? 46 : 50,
              child: Row(
                children: <Widget>[
                  _AppLogo(
                    compact: true,
                    showBrandText: !isDriver,
                    onTap: onBrandTap,
                  ),
                  const Spacer(),
                  if (onLeaderboardTap != null)
                    _LeaderboardIconButton(
                      onTap: onLeaderboardTap!,
                      compact: true,
                    ),
                  _ModernIconButton(
                    onTap: onNotificationsTap,
                    compact: true,
                    count: notificationUnreadCount,
                  ),
                  const SizedBox(width: 5),
                  _ProfileAvatarButton(
                    firstName: firstName,
                    profileImageUrl: profileImageUrl,
                    showVerifiedBadge: showVerifiedBadge,
                    onTap: onProfileTap,
                    compact: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 3 : 5,
                  vertical: 4,
                ),
                child: Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.archivoBlack(
                    color: Colors.white,
                    fontSize: compact ? 20 : 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.35,
                    height: 1,
                    shadows: <Shadow>[
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.48),
                        blurRadius: 9,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 3 : 10,
            vertical: compact ? 3 : 8,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 9 : 10),
                child: Image.asset(
                  AppAssets.logo,
                  width: compact ? 28 : 36,
                  height: compact ? 28 : 36,
                  fit: BoxFit.cover,
                ),
              ),
              if (showBrandText) ...[
                SizedBox(width: compact ? 5 : 8),
                Text(
                  'SakayNow',
                  style: GoogleFonts.poppins(
                    color: PassengerUi.primary,
                    fontSize: compact ? 15 : 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    shadows: <Shadow>[
                      Shadow(
                        color: PassengerUi.surface.withValues(alpha: 0.85),
                        blurRadius: 7,
                      ),
                    ],
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

class _LeaderboardIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;

  const _LeaderboardIconButton({required this.onTap, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: compact ? 3 : 8),
      child: Tooltip(
        message: 'Open leaderboard',
        child: Semantics(
          button: true,
          label: 'Open leaderboard',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('home-leaderboard-button'),
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: compact ? 34 : 42,
                height: compact ? 34 : 42,
                child: Icon(
                  Icons.leaderboard_rounded,
                  size: compact ? 22 : 26,
                  color: PassengerUi.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  final int count;

  const _ModernIconButton({
    required this.onTap,
    required this.compact,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = count > 0;

    return Padding(
      padding: EdgeInsets.only(right: compact ? 3 : 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: compact ? 34 : 42,
              height: compact ? 34 : 42,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Text(
                    '🔔',
                    style: TextStyle(fontSize: compact ? 24 : 28, height: 1),
                  ),
                  if (hasUnread)
                    Positioned(
                      top: compact ? 4 : 8,
                      right: compact ? 4 : 8,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
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
                            fontSize: 8,
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
      ),
    );
  }
}

class _ProfileAvatarButton extends StatelessWidget {
  final String firstName;
  final String? profileImageUrl;
  final bool showVerifiedBadge;
  final VoidCallback? onTap;
  final bool compact;

  const _ProfileAvatarButton({
    required this.firstName,
    required this.profileImageUrl,
    required this.showVerifiedBadge,
    required this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Tooltip(
      message: 'Open profile',
      child: Semantics(
        button: true,
        label: 'Open profile',
        child: InkWell(
          key: const Key('home-profile-avatar-button'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(right: compact ? 1 : 4),
                padding: EdgeInsets.all(compact ? 2 : 2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PassengerUi.surface.withValues(alpha: 0.9),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: compact ? 14 : 18,
                  backgroundColor: PassengerUi.surface.withValues(alpha: 0.76),
                  child: ClipOval(
                    child: _StableProfileAvatarImage(
                      imageUrl: profileImageUrl,
                      width: compact ? 28 : 36,
                      height: compact ? 28 : 36,
                      fallback: _AvatarFallback(initial: initial),
                    ),
                  ),
                ),
              ),
              if (showVerifiedBadge)
                Positioned(
                  right: compact ? -3 : 0,
                  bottom: -1,
                  child: Container(
                    width: compact ? 13 : 16,
                    height: compact ? 13 : 16,
                    decoration: BoxDecoration(
                      color: PassengerUi.successText,
                      shape: BoxShape.circle,
                      border: Border.all(color: PassengerUi.surface, width: 2),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: compact ? 8 : 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
