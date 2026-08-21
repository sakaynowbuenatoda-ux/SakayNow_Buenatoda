import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/registration_service.dart';
import '../../core/session/account_flags.dart';
import '../../models/driver_document_status.dart';
import '../../services/driver_credential_service.dart';
import '../../services/driver_registration_recovery_service.dart';
import '../../services/driver_renewal_service.dart';
import '../../services/driver_vehicle_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/registration_image_preview.dart';

class DriverInfoHubPage extends StatefulWidget {
  final String driverId;
  final DriverRenewalService renewalService;
  final DriverCredentialService credentialService;
  final DriverVehicleService vehicleService;
  final DriverRegistrationRecoveryService registrationRecoveryService;

  DriverInfoHubPage({
    super.key,
    required this.driverId,
    DriverRenewalService? renewalService,
    DriverCredentialService? credentialService,
    DriverVehicleService? vehicleService,
    DriverRegistrationRecoveryService? registrationRecoveryService,
  }) : renewalService = renewalService ?? DriverRenewalService(),
       credentialService = credentialService ?? DriverCredentialService(),
       vehicleService = vehicleService ?? DriverVehicleService(),
       registrationRecoveryService =
           registrationRecoveryService ?? DriverRegistrationRecoveryService();

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
  void initState() {
    super.initState();
    _recoverRegistrationDocuments();
  }

