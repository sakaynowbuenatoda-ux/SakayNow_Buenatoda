import 'package:flutter/material.dart';

import '../../models/driver_payout_account.dart';
import '../passenger_widgets/passenger_ui.dart';

class DriverPayoutAccountCard extends StatelessWidget {
  final DriverPayoutAccount account;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;

  const DriverPayoutAccountCard({
    super.key,
    required this.account,
    this.onEdit,
    this.onDelete,
    this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 48,
            height: 48,
            child: Icon(account.type.icon, color: PassengerUi.dark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        account.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PassengerUi.cardTitle,
                      ),
                    ),
                    if (account.isDefault)
                      PassengerStatusChip(
                        label: 'Default',
                        textColor: PassengerUi.successText,
                        backgroundColor: PassengerUi.successBackground,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  account.accountLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.bodyText,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: PassengerUi.body),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit?.call();
              } else if (value == 'delete') {
                onDelete?.call();
              } else if (value == 'default') {
                onSetDefault?.call();
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              if (!account.isDefault)
                const PopupMenuItem<String>(
                  value: 'default',
                  child: Text('Set default'),
                ),
              const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
