import 'package:flutter/material.dart';

import '../../widgets/passenger_widgets/passenger_ui.dart';

class DevelopersPage extends StatelessWidget {
  const DevelopersPage({super.key});

  static const List<_DeveloperProfile> _teamLeader = <_DeveloperProfile>[
    _DeveloperProfile(
      name: 'Jary M. Estorgio',
      role: 'Team Leader',
      subtitle: 'Lead Researcher',
    ),
  ];

  static const List<_DeveloperProfile> _members = <_DeveloperProfile>[
    _DeveloperProfile(
      name: 'Noel P. Gicain Jr.',
      role: 'Member',
      subtitle: 'Lead Developer',
    ),
    _DeveloperProfile(
      name: 'Kathleen N. Cordero',
      role: 'Member',
      subtitle: 'Researcher',
    ),
    _DeveloperProfile(
      name: 'Mark S. Turla',
      role: 'Member',
      subtitle: 'Developer',
    ),
    _DeveloperProfile(
      name: 'Regine N. Naquila',
      role: 'Member',
      subtitle: 'Researcher',
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
        title: Text('Developers', style: PassengerUi.cardTitle),
      ),
      body: PassengerPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _DevelopersHeader(),
            SizedBox(height: 18),
            _DeveloperSection(title: 'Team Leader', developers: _teamLeader),
            SizedBox(height: 18),
            _DeveloperSection(title: 'Members', developers: _members),
          ],
        ),
      ),
    );
  }
}

class _DevelopersHeader extends StatelessWidget {
  const _DevelopersHeader();

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: PassengerUi.mutedSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.groups_rounded, color: PassengerUi.primary),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Meet the developers of SakayNow Buenatoda',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PassengerUi.cardTitle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperSection extends StatelessWidget {
  final String title;
  final List<_DeveloperProfile> developers;

  const _DeveloperSection({required this.title, required this.developers});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: PassengerUi.sectionTitle.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 10),
        ...developers.asMap().entries.map(
          (entry) => Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == developers.length - 1 ? 0 : 12,
            ),
            child: _DeveloperCard(profile: entry.value),
          ),
        ),
      ],
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  final _DeveloperProfile profile;

  const _DeveloperCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          _DeveloperAvatar(name: profile.name),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.cardTitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  profile.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.bodyText,
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          PassengerStatusChip(
            label: profile.role,
            textColor: PassengerUi.successText,
            backgroundColor: PassengerUi.successBackground,
          ),
        ],
      ),
    );
  }
}

class _DeveloperAvatar extends StatelessWidget {
  final String name;

  const _DeveloperAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: PassengerUi.accentBlue.withValues(alpha: 0.12),
      child: Text(
        _initials,
        style: TextStyle(
          color: PassengerUi.accentBlue,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }

  String get _initials {
    final parts = name
        .replaceAll('.', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }

    final first = parts.first.characters.first;
    final last = parts.length == 1 ? '' : parts.last.characters.first;
    return '$first$last'.toUpperCase();
  }
}

class _DeveloperProfile {
  final String name;
  final String role;
  final String subtitle;

  const _DeveloperProfile({
    required this.name,
    required this.role,
    required this.subtitle,
  });
}
