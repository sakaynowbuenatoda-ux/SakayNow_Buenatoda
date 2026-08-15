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
          ...items.map((item) => SettingsListTile(item: item)),
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
              SizedBox(
                width: compact ? 40 : 42,
                height: compact ? 40 : 42,
                child: Icon(
                  item.icon,
                  color: enabled ? PassengerUi.dark : PassengerUi.body,
                  size: 22,
                ),
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
              if (item.statusLabel != null && item.statusLabel!.isNotEmpty) ...[
                const SizedBox(width: 10),
                _SettingsStatusBadge(
                  label: item.statusLabel!,
                  enabled: enabled,
                ),
              ],
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
