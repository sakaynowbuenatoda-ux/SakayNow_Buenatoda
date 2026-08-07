import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/registration_service.dart';
import '../../models/driver_document_status.dart';
import '../../models/driver_payout_account.dart';
import '../../services/driver_payout_account_service.dart';
import '../../services/driver_renewal_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/registration_image_preview.dart';
import 'driver_payout_accounts_page.dart';

class DriverInfoHubPage extends StatefulWidget {
  final String driverId;
  final DriverRenewalService renewalService;
  final DriverPayoutAccountService payoutAccountService;

  DriverInfoHubPage({
    super.key,
    required this.driverId,
    DriverRenewalService? renewalService,
    DriverPayoutAccountService? payoutAccountService,
  }) : renewalService = renewalService ?? DriverRenewalService(),
       payoutAccountService =
           payoutAccountService ?? DriverPayoutAccountService();

  @override
  State<DriverInfoHubPage> createState() => _DriverInfoHubPageState();
}

class _DriverInfoHubPageState extends State<DriverInfoHubPage> {
  final ImagePicker _imagePicker = ImagePicker();
  DriverDocumentType _renewalType = DriverDocumentType.driversLicense;
  RegistrationImageSelection? _renewalFile;
  DateTime? _renewalExpiry;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: PassengerUi.background,
        appBar: AppBar(
          backgroundColor: PassengerUi.surface,
          surfaceTintColor: PassengerUi.surface,
          elevation: 0,
          title: Text('Driver Info Hub', style: PassengerUi.cardTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: PassengerUi.primary,
            unselectedLabelColor: PassengerUi.body,
            indicatorColor: PassengerUi.primary,
            tabs: const <Tab>[
              Tab(text: 'Basic Info'),
              Tab(text: 'Requirements'),
              Tab(text: 'Vehicle Details'),
              Tab(text: 'Payout Reference'),
              Tab(text: 'Renewal Status'),
            ],
          ),
        ),
        body: StreamBuilder<Map<String, dynamic>>(
          stream: widget.renewalService.watchDriver(widget.driverId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return PassengerPageContainer(
                child: PassengerEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load driver information',
                  description: userFacingErrorMessage(
                    snapshot.error,
                    fallback: 'Please try again in a moment.',
                  ),
                ),
              );
            }

