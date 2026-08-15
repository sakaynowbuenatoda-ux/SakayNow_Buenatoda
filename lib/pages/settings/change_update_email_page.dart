import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/auth/signup_validators.dart';
import '../../services/email_verification_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';

class ChangeUpdateEmailPage extends StatefulWidget {
  final EmailVerificationClient verificationService;
  final EmailVerificationStatus? initialStatus;

  ChangeUpdateEmailPage({
    super.key,
    EmailVerificationClient? verificationService,
    this.initialStatus,
  }) : verificationService = verificationService ?? EmailVerificationService();

  @override
  State<ChangeUpdateEmailPage> createState() => _ChangeUpdateEmailPageState();
}

class _ChangeUpdateEmailPageState extends State<ChangeUpdateEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _newEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController();

  EmailVerificationStatus? _status;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isRequestingEmailUpdate = false;
  bool _obscureCurrentPassword = true;
  bool _hasRequestedEmailUpdate = false;
  String? _pendingEmail;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initialStatus = widget.initialStatus;
    if (initialStatus == null) {
      _loadStatus();
    } else {
      _status = initialStatus;
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus({bool refresh = false}) async {
    setState(() {
      if (refresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final status = await widget.verificationService.loadStatus(
        refresh: refresh,
      );
      var syncErrorMessage = '';
      if (status.isVerified) {
        try {
          await widget.verificationService.syncVerifiedEmailToProfile();
        } catch (error) {
          syncErrorMessage = userFacingErrorMessage(
            error,
            fallback:
                'Email is verified, but your profile could not be updated yet. Please refresh in a moment.',
          );
        }
      }

      if (!mounted) {
        return;
      }

      final pendingEmail = _pendingEmail;
      final didCompletePendingEmailUpdate =
          pendingEmail != null &&
          status.isVerified &&
          _emailsMatch(status.email, pendingEmail);

      setState(() {
        _status = status;
        _errorMessage = syncErrorMessage.isEmpty ? null : syncErrorMessage;
        _isLoading = false;
        _isRefreshing = false;
        if (didCompletePendingEmailUpdate) {
          _hasRequestedEmailUpdate = false;
          _pendingEmail = null;
        }
      });

      if (refresh && status.isVerified) {
        _showSnackBar(
          didCompletePendingEmailUpdate
              ? 'Email updated and verified successfully.'
              : 'Email verified successfully.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _authMessage(error);
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = userFacingErrorMessage(
            error,
            fallback: 'Unable to load email status. Please try again.',
          );
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _requestEmailUpdate() async {
    final status = _status;
    if (_isRequestingEmailUpdate ||
        status == null ||
        !status.hasSignedInUser ||
        !status.hasEmail) {
      return;
    }

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final newEmail = _newEmailController.text.trim();

    setState(() {
      _isRequestingEmailUpdate = true;
      _errorMessage = null;
    });

    try {
      await widget.verificationService.requestEmailUpdate(
        newEmail: newEmail,
        currentPassword: _currentPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _hasRequestedEmailUpdate = true;
        _pendingEmail = newEmail;
      });
      _newEmailController.clear();
      _currentPasswordController.clear();
      _showSnackBar('Verification link sent to $newEmail.');
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _authMessage(error));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = userFacingErrorMessage(
            error,
            fallback: 'Unable to update email. Please try again.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingEmailUpdate = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final isVerified = status?.isVerified == true;
    final title = isVerified ? 'Update Email' : 'Change Email';

    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: _isRequestingEmailUpdate
              ? null
              : () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text(title, style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        maxContentWidth: PassengerUi.settingsContentWidth,
        child: _isLoading
            ? const _ChangeUpdateEmailLoadingState()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_errorMessage != null) ...<Widget>[
                    _ChangeUpdateEmailErrorBanner(
                      message: _errorMessage!,
                      onRetry: () => _loadStatus(refresh: true),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (status == null ||
                      !status.hasSignedInUser ||
                      !status.hasEmail)
                    const _ChangeUpdateEmailEmptyState()
                  else
                    _EmailUpdateCard(
                      formKey: _formKey,
                      currentEmail: status.email!,
                      pendingEmail: _pendingEmail,
                      isVerified: status.isVerified,
                      isSaving: _isRequestingEmailUpdate,
                      isRefreshing: _isRefreshing,
                      hasRequestedEmailUpdate: _hasRequestedEmailUpdate,
                      obscureCurrentPassword: _obscureCurrentPassword,
                      newEmailController: _newEmailController,
                      currentPasswordController: _currentPasswordController,
                      onSubmit: _requestEmailUpdate,
                      onRefresh: () => _loadStatus(refresh: true),
                      onTogglePasswordVisibility: () => setState(
                        () =>
                            _obscureCurrentPassword = !_obscureCurrentPassword,
                      ),
                      validateNewEmail: _validateNewEmail,
                      validateCurrentPassword: _validateCurrentPassword,
                    ),
                ],
              ),
      ),
    );
  }

  String? _validateNewEmail(String? value) {
    final emailError = SignupValidators.email(value);
    if (emailError != null) {
      return emailError;
    }

    if (_emailsMatch(value, _status?.email)) {
      return 'Enter a different email address';
    }

    return null;
  }

  String? _validateCurrentPassword(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Enter your current password';
    }

    return null;
  }

  bool _emailsMatch(String? left, String? right) {
    return left != null &&
        right != null &&
        left.trim().toLowerCase() == right.trim().toLowerCase();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _authMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'too-many-requests' =>
        'Too many email requests were made. Please try again later.',
      'user-token-expired' || 'requires-recent-login' =>
        'Please sign in again before updating your email.',
      'missing-email' => 'No email address is linked to this account.',
      'missing-password' => 'Enter your current password.',
      'invalid-email' => 'Enter a valid email address.',
      'same-email' => 'Enter a different email address.',
      'wrong-password' ||
      'invalid-credential' => 'Current password is incorrect.',
      'email-already-in-use' ||
      'credential-already-in-use' => 'That email is already registered.',
      _ => error.message ?? 'Unable to update email.',
    };
  }
}

class _EmailUpdateCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String currentEmail;
  final String? pendingEmail;
  final bool isVerified;
  final bool isSaving;
  final bool isRefreshing;
  final bool hasRequestedEmailUpdate;
  final bool obscureCurrentPassword;
  final TextEditingController newEmailController;
  final TextEditingController currentPasswordController;
  final VoidCallback onSubmit;
  final VoidCallback onRefresh;
  final VoidCallback onTogglePasswordVisibility;
  final String? Function(String?) validateNewEmail;
  final String? Function(String?) validateCurrentPassword;

  const _EmailUpdateCard({
    required this.formKey,
    required this.currentEmail,
    required this.pendingEmail,
    required this.isVerified,
    required this.isSaving,
    required this.isRefreshing,
    required this.hasRequestedEmailUpdate,
    required this.obscureCurrentPassword,
    required this.newEmailController,
    required this.currentPasswordController,
    required this.onSubmit,
    required this.onRefresh,
    required this.onTogglePasswordVisibility,
    required this.validateNewEmail,
    required this.validateCurrentPassword,
  });

  @override
  Widget build(BuildContext context) {
    final title = isVerified ? 'Update Email' : 'Change Email';
    final buttonLabel = isVerified ? 'Send Update Link' : 'Send Change Link';

    return PassengerSurfaceCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: PassengerUi.valueText),
            const SizedBox(height: 8),
            Text(
              'Enter a new login email and confirm your current password. The email changes only after the new address is verified.',
              style: PassengerUi.bodyText,
            ),
            if (hasRequestedEmailUpdate && pendingEmail != null) ...<Widget>[
              const SizedBox(height: 12),
              _PendingEmailUpdateNotice(email: pendingEmail!),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: newEmailController,
              enabled: !isSaving,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: validateNewEmail,
              decoration: const InputDecoration(
                labelText: 'New email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: currentPasswordController,
              enabled: !isSaving,
              obscureText: obscureCurrentPassword,
              textInputAction: TextInputAction.done,
              validator: validateCurrentPassword,
              onFieldSubmitted: (_) {
                if (!isSaving) {
                  onSubmit();
                }
              },
              decoration: InputDecoration(
                labelText: 'Current password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: isSaving ? null : onTogglePasswordVisibility,
                  icon: Icon(
                    obscureCurrentPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : onSubmit,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.mark_email_read_outlined),
                label: Text(isSaving ? 'Sending...' : buttonLabel),
              ),
            ),
            if (hasRequestedEmailUpdate) ...<Widget>[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isRefreshing ? null : onRefresh,
                  icon: isRefreshing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PassengerUi.accentBlue,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(isRefreshing ? 'Checking...' : 'Refresh Status'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Current email: $currentEmail',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PassengerUi.bodyText.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingEmailUpdateNotice extends StatelessWidget {
  final String email;

  const _PendingEmailUpdateNotice({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PassengerUi.warningSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PassengerUi.highlightAmber.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.pending_actions_rounded,
            color: PassengerUi.highlightAmber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Check $email, open the verification link, then refresh this page.',
              style: PassengerUi.bodyText.copyWith(
                color: PassengerUi.title,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeUpdateEmailErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ChangeUpdateEmailErrorBanner({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: Colors.red.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: PassengerUi.bodyText,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ChangeUpdateEmailEmptyState extends StatelessWidget {
  const _ChangeUpdateEmailEmptyState();

  @override
  Widget build(BuildContext context) {
    return const PassengerEmptyState(
      icon: Icons.alternate_email_rounded,
      title: 'No email available',
      description: 'Sign in with an email account before changing your email.',
    );
  }
}

class _ChangeUpdateEmailLoadingState extends StatelessWidget {
  const _ChangeUpdateEmailLoadingState();

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: PassengerUi.accentBlue,
            ),
          ),
          const SizedBox(width: 12),
          Text('Loading email status...', style: PassengerUi.bodyText),
        ],
      ),
    );
  }
}
