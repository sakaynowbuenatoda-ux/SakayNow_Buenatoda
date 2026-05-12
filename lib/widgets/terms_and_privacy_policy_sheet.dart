import 'package:flutter/material.dart';
import '../pages/auth/auth_ui.dart';

Future<void> showTermsAndPrivacyPolicySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        AuthUi.scope(sheetContext, TermsAndPrivacyPolicySheet()),
  );
}

class TermsAndPrivacyPolicySheet extends StatelessWidget {
  const TermsAndPrivacyPolicySheet({super.key});

  static Color get _primaryColor => AuthUi.primary;
  static Color get _secondaryColor => AuthUi.accentBlue;
  static Color get _surfaceColor => AuthUi.mutedSurface;
  static Color get _borderColor => AuthUi.border;
  static Color get _titleColor => AuthUi.title;
  static Color get _bodyColor => AuthUi.body;

  static const List<_PolicySectionData> _termsSections = [
    _PolicySectionData(
      number: '1',
      title: 'Acceptance of Terms',
      body:
          'By accessing or using SakayNow Buenatoda, you agree to be bound by these Terms and Conditions. If you do not agree, please do not use the app.',
    ),
    _PolicySectionData(
      number: '2',
      title: 'Description of Service',
      body:
          'SakayNow Buenatoda is a transport facilitation platform that connects passengers with drivers for booking rides. The platform does not own or operate vehicles but serves as an intermediary.',
    ),
    _PolicySectionData(
      number: '3',
      title: 'User Accounts',
      bullets: [
        'Users must provide accurate and complete information upon registration.',
        'You are responsible for maintaining the confidentiality of your account credentials.',
        'Any activity under your account is your responsibility.',
      ],
    ),
    _PolicySectionData(
      number: '4',
      title: 'User Roles',
      bullets: [
        'Passengers may book rides and provide feedback.',
        'Drivers must submit valid credentials and comply with transport regulations.',
        'Admins manage and monitor system operations.',
      ],
    ),
    _PolicySectionData(
      number: '5',
      title: 'Booking and Payments',
      bullets: [
        'All bookings are subject to driver availability.',
        'Fare estimates are provided but may vary due to traffic or route changes.',
        'Payments must be completed through approved methods.',
      ],
    ),
    _PolicySectionData(
      number: '6',
      title: 'User Conduct',
      intro: 'Users agree not to:',
      bullets: [
        'Provide false or misleading information.',
        'Engage in fraudulent or harmful activities.',
        'Harass, abuse, or harm other users.',
        'Use the platform for illegal purposes.',
      ],
    ),
    _PolicySectionData(
      number: '7',
      title: 'Driver Responsibilities',
      intro: 'Drivers must:',
      bullets: [
        'Maintain valid licenses and permits.',
        'Ensure passenger safety.',
        'Follow traffic laws and regulations.',
      ],
    ),
    _PolicySectionData(
      number: '8',
      title: 'Limitation of Liability',
      intro: 'SakayNow Buenatoda is not liable for:',
      bullets: [
        'Accidents, damages, or losses during rides.',
        'Delays, cancellations, or service interruptions.',
        'User misconduct.',
      ],
    ),
    _PolicySectionData(
      number: '9',
      title: 'Suspension and Termination',
      body:
          'We reserve the right to suspend or terminate accounts that violate these terms.',
    ),
    _PolicySectionData(
      number: '10',
      title: 'Amendments',
      body:
          'These Terms may be updated at any time. Continued use of the app means acceptance of changes.',
    ),
  ];

