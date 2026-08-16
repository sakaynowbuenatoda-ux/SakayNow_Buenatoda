import 'package:flutter/material.dart';

import '../../models/passenger_payment_method.dart';
import 'passenger_ui.dart';

class PassengerPaymentMethodCard extends StatelessWidget {
  final PassengerPaymentMethod method;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;
  final bool embedded;

  const PassengerPaymentMethodCard({
    super.key,
    required this.method,
    this.onEdit,
    this.onDelete,
    this.onSetDefault,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: <Widget>[
        SizedBox(
          width: embedded ? 36 : 48,
          height: embedded ? 36 : 48,
          child: Icon(
            method.type.icon,
            size: embedded ? 19 : null,
            color: PassengerUi.icon,
          ),
        ),
        SizedBox(width: embedded ? 12 : 14),
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
                      style: embedded
                          ? PassengerUi.cardTitle.copyWith(fontSize: 14.5)
                          : PassengerUi.cardTitle,
                    ),
                  ),
                  if (method.isDefault && !embedded)
                    PassengerStatusChip(
                      label: 'Default',
                      textColor: PassengerUi.successText,
                      backgroundColor: PassengerUi.successBackground,
                    ),
                ],
              ),
              SizedBox(height: embedded ? 2 : 4),
              Text(
                method.accountLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: embedded
                    ? PassengerUi.bodyText.copyWith(fontSize: 12)
                    : PassengerUi.bodyText,
              ),
            ],
          ),
        ),
        if (embedded && method.isDefault) ...<Widget>[
          const SizedBox(width: 8),
          Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: PassengerUi.successText,
          ),
        ] else if (!method.isCash) ...<Widget>[
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: PassengerUi.body),
            iconSize: embedded ? 20 : 24,
            padding: embedded ? EdgeInsets.zero : const EdgeInsets.all(8),
            constraints: embedded
                ? const BoxConstraints.tightFor(width: 36, height: 36)
                : null,
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
          ),
        ] else ...<Widget>[
          const SizedBox(width: 8),
          Icon(
            Icons.check_circle_rounded,
            size: embedded ? 20 : 24,
            color: PassengerUi.successText,
          ),
        ],
      ],
    );

    if (embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: content,
      );
    }

    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }
}
