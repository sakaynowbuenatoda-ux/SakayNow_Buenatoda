import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/session/app_user.dart';
import '../../core/session/session_service.dart';
import '../../services/chat_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../messages/chat_page.dart';
import 'account_status_page.dart';
import 'auth_ui.dart';
import 'loading_screen.dart';
import 'welcome_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: SessionService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return LoadingScreen();
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return const WelcomePage();
        }

        return StreamBuilder<AppUser>(
          stream: SessionService.watchUserProfile(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return LoadingScreen();
            }

            if (profileSnapshot.hasError) {
              return _AuthErrorState(
                message: userFacingErrorMessage(
                  profileSnapshot.error,
                  fallback:
                      'Unable to load your account profile. Please try again.',
                ),
              );
            }

            final appUser = profileSnapshot.data;
            if (appUser == null) {
              return const _AuthErrorState(
                message: 'Unable to load user profile.',
              );
            }

            if (appUser.isBanned) {
              return AccountStatusPage(
                icon: Icons.block_rounded,
                title: 'Account access restricted',
                description:
                    'This account is currently restricted. Please contact the SakayNow admin team if you believe this is a mistake.',
                primaryLabel: 'Back to login',
                onPrimaryPressed: (context) => SessionService.signOut(),
                secondaryLabel: 'Contact Admin',
                onSecondaryPressed: (context) =>
                    _openAdminSupportChat(context, appUser),
              );
            }

            if (appUser.isDeleted) {
              return AccountStatusPage(
                icon: Icons.no_accounts_rounded,
                title: 'Account permanently deleted',
                description:
                    'This account has passed the 60-day restoration window and its personal profile data has been permanently removed. Booking and transaction records may be retained for up to 5 years for safety, payment, audit, legal, and dispute purposes.',
                primaryLabel: 'Back to login',
                onPrimaryPressed: (context) => SessionService.signOut(),
              );
            }

            if (appUser.isDeactivated) {
              return AccountStatusPage(
                icon: Icons.no_accounts_rounded,
                title: 'Account deactivated',
                description: _deactivatedAccountDescription(appUser),
                primaryLabel: 'Back to login',
                onPrimaryPressed: (context) => SessionService.signOut(),
                secondaryLabel: 'Contact Admin',
                onSecondaryPressed: (context) =>
                    _openAdminSupportChat(context, appUser),
              );
            }

            return SessionService.buildHomeForUser(appUser);
          },
        );
      },
    );
  }
}

Future<void> _openAdminSupportChat(BuildContext context, AppUser user) async {
  final chatService = ChatService();
  final userName = _displayNameFor(user);

  try {
    final conversationId = await chatService.ensureSupportConversation(
      userId: user.userId,
      userName: userName,
      userRole: user.role,
    );

    if (!context.mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          currentUserId: user.userId,
          currentUserRole: user.role,
          title: 'SakayNow Support',
          subtitle: 'Admin',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          userFacingErrorMessage(
            error,
            fallback:
                'Unable to open admin support right now. Please try again.',
          ),
        ),
      ),
    );
  }
}

String _displayNameFor(AppUser user) {
  final fullName = '${user.firstName} ${user.lastName}'.trim();
  if (fullName.isNotEmpty) {
    return fullName;
  }

  if (user.email.trim().isNotEmpty) {
    return user.email.trim();
  }

  return 'SakayNow User';
}

String _deactivatedAccountDescription(AppUser user) {
  final restoreDeadline = user.deactivationRestoreDeadline;
  final deadlineText = restoreDeadline == null
      ? 'within 60 days from deactivation'
      : 'until ${_formatDate(restoreDeadline)}';

  return 'This account is deactivated and can only be restored by an admin $deadlineText. After the 60-day restoration window, personal account identity is permanently removed. Booking and transaction records may be retained for up to 5 years for safety, payment, audit, legal, and dispute purposes.';
}

String _formatDate(DateTime value) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

class _AuthErrorState extends StatelessWidget {
  final String message;

  const _AuthErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return AuthUi.scope(
      context,
      Scaffold(
        backgroundColor: AuthUi.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewPadding.bottom + 56,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AuthUi.primary),
                  SizedBox(height: 12),
                  Text(
                    'Something went wrong while restoring your session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AuthUi.body),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: SessionService.signOut,
                    child: Text('Back to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