  static const List<_PolicySectionData> _privacySections = [
    _PolicySectionData(
      number: '1',
      title: 'Introduction',
      body:
          'SakayNow Buenatoda respects your privacy and is committed to protecting your personal data in compliance with the Data Privacy Act of 2012.',
    ),
    _PolicySectionData(
      number: '2',
      title: 'Information We Collect',
      bulletGroups: [
        _PolicyBulletGroup(
          label: 'Personal Information',
          items: [
            'Name',
            'Email address',
            'Contact number',
            'Age and gender',
            'Profile photo or selfie',
            'Government-issued ID for drivers',
          ],
        ),
        _PolicyBulletGroup(
          label: 'Account Information',
          items: ['User ID', 'Role such as Passenger, Driver, or Admin'],
        ),
        _PolicyBulletGroup(
          label: 'Location Data',
          items: ['Real-time GPS location for booking and tracking'],
        ),
        _PolicyBulletGroup(
          label: 'Device and Usage Data',
          items: ['Device type', 'App usage logs'],
        ),
      ],
    ),
    _PolicySectionData(
      number: '3',
      title: 'How We Use Your Information',
      intro: 'We use your data to:',
      bullets: [
        'Provide and improve services.',
        'Facilitate ride bookings.',
        'Verify identity and credentials.',
        'Ensure safety and security.',
        'Communicate updates and notifications.',
      ],
    ),
    _PolicySectionData(
      number: '4',
      title: 'Data Sharing',
      bullets: [
        'We may share your data with drivers and passengers for ride coordination.',
        'We may share your data with service providers such as cloud storage and analytics providers.',
        'We may share your data with government authorities when required by law.',
        'We do not sell your personal data.',
      ],
    ),
    _PolicySectionData(
      number: '5',
      title: 'Data Protection Measures',
      intro: 'We implement:',
      bullets: [
        'Secure authentication systems.',
        'Encrypted data storage.',
        'Access control and monitoring.',
      ],
    ),
    _PolicySectionData(
      number: '6',
      title: 'Data Retention',
      body:
          'Your data is retained only as long as necessary for service purposes or legal compliance.',
    ),
    _PolicySectionData(
      number: '7',
      title: 'Your Rights',
      body:
          'Under the Data Privacy Act of 2012, you have the right to access your personal data, correct inaccurate data, request deletion of your data, withdraw consent, and file a complaint with the National Privacy Commission.',
    ),
    _PolicySectionData(
      number: '8',
      title: 'Consent',
      body:
          'By using the app, you consent to the collection and processing of your data as outlined in this policy.',
    ),
    _PolicySectionData(
      number: '9',
      title: 'Cookies and Tracking',
      body:
          'We may use cookies or similar technologies to enhance user experience and analyze usage patterns.',
    ),
    _PolicySectionData(
      number: '10',
      title: 'Changes to Privacy Policy',
      body:
          'We may update this Privacy Policy. Users will be notified of significant changes.',
    ),
    _PolicySectionData(
      number: '11',
      title: 'Contact Us',
      bullets: [
        'SakayNow Buenatoda Support',
        'Email: sakaynowbuenatoda@gmail.com',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.88;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              SizedBox(height: 12),
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: AuthUi.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AuthUi.mutedSurface,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Registration Policy',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Terms and Conditions',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _titleColor,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Please review these terms and privacy practices before creating your SakayNow Buenatoda account.',
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: _bodyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AuthUi.mutedSurface,
                      ),
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _borderColor),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PolicyHighlightCards(),
                      SizedBox(height: 18),
                      _PolicyBlock(
                        icon: Icons.gavel_rounded,
                        accentColor: _primaryColor,
                        title: 'Terms and Conditions',
                        subtitle:
                            'These terms explain the responsibilities, limits, and expected conduct for everyone using the platform.',
                        sections: _termsSections,
                      ),
                      SizedBox(height: 16),
                      _PolicyBlock(
                        icon: Icons.verified_user_outlined,
                        accentColor: _secondaryColor,
                        title: 'Privacy Policy',
                        subtitle:
                            'This outlines what data is collected, how it is used, and the rights available to users.',
                        sections: _privacySections,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyHighlightCards extends StatelessWidget {
  const _PolicyHighlightCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HighlightCard(
            icon: Icons.shield_outlined,
            title: 'Safety First',
            body:
                'Verification, account integrity, and responsible platform use are required.',
            color: AuthUi.mutedSurface,
            iconColor: AuthUi.primary,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _HighlightCard(
            icon: Icons.lock_outline_rounded,
            title: 'Data Privacy',
            body:
                'Your personal information is handled with protection and limited purpose.',
            color: Color(0xFFEFFAF3),
            iconColor: Color(0xFF1F8F4E),
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final Color iconColor;

  const _HighlightCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: TermsAndPrivacyPolicySheet._titleColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: TermsAndPrivacyPolicySheet._bodyColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyBlock extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final List<_PolicySectionData> sections;

  const _PolicyBlock({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TermsAndPrivacyPolicySheet._surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TermsAndPrivacyPolicySheet._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: TermsAndPrivacyPolicySheet._titleColor,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: TermsAndPrivacyPolicySheet._bodyColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PolicySectionCard(
                section: section,
                accentColor: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  final _PolicySectionData section;
  final Color accentColor;

  const _PolicySectionCard({required this.section, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TermsAndPrivacyPolicySheet._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  section.number,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: TermsAndPrivacyPolicySheet._titleColor,
                  ),
                ),
              ),
            ],
          ),
          if (section.body != null) ...[
            SizedBox(height: 10),
            Text(
              section.body!,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: TermsAndPrivacyPolicySheet._bodyColor,
              ),
            ),
          ],
          if (section.intro != null) ...[
            SizedBox(height: 10),
            Text(
              section.intro!,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: TermsAndPrivacyPolicySheet._titleColor,
              ),
            ),
          ],
          if (section.bullets.isNotEmpty) ...[
            SizedBox(height: 10),
            ...section.bullets.map((bullet) => _PolicyBullet(text: bullet)),
          ],
          if (section.bulletGroups.isNotEmpty) ...[
            SizedBox(height: 10),
            ...section.bulletGroups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: TermsAndPrivacyPolicySheet._titleColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...group.items.map((item) => _PolicyBullet(text: item)),
                  ],
                ),
              ),
            ),
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
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: TermsAndPrivacyPolicySheet._secondaryColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: TermsAndPrivacyPolicySheet._bodyColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySectionData {
  final String number;
  final String title;
  final String? body;
  final String? intro;
  final List<String> bullets;
  final List<_PolicyBulletGroup> bulletGroups;

  const _PolicySectionData({
    required this.number,
    required this.title,
    this.body,
    this.intro,
    this.bullets = const <String>[],
    this.bulletGroups = const <_PolicyBulletGroup>[],
  });
}

class _PolicyBulletGroup {
  final String label;
  final List<String> items;

  const _PolicyBulletGroup({required this.label, required this.items});
}
