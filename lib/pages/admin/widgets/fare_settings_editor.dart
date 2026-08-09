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
            message: 'Unable to load fare settings. Please try again.',
          );
        }

        if (!snapshot.hasData) {
          return const AdminSurfaceCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final settings = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Current configuration',
                    style: AdminUi.cardTitle.copyWith(fontSize: 14),
                  ),
                ),
                AdminStatusChip(
                  label: 'Live',
                  textColor: AdminUi.success,
                  backgroundColor: AdminUi.successBackground,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FareSummaryGrid(settings: settings),
            const SizedBox(height: 12),
            _FarePolicyNotice(
              title: 'Driver pickup pricing',
              description: settings.driverPickupSurchargeDescription,
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: AdminUi.border),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                final updateText = settings.updatedAt == null
                    ? 'Default fare guide is currently active.'
                    : 'Updated ${formatDateTime(settings.updatedAt)}';
                final status = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.history_rounded, size: 17, color: AdminUi.muted),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        updateText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AdminUi.bodyText.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                );
                final button = ElevatedButton.icon(
                  onPressed: () => _openEditor(context, settings),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Edit fare rules'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      status,
                      const SizedBox(height: 12),
                      button,
                    ],
                  );
                }

                return Row(
                  children: <Widget>[
                    Expanded(child: status),
                    const SizedBox(width: 14),
                    button,
                  ],
                );
              },
            ),
          ],
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

class _FareSummaryGrid extends StatelessWidget {
  final FareSettings settings;

  const _FareSummaryGrid({required this.settings});

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value, IconData icon})>[
      (
        label: '1 barangay',
        value: settings.oneBarangayFareLabel,
        icon: Icons.location_on_outlined,
      ),
      (
        label: 'Up to 5 barangays',
        value: settings.buenavistaFiveBarangayFareLabel,
        icon: Icons.holiday_village_outlined,
      ),
      (
        label: 'Extended routes',
        value: settings.outsideBuenavistaRangeLabel,
        icon: Icons.route_outlined,
      ),
      (
        label: 'Regular discount',
        value: settings.regularPassengerDiscountLabel,
        icon: Icons.person_outline_rounded,
      ),
      (
        label: 'Student discount',
        value: settings.studentDiscountLabel,
        icon: Icons.school_outlined,
      ),
      (
        label: 'Senior discount',
        value: settings.seniorCitizenDiscountLabel,
        icon: Icons.elderly_outlined,
      ),
      (
        label: 'Platform commission',
        value: settings.commissionLabel,
        icon: Icons.percent_rounded,
      ),
      (
        label: 'Pickup add-on',
        value: settings.driverPickupSurchargeRangeLabel,
        icon: Icons.two_wheeler_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final columns = constraints.maxWidth >= 620
            ? 3
            : constraints.maxWidth >= 330
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _FareValueTile(
                    label: item.label,
                    value: item.value,
                    icon: item.icon,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _FareValueTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _FareValueTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminUi.subtleSurface,
        borderRadius: AdminUi.radius,
        border: Border.all(color: AdminUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: AdminUi.accentBlue),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminUi.labelText.copyWith(fontSize: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminUi.valueText.copyWith(fontSize: 14.5),
          ),
        ],
      ),
    );
  }
}

class _FarePolicyNotice extends StatelessWidget {
  final String title;
  final String description;

