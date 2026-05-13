import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  static const List<_PolicySection> _sections = <_PolicySection>[
    _PolicySection(
      number: '1',
      title: 'Acceptance of Terms',
      body:
          'By accessing or using SakayNow Buenatoda, you agree to be bound by these Terms and Conditions. If you do not agree, please do not use the app.',
    ),
    _PolicySection(
      number: '2',
      title: 'Description of Service',
      body:
          'SakayNow Buenatoda is a transport facilitation platform that connects passengers with drivers for booking rides. The platform does not own or operate vehicles but serves as an intermediary.',
    ),
    _PolicySection(
      number: '3',
      title: 'User Accounts',
      bullets: <String>[
        'Users must provide accurate and complete information upon registration.',
        'You are responsible for maintaining the confidentiality of your account credentials.',
        'Any activity under your account is your responsibility.',
      ],
    ),
    _PolicySection(
      number: '4',
      title: 'User Roles',
      bullets: <String>[
        'Passengers may book rides and provide feedback.',
        'Drivers must submit valid credentials and comply with transport regulations.',
        'Admins manage and monitor system operations.',
      ],
    ),
    _PolicySection(
      number: '5',
      title: 'Booking and Payments',
      bullets: <String>[
        'All bookings are subject to driver availability.',
        'Fare estimates are provided but may vary due to traffic or route changes.',
        'Payments must be completed through approved methods.',
      ],
    ),
    _PolicySection(
      number: '6',
      title: 'User Conduct',
      intro: 'Users agree not to:',
      bullets: <String>[
        'Provide false or misleading information.',
        'Engage in fraudulent or harmful activities.',
        'Harass, abuse, or harm other users.',
        'Use the platform for illegal purposes.',
      ],
    ),
    _PolicySection(
      number: '7',
      title: 'Driver Responsibilities',
      intro: 'Drivers must:',
      bullets: <String>[
        'Maintain valid licenses and permits.',
        'Ensure passenger safety.',
        'Follow traffic laws and regulations.',
      ],
    ),
    _PolicySection(
      number: '8',
      title: 'Limitation of Liability',
      intro: 'SakayNow Buenatoda is not liable for:',
      bullets: <String>[
        'Accidents, damages, or losses during rides.',
        'Delays, cancellations, or service interruptions.',
        'User misconduct.',
      ],
    ),
    _PolicySection(
      number: '9',
      title: 'Suspension and Termination',
      body:
          'We reserve the right to suspend or terminate accounts that violate these terms.',
    ),
    _PolicySection(
      number: '10',
      title: 'Amendments',
      body:
          'These Terms may be updated at any time. Continued use of the app means acceptance of changes.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _PolicyScaffold(
      title: 'Terms and Conditions',
      headerIcon: Icons.gavel_rounded,
      headerTitle: 'Terms and Conditions',
      headerSubtitle:
          'Responsibilities, limits, and expected conduct for everyone using SakayNow Buenatoda.',
      sections: _sections,
    );
  }
}

class _PolicyScaffold extends StatelessWidget {
  final String title;
  final IconData headerIcon;
  final String headerTitle;
  final String headerSubtitle;
  final List<_PolicySection> sections;

  const _PolicyScaffold({
    required this.title,
    required this.headerIcon,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text(title, style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PassengerPageHeader(
              title: headerTitle,
              subtitle: headerSubtitle,
              icon: headerIcon,
              accentColor: PassengerUi.primary,
            ),
            SizedBox(height: 16),
            ...sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PolicySectionCard(section: section),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  final _PolicySection section;

  const _PolicySectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PassengerUi.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  section.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: PassengerUi.cardTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (section.body != null) ...<Widget>[
            SizedBox(height: 12),
            Text(section.body!, style: PassengerUi.bodyText),
          ],
          if (section.intro != null) ...<Widget>[
            SizedBox(height: 12),
            Text(
              section.intro!,
              style: PassengerUi.valueText.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (section.bullets.isNotEmpty) ...<Widget>[
            SizedBox(height: 10),
            ...section.bullets.map((item) => _PolicyBullet(text: item)),
          ],
        ],
      ),
    );
  }
}

class _PolicyBullet extends StatelessWidget {
  final String text;

  const _PolicyBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(
              color: PassengerUi.accentBlue,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10),
          Expanded(child: Text(text, style: PassengerUi.bodyText)),
        ],
      ),
    );
  }
}

class _PolicySection {
  final String number;
  final String title;
  final String? body;
  final String? intro;
  final List<String> bullets;

  const _PolicySection({
    required this.number,
    required this.title,
    this.body,
    this.intro,
    this.bullets = const <String>[],
  });
}
