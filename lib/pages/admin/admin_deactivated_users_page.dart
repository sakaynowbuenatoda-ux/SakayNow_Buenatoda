import 'package:flutter/material.dart';

import '../../widgets/confirmation_dialog.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

enum DeactivatedUserSort {
  newest,
  oldest,
  name,
  role;

  String get label {
    switch (this) {
      case DeactivatedUserSort.newest:
        return 'Newest deactivation';
      case DeactivatedUserSort.oldest:
        return 'Oldest deactivation';
      case DeactivatedUserSort.name:
        return 'Name A-Z';
      case DeactivatedUserSort.role:
        return 'Role';
    }
  }
}

class AdminDeactivatedUsersPage extends StatefulWidget {
  final String adminId;

  const AdminDeactivatedUsersPage({super.key, required this.adminId});

  @override
  State<AdminDeactivatedUsersPage> createState() =>
      _AdminDeactivatedUsersPageState();
}

class _AdminDeactivatedUsersPageState extends State<AdminDeactivatedUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  DeactivatedUserSort _sort = DeactivatedUserSort.newest;

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
        title: Text('Deactivated Users', style: AdminUi.cardTitle),
      ),
      body: AdminPageContainer(
        maxContentWidth: AdminUi.listContentWidth,
        child: StreamBuilder<List<AdminUserRecord>>(
          stream: AdminService.watchDeactivatedUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AdminErrorCard(
                message: 'Unable to load deactivated users: ${snapshot.error}',
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final users = _sortedUsers(
              snapshot.data!
                  .where((user) => _matchesSearch(user, _query))
                  .toList(growable: false),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminCountPageHeader(
                  title: 'Deactivated Users',
                  subtitle:
                      'Restore accounts before their 60-day permanent deletion window ends.',
                  count: users.length.toString(),
                  countLabel: 'Accounts',
                  icon: Icons.no_accounts_rounded,
                  accentColor: AdminUi.primary,
                ),
                SizedBox(height: 12),
                _DeactivatedUserControls(
                  searchController: _searchController,
                  sort: _sort,
                  onSortChanged: (value) => setState(() => _sort = value),
                ),
                SizedBox(height: 16),
                Text('User List', style: AdminUi.sectionTitle),
                SizedBox(height: 12),
                if (users.isEmpty)
                  AdminEmptyCollection(
                    icon: Icons.no_accounts_outlined,
                    title: _query.isEmpty
                        ? 'No deactivated users'
                        : 'No matching deactivated users',
                    description: _query.isEmpty
                        ? 'Accounts deactivated by users will appear here during their 60-day restoration window.'
                        : 'Try searching by name, email, role, or user ID.',
                  )
                else
                  ...users.map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AdminUserCard(
                        user: user,
                        hintLabel: _deactivationSummary(user),
                        actions: [
                          AdminActionButton(
                            label: user.canRestoreDeactivated
                                ? 'Restore'
                                : 'Expired',
                            icon: Icons.restore_rounded,
                            backgroundColor: user.canRestoreDeactivated
                                ? AdminUi.successBackground
                                : AdminUi.mutedSurface,
                            foregroundColor: user.canRestoreDeactivated
                                ? AdminUi.successText
                                : AdminUi.body,
                            onPressed: user.canRestoreDeactivated
                                ? () => _confirmRestore(user)
                                : null,
                          ),
                        ],
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

  List<AdminUserRecord> _sortedUsers(List<AdminUserRecord> users) {
    final sorted = List<AdminUserRecord>.of(users);

    sorted.sort((a, b) {
      switch (_sort) {
        case DeactivatedUserSort.newest:
          return _deactivationDate(b).compareTo(_deactivationDate(a));
        case DeactivatedUserSort.oldest:
          return _deactivationDate(a).compareTo(_deactivationDate(b));
        case DeactivatedUserSort.name:
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        case DeactivatedUserSort.role:
          final roleCompare = a.roleLabel.compareTo(b.roleLabel);
          return roleCompare == 0
              ? a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase())
              : roleCompare;
      }
    });

    return sorted;
  }

  DateTime _deactivationDate(AdminUserRecord user) {
    return user.deactivatedAt ??
        user.deactivationRestoreDeadline ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _deactivationSummary(AdminUserRecord user) {
    final deactivated = user.deactivatedAt == null
        ? 'Deactivation date unavailable'
        : 'Deactivated ${_formatDate(user.deactivatedAt!)}';
    final deadline = user.deactivationRestoreDeadline;

    if (deadline == null) {
      return '$deactivated. Restore within 60 days from deactivation.';
    }

    final daysLeft = deadline.difference(DateTime.now()).inDays;
    final window = deadline.isBefore(DateTime.now())
        ? 'Restore window expired ${_formatDate(deadline)}.'
        : '${daysLeft.clamp(0, 60)} day(s) left. Restore before ${_formatDate(deadline)}.';

    return '$deactivated. $window';
  }

  Future<void> _confirmRestore(AdminUserRecord user) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Restore Account?',
      message:
          'This will restore ${user.fullName} and allow the account to sign in again. The existing verification state will be preserved.',
      confirmLabel: 'Restore',
      icon: Icons.restore_rounded,
      confirmColor: AdminUi.successText,
    );

    if (!confirmed || !mounted) {
      return;
    }

    try {
      await AdminService.restoreDeactivatedUser(
        userId: user.userId,
        adminId: widget.adminId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.fullName} has been restored.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $error')));
    }
  }

  bool _matchesSearch(AdminUserRecord user, String query) {
    if (query.isEmpty) {
      return true;
    }

    final haystack = <String>[
      user.fullName,
      user.email,
      user.roleLabel,
      user.statusLabel,
      user.userId,
    ].join(' ').toLowerCase();

    return haystack.contains(query);
  }

  String _formatDate(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _DeactivatedUserControls extends StatelessWidget {
  final TextEditingController searchController;
  final DeactivatedUserSort sort;
  final ValueChanged<DeactivatedUserSort> onSortChanged;

  const _DeactivatedUserControls({
    required this.searchController,
    required this.sort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final search = _SearchField(controller: searchController);
    final sortMenu = _SortMenu(sort: sort, onChanged: onSortChanged);

    if (compact) {
      return Column(children: [search, SizedBox(height: 10), sortMenu]);
    }

    return Row(
      children: [
        Expanded(child: search),
        SizedBox(width: 12),
        SizedBox(width: 230, child: sortMenu),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by name, email, role, or user ID',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: AdminUi.surface,
        border: OutlineInputBorder(
          borderRadius: AdminUi.radius,
          borderSide: BorderSide(color: AdminUi.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AdminUi.radius,
          borderSide: BorderSide(color: AdminUi.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AdminUi.radius,
          borderSide: BorderSide(color: AdminUi.accent, width: 1.4),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  final DeactivatedUserSort sort;
  final ValueChanged<DeactivatedUserSort> onChanged;

  const _SortMenu({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DeactivatedUserSort>(
      value: sort,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Sort',
        prefixIcon: const Icon(Icons.sort_rounded),
        filled: true,
        fillColor: AdminUi.surface,
        border: OutlineInputBorder(
          borderRadius: AdminUi.radius,
          borderSide: BorderSide(color: AdminUi.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AdminUi.radius,
          borderSide: BorderSide(color: AdminUi.border),
        ),
      ),
      items: DeactivatedUserSort.values
          .map(
            (value) => DropdownMenuItem<DeactivatedUserSort>(
              value: value,
              child: Text(value.label),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
