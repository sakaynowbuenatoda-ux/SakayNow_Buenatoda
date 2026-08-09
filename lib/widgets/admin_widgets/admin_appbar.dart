import 'package:flutter/material.dart';
import '../../config/app_assets.dart';
import '../../pages/admin/widgets/admin_ui.dart';
import '../firebase_storage_image.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String adminName;
  final String roleLabel;
  final String appName;
  final String? profileImageUrl;
  final String? logoAssetPath;
  final VoidCallback onMenuTap;
  final VoidCallback? onBrandTap;
  final bool showMenuButton;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final int notificationUnreadCount;

  const AdminAppBar({
    super.key,
    required this.adminName,
    this.roleLabel = 'Admin',
    required this.appName,
    this.profileImageUrl,
    required this.onMenuTap,
    this.onBrandTap,
    this.showMenuButton = true,
    this.onNotificationsTap,
    this.onProfileTap,
    this.notificationUnreadCount = 0,
    this.logoAssetPath = AppAssets.logo,
  });

  @override
  Size get preferredSize => const Size.fromHeight(AdminUi.appBarHeight + 1);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final appBarForeground = AdminUi.isDarkMode ? AdminUi.title : Colors.black;

    return AppBar(
      automaticallyImplyLeading: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: AdminUi.border),
      ),
      elevation: 0,
      backgroundColor: AdminUi.surface,
      surfaceTintColor: AdminUi.surface,
      toolbarHeight: AdminUi.appBarHeight,
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.only(left: showMenuButton ? 10 : 24, right: 10),
        child: Row(
          children: [
            if (showMenuButton) ...[
              IconButton(
                onPressed: onMenuTap,
                icon: Icon(Icons.menu_rounded, color: AdminUi.title, size: 24),
                tooltip: 'Open menu',
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onBrandTap,
                  borderRadius: AdminUi.radius,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: AdminUi.mutedSurface,
                            borderRadius: AdminUi.radius,
                            border: Border.all(color: AdminUi.strongBorder),
                          ),
                          child: logoAssetPath != null
                              ? ClipRRect(
                                  borderRadius: AdminUi.radius,
                                  child: Image.asset(
                                    logoAssetPath!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.directions_bus_rounded,
                                  color: AdminUi.primary,
                                  size: 20,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            appName,
                            overflow: TextOverflow.ellipsis,
                            style: AdminUi.cardTitle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (onNotificationsTap != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _AdminNotificationButton(
              count: notificationUnreadCount,
              onTap: onNotificationsTap!,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onProfileTap,
              borderRadius: AdminUi.radius,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AdminUi.strongBorder),
                          ),
                          child: ClipOval(
                            child: FirebaseStorageImage(
                              imageUrl: profileImageUrl,
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                              fallback: CircleAvatar(
                                radius: 17,
                                backgroundColor: AdminUi.mutedSurface,
                                child: Text(
                                  adminName.isNotEmpty
                                      ? adminName[0].toUpperCase()
                                      : 'A',
                                  style: TextStyle(
                                    color: appBarForeground,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AdminUi.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AdminUi.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: compact ? 92 : 132),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adminName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdminUi.bodyText.copyWith(
                              color: appBarForeground,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 2),
                            Text(
                              roleLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AdminUi.labelText.copyWith(
                                color: appBarForeground.withValues(alpha: 0.60),
                                fontSize: 10.5,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminNotificationButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _AdminNotificationButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = count > 0;
    final iconColor = AdminUi.isDarkMode ? AdminUi.title : Colors.black;

    return Material(
      color: AdminUi.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AdminUi.radius,
        side: BorderSide(color: AdminUi.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AdminUi.radius,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_rounded, color: iconColor, size: 21),
              if (hasUnread)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 15,
                      minHeight: 15,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AdminUi.primary,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AdminUi.surface, width: 1.4),
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ).copyWith(color: AdminUi.onPrimary),
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