  Future<void> _recoverRegistrationDocuments() async {
    try {
      final recovered = await widget.registrationRecoveryService
          .recoverIfPossible(widget.driverId);
      if (!recovered || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your registration documents were recovered and attached for admin review.',
          ),
        ),
      );
    } catch (_) {
      // Manual Driver Hub uploads remain available when recovery is not possible.
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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
                _RequirementsTab(
                  driverId: widget.driverId,
                  profile: profile,
                  service: widget.credentialService,
                ),
                _VehicleDetailsTab(
                  driverId: widget.driverId,
                  profile: profile,
                  service: widget.vehicleService,
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
            showIcon: false,
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
          SizedBox(
            width: 48,
            height: 48,
            child: Icon(presentation.icon, color: PassengerUi.dark),
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
            showIcon: false,
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
  final String driverId;
  final _DriverHubProfile profile;
  final DriverCredentialService service;

  const _RequirementsTab({
    required this.driverId,
    required this.profile,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final documents = <(DriverCredentialType, String?, DateTime?)>[
      (
        DriverCredentialType.driversLicense,
        profile.driversLicenseUrl,
        profile.documentStatus.driversLicenseExpiry,
      ),
      (
        DriverCredentialType.orCr,
        profile.orCrUrl,
        profile.documentStatus.orCrExpiry,
      ),
      (DriverCredentialType.nbiClearance, profile.nbiClearanceUrl, null),
      (DriverCredentialType.selfie, profile.selfieUrl, null),
    ];

    return _HubTabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Requirements & Documents',
            subtitle:
                'Add missing credentials or replace an existing image. Changes are sent to admins for verification.',
            icon: Icons.description_rounded,
            accentColor: PassengerUi.accentBlue,
            showIcon: false,
          ),
          const SizedBox(height: 16),
          ...documents.map(
            (document) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EditableCredentialCard(
                key: ValueKey<DriverCredentialType>(document.$1),
                driverId: driverId,
                type: document.$1,
                imageUrl: document.$2,
                expiry: document.$3,
                service: service,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableCredentialCard extends StatefulWidget {
  final String driverId;
  final DriverCredentialType type;
  final String? imageUrl;
  final DateTime? expiry;
  final DriverCredentialService service;

  const _EditableCredentialCard({
    super.key,
    required this.driverId,
    required this.type,
    required this.imageUrl,
    required this.expiry,
    required this.service,
  });

  @override
  State<_EditableCredentialCard> createState() =>
      _EditableCredentialCardState();
}

class _EditableCredentialCardState extends State<_EditableCredentialCard> {
  final ImagePicker _imagePicker = ImagePicker();
  RegistrationImageSelection? _selectedFile;
  DateTime? _expiry;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _expiry = _futureExpiryOrNull(widget.expiry);
  }

  @override
  void didUpdateWidget(covariant _EditableCredentialCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.expiry != widget.expiry) {
      _expiry = _futureExpiryOrNull(widget.expiry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCredential = widget.imageUrl?.trim().isNotEmpty == true;
    final actionLabel = hasCredential ? 'Update credential' : 'Add credential';

    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(widget.type.label, style: PassengerUi.cardTitle),
                ),
                if (widget.expiry != null)
                  Text(
                    _formatDate(widget.expiry!),
                    style: PassengerUi.bodyText,
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: FirebaseStorageImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.cover,
              fallback: Container(
                color: PassengerUi.mutedSurface,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: PassengerUi.body,
                    ),
                    const SizedBox(height: 6),
                    Text('No credential uploaded', style: PassengerUi.bodyText),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: _isEditing
                ? _buildEditor(hasCredential)
                : SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: Key('credential-action-${widget.type.storageName}'),
                      onPressed: _isSaving
                          ? null
                          : () => setState(() => _isEditing = true),
                      icon: Icon(
                        hasCredential
                            ? Icons.edit_outlined
                            : Icons.add_photo_alternate_outlined,
                      ),
                      label: Text(actionLabel),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(bool hasCredential) {
    final type = widget.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          type.requiresExpiry
              ? 'Enter a valid expiry date. You can also choose a new image to replace the current credential.'
              : type == DriverCredentialType.selfie
              ? 'Capture a clear, current selfie using your camera.'
              : 'Choose a clear and readable image.',
          style: PassengerUi.bodyText,
        ),
        if (type.requiresExpiry) ...<Widget>[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: Key('credential-expiry-${type.storageName}'),
              onPressed: _isSaving ? null : _pickExpiry,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _expiry == null
                    ? 'Choose expiry date'
                    : 'Expiry: ${_formatDate(_expiry!)}',
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: Key('credential-picker-${type.storageName}'),
            onPressed: _isSaving ? null : _pickCredential,
            icon: Icon(
              type == DriverCredentialType.selfie
                  ? Icons.camera_alt_outlined
                  : Icons.upload_file_rounded,
            ),
            label: Text(
              _selectedFile == null
                  ? type == DriverCredentialType.selfie
                        ? 'Capture selfie'
                        : 'Choose image'
                  : type == DriverCredentialType.selfie
                  ? 'Recapture selfie'
                  : 'Change selected image',
            ),
          ),
        ),
        if (_selectedFile != null) ...<Widget>[
          const SizedBox(height: 12),
          RegistrationImagePreview(selection: _selectedFile!, height: 180),
        ],
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : _cancelEditing,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                key: Key('credential-submit-${type.storageName}'),
                onPressed:
                    !_isSaving &&
                        (_selectedFile != null ||
                            (hasCredential &&
                                type.requiresExpiry &&
                                !_isSameDate(_expiry, widget.expiry))) &&
                        (!type.requiresExpiry || _expiry != null)
                    ? _saveCredential
                    : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving' : 'Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickCredential() async {
    try {
      final source = widget.type == DriverCredentialType.selfie
          ? ImageSource.camera
          : ImageSource.gallery;
      final file = await _imagePicker.pickImage(source: source);
      if (file == null) return;
      final selection = await RegistrationImageSelection.fromXFile(file);
      if (mounted) setState(() => _selectedFile = selection);
    } on PlatformException {
      _showMessage(
        widget.type == DriverCredentialType.selfie
            ? 'Unable to open the camera. Check app permissions.'
            : 'Unable to open the gallery. Check app permissions.',
      );
    } on RegistrationImageSelectionException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to read that image. Please choose another file.');
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final firstDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final selected = await showDatePicker(
      context: context,
      initialDate: _expiry ?? firstDate.add(const Duration(days: 364)),
      firstDate: firstDate,
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: 'Select ${widget.type.label} expiry',
    );
    if (selected != null && mounted) setState(() => _expiry = selected);
  }

  Future<void> _saveCredential() async {
    final file = _selectedFile;
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      await widget.service.saveCredential(
        driverId: widget.driverId,
        type: widget.type,
        document: file,
        expiry: _expiry,
      );
      if (!mounted) return;
      setState(() {
        _selectedFile = null;
        _isEditing = false;
      });
      _showMessage(
        '${widget.type.label} sent for admin review. Your verified access and current approved document stay active.',
      );
    } on DriverCredentialUpdateException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(
        userFacingErrorMessage(
          error,
          fallback: 'Unable to save the credential. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _selectedFile = null;
      _expiry = _futureExpiryOrNull(widget.expiry);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static DateTime? _futureExpiryOrNull(DateTime? value) {
    return value != null && value.isAfter(DateTime.now()) ? value : null;
  }

  static bool _isSameDate(DateTime? first, DateTime? second) {
    if (first == null || second == null) return first == second;
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _VehicleDetailsTab extends StatefulWidget {
  final String driverId;
  final _DriverHubProfile profile;
  final DriverVehicleService service;

  const _VehicleDetailsTab({
    required this.driverId,
    required this.profile,
    required this.service,
  });

  @override
  State<_VehicleDetailsTab> createState() => _VehicleDetailsTabState();
}

class _VehicleDetailsTabState extends State<_VehicleDetailsTab> {
  static const List<String> _standardVehicleTypes = <String>[
    'Traditional Tricycle',
    'E-Tricycle (Bao-bao)',
    'Motorela / Custom',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  late String _vehicleType;
  RegistrationImageSelection? _frontPhoto;
  RegistrationImageSelection? _backPhoto;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _resetEditor();
  }

  @override
  void didUpdateWidget(covariant _VehicleDetailsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.profile != widget.profile) {
      _resetEditor();
    }
  }

  @override
  void dispose() {
    _colorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return _HubTabPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerPageHeader(
            title: 'Vehicle Details',
            subtitle:
                'Add missing vehicle information or update what passengers see. Changes are sent to admins for verification.',
            icon: Icons.local_taxi_rounded,
            accentColor: PassengerUi.secondary,
            showIcon: false,
          ),
          const SizedBox(height: 16),
          if (_isEditing) _buildEditor() else _buildDetails(profile),
        ],
      ),
    );
  }

  Widget _buildDetails(_DriverHubProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('vehicle-details-action'),
            onPressed: _isSaving
                ? null
                : () => setState(() => _isEditing = true),
            icon: Icon(
              _hasCompleteVehicleDetails(profile)
                  ? Icons.edit_outlined
                  : Icons.add_rounded,
            ),
            label: Text(
              _hasCompleteVehicleDetails(profile)
                  ? 'Update vehicle details'
                  : 'Add vehicle details',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PassengerSurfaceCard(
            child: Column(
              children: <Widget>[
                DropdownButtonFormField<String>(
                  key: const Key('vehicle-type-field'),
                  value: _vehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle type',
                    border: OutlineInputBorder(),
                  ),
                  items: _availableVehicleTypes
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _vehicleType = value);
                          }
                        },
                  validator: (value) => _required(value, 'Vehicle type'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('tricycle-color-field'),
                  controller: _colorController,
                  enabled: !_isSaving,
                  maxLength: 50,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tricycle color',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => _required(value, 'Tricycle color'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  key: const Key('plate-number-field'),
                  controller: _plateController,
                  enabled: !_isSaving,
                  maxLength: 50,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Plate / Franchise No.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      _required(value, 'Plate / Franchise No.'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildPhotoEditor(
            label: 'Front tricycle photo',
            existingUrl: widget.profile.tricycleFrontUrl,
            selection: _frontPhoto,
            keyName: 'front',
            onPick: () => _pickPhoto(isFront: true),
          ),
          const SizedBox(height: 12),
          _buildPhotoEditor(
            label: 'Back tricycle photo',
            existingUrl: widget.profile.tricycleBackUrl,
            selection: _backPhoto,
            keyName: 'back',
            onPick: () => _pickPhoto(isFront: false),
          ),
          const SizedBox(height: 14),
          Text(
            'Vehicle changes are sent for admin review. Verified accounts keep their current approved details and access while the review is pending.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _cancelEditing,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('vehicle-details-submit'),
                  onPressed: _canSave ? _saveVehicleDetails : null,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving' : 'Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoEditor({
    required String label,
    required String? existingUrl,
    required RegistrationImageSelection? selection,
    required String keyName,
    required VoidCallback onPick,
  }) {
    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(label, style: PassengerUi.cardTitle),
          ),
          if (selection != null)
            RegistrationImagePreview(selection: selection, height: 180)
          else
            SizedBox(
              width: double.infinity,
              height: 180,
              child: FirebaseStorageImage(
                imageUrl: existingUrl,
                fit: BoxFit.cover,
                fallback: Container(
                  color: PassengerUi.mutedSurface,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: PassengerUi.body,
                      ),
                      const SizedBox(height: 6),
                      Text('No photo uploaded', style: PassengerUi.bodyText),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('vehicle-$keyName-photo-picker'),
                onPressed: _isSaving ? null : onPick,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(
                  selection != null || _hasValue(existingUrl)
                      ? 'Replace photo'
                      : 'Choose photo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto({required bool isFront}) async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final selection = await RegistrationImageSelection.fromXFile(file);
      if (!mounted) return;
      setState(() {
        if (isFront) {
          _frontPhoto = selection;
        } else {
          _backPhoto = selection;
        }
      });
    } on PlatformException {
      _showMessage('Unable to open the gallery. Check app permissions.');
    } on RegistrationImageSelectionException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to read that image. Please choose another file.');
    }
  }

  Future<void> _saveVehicleDetails() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;
    if (!_hasEffectivePhotos) {
      _showMessage('Choose clear front and back tricycle photos.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.service.saveVehicleDetails(
        driverId: widget.driverId,
        vehicleType: _vehicleType,
        tricycleColor: _colorController.text,
        plateNumber: _plateController.text,
        existingFrontUrl: widget.profile.tricycleFrontUrl,
        existingBackUrl: widget.profile.tricycleBackUrl,
        frontPhoto: _frontPhoto,
        backPhoto: _backPhoto,
      );
      if (!mounted) return;
      setState(() {
        _frontPhoto = null;
        _backPhoto = null;
        _isEditing = false;
      });
      _showMessage(
        'Vehicle details sent for admin review. Your verified access and current approved details stay active.',
      );
    } on DriverVehicleUpdateException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(
        userFacingErrorMessage(
          error,
          fallback: 'Unable to save vehicle details. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _frontPhoto = null;
      _backPhoto = null;
      _resetEditor();
    });
  }

  void _resetEditor() {
    final existingType = widget.profile.vehicleType.trim();
    _vehicleType = existingType.isEmpty
        ? _standardVehicleTypes.first
        : existingType;
    _colorController.text = widget.profile.tricycleColor;
    _plateController.text = widget.profile.plateNumber;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> get _availableVehicleTypes {
    if (_standardVehicleTypes.contains(_vehicleType)) {
      return _standardVehicleTypes;
    }
    return <String>[..._standardVehicleTypes, _vehicleType];
  }

  bool get _hasEffectivePhotos =>
      (_frontPhoto != null || _hasValue(widget.profile.tricycleFrontUrl)) &&
      (_backPhoto != null || _hasValue(widget.profile.tricycleBackUrl));

  bool get _hasChanges =>
      _frontPhoto != null ||
      _backPhoto != null ||
      _vehicleType.trim() != widget.profile.vehicleType.trim() ||
      _colorController.text.trim() != widget.profile.tricycleColor.trim() ||
      _plateController.text.trim() != widget.profile.plateNumber.trim();

  bool get _canSave =>
      !_isSaving &&
      _vehicleType.trim().isNotEmpty &&
      _colorController.text.trim().isNotEmpty &&
      _plateController.text.trim().isNotEmpty &&
      _hasEffectivePhotos &&
      _hasChanges;

  static bool _hasCompleteVehicleDetails(_DriverHubProfile profile) =>
      profile.vehicleType.trim().isNotEmpty &&
      profile.tricycleColor.trim().isNotEmpty &&
      profile.plateNumber.trim().isNotEmpty &&
      _hasValue(profile.tricycleFrontUrl) &&
      _hasValue(profile.tricycleBackUrl);

  static bool _hasValue(String? value) => value?.trim().isNotEmpty == true;

  static String? _required(String? value, String label) =>
      value?.trim().isEmpty ?? true ? '$label is required' : null;
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

  const _HubDocumentCard({required this.label, this.imageUrl});

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

  const _HubValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? 'Not provided' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
      isVerified: isVerifiedAccountData(data),
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
