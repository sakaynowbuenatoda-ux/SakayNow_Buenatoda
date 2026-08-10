import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/driver_signup.dart';
import '../../widgets/passenger_signup.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'auth_ui.dart';
import 'auth_gate.dart';
import 'widgets/auth_brand_header.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);
    final horizontalPadding = compact ? 14.0 : 18.0;

    return AuthUi.scope(
      context,
      DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AuthUi.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bottomInset = PassengerUi.pageBottomInset(context);
                final panelMinHeight =
                    constraints.maxHeight - (compact ? 210 : 220);

                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 12 + bottomInset),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 24 : 32,
                            12,
                            compact ? 24 : 32,
                            compact ? 28 : 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const _BackToLoginButton(),
                              SizedBox(height: compact ? 18 : 22),
                              const AuthBrandHeader(centered: true),
                              SizedBox(height: compact ? 24 : 28),
                              Text(
                                'Create your account',
                                style: GoogleFonts.poppins(
                                  color: AuthUi.title,
                                  fontSize: compact ? 28 : 32,
                                  height: 1.15,
                                  letterSpacing: -0.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: panelMinHeight < 0 ? 0 : panelMinHeight,
                        ),
                        margin: EdgeInsets.fromLTRB(
                          compact ? 12 : 16,
                          0,
                          compact ? 12 : 16,
                          0,
                        ),
                        decoration: BoxDecoration(
                          color: AuthUi.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            compact ? 14 : 16,
                            horizontalPadding,
                            compact ? 18 : 22,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: compact ? 42 : 50,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: AuthUi.border,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 14 : 16),
                              Text(
                                'Choose account type',
                                style: TextStyle(
                                  fontSize: compact ? 16 : 18,
                                  fontWeight: FontWeight.w700,
                                  color: AuthUi.title,
                                ),
                              ),
                              SizedBox(height: compact ? 14 : 16),
                              Container(
                                height: compact ? 52 : 56,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AuthUi.mutedSurface,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: TabBar(
                                  indicator: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: AuthUi.signalGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AuthUi.primary.withValues(
                                          alpha: 0.22,
                                        ),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  splashBorderRadius: BorderRadius.circular(
                                    999,
                                  ),
                                  labelStyle: TextStyle(
                                    fontSize: compact ? 14 : 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  unselectedLabelStyle: TextStyle(
                                    fontSize: compact ? 14 : 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  tabs: const [
                                    Tab(text: 'Passenger'),
                                    Tab(text: 'Driver'),
                                  ],
                                ),
                              ),
                              SizedBox(height: compact ? 16 : 20),
                              const _SignUpTabContent(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SignUpTabContent extends StatelessWidget {
  const _SignUpTabContent();

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);

    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, _) {
        final index = controller.index;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(index),
            child: index == 0 ? PassengerSignup() : DriverSignUp(),
          ),
        );
      },
    );
  }
}

class _BackToLoginButton extends StatelessWidget {
  const _BackToLoginButton();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AuthGate()),
          (route) => false,
        );
      },
      style: TextButton.styleFrom(
        foregroundColor: AuthUi.title,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 22),
      label: Text(
        'back',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }
}
