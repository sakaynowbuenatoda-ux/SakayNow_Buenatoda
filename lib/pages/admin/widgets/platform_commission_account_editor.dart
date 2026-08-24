import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/platform_commission_account.dart';
import '../../../widgets/app_skeleton.dart';
import '../admin_service.dart';
import 'admin_shared.dart';

class PlatformCommissionAccountEditor extends StatelessWidget {
  final String adminId;

  const PlatformCommissionAccountEditor({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlatformCommissionAccount?>(
      stream: AdminService.watchPlatformCommissionAccount(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AdminErrorCard(
            message:
                'Unable to load the platform commission account. Please try again.',
          );
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const AppSkeletonCard(lineCount: 3);
        }

        final account = snapshot.data;
        if (account == null) {
          return _EmptyCommissionAccount(
            onConfigure: () => _openEditor(context, null),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AdminUi.blueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(account.type.icon, color: AdminUi.accentBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(account.displayLabel, style: AdminUi.cardTitle),
                      const SizedBox(height: 3),
                      Text(account.accountSummary, style: AdminUi.bodyText),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AdminStatusChip(
                  label: account.isEnabled ? 'Enabled' : 'Disabled',
                  textColor: account.isEnabled
                      ? AdminUi.successText
                      : AdminUi.danger,
                  backgroundColor: account.isEnabled
                      ? AdminUi.successBackground
                      : AdminUi.dangerSoft,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AdminInfoPanel(
              title: 'Xendit checkout settlement',
              description: account.isEnabled
                  ? 'Nonzero platform commission is linked to this private settlement account during checkout.'
                  : 'Enable this account before accepting a checkout with nonzero platform commission.',
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    account.updatedAt == null
                        ? 'Commission account configured'
                        : 'Updated ${formatDateTime(account.updatedAt)}',
                    style: AdminUi.labelText,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openEditor(context, account),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit account'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    PlatformCommissionAccount? account,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _PlatformCommissionAccountDialog(adminId: adminId, account: account),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Platform commission account saved.')),
      );
    }
  }
}

class _EmptyCommissionAccount extends StatelessWidget {
  final VoidCallback onConfigure;

  const _EmptyCommissionAccount({required this.onConfigure});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AdminInfoPanel(
          title: 'No commission account configured',
          description:
              'Add the private GCash, Maya, or bank settlement account used for platform commission from Xendit checkout.',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: onConfigure,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Configure account'),
          ),
        ),
      ],
    );
  }
}

class _PlatformCommissionAccountDialog extends StatefulWidget {
  final String adminId;
  final PlatformCommissionAccount? account;

  const _PlatformCommissionAccountDialog({
    required this.adminId,
    required this.account,
  });

  @override
  State<_PlatformCommissionAccountDialog> createState() =>
      _PlatformCommissionAccountDialogState();
}

class _PlatformCommissionAccountDialogState
    extends State<_PlatformCommissionAccountDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late PlatformCommissionAccountType _type;
  late final TextEditingController _labelController;
  late final TextEditingController _accountNameController;
  late final TextEditingController _accountReferenceController;
  late final TextEditingController _bankNameController;
  late bool _isEnabled;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _type = account?.type ?? PlatformCommissionAccountType.gcash;
    _labelController = TextEditingController(text: account?.label ?? '');
    _accountNameController = TextEditingController(
      text: account?.accountName ?? '',
    );
    _accountReferenceController = TextEditingController(
      text: account?.accountReference ?? '',
    );
    _bankNameController = TextEditingController(text: account?.bankName ?? '');
    _isEnabled = account?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _accountNameController.dispose();
    _accountReferenceController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminUi.surface,
      title: Text(
        widget.account == null
            ? 'Add commission account'
            : 'Edit commission account',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Only admins can view or change these settlement details. API keys and passwords must never be entered here.',
                  style: AdminUi.bodyText,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PlatformCommissionAccountType>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Account type',
                    border: OutlineInputBorder(),
                  ),
                  items: PlatformCommissionAccountType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _type = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _labelController,
                  enabled: !_isSaving,
                  maxLength: 60,
                  decoration: InputDecoration(
                    labelText: 'Account label',
                    hintText: '${_type.label} commission account',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 2),
                if (_type == PlatformCommissionAccountType.bank) ...<Widget>[
                  TextFormField(
                    controller: _bankNameController,
                    enabled: !_isSaving,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Bank name',
                      border: OutlineInputBorder(),
                    ),
                    validator: _requiredLabel,
                  ),
                  const SizedBox(height: 2),
                ],
                TextFormField(
                  controller: _accountNameController,
                  enabled: !_isSaving,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Account name',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredLabel,
                ),
                const SizedBox(height: 2),
                TextFormField(
                  controller: _accountReferenceController,
                  enabled: !_isSaving,
                  maxLength: 100,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9+ ._\-]'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: _type == PlatformCommissionAccountType.bank
                        ? 'Account number'
                        : 'Mobile number or account reference',
                    border: const OutlineInputBorder(),
                  ),
                  validator: _accountReferenceValidator,
                ),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable for checkout'),
                  subtitle: const Text(
                    'Required when the configured platform commission is above 0%.',
                  ),
                  value: _isEnabled,
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _isEnabled = value),
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: AdminUi.bodyText.copyWith(color: AdminUi.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_isSaving ? 'Saving...' : 'Save account'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final label = _labelController.text.trim();
    final account = PlatformCommissionAccount(
      id: widget.account?.id ?? 'current',
      type: _type,
      label: label.isEmpty ? '${_type.label} commission account' : label,
      accountName: _accountNameController.text.trim(),
      accountReference: _accountReferenceController.text.trim(),
      bankName: _type == PlatformCommissionAccountType.bank
          ? _bankNameController.text.trim()
          : '',
      isEnabled: _isEnabled,
      updatedBy: widget.adminId,
      createdAt: widget.account?.createdAt,
      updatedAt: widget.account?.updatedAt,
    );

    try {
      await AdminService.savePlatformCommissionAccount(
        account: account,
        adminId: widget.adminId,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Unable to save commission account: $error';
        });
      }
    }
  }

  static String? _requiredLabel(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.length < 2) {
      return 'Enter at least 2 characters.';
    }
    return null;
  }

  static String? _accountReferenceValidator(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.length < 4) {
      return 'Enter at least 4 characters.';
    }
    return null;
  }
}
