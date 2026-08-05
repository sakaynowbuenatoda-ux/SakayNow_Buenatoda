import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth/registration_service.dart';
import '../core/auth/signup_validators.dart';
import '../pages/auth/auth_gate.dart';
import '../pages/auth/auth_ui.dart';
import '../utils/user_facing_error_message.dart';
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

  bool _isSubmitting = false;
  bool _agreeToPolicies = false;
  bool _showValidationErrors = false;

  String? _gender;
  String _passengerType = 'regular';

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
      _showMessage('Please review the required fields above.');
      return;
    }

    if (!_agreeToPolicies) {
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
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        userFacingErrorMessage(
          e,
          fallback: 'Unable to create your account. Please try again.',
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
      padding: const EdgeInsets.all(16),
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
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AuthUi.title,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: AuthUi.body),
          ),
          SizedBox(height: 16),
          child,
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
              'Passenger Quick Registration',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AuthUi.title,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Create your passenger account instantly and start booking rides.',
              style: TextStyle(
                fontSize: 13.5,
                color: AuthUi.body,
                height: 1.45,
              ),
            ),
            SizedBox(height: 20),
            _sectionCard(
              title: 'Account Information',
              subtitle: 'Enter your basic details to register immediately.',
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
                        DropdownMenuItem(
                          value: 'senior_citizen',
                          child: Text('Senior Citizen'),
                        ),
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
                    if (!_agreeToPolicies && _showValidationErrors)
                      Padding(
                        padding: EdgeInsets.only(top: 8, left: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'You must agree before creating an account.',
                            style: TextStyle(fontSize: 12.5, color: AuthUi.primary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuthUi.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Create Passenger Account',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
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
