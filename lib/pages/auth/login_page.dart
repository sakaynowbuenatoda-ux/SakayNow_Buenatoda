import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_assets.dart';
import '../../core/auth/signup_validators.dart';
import '../../core/session/session_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'auth_ui.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

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

    return AuthUi.scope(
      context,
      Scaffold(
        backgroundColor: AuthUi.background,
        body: Container(
          decoration: BoxDecoration(gradient: AuthUi.mapGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 20,
                  compact ? 16 : 20,
                  compact ? 16 : 20,
                  (compact ? 16 : 20) + PassengerUi.pageBottomInset(context),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: compact ? 68 : 80,
                            height: compact ? 68 : 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(
                                    0xFF0C2238,
                                  ).withValues(alpha: 0.06),
                                  blurRadius: 18,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              AppAssets.logo,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(height: compact ? 12 : 10),
                          Text(
                            'SakayNow BuenaToda',
                            style: GoogleFonts.poppins(
                              fontSize: compact ? 24 : 26,
                              letterSpacing: 0,
                              color: AuthUi.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 22 : 32),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 18 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Color(
                                  0xFF0C2238,
                                ).withValues(alpha: 0.08),
                                blurRadius: compact ? 14 : 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(compact ? 18 : 20),
                            child: Column(
                              children: [
                                Text(
                                  'Welcome Back',
                                  style: GoogleFonts.poppins(
                                    fontSize: compact ? 20 : 22,
                                    color: AuthUi.title,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: compact ? 18 : 22),
                                TextField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    hintText: 'Email',
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: AuthUi.accentBlue,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: compact ? 14 : 16,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 15),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    hintText: 'Password',
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: AuthUi.accentBlue,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: compact ? 14 : 16,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _openForgotPasswordPage,
                                    style: TextButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text('Forgot Password?'),
                                  ),
                                ),
                                SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: compact ? 52 : 55,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AuthUi.darkActionGradient,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: AuthUi.cardShadow,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _loginUser,
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                      ),
                                      child: Center(
                                        child: _isLoading
                                            ? SizedBox(
                                                height: 22,
                                                width: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : Text(
                                                'Login',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity,
                                  height: compact ? 52 : 55,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SignUpPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Create Account',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
