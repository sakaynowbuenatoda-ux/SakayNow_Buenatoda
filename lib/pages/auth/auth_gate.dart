import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/session/app_user.dart';
import '../../core/session/session_service.dart';
import 'account_status_page.dart';
import 'auth_ui.dart';
import 'loading_screen.dart';
import 'login_page.dart';

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
          return LoginPage();
        }

        return StreamBuilder<AppUser>(
          stream: SessionService.watchUserProfile(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return LoadingScreen();
            }

            if (profileSnapshot.hasError) {
              return _AuthErrorState(message: profileSnapshot.error.toString());
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
              );
            }

            return SessionService.buildHomeForUser(appUser);
          },
        );
      },
    );
  }
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