  const _FarePolicyNotice({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminUi.soft(AdminUi.accentBlue, alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminUi.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AdminUi.valueText.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                Text(description, style: AdminUi.bodyText),
              ],
            ),
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
  late final TextEditingController _regularDiscountController;
  late final TextEditingController _studentDiscountController;
  late final TextEditingController _seniorDiscountController;
  late final TextEditingController _pickupPerBarangayController;
  late final TextEditingController _maxPickupSurchargeController;
  late final TextEditingController _commissionController;
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
    _regularDiscountController = TextEditingController(
      text: _percentText(settings.regularPassengerDiscountRate),
    );
    _studentDiscountController = TextEditingController(
      text: _percentText(settings.studentDiscountRate),
    );
    _seniorDiscountController = TextEditingController(
      text: _percentText(settings.seniorCitizenDiscountRate),
    );
    _pickupPerBarangayController = TextEditingController(
      text: settings.driverPickupSurchargePerExtraBarangay.toString(),
    );
    _maxPickupSurchargeController = TextEditingController(
      text: settings.maxDriverPickupSurcharge.toString(),
    );
    _commissionController = TextEditingController(
      text: (settings.commissionRate * 100).toStringAsFixed(1),
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
    _regularDiscountController.dispose();
    _studentDiscountController.dispose();
    _seniorDiscountController.dispose();
    _pickupPerBarangayController.dispose();
    _maxPickupSurchargeController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final maxHeight = (screenSize.height - 32).clamp(360.0, 820.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: AdminUi.surface,
      shape: RoundedRectangleBorder(borderRadius: AdminUi.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Edit fare system', style: AdminUi.sectionTitle),
                        const SizedBox(height: 3),
                        Text(
                          'Configure pricing for new and newly accepted bookings.',
                          style: AdminUi.bodyText.copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AdminUi.border),
            Flexible(
              child: ColoredBox(
                color: AdminUi.background,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _FareEditorSection(
                          title: 'Buenavista base fares',
                          description:
                              'Set the standard rates for trips within the municipality.',
                          child: _FareEditorGrid(
                            children: <Widget>[
                              _FareAmountField(
                                controller: _oneBarangayController,
                                label: '1 barangay',
                              ),
                              _FareAmountField(
                                controller: _fiveBarangayController,
                                label: 'Up to 5 barangays',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FareEditorSection(
                          title: 'Distance-based fares',
                          description:
                              'Keep each tier equal to or higher than the tier before it.',
                          child: _FareEditorGrid(
                            children: <Widget>[
                              _FareAmountField(
                                controller: _minFareController,
                                label: '0-6 km · minimum',
                              ),
                              _FareAmountField(
                                controller: _nineKmFareController,
                                label: '6-9 km',
                              ),
                              _FareAmountField(
                                controller: _twelveKmFareController,
                                label: '9-12 km',
                              ),
                              _FareAmountField(
                                controller: _sixteenKmFareController,
                                label: '12-16 km',
                              ),
                              _FareAmountField(
                                controller: _maxFareController,
                                label: 'Over 16 km · maximum',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FareEditorSection(
                          title: 'Passenger discounts and commission',
                          description:
                              'Regular discounts apply automatically. Student and senior discounts require a verified account.',
                          child: _FareEditorGrid(
                            children: <Widget>[
                              _PercentageField(
                                controller: _regularDiscountController,
                                label: 'Regular passenger discount',
                                validator: _validateDiscountPercent,
                              ),
                              _PercentageField(
                                controller: _studentDiscountController,
                                label: 'Student discount',
                                validator: _validateDiscountPercent,
                              ),
                              _PercentageField(
                                controller: _seniorDiscountController,
                                label: 'Senior citizen discount',
                                validator: _validateDiscountPercent,
                              ),
                              _PercentageField(
                                controller: _commissionController,
                                label: 'Platform commission',
                                validator: _validateCommissionPercent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FareEditorSection(
                          title: 'Driver pickup add-on',
                          description:
                              'Charge per extra barangay between the selected driver and pickup. Set both values to 0 to disable it.',
                          child: _FareEditorGrid(
                            children: <Widget>[
                              _FareAmountField(
                                controller: _pickupPerBarangayController,
                                label: 'Per extra barangay',
                                allowZero: true,
                              ),
                              _FareAmountField(
                                controller: _maxPickupSurchargeController,
                                label: 'Maximum pickup add-on',
                                allowZero: true,
                              ),
                            ],
                          ),
                        ),
                        if (_errorMessage != null) ...<Widget>[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AdminUi.dangerSoft,
                              borderRadius: AdminUi.radius,
                              border: Border.all(
                                color: AdminUi.danger.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: AdminUi.danger,
                                  size: 20,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AdminUi.bodyText.copyWith(
                                      color: AdminUi.danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: AdminUi.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final notice = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.info_outline_rounded,
                        size: 17,
                        color: AdminUi.muted,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Changes apply to future fare calculations.',
                          style: AdminUi.bodyText.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_isSaving ? 'Saving...' : 'Save changes'),
                      ),
                    ],
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        notice,
                        const SizedBox(height: 12),
                        actions,
                      ],
                    );
                  }

                  return Row(
                    children: <Widget>[
                      Expanded(child: notice),
                      const SizedBox(width: 16),
                      actions,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
    final regularDiscountPercent = double.parse(
      _regularDiscountController.text,
    );
    final studentDiscountPercent = double.parse(
      _studentDiscountController.text,
    );
    final seniorDiscountPercent = double.parse(_seniorDiscountController.text);
    final pickupPerBarangay = _readAmount(_pickupPerBarangayController);
    final maxPickupSurcharge = _readAmount(_maxPickupSurchargeController);
    final commissionPercent = double.parse(_commissionController.text);

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
    if (pickupPerBarangay == 0 && maxPickupSurcharge != 0) {
      setState(() {
        _errorMessage =
            'Set the maximum pickup add-on to 0 when the per-barangay add-on is disabled.';
      });
      return;
    }
    if (maxPickupSurcharge < pickupPerBarangay) {
      setState(() {
        _errorMessage =
            'Maximum pickup add-on must be at least the per-barangay add-on.';
      });
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
        regularPassengerDiscountRate: regularDiscountPercent / 100,
        studentDiscountRate: studentDiscountPercent / 100,
        seniorCitizenDiscountRate: seniorDiscountPercent / 100,
        driverPickupSurchargePerExtraBarangay: pickupPerBarangay,
        maxDriverPickupSurcharge: maxPickupSurcharge,
        commissionRate: commissionPercent / 100,
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

  static String _percentText(double rate) {
    final percent = rate * 100;
    return percent % 1 == 0
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
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

  static String? _validateNonNegativeAmount(String? value) {
    final amount = int.tryParse(value?.trim() ?? '');
    if (amount == null) {
      return 'Enter a valid peso amount.';
    }

    if (amount < 0) {
      return 'Amount cannot be negative.';
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

  static String? _validateCommissionPercent(String? value) {
    final percent = double.tryParse(value?.trim() ?? '');
    if (percent == null) {
      return 'Enter a valid commission percent.';
    }

    if (percent < 0 || percent > 100) {
      return 'Commission must be between 0 and 100.';
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

class _FareEditorSection extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _FareEditorSection({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: AdminUi.cardRadius,
        border: Border.all(color: AdminUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AdminUi.cardTitle),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: AdminUi.bodyText.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FareEditorGrid extends StatelessWidget {
  final List<Widget> children;

  const _FareEditorGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth >= 480 ? 2 : 1;
        final fieldWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: children
              .map((child) => SizedBox(width: fieldWidth, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _PercentageField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;

  const _PercentageField({
    required this.controller,
    required this.label,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      style: AdminUi.valueText.copyWith(fontSize: 14),
      decoration: _fareFieldDecoration(label: label, suffixText: '%'),
      validator: validator,
    );
  }
}

InputDecoration _fareFieldDecoration({
  required String label,
  String? prefixText,
  String? suffixText,
}) {
  final baseBorder = OutlineInputBorder(
    borderRadius: AdminUi.radius,
    borderSide: BorderSide(color: AdminUi.border),
  );

  return InputDecoration(
    labelText: label,
    hintText: '0',
    prefixText: prefixText,
    suffixText: suffixText,
    filled: true,
    fillColor: AdminUi.subtleSurface,
    labelStyle: AdminUi.bodyText.copyWith(color: AdminUi.muted),
    floatingLabelStyle: AdminUi.labelText.copyWith(color: AdminUi.accent),
    hintStyle: AdminUi.bodyText.copyWith(color: AdminUi.muted),
    prefixStyle: AdminUi.valueText.copyWith(fontSize: 14),
    suffixStyle: AdminUi.valueText.copyWith(color: AdminUi.muted, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: baseBorder,
    enabledBorder: baseBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: AdminUi.radius,
      borderSide: BorderSide(color: AdminUi.accent, width: 1.5),
    ),
  );
}

class _FareAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool allowZero;

  const _FareAmountField({
    required this.controller,
    required this.label,
    this.allowZero = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      style: AdminUi.valueText.copyWith(fontSize: 14),
      decoration: _fareFieldDecoration(
        label: label,
        prefixText: '${FareSettings.defaultCurrency} ',
      ),
      validator: allowZero
          ? _FareSettingsDialogState._validateNonNegativeAmount
          : _FareSettingsDialogState._validateFareAmount,
    );
  }
}
