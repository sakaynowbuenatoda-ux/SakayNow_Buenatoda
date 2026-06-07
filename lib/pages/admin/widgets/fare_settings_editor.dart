import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/fare_settings.dart';
import '../admin_service.dart';
import 'admin_shared.dart';

class FareSettingsEditor extends StatelessWidget {
  final String adminId;

  const FareSettingsEditor({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FareSettings>(
      stream: AdminService.watchFareSettings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AdminErrorCard(
            message: 'Unable to load fare settings: ${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const AdminSurfaceCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final settings = snapshot.data!;

        return AdminSurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AdminUi.accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.price_change_rounded,
                      color: AdminUi.accentBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Editable Fare System', style: AdminUi.cardTitle),
                        const SizedBox(height: 5),
                        Text(
                          'These values are used when passengers preview fares and when bookings save the final fare shown to drivers.',
                          style: AdminUi.bodyText,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _FareValueTile(
                    label: '1 barangay',
                    value: settings.oneBarangayFareLabel,
                  ),
                  _FareValueTile(
                    label: 'Up to 5 barangays',
                    value: settings.buenavistaFiveBarangayFareLabel,
                  ),
                  _FareValueTile(
                    label: 'Outside route range',
                    value: settings.outsideBuenavistaRangeLabel,
                  ),
                  _FareValueTile(
                    label: 'Student discount',
                    value: settings.studentDiscountLabel,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      settings.updatedAt == null
                          ? 'Using default fare table until an admin saves changes.'
                          : 'Last updated ${formatDateTime(settings.updatedAt)}',
                      style: AdminUi.bodyText.copyWith(fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _openEditor(context, settings),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, FareSettings settings) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _FareSettingsDialog(adminId: adminId, settings: settings),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fare settings updated.')));
    }
  }
}

class _FareValueTile extends StatelessWidget {
  final String label;
  final String value;

  const _FareValueTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminUi.mutedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.bodyText.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.valueText,
          ),
        ],
      ),
    );
  }
}

class _FareSettingsDialog extends StatefulWidget {
  final String adminId;
  final FareSettings settings;

  const _FareSettingsDialog({required this.adminId, required this.settings});

  @override
  State<_FareSettingsDialog> createState() => _FareSettingsDialogState();
}

