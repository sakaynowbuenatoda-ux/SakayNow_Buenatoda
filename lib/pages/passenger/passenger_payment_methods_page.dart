import 'package:flutter/material.dart';

import '../../models/passenger_payment_method.dart';
import '../../services/payment_method_service.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/passenger_widgets/passenger_payment_method_card.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

class PassengerPaymentMethodsPage extends StatefulWidget {
  final String userId;
  final PaymentMethodService paymentMethodService;

  PassengerPaymentMethodsPage({
    super.key,
    required this.userId,
    PaymentMethodService? paymentMethodService,
  }) : paymentMethodService = paymentMethodService ?? PaymentMethodService();

  @override
  State<PassengerPaymentMethodsPage> createState() =>
      _PassengerPaymentMethodsPageState();
}

class _PassengerPaymentMethodsPageState
    extends State<PassengerPaymentMethodsPage> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        title: Text('Payment Methods', style: PassengerUi.cardTitle),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add payment method',
            onPressed: _isSaving ? null : () => _openForm(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: PassengerPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            StreamBuilder<List<PassengerPaymentMethod>>(
              stream: widget.paymentMethodService.watchPaymentMethods(
                widget.userId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppSkeletonList(
                    itemCount: 3,
                    padding: EdgeInsets.zero,
                  );
                }

                if (snapshot.hasError) {
                  return PassengerEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Unable to load payments',
                    description:
                        'Payment methods could not be loaded. Please try again.',
                  );
                }

                final methods = snapshot.data ?? <PassengerPaymentMethod>[];
                if (methods.length <= 1) {
                  return Column(
                    children: <Widget>[
                      PassengerPaymentMethodCard(
                        method: PassengerPaymentMethod.cash(
                          userId: widget.userId,
                        ),
                      ),
                      const SizedBox(height: 12),
                      PassengerEmptyState(
                        icon: Icons.wallet_outlined,
                        title: 'No cashless methods yet',
                        description:
                            'Add GCash, Maya, or card as checkout preferences.',
                      ),
                    ],
                  );
                }

                return Column(
                  children: methods
                      .asMap()
                      .entries
                      .map(
                        (entry) => Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key == methods.length - 1 ? 0 : 12,
                          ),
                          child: PassengerPaymentMethodCard(
                            method: entry.value,
                            onEdit: () => _openForm(method: entry.value),
                            onDelete: () => _delete(entry.value),
                            onSetDefault: () => _setDefault(entry.value),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _openForm({PassengerPaymentMethod? method}) async {
    final result = await showDialog<PassengerPaymentMethod>(
      context: context,
      builder: (_) =>
          _PaymentMethodFormSheet(userId: widget.userId, initialMethod: method),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.paymentMethodService.savePaymentMethod(result);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment method saved.')));
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save payment method: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _delete(PassengerPaymentMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete payment method?'),
        content: Text(method.displayLabel),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.paymentMethodService.deletePaymentMethod(
        userId: widget.userId,
        paymentMethodId: method.id,
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete payment method: $error')),
        );
      }
    }
  }

  Future<void> _setDefault(PassengerPaymentMethod method) async {
    try {
      await widget.paymentMethodService.setDefaultPaymentMethod(
        userId: widget.userId,
        paymentMethodId: method.id,
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update default method: $error')),
        );
      }
    }
  }
}

class _PaymentMethodFormSheet extends StatefulWidget {
  final String userId;
  final PassengerPaymentMethod? initialMethod;

  const _PaymentMethodFormSheet({required this.userId, this.initialMethod});

  @override
  State<_PaymentMethodFormSheet> createState() =>
      _PaymentMethodFormSheetState();
}

class _PaymentMethodFormSheetState extends State<_PaymentMethodFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late PassengerPaymentMethodType _type;
  late final TextEditingController _labelController;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final method = widget.initialMethod;
    _type = method?.type == PassengerPaymentMethodType.cash || method == null
        ? PassengerPaymentMethodType.gcash
        : method.type;
    _labelController = TextEditingController(text: method?.displayLabel ?? '');
    _isDefault = method?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      insetAnimationDuration: const Duration(milliseconds: 180),
      insetAnimationCurve: Curves.easeOutCubic,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: PassengerUi.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PassengerUi.border),
            boxShadow: PassengerUi.cardShadow,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.initialMethod == null
                              ? 'Add Payment'
                              : 'Edit Payment',
                          style: PassengerUi.cardTitle,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PassengerPaymentMethodType>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        const <PassengerPaymentMethodType>[
                              PassengerPaymentMethodType.gcash,
                              PassengerPaymentMethodType.maya,
                              PassengerPaymentMethodType.card,
                            ]
                            .map(
                              (type) =>
                                  DropdownMenuItem<PassengerPaymentMethodType>(
                                    value: type,
                                    child: Text(type.label),
                                  ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _type = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _labelController,
                    decoration: InputDecoration(
                      labelText: 'Label',
                      hintText: _type.label,
                      border: const OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _XenditCheckoutNote(type: _type),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isDefault,
                    title: Text('Use as default', style: PassengerUi.bodyText),
                    onChanged: (value) => setState(() => _isDefault = value),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Payment'),
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

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final existing = widget.initialMethod;
    final method = PassengerPaymentMethod(
      id: existing?.id ?? '',
      userId: widget.userId,
      type: _type,
      label: _labelController.text.trim().isEmpty
          ? _type.label
          : _labelController.text.trim(),
      accountName: '',
      accountReference: 'Xendit checkout',
      isDefault: _isDefault,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
    );
    Navigator.of(context).pop(method);
  }
}

class _XenditCheckoutNote extends StatelessWidget {
  final PassengerPaymentMethodType type;

  const _XenditCheckoutNote({required this.type});

  @override
  Widget build(BuildContext context) {
    final text = type == PassengerPaymentMethodType.card
        ? 'Card number, expiry date, and CVV are entered only on Xendit checkout.'
        : '${type.label} account details are entered only on Xendit checkout.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PassengerUi.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PassengerUi.accentBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.lock_outline_rounded, color: PassengerUi.accentBlue),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: PassengerUi.bodyText)),
        ],
      ),
    );
  }
}
