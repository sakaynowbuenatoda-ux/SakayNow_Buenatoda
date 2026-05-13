import 'package:flutter/material.dart';

import '../../models/passenger_payment_method.dart';
import 'passenger_ui.dart';

class PassengerPaymentMethodCard extends StatelessWidget {
  final PassengerPaymentMethod method;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;

  const PassengerPaymentMethodCard({
    super.key,
    required this.method,
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: method.type.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(method.type.icon, color: method.type.accentColor),
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
                        method.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PassengerUi.cardTitle,
                      ),
                    ),
                    if (method.isDefault)
                      PassengerStatusChip(
                        label: 'Default',
                        textColor: PassengerUi.successText,
                        backgroundColor: PassengerUi.successBackground,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  method.accountLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.bodyText,
                ),
              ],
            ),
          ),
          if (!method.isCash)
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
                if (!method.isDefault)
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
            )
          else
            Icon(Icons.check_circle_rounded, color: PassengerUi.successText),
        ],
      ),
    );
  }
}
