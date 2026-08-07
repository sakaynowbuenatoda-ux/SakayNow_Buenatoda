import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/user_facing_error_message.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../auth/auth_gate.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSaving = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        leading: IconButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text('Change Password', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        maxContentWidth: PassengerUi.settingsContentWidth,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PassengerPageHeader(
                title: 'Change Password',
                subtitle:
                    'Confirm your current password before setting a new one.',
                icon: Icons.password_rounded,
                accentColor: PassengerUi.accentBlue,
              ),
              const SizedBox(height: 16),
              PassengerSurfaceCard(
                child: Column(
                  children: <Widget>[
                    _PasswordField(
                      controller: _oldPasswordController,
                      label: 'Old password',
                      obscureText: _obscureOld,
                      onToggleVisibility: () =>
                          setState(() => _obscureOld = !_obscureOld),
                      validator: _validateOldPassword,
                    ),
                    const SizedBox(height: 12),
                    _PasswordField(
                      controller: _newPasswordController,
                      label: 'New password',
                      obscureText: _obscureNew,
                      onToggleVisibility: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      validator: _validateNewPassword,
                    ),
                    const SizedBox(height: 12),
                    _PasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm new password',
                      obscureText: _obscureConfirm,
                      onToggleVisibility: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: _validateConfirmPassword,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submit,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                          _isSaving ? 'Updating...' : 'Update Password',
                        ),
                      ),
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

  String? _validateOldPassword(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Enter your old password.';
    }

    return null;
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Enter a new password.';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    if (password == _oldPasswordController.text) {
      return 'New password must be different.';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Confirm your new password.';
    }

    if (value != _newPasswordController.text) {
      return 'Passwords do not match.';
    }

    return null;
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      if (user == null || email == null || email.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Unable to confirm the current signed-in account.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: _oldPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      if (!mounted) {
        return;
      }

      await _showSuccessValidation();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showError(_authMessage(error));
      }
    } catch (error) {
      if (mounted) {
        _showError(
          userFacingErrorMessage(
            error,
            fallback: 'Unable to change password. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change password?'),
          content: const Text(
            'Your account password will be updated after confirming your old password.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessValidation() {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.10),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, _, _) {
        Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        });

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 260,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: PassengerUi.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PassengerUi.border),
                boxShadow: PassengerUi.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.check_circle_rounded,
                    color: PassengerUi.successText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Password changed successfully',
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

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _authMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'wrong-password' || 'invalid-credential' => 'Old password is incorrect.',
      'weak-password' => 'New password is too weak.',
      'requires-recent-login' =>
        'Please sign in again before changing your password.',
      _ => error.message ?? 'Unable to change password.',
    };
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggleVisibility;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggleVisibility,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }
}