class _FareSettingsDialogState extends State<_FareSettingsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _oneBarangayController;
  late final TextEditingController _fiveBarangayController;
  late final TextEditingController _minFareController;
  late final TextEditingController _nineKmFareController;
  late final TextEditingController _twelveKmFareController;
  late final TextEditingController _sixteenKmFareController;
  late final TextEditingController _maxFareController;
  late final TextEditingController _studentDiscountController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _oneBarangayController = TextEditingController(
      text: settings.oneBarangayFare.toString(),
    );
    _fiveBarangayController = TextEditingController(
      text: settings.buenavistaFiveBarangayFare.toString(),
    );
    _minFareController = TextEditingController(
      text: settings.outsideBuenavistaMinFare.toString(),
    );
    _nineKmFareController = TextEditingController(
      text: settings.outsideBuenavistaNineKmFare.toString(),
    );
    _twelveKmFareController = TextEditingController(
      text: settings.outsideBuenavistaTwelveKmFare.toString(),
    );
    _sixteenKmFareController = TextEditingController(
      text: settings.outsideBuenavistaSixteenKmFare.toString(),
    );
    _maxFareController = TextEditingController(
      text: settings.outsideBuenavistaMaxFare.toString(),
    );
    _studentDiscountController = TextEditingController(
      text: (settings.studentDiscountRate * 100).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _oneBarangayController.dispose();
    _fiveBarangayController.dispose();
    _minFareController.dispose();
    _nineKmFareController.dispose();
    _twelveKmFareController.dispose();
    _sixteenKmFareController.dispose();
    _maxFareController.dispose();
    _studentDiscountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Fare System'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Buenavista fares', style: AdminUi.cardTitle),
                const SizedBox(height: 10),
                _FareAmountField(
                  controller: _oneBarangayController,
                  label: '1 barangay fare',
                ),
                const SizedBox(height: 10),
                _FareAmountField(
                  controller: _fiveBarangayController,
                  label: 'Up to 5 barangays fare',
                ),
                const SizedBox(height: 16),
                Text('Distance fares', style: AdminUi.cardTitle),
                const SizedBox(height: 10),
                _FareAmountField(
                  controller: _minFareController,
                  label: '0-6 km / minimum route fare',
                ),
                const SizedBox(height: 10),
                _FareAmountField(
                  controller: _nineKmFareController,
                  label: '6-9 km fare',
                ),
                const SizedBox(height: 10),
                _FareAmountField(
                  controller: _twelveKmFareController,
                  label: '9-12 km fare',
                ),
                const SizedBox(height: 10),
                _FareAmountField(
                  controller: _sixteenKmFareController,
                  label: '12-16 km fare',
                ),
                const SizedBox(height: 10),
                _FareAmountField(
                  controller: _maxFareController,
                  label: 'Over 16 km / maximum route fare',
                ),
                const SizedBox(height: 16),
                Text('Discount', style: AdminUi.cardTitle),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _studentDiscountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Verified student discount percent',
                    prefixText: '',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateDiscountPercent,
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: AdminUi.bodyText.copyWith(
                      color: AdminUi.primary,
                      fontWeight: FontWeight.w700,
                    ),
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
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(_isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final oneBarangay = _readAmount(_oneBarangayController);
    final fiveBarangays = _readAmount(_fiveBarangayController);
    final minFare = _readAmount(_minFareController);
    final nineKmFare = _readAmount(_nineKmFareController);
    final twelveKmFare = _readAmount(_twelveKmFareController);
    final sixteenKmFare = _readAmount(_sixteenKmFareController);
    final maxFare = _readAmount(_maxFareController);
    final discountPercent = double.parse(_studentDiscountController.text);

    final orderingError = _tierOrderingError(
      oneBarangay: oneBarangay,
      fiveBarangays: fiveBarangays,
      minFare: minFare,
      nineKmFare: nineKmFare,
      twelveKmFare: twelveKmFare,
      sixteenKmFare: sixteenKmFare,
      maxFare: maxFare,
    );
    if (orderingError != null) {
      setState(() => _errorMessage = orderingError);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final settings = widget.settings.copyWith(
        oneBarangayFare: oneBarangay,
        buenavistaFiveBarangayFare: fiveBarangays,
        outsideBuenavistaMinFare: minFare,
        outsideBuenavistaNineKmFare: nineKmFare,
        outsideBuenavistaTwelveKmFare: twelveKmFare,
        outsideBuenavistaSixteenKmFare: sixteenKmFare,
        outsideBuenavistaMaxFare: maxFare,
        studentDiscountRate: discountPercent / 100,
      );

      await AdminService.updateFareSettings(
        settings: settings,
        adminId: widget.adminId,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Unable to save fare settings: $error';
        });
      }
    }
  }

  static int _readAmount(TextEditingController controller) {
    return int.parse(controller.text.trim());
  }

  static String? _validateFareAmount(String? value) {
    final amount = int.tryParse(value?.trim() ?? '');
    if (amount == null) {
      return 'Enter a valid peso amount.';
    }

    if (amount <= 0) {
      return 'Fare must be greater than 0.';
    }

    return null;
  }

  static String? _validateDiscountPercent(String? value) {
    final percent = double.tryParse(value?.trim() ?? '');
    if (percent == null) {
      return 'Enter a valid discount percent.';
    }

    if (percent < 0 || percent > 100) {
      return 'Discount must be between 0 and 100.';
    }

    return null;
  }

  static String? _tierOrderingError({
    required int oneBarangay,
    required int fiveBarangays,
    required int minFare,
    required int nineKmFare,
    required int twelveKmFare,
    required int sixteenKmFare,
    required int maxFare,
  }) {
    if (fiveBarangays < oneBarangay) {
      return 'Up to 5 barangays fare must be at least the 1 barangay fare.';
    }

    if (nineKmFare < minFare ||
        twelveKmFare < nineKmFare ||
        sixteenKmFare < twelveKmFare ||
        maxFare < sixteenKmFare) {
      return 'Distance fares must increase or stay the same as distance grows.';
    }

    return null;
  }
}

class _FareAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _FareAmountField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: '${FareSettings.defaultCurrency} ',
        border: const OutlineInputBorder(),
      ),
      validator: _FareSettingsDialogState._validateFareAmount,
    );
  }
}
