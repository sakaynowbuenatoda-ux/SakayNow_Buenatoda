import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart'; 
import 'widgets/passenger_widgets/passenger_ui.dart';
import 'pages/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); 

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SakayNow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: PassengerUi.primary,
          primary: PassengerUi.primary,
          secondary: PassengerUi.secondary,
          surface: PassengerUi.surface,
        ),
        scaffoldBackgroundColor: PassengerUi.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: PassengerUi.background,
          surfaceTintColor: PassengerUi.background,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
