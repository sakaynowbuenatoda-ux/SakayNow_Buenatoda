import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';
import 'auth_ui.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'widgets/welcome_hero_content.dart';
import 'widgets/welcome_product_preview.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  void _openLogin(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _openSignUp(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignUpPage()));
  }

  @override
  Widget build(BuildContext context) {
    final compact = PassengerUi.isCompactWidth(context);

    return AuthUi.scope(
      context,
      Scaffold(
        backgroundColor: AuthUi.background,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Color(0xFFFFFFFF),
                Color(0xFFF8FAFC),
                Color(0xFFEFF6FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bottomInset = PassengerUi.pageBottomInset(context);
                final horizontalPadding = compact ? 18.0 : 28.0;
                final verticalPadding = compact ? 18.0 : 24.0;
                final wide = constraints.maxWidth >= 860;
                final minHeight =
                    constraints.maxHeight - verticalPadding * 2 - bottomInset;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    verticalPadding + bottomInset,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: minHeight < 0 ? 0 : minHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: WelcomeHeroContent(
                                      compact: compact,
                                      centered: false,
                                      onLogin: () => _openLogin(context),
                                      onSignUp: () => _openSignUp(context),
                                    ),
                                  ),
                                  const SizedBox(width: 36),
                                  const Expanded(
                                    flex: 5,
                                    child: WelcomeProductPreview(
                                      compact: false,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  WelcomeHeroContent(
                                    compact: compact,
                                    centered: true,
                                    onLogin: () => _openLogin(context),
                                    onSignUp: () => _openSignUp(context),
                                  ),
                                  const SizedBox(height: 26),
                                  WelcomeProductPreview(compact: compact),
                                ],
                              ),
                      ),
                    ),
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
