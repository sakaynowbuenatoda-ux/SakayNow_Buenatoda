import 'package:flutter/material.dart';

import '../../services/admin_account_service.dart';
import '../../services/chat_service.dart';
import '../../utils/user_facing_error_message.dart';
import '../../widgets/confirmation_dialog.dart';
import '../messages/chat_page.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

enum AdminAccountStatusFilter {
  all,
  active,
  deactivated;

  String get label {
    switch (this) {
      case AdminAccountStatusFilter.all:
        return 'All';
      case AdminAccountStatusFilter.active:
        return 'Active';
      case AdminAccountStatusFilter.deactivated:
        return 'Deactivated';
    }
  }
}

enum AdminAccountSort {
  newest,
  name;

  String get label {
    switch (this) {
      case AdminAccountSort.newest:
        return 'Newest';
      case AdminAccountSort.name:
        return 'Name A-Z';
    }
  }
}

class AdminAccountsPage extends StatefulWidget {
  final String adminId;

  const AdminAccountsPage({super.key, required this.adminId});

  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage> {
  final TextEditingController _searchController = TextEditingController();
  final AdminAccountService _accountService = AdminAccountService();
  final Set<String> _deactivatingAdminIds = <String>{};
  final Set<String> _restoringAdminIds = <String>{};
  String _query = '';
  AdminAccountStatusFilter _statusFilter = AdminAccountStatusFilter.all;
  AdminAccountSort _sort = AdminAccountSort.newest;

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
        title: Text('Admin Accounts', style: AdminUi.cardTitle),
      ),
      body: AdminPageContainer(
        maxContentWidth: AdminUi.listContentWidth,
        child: StreamBuilder<AdminUserRecord>(
          stream: AdminService.watchUser(widget.adminId),
          builder: (context, currentAdminSnapshot) {
            if (currentAdminSnapshot.hasError) {
              return AdminErrorCard(
                message:
                    'Unable to confirm main admin access: ${currentAdminSnapshot.error}',
              );
            }

            if (!currentAdminSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final currentAdmin = currentAdminSnapshot.data!;
            if (!currentAdmin.isMainAdmin) {
              return const AdminErrorCard(
                message:
                    'Only the main admin account can manage admin accounts.',
              );
            }

            return StreamBuilder<List<AdminUserRecord>>(
              stream: AdminService.watchManagedAdmins(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AdminErrorCard(
                    message: 'Unable to load admin accounts. Please try again.',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allAdmins = snapshot.data!;
                final filteredAdmins = _sortedAdmins(
                  allAdmins
                      .where(_matchesStatusFilter)
                      .where(_matchesSearch)
                      .toList(growable: false),
                );
                final hasActiveFilters =
                    _query.isNotEmpty ||
                    _statusFilter != AdminAccountStatusFilter.all;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminCountPageHeader(
                      title: 'Admin Accounts',
                      subtitle:
                          'Manage secondary admin accounts created by the main admin.',
                      count: filteredAdmins.length.toString(),
                      countLabel: 'Admins',
                      accentColor: AdminUi.primary,
                    ),
                    const SizedBox(height: 12),
                    _AdminAccountControls(
                      searchController: _searchController,
                      statusFilter: _statusFilter,
                      sort: _sort,
                      onStatusFilterChanged: (value) =>
                          setState(() => _statusFilter = value),
                      onSortChanged: (value) => setState(() => _sort = value),
                    ),
                    const SizedBox(height: 16),
                    Text('Admin List', style: AdminUi.sectionTitle),
                    const SizedBox(height: 12),
                    if (filteredAdmins.isEmpty)
                      AdminEmptyCollection(
                        icon: hasActiveFilters
                            ? Icons.search_off_rounded
                            : Icons.admin_panel_settings_outlined,
                        title: hasActiveFilters
                            ? 'No matching admin accounts'
                            : 'No secondary admin accounts',
                        description: hasActiveFilters
                            ? 'Try searching by name, email, status, or user ID.'
                            : 'Admin accounts created by the main admin will appear here.',
                      )
                    else
                      ...filteredAdmins.map(
                        (admin) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AdminUserCard(
                            user: admin,
                            hintLabel: _adminSummary(admin),
                            actions: [
                              _AdminDirectMessageButton(
                                currentAdmin: currentAdmin,
                                targetAdmin: admin,
                              ),
                              if (admin.isDeactivated)
                                AdminActionButton(
                                  label:
                                      _restoringAdminIds.contains(admin.userId)
                                      ? 'Restoring...'
                                      : 'Restore',
                                  icon: Icons.restore_rounded,
                                  backgroundColor: AdminUi.successBackground,
                                  foregroundColor: AdminUi.successText,
                                  onPressed:
                                      _restoringAdminIds.contains(admin.userId)
                                      ? null
                                      : () => _confirmRestore(admin),
                                )
                              else
                                AdminActionButton(
                                  label:
                                      _deactivatingAdminIds.contains(
                                        admin.userId,
                                      )
                                      ? 'Deactivating...'
                                      : 'Deactivate',
                                  icon: Icons.block_rounded,
                                  backgroundColor: AdminUi.dangerSoft,
                                  foregroundColor: AdminUi.danger,
                                  onPressed:
                                      _deactivatingAdminIds.contains(
                                        admin.userId,
                                      )
                                      ? null
                                      : () => _confirmDeactivate(admin),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _matchesStatusFilter(AdminUserRecord admin) {
    switch (_statusFilter) {
      case AdminAccountStatusFilter.all:
        return true;
      case AdminAccountStatusFilter.active:
        return !admin.isDeactivated && !admin.isDeleted;
      case AdminAccountStatusFilter.deactivated:
        return admin.isDeactivated && !admin.isDeleted;
    }
  }

  bool _matchesSearch(AdminUserRecord admin) {
    if (_query.isEmpty) {
      return true;
    }

    final haystack = <String>[
      admin.fullName,
      admin.email,
      admin.statusLabel,
      admin.userId,
    ].join(' ').toLowerCase();

    return haystack.contains(_query);
  }

  List<AdminUserRecord> _sortedAdmins(List<AdminUserRecord> admins) {
    final sorted = List<AdminUserRecord>.of(admins);

    switch (_sort) {
      case AdminAccountSort.newest:
        sorted.sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        return sorted;
      case AdminAccountSort.name:
        sorted.sort(
          (a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        );
        return sorted;
    }
  }

  String _adminSummary(AdminUserRecord admin) {
    if (admin.isDeactivated) {
      final date = admin.deactivatedAt == null
          ? 'Deactivation timestamp unavailable'
          : 'Deactivated ${formatDateTime(admin.deactivatedAt)}';
      return '$date. This admin no longer has admin privileges.';
    }

    final createdAt = admin.createdAt == null
        ? 'Creation timestamp unavailable'
        : 'Created ${formatDateTime(admin.createdAt)}';
    return '$createdAt. This account can access admin tools while active.';
  }

  Future<void> _confirmDeactivate(AdminUserRecord admin) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Deactivate Admin?',
      message:
          'This will deactivate ${admin.fullName} and remove admin access. This does not delete the account.',
      confirmLabel: 'Deactivate',
      icon: Icons.no_accounts_rounded,
      confirmColor: AdminUi.danger,
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _deactivatingAdminIds.add(admin.userId));
    try {
      await _accountService.deactivateAdminAccount(adminUserId: admin.userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${admin.fullName} has been deactivated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback: 'Unable to deactivate this admin. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deactivatingAdminIds.remove(admin.userId));
      }
    }
  }

  Future<void> _confirmRestore(AdminUserRecord admin) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Restore Admin?',
      message:
          'This will restore ${admin.fullName} and allow the account to use admin tools again.',
      confirmLabel: 'Restore',
      icon: Icons.restore_rounded,
      confirmColor: AdminUi.successText,
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _restoringAdminIds.add(admin.userId));
    try {
      await _accountService.restoreAdminAccount(adminUserId: admin.userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${admin.fullName} has been restored.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingErrorMessage(
              error,
              fallback: 'Unable to restore this admin. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _restoringAdminIds.remove(admin.userId));
      }
    }
  }
}

class _AdminAccountControls extends StatelessWidget {
  final TextEditingController searchController;
  final AdminAccountStatusFilter statusFilter;
  final AdminAccountSort sort;
  final ValueChanged<AdminAccountStatusFilter> onStatusFilterChanged;
  final ValueChanged<AdminAccountSort> onSortChanged;

  const _AdminAccountControls({
    required this.searchController,
    required this.statusFilter,
    required this.sort,
    required this.onStatusFilterChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 820;
    final search = _AdminAccountSearchField(controller: searchController);
    final status = _AdminAccountStatusFilterField(
      value: statusFilter,
      onChanged: onStatusFilterChanged,
    );
    final sortField = _AdminAccountSortField(
      value: sort,
      onChanged: onSortChanged,
    );

    if (compact) {
      return Column(
        children: [
          search,
          const SizedBox(height: 10),
          status,
          const SizedBox(height: 10),
          sortField,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: search),
        const SizedBox(width: 12),
        SizedBox(width: 180, child: status),
        const SizedBox(width: 12),
        SizedBox(width: 180, child: sortField),
      ],
    );
  }
}

class _AdminAccountSearchField extends StatelessWidget {
  final TextEditingController controller;

  const _AdminAccountSearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: AdminUi.inputDecoration(
        hintText: 'Search by name, email, status, or user ID',
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

class _AdminAccountStatusFilterField extends StatelessWidget {
  final AdminAccountStatusFilter value;
  final ValueChanged<AdminAccountStatusFilter> onChanged;

  const _AdminAccountStatusFilterField({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AdminAccountStatusFilter>(
      value: value,
      isExpanded: true,
      decoration: AdminUi.inputDecoration(
        hintText: '',
        labelText: 'Status',
        prefixIcon: const Icon(Icons.filter_list_rounded),
      ),
      items: AdminAccountStatusFilter.values
          .map(
            (filter) => DropdownMenuItem<AdminAccountStatusFilter>(
              value: filter,
              child: Text(filter.label),
            ),
          )
          .toList(growable: false),
      onChanged: (next) {
        if (next != null) {
          onChanged(next);
        }
      },
    );
  }
}

class _AdminAccountSortField extends StatelessWidget {
  final AdminAccountSort value;
  final ValueChanged<AdminAccountSort> onChanged;

  const _AdminAccountSortField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AdminAccountSort>(
      value: value,
      isExpanded: true,
      decoration: AdminUi.inputDecoration(
        hintText: '',
        labelText: 'Sort',
        prefixIcon: const Icon(Icons.sort_rounded),
      ),
      items: AdminAccountSort.values
          .map(
            (sort) => DropdownMenuItem<AdminAccountSort>(
              value: sort,
              child: Text(sort.label),
            ),
          )
          .toList(growable: false),
      onChanged: (next) {
        if (next != null) {
          onChanged(next);
        }
      },
    );
  }
}

class _AdminDirectMessageButton extends StatefulWidget {
  final AdminUserRecord currentAdmin;
  final AdminUserRecord targetAdmin;

  const _AdminDirectMessageButton({
    required this.currentAdmin,
    required this.targetAdmin,
  });

  @override
  State<_AdminDirectMessageButton> createState() =>
      _AdminDirectMessageButtonState();
}

class _AdminDirectMessageButtonState extends State<_AdminDirectMessageButton> {
  final ChatService _chatService = ChatService();
  bool _isOpening = false;

  bool get _canMessage {
    return !_isOpening &&
        !widget.targetAdmin.isDeactivated &&
        !widget.targetAdmin.isDeleted &&
        widget.currentAdmin.userId.trim().isNotEmpty &&
        widget.targetAdmin.userId.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return AdminActionButton(
      label: _isOpening ? 'Opening...' : 'Message',
      icon: _isOpening
          ? Icons.hourglass_top_rounded
          : Icons.chat_bubble_outline_rounded,
      backgroundColor: AdminUi.blueSoft,
      foregroundColor: AdminUi.accentBlue,
      onPressed: _canMessage ? _openConversation : null,
    );
  }

  Future<void> _openConversation() async {
    if (_isOpening) {
      return;
    }

    setState(() => _isOpening = true);
    try {
      final conversationId = await _chatService.ensureAdminConversation(
        currentAdminId: widget.currentAdmin.userId,
        currentAdminName: widget.currentAdmin.fullName,
        targetAdminId: widget.targetAdmin.userId,
        targetAdminName: widget.targetAdmin.fullName,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            currentUserId: widget.currentAdmin.userId,
            currentUserRole: 'admin',
            title: widget.targetAdmin.fullName,
            subtitle: 'Admin direct',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open message: $error')));
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }
}
