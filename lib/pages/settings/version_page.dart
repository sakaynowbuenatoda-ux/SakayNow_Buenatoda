import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';

class VersionPage extends StatefulWidget {
  const VersionPage({super.key});

  @override
  State<VersionPage> createState() => _VersionPageState();
}

class _VersionPageState extends State<VersionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.primary),
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = _controller.value;

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + (value * 0.7), -1),
                end: Alignment(1 - (value * 0.7), 1),
                colors: const <Color>[
                  Color(0xFFF8FBFF),
                  Color(0xFFDCEBFF),
                  Color(0xFFE8F8EF),
                  Color(0xFFFFFFFF),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'SakayNow BuenaToda',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PassengerUi.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 34),
                      Text(
                        'Version',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PassengerUi.primary.withValues(alpha: 0.82),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1.0',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PassengerUi.accentBlue,
                          fontSize: 76,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'from Developer team',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PassengerUi.primary.withValues(alpha: 0.68),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Version notes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PassengerUi.primary.withValues(alpha: 0.62),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _VersionNotes(),
                      const SizedBox(height: 12),
                      Text(
                        'All rights reserved',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PassengerUi.primary.withValues(alpha: 0.52),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VersionNotes extends StatelessWidget {
  const _VersionNotes();

  static const List<String> _notes = <String>[
    'SakayNow BuenaToda is still in active development.',
    'Some features are available now, while others are coming soon.',
    'Notifications, admin messaging, and support tools will be expanded.',
    'Booking, dashboard, payment, and account features may continue to improve.',
    'Future updates will add more complete ride, safety, and service tools.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _notes
          .map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                note,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PassengerUi.primary.withValues(alpha: 0.58),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
