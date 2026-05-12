import 'package:flutter/material.dart';

import '../../config/app_assets.dart';
import '../../widgets/driver_signup.dart';
import '../../widgets/passenger_signup.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'auth_ui.dart';
import 'auth_gate.dart';

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
                    constraints.maxHeight - (compact ? 96 : 104);

                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 12 + bottomInset),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.fromLTRB(
                          compact ? 12 : 16,
                          10,
                          compact ? 12 : 16,
                          compact ? 8 : 10,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 14 : 16,
                          vertical: compact ? 12 : 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: AuthUi.darkActionGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: compact
                            ? Column(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: const _BackToLoginButton(),
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.16,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Image.asset(
                                            AppAssets.logo,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Create account',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.16,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Image.asset(
                                            AppAssets.logo,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Create Account',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: const _BackToLoginButton(),
                                  ),
                                ],
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
    return TextButton(
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
        foregroundColor: Colors.white,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        'Back to Login',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
    );
  }
}
