import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'config/app_environment.dart';
import 'core/preferences/app_preferences_controller.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  NotificationService.registerBackgroundHandler();
  await AppEnvironment.load();
  await AppPreferencesController.instance.load();
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const MyApp());
  unawaited(NotificationService.instance.initialize());
}
