import 'package:flutter/material.dart';

import '../../../widgets/passenger_widgets/passenger_ui.dart';

class SettingsSectionCard extends StatelessWidget {
  final String? title;
  final List<SettingsTileData> items;

  const SettingsSectionCard({super.key, this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null && title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Text(title!, style: PassengerUi.cardTitle),
            ),
          ...items.asMap().entries.map(
            (entry) => Column(
              children: <Widget>[
                SettingsListTile(item: entry.value),
                if (entry.key != items.length - 1)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Divider(height: 1, color: PassengerUi.border),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsListTile extends StatelessWidget {
  final SettingsTileData item;

  const SettingsListTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final enabled = item.isEnabled && item.onTap != null;
    final accentColor = enabled ? item.accentColor : PassengerUi.body;

    return Opacity(
      opacity: enabled ? 1 : 0.78,
      child: InkWell(
        onTap: enabled ? item.onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 18,
            vertical: compact ? 12 : 14,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: compact ? 40 : 42,
                height: compact ? 40 : 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: accentColor, size: 22),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: PassengerUi.valueText.copyWith(
                        fontSize: compact ? 14 : 14.5,
                        color: enabled ? PassengerUi.title : PassengerUi.body,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (item.statusLabel != null && item.statusLabel!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _SettingsStatusBadge(
                        label: item.statusLabel!,
                        enabled: enabled,
                      ),
                    ),
                  Icon(
                    enabled ? Icons.chevron_right_rounded : Icons.lock_rounded,
                    color: enabled ? PassengerUi.accentBlue : PassengerUi.body,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsTileData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isEnabled;
  final String? statusLabel;

  SettingsTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.onTap,
    this.isEnabled = true,
    this.statusLabel,
  });
}

class _SettingsStatusBadge extends StatelessWidget {
  final String label;
  final bool enabled;

  const _SettingsStatusBadge({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = enabled
        ? PassengerUi.successBackground
        : PassengerUi.warningSoft;
    final foregroundColor = enabled
        ? PassengerUi.successText
        : PassengerUi.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: PassengerUi.bodyText.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
          height: 1,
        ),
      ),
    );
  }
}
