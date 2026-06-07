import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/auth/registration_service.dart';
import '../core/auth/signup_validators.dart';
import '../pages/auth/auth_gate.dart';
import '../pages/auth/auth_ui.dart';
import 'account_creation_success_dialog.dart';
import 'terms_and_privacy_policy_sheet.dart';

class PassengerSignup extends StatefulWidget {
  const PassengerSignup({super.key});

  @override
  State<PassengerSignup> createState() => _PassengerSignupState();
}

class _PassengerSignupState extends State<PassengerSignup> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _agreeToPolicies = false;
  bool _showValidationErrors = false;

  String? _gender;
  String _passengerType = 'regular';
  File? _idFile;
  File? _selfieFile;

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickId() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (!mounted || file == null) return;
      setState(() => _idFile = File(file.path));
    } on PlatformException {
      _showMessage('Unable to open gallery. Please check app permissions.');
    }
  }

  Future<void> _captureSelfie() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.camera);
      if (!mounted || file == null) return;
      setState(() => _selfieFile = File(file.path));
    } on PlatformException {
      _showMessage('Unable to open camera. Please check app permissions.');
    }
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
        minimumAge: SignupValidators.passengerMinimumAge,
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

    if (_idFile == null) {
      setState(() => _currentStep = 1);
      _showMessage('Please upload an ID.');
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
      await RegistrationService.registerPassenger(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        age: _ageController.text.trim(),
        gender: _gender,
        passengerType: _passengerType,
        idFile: _idFile!,
        selfieFile: _selfieFile!,
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
        message = 'Email and password signup is disabled in Firebase Auth.';
      }

      if (!mounted) return;
      _showMessage(message);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showMessage(_firebaseErrorMessage(e));
    } on RegistrationDocumentUploadException {
      if (!mounted) return;
      _showMessage(
        'Account created, but document upload failed. You can update your documents later.',
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AuthGate()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _firebaseErrorMessage(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Unable to save account details. Please check Firebase rules.';
    }

    if (e.code == 'network-request-failed' || e.code == 'unavailable') {
      return 'Network error. Please check your connection and try again.';
    }

    return e.message ?? 'Signup failed. Please try again.';
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
              fontWeight: FontWeight.w700,
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
    required File? file,
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
                        fontWeight: FontWeight.w700,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                file,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [('1', 'Basic Info'), ('2', 'ID Upload'), ('3', 'Selfie')];

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
      subtitle: 'Please enter your details accurately.',
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
                  minimumAge: SignupValidators.passengerMinimumAge,
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
            DropdownButtonFormField<String>(
              value: _passengerType,
              decoration: _inputDecoration(
                label: 'Passenger Type',
                icon: Icons.school_outlined,
              ),
              items: [
                DropdownMenuItem(value: 'regular', child: Text('Regular')),
                DropdownMenuItem(value: 'student', child: Text('Student')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _passengerType = value);
                }
              },
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

  Widget _buildIdStep() {
    return _sectionCard(
      title: 'ID Verification',
      subtitle: 'Upload a clear and readable school ID or valid government ID.',
      child: _uploadTile(
        title: 'Identification Upload',
        subtitle: 'Accepted: school ID or valid government-issued ID.',
        icon: Icons.badge_outlined,
        onTap: _pickId,
        file: _idFile,
      ),
    );
  }

  Widget _buildSelfieStep() {
    return _sectionCard(
      title: 'Selfie Verification',
      subtitle: 'Take a live selfie using your camera for identity checking.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selfieFile!,
                height: 210,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
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
          if (!_agreeToPolicies)
            Padding(
              padding: EdgeInsets.only(top: 8, left: 12),
              child: Text(
                'You must agree before creating an account.',
                style: TextStyle(fontSize: 12.5, color: AuthUi.primary),
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
              'Passenger Registration',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AuthUi.title,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Complete the steps below to create your passenger account.',
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
                    if (_currentStep == 1) _buildIdStep(),
                    if (_currentStep == 2) _buildSelfieStep(),
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