            final data = snapshot.data;
            if (data == null || data.isEmpty) {
              return const PassengerPageContainer(
                child: PassengerEmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'Driver profile not found',
                  description: 'Your driver information is not available.',
                ),
              );
            }

            final profile = _DriverHubProfile.fromMap(data);
            return TabBarView(
              children: <Widget>[
                _BasicInfoTab(profile: profile),
                _RequirementsTab(profile: profile),
                _VehicleDetailsTab(profile: profile),
                _PayoutReferenceTab(
                  driverId: widget.driverId,
                  service: widget.payoutAccountService,
                ),
                _buildRenewalTab(profile),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRenewalTab(_DriverHubProfile profile) {
    final status = profile.documentStatus;
    final state = status.stateAt(DateTime.now());
    final canSubmit = !status.hasPendingRenewal;

    return _HubTabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Renewal Status',
            subtitle:
                'Keep your Driver\'s License and OR/CR current to continue receiving bookings.',
            icon: Icons.verified_rounded,
            accentColor: PassengerUi.highlightAmber,
          ),
          const SizedBox(height: 16),
          DriverRenewalStatusCard(status: status),
          const SizedBox(height: 16),
          _DocumentExpiryCard(
            label: 'Driver\'s License',
            expiry: status.driversLicenseExpiry,
            now: DateTime.now(),
          ),
          const SizedBox(height: 10),
          _DocumentExpiryCard(
            label: 'OR/CR',
            expiry: status.orCrExpiry,
            now: DateTime.now(),
          ),
          const SizedBox(height: 20),
          PassengerSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Submit a replacement', style: PassengerUi.cardTitle),
                const SizedBox(height: 6),
                Text(
                  canSubmit
                      ? 'Choose the document being renewed, its new expiry date, and a clear replacement image.'
                      : 'Wait for the current submission to be reviewed before uploading another replacement.',
                  style: PassengerUi.bodyText,
                ),
                if (status.wasRenewalRejected &&
                    status.renewalRejectionReason != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Admin note: ${status.renewalRejectionReason}',
                    style: PassengerUi.bodyText.copyWith(
                      color: PassengerUi.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<DriverDocumentType>(
                  key: const Key('renewal-document-type'),
                  value: _renewalType,
                  decoration: const InputDecoration(
                    labelText: 'Document type',
                    border: OutlineInputBorder(),
                  ),
                  items: DriverDocumentType.values
                      .map(
                        (type) => DropdownMenuItem<DriverDocumentType>(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: canSubmit && !_isSubmitting
                      ? (value) {
                          if (value != null) {
                            setState(() => _renewalType = value);
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('renewal-expiry-picker'),
                  onPressed: canSubmit && !_isSubmitting
                      ? _pickRenewalExpiry
                      : null,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _renewalExpiry == null
                        ? 'Choose new expiry date'
                        : 'New expiry: ${_formatDate(_renewalExpiry!)}',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('renewal-document-picker'),
                  onPressed: canSubmit && !_isSubmitting
                      ? _pickRenewalDocument
                      : null,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    _renewalFile == null
                        ? 'Choose replacement image'
                        : 'Replace selected image',
                  ),
                ),
                if (_renewalFile != null) ...<Widget>[
                  const SizedBox(height: 12),
                  RegistrationImagePreview(
                    selection: _renewalFile!,
                    height: 180,
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('submit-driver-renewal'),
                    onPressed:
                        canSubmit &&
                            !_isSubmitting &&
                            _renewalFile != null &&
                            _renewalExpiry != null
                        ? _submitRenewal
                        : null,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _isSubmitting ? 'Submitting' : 'Submit for review',
                    ),
                  ),
                ),
                if (state == DriverRenewalState.expired) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Your account stays offline until the expired document is approved.',
                    style: PassengerUi.bodyText.copyWith(
                      color: PassengerUi.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRenewalDocument() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final selection = await RegistrationImageSelection.fromXFile(file);
      if (mounted) setState(() => _renewalFile = selection);
    } on PlatformException {
      _showMessage('Unable to open the gallery. Check app permissions.');
    } on RegistrationImageSelectionException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to read that image. Please choose another file.');
    }
  }

  Future<void> _pickRenewalExpiry() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _renewalExpiry ?? now.add(const Duration(days: 365)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: 'Select replacement expiry date',
    );
    if (selected != null && mounted) {
      setState(() => _renewalExpiry = selected);
    }
  }

  Future<void> _submitRenewal() async {
    final file = _renewalFile;
    final expiry = _renewalExpiry;
    if (file == null || expiry == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.renewalService.submitRenewal(
        driverId: widget.driverId,
        documentType: _renewalType,
        document: file,
        newExpiry: expiry,
      );
      if (!mounted) return;
      setState(() {
        _renewalFile = null;
        _renewalExpiry = null;
      });
      _showMessage('Renewal submitted for admin review.');
    } on DriverRenewalSubmissionException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(
        userFacingErrorMessage(
          error,
          fallback: 'Unable to submit renewal. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class DriverRenewalStatusCard extends StatelessWidget {
  final DriverDocumentStatus status;
  final DateTime? now;

  const DriverRenewalStatusCard({super.key, required this.status, this.now});

  @override
  Widget build(BuildContext context) {
    final state = status.stateAt(now ?? DateTime.now());
    final presentation = _RenewalPresentation.forState(state);

    return PassengerSurfaceCard(
      key: Key('driver-renewal-state-${state.name}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: presentation.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(presentation.icon, color: presentation.foreground),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text('Document status', style: PassengerUi.cardTitle),
                    PassengerStatusChip(
                      label: state.label,
                      textColor: presentation.foreground,
                      backgroundColor: presentation.background,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(state.description, style: PassengerUi.bodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BasicInfoTab extends StatelessWidget {
  final _DriverHubProfile profile;

  const _BasicInfoTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return _HubTabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: profile.fullName,
            subtitle: 'Basic driver account information',
            icon: Icons.account_circle_rounded,
            accentColor: PassengerUi.primary,
          ),
          const SizedBox(height: 16),
          PassengerSurfaceCard(
            child: Column(
              children: <Widget>[
                _HubValueRow(label: 'Email', value: profile.email),
                _HubValueRow(label: 'Age', value: profile.age),
                _HubValueRow(label: 'Gender', value: profile.gender),
                _HubValueRow(
                  label: 'Verification',
                  value: profile.isVerified
                      ? 'Verified'
                      : 'Pending verification',
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementsTab extends StatelessWidget {
  final _DriverHubProfile profile;

  const _RequirementsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final documents = <(String, String?, DateTime?)>[
      (
        'Driver\'s License',
        profile.driversLicenseUrl,
        profile.documentStatus.driversLicenseExpiry,
      ),
      ('OR/CR', profile.orCrUrl, profile.documentStatus.orCrExpiry),
      ('NBI Clearance', profile.nbiClearanceUrl, null),
      ('Driver Selfie', profile.selfieUrl, null),
    ];

    return _HubTabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Requirements & Documents',
            subtitle: 'Private credentials visible only to you and admins.',
            icon: Icons.description_rounded,
            accentColor: PassengerUi.accentBlue,
          ),
          const SizedBox(height: 16),
          ...documents.map(
            (document) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HubDocumentCard(
                label: document.$1,
                imageUrl: document.$2,
                expiry: document.$3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleDetailsTab extends StatelessWidget {
  final _DriverHubProfile profile;

  const _VehicleDetailsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return _HubTabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Vehicle Details',
            subtitle: 'The identification passengers see for assigned rides.',
            icon: Icons.local_taxi_rounded,
            accentColor: PassengerUi.secondary,
          ),
          const SizedBox(height: 16),
          PassengerSurfaceCard(
            child: Column(
              children: <Widget>[
                _HubValueRow(label: 'Vehicle type', value: profile.vehicleType),
                _HubValueRow(
                  label: 'Tricycle color',
                  value: profile.tricycleColor,
                ),
                _HubValueRow(
                  label: 'Plate / Franchise No.',
                  value: profile.plateNumber,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HubDocumentCard(
            label: 'Front tricycle photo',
            imageUrl: profile.tricycleFrontUrl,
          ),
          const SizedBox(height: 12),
          _HubDocumentCard(
            label: 'Back tricycle photo',
            imageUrl: profile.tricycleBackUrl,
          ),
        ],
      ),
    );
  }
}

class _PayoutReferenceTab extends StatelessWidget {
  final String driverId;
  final DriverPayoutAccountService service;

  const _PayoutReferenceTab({required this.driverId, required this.service});

  @override
  Widget build(BuildContext context) {
    return _HubTabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Payout Reference',
            subtitle: 'Accounts used for online ride payouts.',
            icon: Icons.payments_rounded,
            accentColor: PassengerUi.accentBlue,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DriverPayoutAccountsPage(driverId: driverId),
                ),
              ),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Manage payout accounts'),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<DriverPayoutAccount>>(
            stream: service.watchPayoutAccounts(driverId),
            builder: (context, snapshot) {
              if (!snapshot.hasData && !snapshot.hasError) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const PassengerEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load payout references',
                  description: 'Open Manage to try again.',
                );
              }
              final accounts = snapshot.data ?? const <DriverPayoutAccount>[];
              if (accounts.isEmpty) {
                return const PassengerEmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'No payout reference yet',
                  description:
                      'Use Manage to add GCash, Maya, or a bank account.',
                );
              }
              return Column(
                children: accounts
                    .map(
                      (account) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PassengerSurfaceCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              account.type.icon,
                              color: account.type.accentColor,
                            ),
                            title: Text(account.displayLabel),
                            subtitle: Text(account.accountLabel),
                            trailing: account.isDefault
                                ? const Icon(Icons.check_circle_rounded)
                                : null,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HubTabPage extends StatelessWidget {
  final Widget child;

  const _HubTabPage({required this.child});

  @override
  Widget build(BuildContext context) {
    return PassengerPageContainer(
      maxContentWidth: PassengerUi.settingsContentWidth,
      child: child,
    );
  }
}

class _HubDocumentCard extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final DateTime? expiry;

  const _HubDocumentCard({required this.label, this.imageUrl, this.expiry});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(label, style: PassengerUi.cardTitle)),
                if (expiry != null)
                  Text(_formatDate(expiry!), style: PassengerUi.bodyText),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: FirebaseStorageImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              fallback: Container(
                color: PassengerUi.mutedSurface,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: PassengerUi.body,
                    ),
                    const SizedBox(height: 6),
                    Text('No image available', style: PassengerUi.bodyText),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentExpiryCard extends StatelessWidget {
  final String label;
  final DateTime? expiry;
  final DateTime now;

  const _DocumentExpiryCard({
    required this.label,
    required this.expiry,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = expiry != null && !expiry!.isAfter(now);
    final isExpiring =
        expiry != null &&
        !isExpired &&
        !expiry!.isAfter(now.add(DriverDocumentStatus.expiringSoonWindow));
    final foreground = isExpired
        ? PassengerUi.primary
        : isExpiring
        ? PassengerUi.highlightAmber
        : PassengerUi.successText;
    final background = isExpired
        ? PassengerUi.dangerSoft
        : isExpiring
        ? PassengerUi.warningSoft
        : PassengerUi.successBackground;

    return PassengerSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(Icons.event_available_outlined, color: foreground),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: PassengerUi.cardTitle)),
          PassengerStatusChip(
            label: expiry == null ? 'Not recorded' : _formatDate(expiry!),
            textColor: foreground,
            backgroundColor: background,
          ),
        ],
      ),
    );
  }
}

class _HubValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _HubValueRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? 'Not provided' : value.trim();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: PassengerUi.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 155, child: Text(label, style: PassengerUi.bodyText)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: PassengerUi.valueText,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverHubProfile {
  final String firstName;
  final String lastName;
  final String email;
  final String age;
  final String gender;
  final bool isVerified;
  final String vehicleType;
  final String tricycleColor;
  final String plateNumber;
  final String? selfieUrl;
  final String? nbiClearanceUrl;
  final String? driversLicenseUrl;
  final String? orCrUrl;
  final String? tricycleFrontUrl;
  final String? tricycleBackUrl;
  final DriverDocumentStatus documentStatus;

  const _DriverHubProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.age,
    required this.gender,
    required this.isVerified,
    required this.vehicleType,
    required this.tricycleColor,
    required this.plateNumber,
    required this.selfieUrl,
    required this.nbiClearanceUrl,
    required this.driversLicenseUrl,
    required this.orCrUrl,
    required this.tricycleFrontUrl,
    required this.tricycleBackUrl,
    required this.documentStatus,
  });

  factory _DriverHubProfile.fromMap(Map<String, dynamic> data) {
    String value(String key) => data[key]?.toString().trim() ?? '';
    String? optional(String key) =>
        DriverDocumentStatus.readOptionalString(data[key]);
    final gender = value('gender');
    return _DriverHubProfile(
      firstName: value('first_name'),
      lastName: value('last_name'),
      email: value('email'),
      age: value('age'),
      gender: gender.isEmpty
          ? ''
          : '${gender[0].toUpperCase()}${gender.substring(1).toLowerCase()}',
      isVerified: (data['is_verified'] ?? data['isVerified'] ?? false) == true,
      vehicleType: value('vehicle_type'),
      tricycleColor: value('tricycle_color'),
      plateNumber: value('plate_number'),
      selfieUrl: optional('selfie_url'),
      nbiClearanceUrl: optional('nbi_clearance_url'),
      driversLicenseUrl: optional('drivers_license_url'),
      orCrUrl: optional('or_cr_url'),
      tricycleFrontUrl: optional('tricycle_front_url'),
      tricycleBackUrl: optional('tricycle_back_url'),
      documentStatus: DriverDocumentStatus.fromMap(data),
    );
  }

  String get fullName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? 'Driver' : value;
  }
}

class _RenewalPresentation {
  final IconData icon;
  final Color foreground;
  final Color background;

  const _RenewalPresentation({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  factory _RenewalPresentation.forState(DriverRenewalState state) {
    return switch (state) {
      DriverRenewalState.valid => _RenewalPresentation(
        icon: Icons.verified_rounded,
        foreground: PassengerUi.successText,
        background: PassengerUi.successBackground,
      ),
      DriverRenewalState.expiringSoon => _RenewalPresentation(
        icon: Icons.schedule_rounded,
        foreground: PassengerUi.highlightAmber,
        background: PassengerUi.warningSoft,
      ),
      DriverRenewalState.expired => _RenewalPresentation(
        icon: Icons.event_busy_rounded,
        foreground: PassengerUi.primary,
        background: PassengerUi.dangerSoft,
      ),
      DriverRenewalState.pendingRenewal => _RenewalPresentation(
        icon: Icons.hourglass_top_rounded,
        foreground: PassengerUi.accentBlue,
        background: PassengerUi.blueSoft,
      ),
      DriverRenewalState.rejected => _RenewalPresentation(
        icon: Icons.cancel_outlined,
        foreground: PassengerUi.primary,
        background: PassengerUi.dangerSoft,
      ),
    };
  }
}

String _formatDate(DateTime value) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
