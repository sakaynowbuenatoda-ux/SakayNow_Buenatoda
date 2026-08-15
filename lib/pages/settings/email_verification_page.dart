import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/email_verification_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'change_update_email_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final EmailVerificationClient verificationService;

  EmailVerificationPage({
    super.key,
    EmailVerificationClient? verificationService,
  }) : verificationService = verificationService ?? EmailVerificationService();

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  EmailVerificationStatus? _status;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isRefreshing = false;
  bool _hasSentEmail = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus({
    bool refresh = false,
    bool showVerifiedMessage = true,
  }) async {
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

      setState(() {
        _status = status;
        _errorMessage = syncErrorMessage.isEmpty ? null : syncErrorMessage;
        _isLoading = false;
        _isRefreshing = false;
      });

      if (refresh && showVerifiedMessage && status.isVerified) {
        _showSnackBar('Email verified successfully.');
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
            fallback:
                'Unable to load email verification status. Please try again.',
          );
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _openChangeUpdateEmailPage(
    EmailVerificationStatus status,
  ) async {
    if (!status.hasSignedInUser || !status.hasEmail) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeUpdateEmailPage(
          verificationService: widget.verificationService,
          initialStatus: status,
        ),
      ),
    );

    if (mounted) {
      await _loadStatus(refresh: true, showVerifiedMessage: false);
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_isSending || _status?.isVerified == true) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await widget.verificationService.sendVerificationEmail();
      if (!mounted) {
        return;
      }

      setState(() => _hasSentEmail = true);
      _showSnackBar('Verification email sent.');
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _authMessage(error));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = userFacingErrorMessage(
            error,
            fallback: 'Unable to send verification email. Please try again.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text('Email Verification', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        maxContentWidth: PassengerUi.settingsContentWidth,
        child: _isLoading
            ? const _EmailVerificationLoadingState()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_errorMessage != null) ...<Widget>[
                    _EmailVerificationErrorBanner(
                      message: _errorMessage!,
                      onRetry: () => _loadStatus(refresh: true),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (status == null ||
                      !status.hasSignedInUser ||
                      !status.hasEmail)
                    const _EmailVerificationEmptyState()
                  else ...<Widget>[
                    _EmailVerificationStatusCard(status: status),
                    const SizedBox(height: 14),
                    if (status.isVerified)
                      _EmailVerifiedCard(
                        onUpdateEmail: () => _openChangeUpdateEmailPage(status),
                      )
                    else
                      _EmailVerificationActionCard(
                        email: status.email!,
                        isSending: _isSending,
                        isRefreshing: _isRefreshing,
                        hasSentEmail: _hasSentEmail,
                        onSend: _sendVerificationEmail,
                        onRefresh: () => _loadStatus(refresh: true),
                        onChangeEmail: () => _openChangeUpdateEmailPage(status),
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _authMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'too-many-requests' =>
        'Too many verification emails were requested. Please try again later.',
      'user-token-expired' || 'requires-recent-login' =>
        'Please sign in again before verifying your email.',
      'missing-email' => 'No email address is linked to this account.',
      _ => error.message ?? 'Unable to manage email verification.',
    };
  }
}

class _EmailVerificationStatusCard extends StatelessWidget {
  final EmailVerificationStatus status;

  const _EmailVerificationStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final isVerified = status.isVerified;

    return PassengerSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              isVerified
                  ? Icons.verified_rounded
                  : Icons.mark_email_unread_outlined,
              color: PassengerUi.dark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isVerified ? 'Verified Email' : 'Email Not Verified',
                  style: PassengerUi.valueText,
                ),
                const SizedBox(height: 5),
                Text(
                  status.email ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.bodyText,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PassengerStatusChip(
            label: isVerified ? 'Verified' : 'Pending',
            textColor: isVerified
                ? PassengerUi.successText
                : PassengerUi.highlightAmber,
            backgroundColor: isVerified
                ? PassengerUi.successBackground
                : PassengerUi.warningSoft,
          ),
        ],
      ),
    );
  }
}

class _EmailVerificationActionCard extends StatelessWidget {
  final String email;
  final bool isSending;
  final bool isRefreshing;
  final bool hasSentEmail;
  final VoidCallback onSend;
  final VoidCallback onRefresh;
  final VoidCallback onChangeEmail;

  const _EmailVerificationActionCard({
    required this.email,
    required this.isSending,
    required this.isRefreshing,
    required this.hasSentEmail,
    required this.onSend,
    required this.onRefresh,
    required this.onChangeEmail,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Send Verification Link', style: PassengerUi.valueText),
          const SizedBox(height: 8),
          Text(
            'A secure verification link will be sent to $email.',
            style: PassengerUi.bodyText,
          ),
          const SizedBox(height: 4),
          Text(
            'If no email arrives, please check your spam folder.',
            style: PassengerUi.bodyText,
          ),
          if (hasSentEmail) ...<Widget>[
            const SizedBox(height: 12),
            _VerificationSentNotice(email: email),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSending ? null : onSend,
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
              label: Text(isSending ? 'Sending...' : 'Send Verification Email'),
            ),
          ),
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
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onChangeEmail,
              icon: const Icon(Icons.alternate_email_rounded),
              label: const Text('Change Email'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationSentNotice extends StatelessWidget {
  final String email;

  const _VerificationSentNotice({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PassengerUi.blueSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PassengerUi.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: PassengerUi.accentBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Check $email, open the link, then refresh this page.',
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

class _EmailVerifiedCard extends StatelessWidget {
  final VoidCallback onUpdateEmail;

  const _EmailVerifiedCard({required this.onUpdateEmail});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.check_circle_rounded, color: PassengerUi.dark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Verification Complete', style: PassengerUi.valueText),
                const SizedBox(height: 6),
                Text(
                  'Your email is already verified for this SakayNow account.',
                  style: PassengerUi.bodyText,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onUpdateEmail,
                    icon: const Icon(Icons.alternate_email_rounded),
                    label: const Text('Update Email'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailVerificationErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EmailVerificationErrorBanner({
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

class _EmailVerificationEmptyState extends StatelessWidget {
  const _EmailVerificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return const PassengerEmptyState(
      icon: Icons.alternate_email_rounded,
      title: 'No email available',
      description:
          'Sign in with an email account before requesting verification.',
    );
  }
}

class _EmailVerificationLoadingState extends StatelessWidget {
  const _EmailVerificationLoadingState();

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
              color: PassengerUi.highlightAmber,
            ),
          ),
          const SizedBox(width: 12),
          Text('Loading email status...', style: PassengerUi.bodyText),
        ],
      ),
    );
  }
}
