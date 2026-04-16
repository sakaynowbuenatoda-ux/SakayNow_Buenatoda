import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/session/app_user.dart';
import '../../core/session/session_service.dart';
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
          return const LoadingScreen();
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return const LoginPage();
        }

        return FutureBuilder<AppUser>(
          future: SessionService.loadUserProfile(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }

            if (profileSnapshot.hasError) {
              return _AuthErrorState(
                message: profileSnapshot.error.toString(),
              );
            }

            final appUser = profileSnapshot.data;
            if (appUser == null) {
              return const _AuthErrorState(
                message: 'Unable to load user profile.',
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
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Something went wrong while restoring your session.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: SessionService.signOut,
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
