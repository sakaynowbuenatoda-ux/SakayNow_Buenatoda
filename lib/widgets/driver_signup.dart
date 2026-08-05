import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/auth/registration_service.dart';
import '../core/auth/signup_validators.dart';
import '../pages/auth/auth_gate.dart';
import '../pages/auth/auth_ui.dart';
import '../utils/user_facing_error_message.dart';
import 'account_creation_success_dialog.dart';
import 'registration_image_preview.dart';
import 'terms_and_privacy_policy_sheet.dart';

class DriverSignUp extends StatefulWidget {
  const DriverSignUp({super.key});

  @override
  State<DriverSignUp> createState() => _DriverSignUpState();
}

class _DriverSignUpState extends State<DriverSignUp> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _tricycleColorController = TextEditingController();
  final _plateNumberController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _agreeToPolicies = false;
  bool _showValidationErrors = false;

  String? _gender;
  String? _vehicleType = 'Traditional Tricycle';
  RegistrationImageSelection? _nbiFile;
  RegistrationImageSelection? _licenseFile;
  RegistrationImageSelection? _selfieFile;
  RegistrationImageSelection? _orCrFile;
  RegistrationImageSelection? _tricycleFrontFile;
  RegistrationImageSelection? _tricycleBackFile;

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _tricycleColorController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickNbi() async {
    final selection = await _pickRegistrationImage(ImageSource.gallery);
    if (!mounted || selection == null) return;
    setState(() => _nbiFile = selection);
  }

  Future<void> _pickLicense() async {
    final selection = await _pickRegistrationImage(ImageSource.gallery);
    if (!mounted || selection == null) return;
    setState(() => _licenseFile = selection);
  }

  Future<void> _captureSelfie() async {
    final selection = await _pickRegistrationImage(ImageSource.camera);
    if (!mounted || selection == null) return;
    setState(() => _selfieFile = selection);
  }

  Future<void> _pickOrCr() async {
    final selection = await _pickRegistrationImage(ImageSource.gallery);
    if (!mounted || selection == null) return;
    setState(() => _orCrFile = selection);
  }

  Future<void> _pickTricycleFront() async {
    final selection = await _pickRegistrationImage(ImageSource.gallery);
    if (!mounted || selection == null) return;
    setState(() => _tricycleFrontFile = selection);
  }

  Future<void> _pickTricycleBack() async {
    final selection = await _pickRegistrationImage(ImageSource.gallery);
    if (!mounted || selection == null) return;
    setState(() => _tricycleBackFile = selection);
  }

  Future<RegistrationImageSelection?> _pickRegistrationImage(
    ImageSource source,
  ) async {
    try {
      final file = await _picker.pickImage(source: source);
      if (file == null) return null;
      return await RegistrationImageSelection.fromXFile(file);
    } on PlatformException {
      _showMessage(
        source == ImageSource.camera
            ? 'Unable to open camera. Please check app permissions.'
            : 'Unable to open gallery. Please check app permissions.',
      );
    } on RegistrationImageSelectionException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Unable to read selected image. Please try another photo.');
    }
    return null;
  }

  void _showPoliciesSheet() {
    showTermsAndPrivacyPolicySheet(context);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateGender(String? value) {
    return value == null ? 'Gender is required' : null;
  }

  bool _validateBasicInfo() {
    final formState = _formKey.currentState;
    if (formState != null) {
      return formState.validate();
    }

    final validations = <String?>[
      SignupValidators.email(_emailController.text),
      SignupValidators.accountFirstName(_firstNameController.text),
      SignupValidators.name(_lastNameController.text, fieldName: 'Last name'),
      SignupValidators.age(
        _ageController.text,
        minimumAge: SignupValidators.driverMinimumAge,
      ),
      _validateGender(_gender),
      SignupValidators.password(_passwordController.text),
      SignupValidators.confirmPassword(
        _confirmPasswordController.text,
        _passwordController.text,
      ),
    ];

    return validations.every((error) => error == null);
  }

  Future<void> _showSuccessAndNavigate() async {
    showAccountCreationSuccessDialog(context);
    await Future<void>.delayed(const Duration(milliseconds: 1550));

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthGate()),
      (route) => false,
    );
  }

  Future<void> _submit() async {
    setState(() => _showValidationErrors = true);

    if (!_validateBasicInfo()) {
      setState(() => _currentStep = 0);
      _showMessage('Please review the required fields in Basic Information.');
      return;
    }

    if (_vehicleType == null ||
        _tricycleColorController.text.trim().isEmpty ||
        _plateNumberController.text.trim().isEmpty ||
        _orCrFile == null ||
        _tricycleFrontFile == null ||
        _tricycleBackFile == null) {
      setState(() => _currentStep = 1);
      _showMessage(
        'Please review and complete all required vehicle information and photos.',
      );
      return;
    }

    if (_nbiFile == null || _licenseFile == null) {
      setState(() => _currentStep = 2);
      _showMessage('Please upload NBI clearance and driver\'s license.');
      return;
    }

    if (_selfieFile == null) {
      setState(() => _currentStep = 2);
      _showMessage('Please capture a live selfie.');
      return;
    }

    if (!_agreeToPolicies) {
      setState(() => _currentStep = 2);
      _showMessage(
        'You must agree to the Terms and Conditions and Privacy Policy.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await RegistrationService.registerDriver(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        age: _ageController.text.trim(),
        gender: _gender,
        vehicleType: _vehicleType!,
        tricycleColor: _tricycleColorController.text.trim(),
        plateNumber: _plateNumberController.text.trim(),
        nbiFile: _nbiFile!,
        licenseFile: _licenseFile!,
        selfieFile: _selfieFile!,
        orCrFile: _orCrFile!,
        tricycleFrontFile: _tricycleFrontFile!,
        tricycleBackFile: _tricycleBackFile!,
      );

      if (!mounted) return;
      await _showSuccessAndNavigate();
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Signup failed.';
      if (e.code == 'email-already-in-use') {
        message = 'That email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'operation-not-allowed') {
        message =
            'Email signup is not available right now. Please contact an admin.';
      }

      if (!mounted) return;
      _showMessage(message);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showMessage(_firebaseErrorMessage(e));
    } on RegistrationDocumentUploadException {
      if (!mounted) return;
      _showMessage(
        'Account created, but your verification photos were not uploaded. You can add them later from your profile.',
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AuthGate()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        userFacingErrorMessage(
          e,
          fallback: 'Unable to create your driver account. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _firebaseErrorMessage(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Unable to save account details right now. Please contact an admin.';
    }

    if (e.code == 'network-request-failed' || e.code == 'unavailable') {
      return 'Network error. Please check your connection and try again.';
    }

    return userFacingErrorMessage(
      e,
      fallback: 'Signup failed. Please try again.',
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AuthUi.accentBlue),
      filled: true,
      fillColor: AuthUi.mutedSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(
        color: AuthUi.accentBlue,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: TextStyle(
        color: AuthUi.primary,
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AuthUi.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AuthUi.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AuthUi.primary, width: 1.4),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthUi.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AuthUi.title,
            ),
          ),
          SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _uploadTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required RegistrationImageSelection? file,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuthUi.mutedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AuthUi.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AuthUi.primary, size: 22),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.5,
                        color: AuthUi.title,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(Icons.upload_file_rounded),
              label: Text(file == null ? 'Choose file' : 'Replace file'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AuthUi.primary,
                side: BorderSide(color: AuthUi.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (file != null) ...[
            SizedBox(height: 14),
            RegistrationImagePreview(
              selection: file,
              height: 180,
              borderRadius: 16,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      ('1', 'Basic Info'),
      ('2', 'Vehicle Details'),
      ('3', 'Driver IDs'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(steps.length, (index) {
            final isActive = _currentStep == index;
            final isDone = _currentStep > index;
            final itemWidth = compact
                ? (constraints.maxWidth - 10) / 2
                : (constraints.maxWidth - 20) / 3;

            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
                decoration: BoxDecoration(
                  color: isActive || isDone
                      ? AuthUi.title.withValues(alpha: 0.06)
                      : AuthUi.mutedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive || isDone
                        ? AuthUi.title.withValues(alpha: 0.16)
                        : AuthUi.border,
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isDone || isActive
                          ? AuthUi.primary
                          : Color(0xFFD1D5DB),
                      child: isDone
                          ? Icon(Icons.check, size: 14, color: Colors.white)
                          : Text(
                              steps[index].$1,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      steps[index].$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 12 : 12.5,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AuthUi.primary : AuthUi.body,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    final isLast = _currentStep == 2;

    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() => _currentStep -= 1),
              style: OutlinedButton.styleFrom(
                foregroundColor: AuthUi.title,
                side: BorderSide(color: Color(0xFFD1D5DB)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Back',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (_currentStep > 0) SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    if (isLast) {
                      _submit();
                    } else {
                      if (_currentStep == 0) {
                        setState(() => _showValidationErrors = true);
                        if (!_validateBasicInfo()) {
                          return;
                        }
                      } else if (_currentStep == 1) {
                        setState(() => _showValidationErrors = true);
                        final formValid =
                            _vehicleFormKey.currentState?.validate() ?? false;
                        if (!formValid ||
                            _vehicleType == null ||
                            _tricycleColorController.text.trim().isEmpty ||
                            _plateNumberController.text.trim().isEmpty) {
                          _showMessage(
                            'Please complete all required vehicle text fields.',
                          );
                          return;
                        }
                        if (_orCrFile == null ||
                            _tricycleFrontFile == null ||
                            _tricycleBackFile == null) {
                          _showMessage(
                            'Please upload OR/CR document and front & back tricycle photos.',
                          );
                          return;
                        }
                      }
                      setState(() => _currentStep += 1);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AuthUi.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Text(
                    isLast ? 'Create Account' : 'Continue',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoStep() {
    return _sectionCard(
      title: 'Basic Information',
      subtitle: 'Please enter your personal details accurately.',
      child: Form(
        key: _formKey,
        autovalidateMode: _showValidationErrors
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: _inputDecoration(
                label: 'Email',
                icon: Icons.email_outlined,
              ),
              validator: SignupValidators.email,
            ),
            SizedBox(height: 14),
            _buildResponsiveFieldRow(
              first: TextFormField(
                controller: _firstNameController,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  label: 'First Name',
                  icon: Icons.person_outline,
                ),
                validator: SignupValidators.accountFirstName,
              ),
              second: TextFormField(
                controller: _lastNameController,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  label: 'Last Name',
                  icon: Icons.badge_outlined,
                ),
                validator: (value) =>
                    SignupValidators.name(value, fieldName: 'Last name'),
              ),
            ),
            SizedBox(height: 14),
            _buildResponsiveFieldRow(
              first: TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration(
                  label: 'Age',
                  icon: Icons.cake_outlined,
                ),
                validator: (value) => SignupValidators.age(
                  value,
                  minimumAge: SignupValidators.driverMinimumAge,
                ),
              ),
              second: DropdownButtonFormField<String>(
                value: _gender,
                decoration: _inputDecoration(
                  label: 'Gender',
                  icon: Icons.wc_outlined,
                ),
                items: [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => _gender = value),
                validator: _validateGender,
              ),
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _inputDecoration(
                label: 'Password',
                icon: Icons.lock_outline_rounded,
              ),
              validator: SignupValidators.password,
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              decoration: _inputDecoration(
                label: 'Confirm Password',
                icon: Icons.verified_user_outlined,
              ),
              validator: (value) => SignupValidators.confirmPassword(
                value,
                _passwordController.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleStep() {
    return _sectionCard(
      title: 'Vehicle Information & Photos',
      subtitle: 'Enter your tricycle details and attach required photos.',
      child: Form(
        key: _vehicleFormKey,
        autovalidateMode: _showValidationErrors
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _vehicleType,
              decoration: _inputDecoration(
                label: 'Vehicle Type',
                icon: Icons.electric_rickshaw_rounded,
              ),
              items: [
                DropdownMenuItem(
                  value: 'Traditional Tricycle',
                  child: Text('Traditional Tricycle'),
                ),
                DropdownMenuItem(
                  value: 'E-Tricycle (Bao-bao)',
                  child: Text('E-Tricycle (Bao-bao)'),
                ),
                DropdownMenuItem(
                  value: 'Motorela / Custom',
                  child: Text('Motorela / Custom'),
                ),
              ],
              onChanged: (value) => setState(() => _vehicleType = value),
              validator: (val) =>
                  val == null ? 'Vehicle type is required' : null,
            ),
            SizedBox(height: 14),
            _buildResponsiveFieldRow(
              first: TextFormField(
                controller: _tricycleColorController,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  label: 'Tricycle Color',
                  icon: Icons.color_lens_outlined,
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Color is required'
                    : null,
              ),
              second: TextFormField(
                controller: _plateNumberController,
                textInputAction: TextInputAction.done,
                decoration: _inputDecoration(
                  label: 'Plate / Franchise No.',
                  icon: Icons.confirmation_number_outlined,
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Plate/Franchise No. required'
                    : null,
              ),
            ),
            SizedBox(height: 18),
            _uploadTile(
              title: 'OR/CR Document',
              subtitle: 'Upload Official Receipt / Certificate of Registration.',
              icon: Icons.article_outlined,
              onTap: _pickOrCr,
              file: _orCrFile,
            ),
            SizedBox(height: 14),
            _uploadTile(
              title: 'Front Tricycle Photo',
              subtitle: 'Clear front view showing vehicle plate or body.',
              icon: Icons.directions_car_filled_outlined,
              onTap: _pickTricycleFront,
              file: _tricycleFrontFile,
            ),
            SizedBox(height: 14),
            _uploadTile(
              title: 'Back Tricycle Photo',
              subtitle: 'Clear back or side view of your tricycle.',
              icon: Icons.local_taxi_rounded,
              onTap: _pickTricycleBack,
              file: _tricycleBackFile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverIdAndSelfieStep() {
    return _sectionCard(
      title: 'Driver Credentials & Selfie',
      subtitle: 'Upload your valid driver documents and capture a live selfie.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _uploadTile(
            title: 'NBI Clearance',
            subtitle: 'Upload a readable and valid NBI clearance image.',
            icon: Icons.description_outlined,
            onTap: _pickNbi,
            file: _nbiFile,
          ),
          SizedBox(height: 14),
          _uploadTile(
            title: 'Driver\'s License',
            subtitle: 'Upload the front side of your valid driver\'s license.',
            icon: Icons.credit_card_outlined,
            onTap: _pickLicense,
            file: _licenseFile,
          ),
          SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AuthUi.mutedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuthUi.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AuthUi.accentBlue,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Camera only. Gallery images are not allowed for selfie verification.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AuthUi.body,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _captureSelfie,
              icon: Icon(Icons.camera_alt_outlined),
              label: Text('Capture Selfie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AuthUi.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_selfieFile != null) ...[
            SizedBox(height: 14),
            RegistrationImagePreview(selection: _selfieFile!, height: 210),
          ],
          SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AuthUi.mutedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuthUi.border),
            ),
            child: CheckboxListTile(
              value: _agreeToPolicies,
              onChanged: (value) {
                setState(() => _agreeToPolicies = value ?? false);
              },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AuthUi.primary,
              title: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: AuthUi.title,
                  ),
                  children: [
                    TextSpan(
                      text:
                          'I agree to the Terms and Conditions and Privacy Policy ',
                    ),
                    TextSpan(
                      text: 'View',
                      style: TextStyle(
                        color: AuthUi.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = _showPoliciesSheet,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registration',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: AuthUi.title,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Complete the steps below to create your driver account for admin verification.',
              style: TextStyle(
                fontSize: 13.5,
                color: AuthUi.body,
                height: 1.45,
              ),
            ),
            SizedBox(height: 18),
            _buildStepIndicator(),
            SizedBox(height: 20),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(_currentStep),
                child: Column(
                  children: [
                    if (_currentStep == 0) _buildBasicInfoStep(),
                    if (_currentStep == 1) _buildVehicleStep(),
                    if (_currentStep == 2) _buildDriverIdAndSelfieStep(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 18),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveFieldRow({
    required Widget first,
    required Widget second,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [first, SizedBox(height: 14), second]);
        }

        return Row(
          children: [
            Expanded(child: first),
            SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
