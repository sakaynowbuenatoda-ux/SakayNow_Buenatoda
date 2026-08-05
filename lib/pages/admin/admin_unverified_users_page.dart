import 'package:flutter/material.dart';

import 'admin_navigation.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

enum AdminUnverifiedQueueType { drivers, passengers }

enum _UnverifiedQueueSort {
  newest,
  alphabetical;

  String get label {
    switch (this) {
      case _UnverifiedQueueSort.newest:
        return 'Newest';
      case _UnverifiedQueueSort.alphabetical:
        return 'Alphabetical';
    }
  }
}

class AdminUnverifiedUsersPage extends StatefulWidget {
  final String adminId;
  final AdminUnverifiedQueueType queueType;

  const AdminUnverifiedUsersPage({
    super.key,
    required this.adminId,
    required this.queueType,
  });

  @override
  State<AdminUnverifiedUsersPage> createState() =>
      _AdminUnverifiedUsersPageState();
}

class _AdminUnverifiedUsersPageState extends State<AdminUnverifiedUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _UnverifiedQueueSort _sort = _UnverifiedQueueSort.newest;

  bool get _showDrivers => widget.queueType == AdminUnverifiedQueueType.drivers;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminUi.background,
      appBar: AppBar(
        backgroundColor: AdminUi.surface,
        surfaceTintColor: AdminUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: AdminUi.title),
        ),
        title: Text(_pageTitle, style: AdminUi.cardTitle),
      ),
      body: AdminPageContainer(
        maxContentWidth: AdminUi.listContentWidth,
        child: StreamBuilder<List<AdminUserRecord>>(
          stream: AdminService.watchUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AdminErrorCard(
                message: 'Unable to load $_collectionLabel. Please try again.',
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final filteredUsers = snapshot.data!
                .where(
                  (user) =>
                      user.isPendingVerification ||
                      (_showDrivers && user.isPendingRenewal),
                )
                .where(
                  (user) => _showDrivers ? user.isDriver : user.isPassenger,
                )
                .where(_matchesSearch)
                .toList(growable: false);
            _sortUsers(filteredUsers);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminCountPageHeader(
                  title: _pageTitle,
                  subtitle: _pageSubtitle,
                  count: filteredUsers.length.toString(),
                  countLabel: _metricLabel,
                  icon: _showDrivers
                      ? Icons.two_wheeler_rounded
                      : Icons.person_outline_rounded,
                  accentColor: _showDrivers
                      ? AdminUi.secondary
                      : AdminUi.accentBlue,
                ),
                SizedBox(height: 12),
                _UnverifiedQueueControls(
                  searchController: _searchController,
                  sort: _sort,
                  onSortChanged: (value) => setState(() => _sort = value),
                ),
                SizedBox(height: 18),
                Text(_sectionTitle, style: AdminUi.sectionTitle),
                SizedBox(height: 6),
                Text(_sectionSubtitle, style: AdminUi.bodyText),
                SizedBox(height: 12),
                if (filteredUsers.isEmpty)
                  AdminEmptyCollection(
                    icon: _showDrivers
                        ? Icons.drive_eta_outlined
                        : Icons.person_search_outlined,
                    title: _query.isEmpty
                        ? _emptyTitle
                        : 'No matching users found',
                    description: _query.isEmpty
                        ? _emptyDescription
                        : 'Try searching by name, email, role, or account status.',
                  )
                else
                  ...filteredUsers.map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AdminQueueUserTile(
                        user: user,
                        onView: () => AdminNavigation.openUserReview(
                          context,
                          adminId: widget.adminId,
                          userId: user.userId,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String get _pageTitle =>
      _showDrivers ? 'Unverified Drivers' : 'Unverified Passengers';

  String get _pageSubtitle => _showDrivers
      ? 'Review drivers who uploaded a selfie, NBI clearance, and license before approving their account.'
      : 'Review passengers who uploaded a selfie and ID before approving their account.';

  String get _collectionLabel =>
      _showDrivers ? 'unverified drivers' : 'unverified passengers';

  String get _metricLabel =>
      _showDrivers ? 'Drivers Waiting' : 'Passengers Waiting';

  String get _sectionTitle => _showDrivers ? 'Driver Queue' : 'Passenger Queue';

  String get _sectionSubtitle => _showDrivers
      ? 'Each list item shows the submitted selfie profile and opens a full driver review page with selfie, NBI clearance, and license.'
      : 'Each list item shows the submitted selfie profile and opens a full passenger review page with selfie and ID.';

  String get _emptyTitle => _showDrivers
      ? 'No unverified drivers waiting'
      : 'No unverified passengers waiting';

  String get _emptyDescription => _showDrivers
      ? 'New driver signups will appear here when they are still waiting for admin verification.'
      : 'New passenger signups will appear here when they are still waiting for admin verification.';

  bool _matchesSearch(AdminUserRecord user) {
    if (_query.isEmpty) {
      return true;
    }

    final haystack = <String>[
      user.fullName,
      user.email,
      user.roleLabel,
      user.statusLabel,
      user.userId,
    ].join(' ').toLowerCase();

    return haystack.contains(_query);
  }

  void _sortUsers(List<AdminUserRecord> users) {
    switch (_sort) {
      case _UnverifiedQueueSort.newest:
        users.sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        return;
      case _UnverifiedQueueSort.alphabetical:
        users.sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
        return;
    }
  }
}

class _UnverifiedQueueControls extends StatelessWidget {
  final TextEditingController searchController;
  final _UnverifiedQueueSort sort;
  final ValueChanged<_UnverifiedQueueSort> onSortChanged;

  const _UnverifiedQueueControls({
    required this.searchController,
    required this.sort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final search = TextField(
      controller: searchController,
      textInputAction: TextInputAction.search,
      decoration: AdminUi.inputDecoration(
        hintText: 'Search by name, email, role, or status',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: searchController.clear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
    final sortField = DropdownButtonFormField<_UnverifiedQueueSort>(
      value: sort,
      isExpanded: true,
      decoration: AdminUi.inputDecoration(
        hintText: '',
        labelText: 'Sort',
        prefixIcon: const Icon(Icons.sort_rounded),
      ),
      items: _UnverifiedQueueSort.values
          .map(
            (value) => DropdownMenuItem<_UnverifiedQueueSort>(
              value: value,
              child: Text(value.label),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value != null) {
          onSortChanged(value);
        }
      },
    );

    if (compact) {
      return Column(children: [search, SizedBox(height: 10), sortField]);
    }

    return Row(
      children: [
        Expanded(child: search),
        SizedBox(width: 12),
        SizedBox(width: 210, child: sortField),
      ],
    );
  }
}
