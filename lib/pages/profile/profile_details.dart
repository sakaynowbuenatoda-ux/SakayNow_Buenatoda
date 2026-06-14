import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/signup_validators.dart';
import '../../services/profile_picture_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'models/profile_view_data.dart';
import 'profile_picture_sheet.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_state_layout.dart';

class ProfileDetailsLoaderPage extends StatelessWidget {
  final String userId;

  const ProfileDetailsLoaderPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: PassengerUi.background,
            body: const SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data?.exists != true) {
          return Scaffold(
            backgroundColor: PassengerUi.background,
            body: SafeArea(
              child: ProfileStateLayout(
                title: 'Profile Details',
                child: PassengerEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load details',
                  description: snapshot.hasError
                      ? userFacingErrorMessage(
                          snapshot.error,
                          fallback:
                              'Unable to load profile details. Please try again.',
                        )
                      : 'No profile details were found for this account.',
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() ?? <String, dynamic>{};
        return ProfileDetailsPage(
          profile: ProfileViewData.fromMap(data, userId),
        );
      },
    );
  }
}

class ProfileDetailsPage extends StatefulWidget {
  final ProfileViewData profile;

  const ProfileDetailsPage({super.key, required this.profile});

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  final ProfilePictureService _profilePictureService = ProfilePictureService();
  late ProfileViewData _profile;
  bool _isSaving = false;
  bool _isUploadingProfilePicture = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  @override
  void didUpdateWidget(covariant ProfileDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profile.userId != widget.profile.userId) {
      _profile = widget.profile;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      body: SafeArea(
        child: PassengerPageContainer(
          maxContentWidth: PassengerUi.settingsContentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: ProfileHeader(title: 'Profile Details')),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isSaving || _isUploadingProfilePicture
                        ? null
                        : _openEditDialog,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined, size: 18),
                    label: Text(_isSaving ? 'Saving' : 'Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ProfilePictureCard(
                profile: _profile,
                isUploading: _isUploadingProfilePicture,
                onChangePressed: _changeProfilePicture,
              ),
              const SizedBox(height: 14),
              PassengerSurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'First Name',
                      value: _profile.firstName,
                    ),
                    _DetailRow(
                      icon: Icons.badge_outlined,
                      label: 'Last Name',
                      value: _profile.lastName,
                    ),
                    _DetailRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: _profile.email,
                    ),
                    _DetailRow(
                      icon: Icons.work_outline_rounded,
                      label: 'Role',
                      value: _profile.roleLabel,
                    ),
                    _DetailRow(
                      icon: Icons.wc_rounded,
                      label: 'Gender',
                      value: _profile.genderLabel,
                    ),
                    _DetailRow(
                      icon: Icons.cake_outlined,
                      label: 'Age',
                      value: _profile.ageLabel,
                    ),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Joined At',
                      value: _profile.joinedAtLabel,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditDialog() async {
    final result = await showDialog<_ProfileEditResult>(
      context: context,
      barrierDismissible: !_isSaving,
      builder: (_) => _EditProfileDetailsDialog(profile: _profile),
    );

    if (result == null || !mounted) {
      return;
    }

    await _saveProfileEdits(result);
  }

  Future<void> _saveProfileEdits(_ProfileEditResult result) async {
    setState(() => _isSaving = true);

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_profile.userId);

      await userRef.update(<String, dynamic>{
        'age': result.age,
        'gender': result.gender,
        'updated_at': FieldValue.serverTimestamp(),
      });

      final updatedSnapshot = await userRef.get();
      final updatedData = updatedSnapshot.data() ?? <String, dynamic>{};

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = ProfileViewData.fromMap(updatedData, _profile.userId);
      });

      await _showValidationDialog(
        icon: Icons.check_circle_rounded,
        iconColor: PassengerUi.successText,
        message: 'Profile details updated',
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.code == 'permission-denied'
          ? 'You can only update your own age and gender.'
          : userFacingErrorMessage(
              error,
              fallback: 'Unable to update profile details.',
            );
      await _showValidationDialog(
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red.shade600,
        message: message,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      await _showValidationDialog(
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red.shade600,
        message: userFacingErrorMessage(
          error,
          fallback: 'Unable to update profile details. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changeProfilePicture() async {
    if (_isUploadingProfilePicture) {
      return;
    }

    if (!_profile.canUpdateProfilePicture) {
      await _showValidationDialog(
        icon: Icons.schedule_rounded,
        iconColor: PassengerUi.highlightAmber,
        message:
            'Profile picture can be changed again on ${_profile.profilePictureNextUpdateLabel}.',
      );
      return;
    }

    final source = await showProfilePictureSourceSheet(context);
    if (source == null || !mounted) {
      return;
    }

    setState(() => _isUploadingProfilePicture = true);

    try {
      final selection = await _profilePictureService.pickProfilePicture(
        userId: _profile.userId,
        source: source,
      );

      if (selection == null || !mounted) {
        return;
      }

      setState(() => _isUploadingProfilePicture = false);
      final confirmed = await showProfilePictureConfirmationDialog(
        context,
        selection: selection,
      );
      if (!mounted || !confirmed) {
        return;
      }

      setState(() => _isUploadingProfilePicture = true);
      await _profilePictureService.uploadProfilePicture(
        userId: _profile.userId,
        selection: selection,
      );

      final updatedSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_profile.userId)
          .get();
      final updatedData = updatedSnapshot.data() ?? <String, dynamic>{};

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = ProfileViewData.fromMap(updatedData, _profile.userId);
      });

      await _showValidationDialog(
        icon: Icons.check_circle_rounded,
        iconColor: PassengerUi.successText,
        message: 'Profile picture updated',
      );
    } on ProfilePictureLimitException catch (error) {
      if (!mounted) {
        return;
      }

      await _showValidationDialog(
        icon: Icons.schedule_rounded,
        iconColor: PassengerUi.highlightAmber,
        message:
            'Profile picture can be changed again on ${_formatDate(error.nextAvailableAt)}.',
      );
    } on ProfilePictureUploadException catch (error) {
      if (!mounted) {
        return;
      }

      await _showValidationDialog(
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red.shade600,
        message: error.message,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      await _showValidationDialog(
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red.shade600,
        message: userFacingErrorMessage(
          error,
          fallback: 'Unable to update profile picture. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfilePicture = false);
      }
    }
  }

  Future<void> _showValidationDialog({
    required IconData icon,
    required Color iconColor,
    required String message,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.10),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, _, _) {
        Future<void>.delayed(const Duration(milliseconds: 1200), () {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        });

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 270,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: PassengerUi.surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PassengerUi.border),
                boxShadow: PassengerUi.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: PassengerUi.valueText.copyWith(fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime value) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _ProfilePictureCard extends StatelessWidget {
  final ProfileViewData profile;
  final bool isUploading;
  final VoidCallback onChangePressed;

  const _ProfilePictureCard({
    required this.profile,
    required this.isUploading,
    required this.onChangePressed,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: PassengerUi.blueSoft,
              shape: BoxShape.circle,
              border: Border.all(color: PassengerUi.border),
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  FirebaseStorageImage(
                    imageUrl: profile.profileImageUrl,
                    fit: BoxFit.cover,
                    fallback: Container(
                      alignment: Alignment.center,
                      color: PassengerUi.blueSoft,
                      child: Text(
                        profile.initials,
                        style: PassengerUi.sectionTitle.copyWith(
                          color: PassengerUi.accentBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (isUploading)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Profile Picture', style: PassengerUi.cardTitle),
                const SizedBox(height: 3),
                Text(
                  profile.canUpdateProfilePicture
                      ? 'Available now'
                      : 'Available ${profile.profilePictureNextUpdateLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isUploading ? null : onChangePressed,
            icon: isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_outlined),
            tooltip: 'Change profile picture',
          ),
        ],
      ),
    );
  }
}

class _EditProfileDetailsDialog extends StatefulWidget {
  final ProfileViewData profile;

  const _EditProfileDetailsDialog({required this.profile});

  @override
  State<_EditProfileDetailsDialog> createState() =>
      _EditProfileDetailsDialogState();
}

class _EditProfileDetailsDialogState extends State<_EditProfileDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ageController;
  String? _gender;

  static const double _dialogHorizontalInset = 24;
  static const double _dialogVerticalInset = 24;
  static const double _dialogReservedHorizontalSpace = 48;
  static const double _dialogMaxContentWidth = 340;

  static const List<DropdownMenuItem<String>> _genderOptions =
      <DropdownMenuItem<String>>[
        DropdownMenuItem(value: 'male', child: Text('Male')),
        DropdownMenuItem(value: 'female', child: Text('Female')),
        DropdownMenuItem(value: 'other', child: Text('Other')),
      ];

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(text: widget.profile.age);
    _gender = _normalizeGender(widget.profile.gender);
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableContentWidth =
        MediaQuery.sizeOf(context).width -
        (_dialogHorizontalInset * 2) -
        _dialogReservedHorizontalSpace;
    final dialogContentWidth = availableContentWidth
        .clamp(0.0, _dialogMaxContentWidth)
        .toDouble();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: _dialogHorizontalInset,
        vertical: _dialogVerticalInset,
      ),
      backgroundColor: PassengerUi.surface,
      surfaceTintColor: PassengerUi.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PassengerUi.accentBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.edit_outlined, color: PassengerUi.accentBlue),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Edit Details', style: PassengerUi.cardTitle)),
        ],
      ),
      content: SizedBox(
        width: dialogContentWidth,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: _validateAge,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                items: _genderOptions,
                validator: (value) =>
                    value == null ? 'Gender is required' : null,
                onChanged: (value) => setState(() => _gender = value),
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: PassengerUi.body)),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Save'),
        ),
      ],
    );
  }

  String? _validateAge(String? value) {
    return SignupValidators.age(
      value,
      minimumAge: widget.profile.isDriver
          ? SignupValidators.driverMinimumAge
          : SignupValidators.passengerMinimumAge,
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    Navigator.of(context).pop(
      _ProfileEditResult(
        age: int.parse(_ageController.text.trim()),
        gender: _gender!,
      ),
    );
  }

  static String? _normalizeGender(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'male' ||
        normalized == 'female' ||
        normalized == 'other') {
      return normalized;
    }

    return null;
  }
}

class _ProfileEditResult {
  final int age;
  final String gender;

  const _ProfileEditResult({required this.age, required this.gender});
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedValue = value.isEmpty ? 'Not set' : value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : PassengerUi.border,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTight = constraints.maxWidth < 390;

          if (isTight) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DetailIcon(icon: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        resolvedValue,
                        style: PassengerUi.valueText.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _DetailIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: PassengerUi.bodyText.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SelectableText(
                  resolvedValue,
                  textAlign: TextAlign.right,
                  style: PassengerUi.valueText.copyWith(fontSize: 14),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailIcon extends StatelessWidget {
  final IconData icon;

  const _DetailIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: PassengerUi.blueSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: PassengerUi.accentBlue),
    );
  }
}
