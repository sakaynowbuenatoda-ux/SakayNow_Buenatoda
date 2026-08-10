import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/auth/signup_validators.dart';
import '../../core/session/session_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'auth_ui.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';
import 'widgets/auth_brand_header.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter both email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SessionService.signIn(email: email, password: password);
      if (!mounted) return;
      _showMessage('Login successful.');
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on StateError catch (e) {
      _showMessage(e.message);
    } on FirebaseException catch (e) {
      String message = 'Login failed.';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid email or password.';
      }
      _showMessage(message);
    } catch (e) {
      _showMessage(
        userFacingErrorMessage(
          e,
          fallback: 'Unable to sign in. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openForgotPasswordPage() {
    final email = _emailController.text.trim();
    final initialEmail = SignupValidators.email(email) == null ? email : null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(initialEmail: initialEmail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final horizontalPadding = compact ? 24.0 : 32.0;
    const topPadding = 12.0;
    const bottomPadding = 20.0;

    return AuthUi.scope(
      context,
      Scaffold(
        backgroundColor: AuthUi.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minimumHeight =
                  constraints.maxHeight - topPadding - bottomPadding;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: minimumHeight < 0 ? 0 : minimumHeight,
                      ),
                      child: IntrinsicHeight(
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              TextButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: AuthUi.title,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 22,
                                ),
                                label: Text(
                                  'Back',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 18 : 22),
                              const AuthBrandHeader(centered: true),
                              SizedBox(height: compact ? 30 : 38),
                              Text(
                                'Login to your\nAccount',
                                style: GoogleFonts.poppins(
                                  color: AuthUi.title,
                                  fontSize: compact ? 32 : 36,
                                  height: 1.2,
                                  letterSpacing: -0.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: compact ? 38 : 48),
                              _FieldLabel(label: 'Email'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                autofillHints: const <String>[
                                  AutofillHints.email,
                                  AutofillHints.username,
                                ],
                                decoration: _fieldDecoration(
                                  hintText: 'Enter your email',
                                ),
                              ),
                              const SizedBox(height: 22),
                              _FieldLabel(label: 'Password'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const <String>[
                                  AutofillHints.password,
                                ],
                                onSubmitted: (_) {
                                  if (!_isLoading) {
                                    _loginUser();
                                  }
                                },
                                decoration: _fieldDecoration(
                                  hintText: 'Enter your password',
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AuthUi.body,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _openForgotPasswordPage,
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Forgot Password?'),
                                ),
                              ),
                              SizedBox(height: compact ? 22 : 28),
                              SizedBox(
                                width: double.infinity,
                                height: compact ? 54 : 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _loginUser,
                                  style: ElevatedButton.styleFrom(
                                    shape: const StadiumBorder(),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                ),
                              ),
                              const Spacer(),
                              Padding(
                                padding: EdgeInsets.only(
                                  top: compact ? 40 : 52,
                                  bottom: 20,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      "Don't have an account?",
                                      style: GoogleFonts.poppins(
                                        color: AuthUi.body,
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const SignUpPage(),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        minimumSize: Size.zero,
                                        padding: const EdgeInsets.only(
                                          left: 5,
                                          top: 8,
                                          bottom: 8,
                                        ),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Sign up'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AuthUi.border),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        color: AuthUi.body.withValues(alpha: 0.72),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: AuthUi.mutedSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      suffixIcon: suffixIcon,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AuthUi.primary, width: 1.4),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: AuthUi.title,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
