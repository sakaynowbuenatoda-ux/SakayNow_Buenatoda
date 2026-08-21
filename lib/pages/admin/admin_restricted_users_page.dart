import 'package:flutter/material.dart';

import '../../utils/user_facing_error_message.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/confirmation_dialog.dart';
import 'admin_models.dart';
import 'admin_navigation.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

enum RestrictedUserSort {
  newest,
  oldest,
  name,
  role;

  String get label {
    switch (this) {
      case RestrictedUserSort.newest:
        return 'Newest restriction';
      case RestrictedUserSort.oldest:
        return 'Oldest restriction';
      case RestrictedUserSort.name:
        return 'Name A-Z';
      case RestrictedUserSort.role:
        return 'Role';
    }
  }
}

class AdminRestrictedUsersPage extends StatefulWidget {
  final String adminId;

  const AdminRestrictedUsersPage({super.key, required this.adminId});

  @override
  State<AdminRestrictedUsersPage> createState() =>
      _AdminRestrictedUsersPageState();
}

class _AdminRestrictedUsersPageState extends State<AdminRestrictedUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  RestrictedUserSort _sort = RestrictedUserSort.newest;

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
      appBar: const AdminDetailAppBar(title: 'Restricted Users'),
      body: AdminPageContainer(
        maxContentWidth: AdminUi.listContentWidth,
        child: StreamBuilder<List<AdminUserRecord>>(
          stream: AdminService.watchRestrictedUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AdminErrorCard(
                message: 'Unable to load restricted users. Please try again.',
              );
            }

            if (!snapshot.hasData) {
              return const AppSkeletonList(padding: EdgeInsets.zero);
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
                  title: 'Restricted Users',
                  subtitle:
                      'Review accounts blocked by admin decisions and restore access when the review is complete.',
                  count: users.length.toString(),
                  countLabel: 'Accounts',
                  accentColor: AdminUi.highlightAmber,
                ),
                SizedBox(height: 12),
                _RestrictedUserControls(
                  searchController: _searchController,
                  sort: _sort,
                  onSortChanged: (value) => setState(() => _sort = value),
                ),
                SizedBox(height: 16),
                Text('User List', style: AdminUi.sectionTitle),
                SizedBox(height: 12),
                if (users.isEmpty)
                  AdminEmptyCollection(
                    icon: Icons.block_outlined,
                    title: _query.isEmpty
                        ? 'No restricted users'
                        : 'No matching restricted users',
                    description: _query.isEmpty
                        ? 'Accounts restricted by admins will appear here for follow-up review.'
                        : 'Try searching by name, email, role, status, or user ID.',
                  )
                else
                  ...users.map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AdminUserCard(
                        user: user,
                        hintLabel: _restrictionSummary(user),
                        onTap: () => AdminNavigation.openUserProfile(
                          context,
                          adminId: widget.adminId,
                          userId: user.userId,
                        ),
                        actions: [
                          AdminActionButton(
                            label: 'View Profile',
                            icon: Icons.visibility_outlined,
                            backgroundColor: AdminUi.blueSoft,
                            foregroundColor: AdminUi.accentBlue,
                            onPressed: () => AdminNavigation.openUserProfile(
                              context,
                              adminId: widget.adminId,
                              userId: user.userId,
                            ),
                          ),
                          AdminActionButton(
                            label: 'Restore Access',
                            icon: Icons.restart_alt_rounded,
                            backgroundColor: AdminUi.successBackground,
                            foregroundColor: AdminUi.successText,
                            onPressed: () => _confirmRestore(user),
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
        case RestrictedUserSort.newest:
          return _restrictionDate(b).compareTo(_restrictionDate(a));
        case RestrictedUserSort.oldest:
          return _restrictionDate(a).compareTo(_restrictionDate(b));
        case RestrictedUserSort.name:
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        case RestrictedUserSort.role:
          final roleCompare = a.roleLabel.compareTo(b.roleLabel);
          return roleCompare == 0
              ? a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase())
              : roleCompare;
      }
    });

    return sorted;
  }

  DateTime _restrictionDate(AdminUserRecord user) {
    return user.reviewedAt ??
        user.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _restrictionSummary(AdminUserRecord user) {
    final date = user.reviewedAt == null
        ? 'Restriction date unavailable'
        : 'Restricted ${formatDateTime(user.reviewedAt)}';

    return '$date. Restore access only after the account review is complete.';
  }

  Future<void> _confirmRestore(AdminUserRecord user) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Restore Access?',
      message:
          'This will restore ${user.fullName}, mark the account as active, and allow the user to sign in again.',
      confirmLabel: 'Restore',
      icon: Icons.restart_alt_rounded,
      confirmColor: AdminUi.successText,
    );

    if (!confirmed || !mounted) {
      return;
    }

    try {
      await AdminService.restoreUser(
        userId: user.userId,
        adminId: widget.adminId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.fullName} is active again.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback: 'Unable to restore this account. Please try again.',
            ),
          ),
        ),
      );
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
}

class _RestrictedUserControls extends StatelessWidget {
  final TextEditingController searchController;
  final RestrictedUserSort sort;
  final ValueChanged<RestrictedUserSort> onSortChanged;

  const _RestrictedUserControls({
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
      decoration: AdminUi.inputDecoration(
        hintText: 'Search by name, email, role, status, or user ID',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  final RestrictedUserSort sort;
  final ValueChanged<RestrictedUserSort> onChanged;

  const _SortMenu({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<RestrictedUserSort>(
      value: sort,
      isExpanded: true,
      decoration: AdminUi.inputDecoration(
        hintText: '',
        labelText: 'Sort',
        prefixIcon: const Icon(Icons.sort_rounded),
      ),
      items: RestrictedUserSort.values
          .map(
            (value) => DropdownMenuItem<RestrictedUserSort>(
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
