import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/signup_validators.dart';
import '../../services/admin_account_service.dart';
import 'widgets/admin_shared.dart';

class AdminCreateAccountPage extends StatefulWidget {
  const AdminCreateAccountPage({super.key});

  @override
  State<AdminCreateAccountPage> createState() => _AdminCreateAccountPageState();
}

class _AdminCreateAccountPageState extends State<AdminCreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AdminAccountService _accountService = AdminAccountService();

  String? _gender;
  bool _isSubmitting = false;

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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _accountService.createAdminAccount(
        email: _emailController.text,
        password: _passwordController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        age: _ageController.text,
        gender: _gender ?? '',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin account created successfully.')),
      );
      Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      _showMessage(error.message ?? 'Unable to create admin account.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to create admin account: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateGender(String? value) {
    return value == null ? 'Gender is required' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminUi.background,
      appBar: AppBar(
        backgroundColor: AdminUi.surface,
        surfaceTintColor: AdminUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: AdminUi.title),
        ),
        title: Text('Create Admin Account', style: AdminUi.cardTitle),
      ),
      body: AdminPageContainer(
        maxContentWidth: AdminUi.formContentWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdminSectionIntro(
              title: 'Create Admin Account',
              subtitle:
                  'Add a verified admin profile. The role is fixed to admin and the reserved name admin cannot be reused.',
            ),
            const SizedBox(height: 16),
            AdminSurfaceCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account Information', style: AdminUi.cardTitle),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: AdminUi.inputDecoration(
                        labelText: 'Email',
                        hintText: 'Official admin email',
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: SignupValidators.email,
                    ),
                    const SizedBox(height: 14),
                    _ResponsiveFieldRow(
                      first: TextFormField(
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                        decoration: AdminUi.inputDecoration(
                          labelText: 'First Name',
                          hintText: 'First name',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            SignupValidators.accountFirstName(value),
                      ),
                      second: TextFormField(
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                        decoration: AdminUi.inputDecoration(
                          labelText: 'Last Name',
                          hintText: 'Last name',
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        validator: (value) => SignupValidators.name(
                          value,
                          fieldName: 'Last name',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ResponsiveFieldRow(
                      first: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AdminUi.inputDecoration(
                          labelText: 'Age',
                          hintText: 'Age',
                          prefixIcon: const Icon(Icons.cake_outlined),
                        ),
                        validator: (value) => SignupValidators.age(
                          value,
                          minimumAge: SignupValidators.driverMinimumAge,
                        ),
                      ),
                      second: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: AdminUi.inputDecoration(
                          labelText: 'Gender',
                          hintText: 'Gender',
                          prefixIcon: const Icon(Icons.wc_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() => _gender = value),
                        validator: _validateGender,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: AdminUi.inputDecoration(
                        labelText: 'Password',
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                      validator: SignupValidators.password,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: AdminUi.inputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Confirm password',
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                      ),
                      validator: (value) => SignupValidators.confirmPassword(
                        value,
                        _passwordController.text,
                      ),
                      onFieldSubmitted: (_) {
                        if (!_isSubmitting) {
                          _submit();
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.admin_panel_settings_rounded),
                        label: Text(
                          _isSubmitting
                              ? 'Creating admin...'
                              : 'Create Admin Account',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminUi.primary,
                          foregroundColor: AdminUi.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: AdminUi.radius,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveFieldRow extends StatelessWidget {
  final Widget first;
  final Widget second;

  const _ResponsiveFieldRow({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;

    if (!wide) {
      return Column(children: [first, const SizedBox(height: 14), second]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 14),
        Expanded(child: second),
      ],
    );
  }
}
