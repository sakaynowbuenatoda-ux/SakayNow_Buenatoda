import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const List<_PrivacySection> _sections = <_PrivacySection>[
    _PrivacySection(
      number: '1',
      title: 'Introduction',
      body:
          'SakayNow Buenatoda respects your privacy and is committed to protecting your personal data in compliance with the Data Privacy Act of 2012.',
    ),
    _PrivacySection(
      number: '2',
      title: 'Information We Collect',
      groups: <_PrivacyGroup>[
        _PrivacyGroup(
          label: 'Personal Information',
          items: <String>[
            'Name',
            'Email address',
            'Contact number',
            'Age and gender',
            'Profile photo or selfie',
            'Government-issued ID for drivers',
          ],
        ),
        _PrivacyGroup(
          label: 'Account Information',
          items: <String>[
            'User ID',
            'Role such as Passenger, Driver, or Admin',
          ],
        ),
        _PrivacyGroup(
          label: 'Location Data',
          items: <String>['Real-time GPS location for booking and tracking'],
        ),
        _PrivacyGroup(
          label: 'Device and Usage Data',
          items: <String>['Device type', 'App usage logs'],
        ),
      ],
    ),
    _PrivacySection(
      number: '3',
      title: 'How We Use Your Information',
      intro: 'We use your data to:',
      bullets: <String>[
        'Provide and improve services.',
        'Facilitate ride bookings.',
        'Verify identity and credentials.',
        'Ensure safety and security.',
        'Communicate updates and notifications.',
      ],
    ),
    _PrivacySection(
      number: '4',
      title: 'Data Sharing',
      bullets: <String>[
        'We may share your data with drivers and passengers for ride coordination.',
        'We may share your data with service providers such as cloud storage and analytics providers.',
        'We may share your data with government authorities when required by law.',
        'We do not sell your personal data.',
      ],
    ),
    _PrivacySection(
      number: '5',
      title: 'Data Protection Measures',
      intro: 'We implement:',
      bullets: <String>[
        'Secure authentication systems.',
        'Encrypted data storage.',
        'Access control and monitoring.',
      ],
    ),
    _PrivacySection(
      number: '6',
      title: 'Data Retention',
      body:
          'Your data is retained only as long as necessary for service purposes or legal compliance.',
    ),
    _PrivacySection(
      number: '7',
      title: 'Your Rights',
      body:
          'Under the Data Privacy Act of 2012, you have the right to access your personal data, correct inaccurate data, request deletion of your data, withdraw consent, and file a complaint with the National Privacy Commission.',
    ),
    _PrivacySection(
      number: '8',
      title: 'Consent',
      body:
          'By using the app, you consent to the collection and processing of your data as outlined in this policy.',
    ),
    _PrivacySection(
      number: '9',
      title: 'Cookies and Tracking',
      body:
          'We may use cookies or similar technologies to enhance user experience and analyze usage patterns.',
    ),
    _PrivacySection(
      number: '10',
      title: 'Changes to Privacy Policy',
      body:
          'We may update this Privacy Policy. Users will be notified of significant changes.',
    ),
    _PrivacySection(
      number: '11',
      title: 'Contact Us',
      bullets: <String>[
        'SakayNow Buenatoda Support',
        'Email: sakaynowbuenatoda@gmail.com',
      ],
    ),
  ];

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
        title: Text('Privacy Policy', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PassengerPageHeader(
              title: 'Privacy Policy',
              subtitle:
                  'What data is collected, how it is used, and the rights available to users.',
              icon: Icons.privacy_tip_outlined,
              accentColor: PassengerUi.primary,
            ),
            SizedBox(height: 16),
            ..._sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PrivacySectionCard(section: section),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySectionCard extends StatelessWidget {
  final _PrivacySection section;

  const _PrivacySectionCard({required this.section});

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
            ...section.bullets.map((item) => _PrivacyBullet(text: item)),
          ],
          if (section.groups.isNotEmpty) ...<Widget>[
            SizedBox(height: 12),
            ...section.groups.map((group) => _PrivacyGroupBlock(group: group)),
          ],
        ],
      ),
    );
  }
}

class _PrivacyGroupBlock extends StatelessWidget {
  final _PrivacyGroup group;

  const _PrivacyGroupBlock({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            group.label,
            style: PassengerUi.valueText.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          ...group.items.map((item) => _PrivacyBullet(text: item)),
        ],
      ),
    );
  }
}

class _PrivacyBullet extends StatelessWidget {
  final String text;

  const _PrivacyBullet({required this.text});

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

class _PrivacySection {
  final String number;
  final String title;
  final String? body;
  final String? intro;
  final List<String> bullets;
  final List<_PrivacyGroup> groups;

  const _PrivacySection({
    required this.number,
    required this.title,
    this.body,
    this.intro,
    this.bullets = const <String>[],
    this.groups = const <_PrivacyGroup>[],
  });
}

class _PrivacyGroup {
  final String label;
  final List<String> items;

  const _PrivacyGroup({required this.label, required this.items});
}
