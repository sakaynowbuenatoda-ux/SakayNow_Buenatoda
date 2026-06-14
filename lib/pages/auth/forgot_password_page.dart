import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_assets.dart';
import '../../core/auth/signup_validators.dart';
import '../../services/password_reset_service.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'auth_ui.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String? initialEmail;
  final PasswordResetSender resetService;
  final PasswordResetLimiter limiter;

  ForgotPasswordPage({
    super.key,
    this.initialEmail,
    PasswordResetSender? resetService,
    PasswordResetLimiter? limiter,
  }) : resetService = resetService ?? PasswordResetService(),
       limiter = limiter ?? PasswordResetLimiter();

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const String _successMessage =
      'If an account exists, a reset link was sent. Please check your inbox and spam folder.';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  PasswordResetLimitSnapshot? _limitSnapshot;
  Timer? _cooldownTimer;
  bool _isSending = false;
  bool _hasSentLink = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initialEmail = widget.initialEmail?.trim() ?? '';
    _emailController = TextEditingController(
      text: SignupValidators.email(initialEmail) == null ? initialEmail : '',
    );
    unawaited(_refreshLimit());
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _refreshLimit() async {
    final snapshot = await widget.limiter.loadSnapshot();
    if (!mounted) {
      return;
    }

    setState(() => _limitSnapshot = snapshot);
    _syncCooldownTimer(snapshot);
  }

  void _syncCooldownTimer(PasswordResetLimitSnapshot snapshot) {
    if (!snapshot.hasCooldown) {
      _cooldownTimer?.cancel();
      _cooldownTimer = null;
      return;
    }

    _cooldownTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refreshLimit()),
    );
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final currentLimit = await widget.limiter.loadSnapshot();
    if (!mounted) {
      return;
    }

    if (!currentLimit.canSend) {
      final message = _limitMessage(currentLimit);
      setState(() {
        _limitSnapshot = currentLimit;
        _errorMessage = message;
      });
      _syncCooldownTimer(currentLimit);
      _showSnackBar(message);
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await widget.resetService.sendResetLink(_emailController.text);
      final nextLimit = await widget.limiter.recordAttempt();
      if (!mounted) {
        return;
      }

      setState(() {
        _hasSentLink = true;
        _limitSnapshot = nextLimit;
      });
      _syncCooldownTimer(nextLimit);
      _showSnackBar('Password reset email requested.');
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        final message = _authMessage(error);
        setState(() => _errorMessage = message);
        _showSnackBar(message);
      }
    } catch (error) {
      if (mounted) {
        final message = 'Unable to send reset link: $error';
        setState(() => _errorMessage = message);
        _showSnackBar(message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
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
                  12,
                  compact ? 16 : 20,
                  (compact ? 16 : 20) + PassengerUi.pageBottomInset(context),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: _isSending
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      _AuthLogo(compact: compact),
                      SizedBox(height: compact ? 18 : 26),
                      _ResetPasswordCard(
                        compact: compact,
                        formKey: _formKey,
                        emailController: _emailController,
                        isSending: _isSending,
                        hasSentLink: _hasSentLink,
                        errorMessage: _errorMessage,
                        limitSnapshot: _limitSnapshot,
                        successMessage: _successMessage,
                        onSend: _sendResetLink,
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _limitMessage(PasswordResetLimitSnapshot snapshot) {
    if (snapshot.hasReachedDailyLimit) {
      return 'You have used all 5 password reset attempts for today. Please try again tomorrow.';
    }

    return 'Please wait ${_formatDuration(snapshot.remainingCooldown)} before requesting another reset link.';
  }

  String _authMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'too-many-requests' =>
        'Too many reset emails were requested. Please try again later.',
      'network-request-failed' =>
        'Network error. Check your connection and try again.',
      'operation-not-allowed' =>
        'Password reset is not available right now. Please contact an admin.',
      'user-disabled' => 'This account is disabled. Please contact support.',
      'missing-android-pkg-name' ||
      'missing-continue-uri' ||
      'missing-ios-bundle-id' ||
      'invalid-continue-uri' ||
      'unauthorized-continue-uri' =>
        'Password reset links are not available right now. Please contact an admin.',
      _ => error.message ?? 'Unable to send reset link.',
    };
  }

  static String _formatDuration(Duration value) {
    final seconds = value.inSeconds.clamp(0, 24 * 60 * 60);
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _AuthLogo extends StatelessWidget {
  final bool compact;

  const _AuthLogo({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: compact ? 68 : 76,
          height: compact ? 68 : 76,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF0C2238).withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(AppAssets.logo, fit: BoxFit.cover),
        ),
        SizedBox(height: compact ? 12 : 10),
        Text(
          'SakayNow BuenaToda',
          style: GoogleFonts.poppins(
            fontSize: compact ? 23 : 25,
            letterSpacing: 0,
            color: AuthUi.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ResetPasswordCard extends StatelessWidget {
  final bool compact;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isSending;
  final bool hasSentLink;
  final String? errorMessage;
  final PasswordResetLimitSnapshot? limitSnapshot;
  final String successMessage;
  final VoidCallback onSend;

  const _ResetPasswordCard({
    required this.compact,
    required this.formKey,
    required this.emailController,
    required this.isSending,
    required this.hasSentLink,
    required this.errorMessage,
    required this.limitSnapshot,
    required this.successMessage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final canSend = limitSnapshot?.canSend == true;
    final isCheckingLimit = limitSnapshot == null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AuthUi.cardShadow,
      ),
      padding: EdgeInsets.all(compact ? 18 : 20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Text(
                'Reset Password',
                style: GoogleFonts.archivoBlack(
                  fontSize: compact ? 20 : 22,
                  color: AuthUi.title,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your account email and we will send a secure password reset link.',
              textAlign: TextAlign.center,
              style: AuthUi.bodyText,
            ),
            SizedBox(height: compact ? 18 : 22),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: SignupValidators.email,
              onFieldSubmitted: (_) {
                if (!isSending && canSend) {
                  onSend();
                }
              },
            ),
            const SizedBox(height: 10),
            Text(
              'If no email arrives, please check your spam or junk folder.',
              style: AuthUi.bodyText.copyWith(fontSize: 13),
            ),
            if (errorMessage != null) ...<Widget>[
              const SizedBox(height: 14),
              _MessageBanner(
                message: errorMessage!,
                icon: Icons.error_outline_rounded,
                iconColor: Colors.red.shade600,
                backgroundColor: Colors.red.shade50,
              ),
            ],
            if (hasSentLink) ...<Widget>[
              const SizedBox(height: 14),
              _MessageBanner(
                message: successMessage,
                icon: Icons.mark_email_read_outlined,
                iconColor: AuthUi.accentBlue,
                backgroundColor: const Color(0xFFEFF6FF),
              ),
            ],
            const SizedBox(height: 12),
            _LimitText(snapshot: limitSnapshot),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: compact ? 52 : 55,
              child: ElevatedButton.icon(
                onPressed: isSending || isCheckingLimit || !canSend
                    ? null
                    : onSend,
                icon: isSending
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
                  _buttonLabel(
                    isSending: isSending,
                    isCheckingLimit: isCheckingLimit,
                    snapshot: limitSnapshot,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buttonLabel({
    required bool isSending,
    required bool isCheckingLimit,
    required PasswordResetLimitSnapshot? snapshot,
  }) {
    if (isSending) {
      return 'Sending...';
    }

    if (isCheckingLimit) {
      return 'Checking...';
    }

    if (snapshot?.hasReachedDailyLimit == true) {
      return 'Daily Limit Reached';
    }

    if (snapshot?.hasCooldown == true) {
      return 'Try Again in ${_ForgotPasswordPageState._formatDuration(snapshot!.remainingCooldown)}';
    }

    return 'Send Reset Link';
  }
}

class _LimitText extends StatelessWidget {
  final PasswordResetLimitSnapshot? snapshot;

  const _LimitText({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    if (snapshot == null) {
      return Text('Checking reset availability...', style: AuthUi.bodyText);
    }

    final message = snapshot.hasReachedDailyLimit
        ? 'You have no password reset sends left today.'
        : '${snapshot.remainingAttempts} of 5 reset sends left today.';

    return Text(message, style: AuthUi.bodyText.copyWith(fontSize: 13));
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const _MessageBanner({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthUi.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AuthUi.bodyText.copyWith(
                color: AuthUi.title,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
