import 'package:flutter/material.dart';

import '../../models/driver_payout_account.dart';
import '../../services/driver_payout_account_service.dart';
import '../../widgets/driver_widgets/driver_payout_account_card.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

class DriverPayoutAccountsPage extends StatefulWidget {
  final String driverId;
  final DriverPayoutAccountService payoutAccountService;

  DriverPayoutAccountsPage({
    super.key,
    required this.driverId,
    DriverPayoutAccountService? payoutAccountService,
  }) : payoutAccountService =
           payoutAccountService ?? DriverPayoutAccountService();

  @override
  State<DriverPayoutAccountsPage> createState() =>
      _DriverPayoutAccountsPageState();
}

class _DriverPayoutAccountsPageState extends State<DriverPayoutAccountsPage> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        title: Text('Payout Accounts', style: PassengerUi.cardTitle),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add payout account',
            onPressed: _isSaving ? null : () => _openForm(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: PassengerPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PassengerPageHeader(
              title: 'Payout Accounts',
              subtitle: '',
              icon: Icons.account_balance_rounded,
              accentColor: PassengerUi.accentBlue,
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<DriverPayoutAccount>>(
              stream: widget.payoutAccountService.watchPayoutAccounts(
                widget.driverId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return PassengerEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Unable to load accounts',
                    description: snapshot.error.toString(),
                  );
                }

                final accounts = snapshot.data ?? <DriverPayoutAccount>[];
                if (accounts.isEmpty) {
                  return PassengerEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No payout account yet',
                    description:
                        'Add GCash, Maya, or bank account details to receive online ride payments.',
                  );
                }

                return Column(
                  children: accounts
                      .asMap()
                      .entries
                      .map(
                        (entry) => Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key == accounts.length - 1 ? 0 : 12,
                          ),
                          child: DriverPayoutAccountCard(
                            account: entry.value,
                            onEdit: () => _openForm(account: entry.value),
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
        label: const Text('Add Account'),
      ),
    );
  }

  Future<void> _openForm({DriverPayoutAccount? account}) async {
    final result = await showDialog<DriverPayoutAccount>(
      context: context,
      builder: (_) => _PayoutAccountFormSheet(
        driverId: widget.driverId,
        initialAccount: account,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.payoutAccountService.savePayoutAccount(result);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payout account saved.')));
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save payout account: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _delete(DriverPayoutAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete payout account?'),
        content: Text(account.displayLabel),
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
      await widget.payoutAccountService.deletePayoutAccount(
        driverId: widget.driverId,
        payoutAccountId: account.id,
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete payout account: $error')),
        );
      }
    }
  }

  Future<void> _setDefault(DriverPayoutAccount account) async {
    try {
      await widget.payoutAccountService.setDefaultPayoutAccount(
        driverId: widget.driverId,
        payoutAccountId: account.id,
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update default account: $error')),
        );
      }
    }
  }
}

class _PayoutAccountFormSheet extends StatefulWidget {
  final String driverId;
  final DriverPayoutAccount? initialAccount;

  const _PayoutAccountFormSheet({required this.driverId, this.initialAccount});

  @override
  State<_PayoutAccountFormSheet> createState() =>
      _PayoutAccountFormSheetState();
}

class _PayoutAccountFormSheetState extends State<_PayoutAccountFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late DriverPayoutAccountType _type;
  late final TextEditingController _labelController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNameController;
  late final TextEditingController _accountReferenceController;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final account = widget.initialAccount;
    _type = account?.type ?? DriverPayoutAccountType.gcash;
    _labelController = TextEditingController(text: account?.displayLabel ?? '');
    _bankNameController = TextEditingController(text: account?.bankName ?? '');
    _accountNameController = TextEditingController(
      text: account?.accountName ?? '',
    );
    _accountReferenceController = TextEditingController(
      text: account?.accountReference ?? '',
    );
    _isDefault = account?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _bankNameController.dispose();
    _accountNameController.dispose();
    _accountReferenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                            widget.initialAccount == null
                                ? 'Add Payout Account'
                                : 'Edit Payout Account',
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
                    DropdownButtonFormField<DriverPayoutAccountType>(
                      value: _type,
                      decoration: const InputDecoration(
                        labelText: 'Account type',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          const <DriverPayoutAccountType>[
                                DriverPayoutAccountType.gcash,
                                DriverPayoutAccountType.maya,
                                DriverPayoutAccountType.bank,
                              ]
                              .map(
                                (type) =>
                                    DropdownMenuItem<DriverPayoutAccountType>(
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
                    if (_type == DriverPayoutAccountType.bank) ...<Widget>[
                      TextFormField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(
                          labelText: 'Bank name',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Enter bank name.';
                          }
                          if (text.length > 60) {
                            return 'Keep this 60 characters or fewer.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _accountNameController,
                      decoration: const InputDecoration(
                        labelText: 'Account name',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Enter account name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accountReferenceController,
                      decoration: InputDecoration(
                        labelText: _type == DriverPayoutAccountType.bank
                            ? 'Account number'
                            : 'Mobile number',
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return _type == DriverPayoutAccountType.bank
                              ? 'Enter account number.'
                              : 'Enter mobile number.';
                        }
                        if (text.length > 40) {
                          return 'Keep this 40 characters or fewer.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isDefault,
                      title: Text(
                        'Use as default',
                        style: PassengerUi.bodyText,
                      ),
                      onChanged: (value) => setState(() => _isDefault = value),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save Payout Account'),
                      ),
                    ),
                  ],
                ),
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

    final existing = widget.initialAccount;
    final account = DriverPayoutAccount(
      id: existing?.id ?? '',
      driverId: widget.driverId,
      type: _type,
      label: _labelController.text.trim().isEmpty
          ? _type.label
          : _labelController.text.trim(),
      accountName: _accountNameController.text.trim(),
      accountReference: _accountReferenceController.text.trim(),
      bankName: _type == DriverPayoutAccountType.bank
          ? _bankNameController.text.trim()
          : '',
      isDefault: _isDefault,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
    );
    Navigator.of(context).pop(account);
  }
}
