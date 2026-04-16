import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';

class AdminWidget extends StatefulWidget {
  const AdminWidget({super.key});

  @override
  State<AdminWidget> createState() => _AdminWidgetState();
}

class _AdminWidgetState extends State<AdminWidget> {
  bool _isLoading = false;

  Future<void> _seedAdmin(BuildContext context) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    FirebaseApp? secondaryApp;

    try {
      const email = 'sakaynowbuenatoda@gmail.com';
      const password = 'qwerty1234';

      secondaryApp = await Firebase.initializeApp(
        name: 'admin-seed-app',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final secondaryFirestore = FirebaseFirestore.instanceFor(app: secondaryApp);

      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      await secondaryFirestore.collection('users').doc(uid).set({
        'user_id': uid,
        'email': email,
        'first_name': 'admin',
        'last_name': null,
        'age': null,
        'gender': null,
        'role': 'admin',
        'id_image_url': null,
        'selfie_url': null,
        'nbi_clearance_url': null,
        'drivers_license_url': null,
        'created_at': FieldValue.serverTimestamp(),
      });

      await secondaryAuth.signOut();
      await secondaryApp.delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin account created.')),
      );
    } on FirebaseAuthException catch (e) {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }

      if (!context.mounted) return;

      String message = e.message ?? 'Failed to seed admin.';

      if (e.code == 'email-already-in-use') {
        message = 'Admin already exists.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : () => _seedAdmin(context),
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.admin_panel_settings_outlined),
      label: const Text('Seed Admin'),
    );
  }
}