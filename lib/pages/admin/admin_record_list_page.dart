import 'package:flutter/material.dart';

import '../../utils/user_facing_error_message.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/confirmation_dialog.dart';
import 'admin_models.dart';
import 'admin_navigation.dart';
import 'admin_service.dart';
import 'widgets/admin_message_user_button.dart';
import 'widgets/admin_shared.dart';

enum AdminRecordListType {
  registeredUsers,
  activeDrivers,
  expiredDriverDocuments,
  studentAccounts,
  completedTrips,
  activeTrips,
}

enum AdminRecordSort {
  newest,
  alphabetical;

  String get label {
    switch (this) {
      case AdminRecordSort.newest:
        return 'Newest';
      case AdminRecordSort.alphabetical:
        return 'Alphabetical';
    }
  }
}

enum AdminRegisteredUserRoleFilter {
  all,
  drivers,
  passengers;

  String get label {
    switch (this) {
      case AdminRegisteredUserRoleFilter.all:
        return 'All';
      case AdminRegisteredUserRoleFilter.drivers:
        return 'Drivers';
      case AdminRegisteredUserRoleFilter.passengers:
        return 'Passengers';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminRegisteredUserRoleFilter.all:
        return Icons.groups_rounded;
      case AdminRegisteredUserRoleFilter.drivers:
        return Icons.local_taxi_rounded;
      case AdminRegisteredUserRoleFilter.passengers:
        return Icons.person_rounded;
    }
  }
}

class AdminRecordListPage extends StatefulWidget {
  final String adminId;
  final AdminRecordListType listType;

  const AdminRecordListPage({
    super.key,
    required this.adminId,
    required this.listType,
  });

  @override
  State<AdminRecordListPage> createState() => _AdminRecordListPageState();
}

class _AdminRecordListPageState extends State<AdminRecordListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  AdminRecordSort _sort = AdminRecordSort.newest;
  AdminRegisteredUserRoleFilter _registeredUserRoleFilter =
      AdminRegisteredUserRoleFilter.all;

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
      appBar: AdminDetailAppBar(title: widget.listType.title),
      body: widget.listType.isUserList
          ? _AdminUserRecordList(
              adminId: widget.adminId,
              listType: widget.listType,
              query: _query,
              sort: _sort,
              roleFilter: _registeredUserRoleFilter,
              searchController: _searchController,
              onSortChanged: (value) => setState(() => _sort = value),
              onRoleFilterChanged: (value) =>
                  setState(() => _registeredUserRoleFilter = value),
            )
          : _AdminBookingRecordList(
              listType: widget.listType,
              query: _query,
              sort: _sort,
              searchController: _searchController,
              onSortChanged: (value) => setState(() => _sort = value),
            ),
    );
  }
}

class _AdminUserRecordList extends StatelessWidget {
  final String adminId;
  final AdminRecordListType listType;
  final String query;
  final AdminRecordSort sort;
  final AdminRegisteredUserRoleFilter roleFilter;
  final TextEditingController searchController;
  final ValueChanged<AdminRecordSort> onSortChanged;
  final ValueChanged<AdminRegisteredUserRoleFilter> onRoleFilterChanged;

  const _AdminUserRecordList({
    required this.adminId,
    required this.listType,
    required this.query,
    required this.sort,
    required this.roleFilter,
    required this.searchController,
    required this.onSortChanged,
    required this.onRoleFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final usersStream = listType == AdminRecordListType.activeDrivers
        ? AdminService.watchActiveDrivers()
        : AdminService.watchUsers();

    return AdminPageContainer(
      maxContentWidth: AdminUi.listContentWidth,
      child: StreamBuilder<List<AdminUserRecord>>(
        stream: usersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AdminErrorCard(
              message: 'Unable to load ${listType.title}. Please try again.',
            );
          }

          if (!snapshot.hasData) {
            return const AppSkeletonList(padding: EdgeInsets.zero);
          }

          final users = snapshot.data!
              .where(listType.matchesUser)
              .where(
                (user) => _matchesRegisteredUserRoleFilter(user, roleFilter),
              )
              .where((user) => _matchesUserSearch(user, query))
              .toList(growable: false);
          _sortUsers(users, sort);
          final hasActiveFilters =
              query.isNotEmpty ||
              (listType == AdminRecordListType.registeredUsers &&
                  roleFilter != AdminRegisteredUserRoleFilter.all);

          return _AdminRecordListLayout(
            listType: listType,
            count: users.length,
            searchController: searchController,
            searchHint: listType.userSearchHint,
            sort: sort,
            onSortChanged: onSortChanged,
            roleFilter: listType == AdminRecordListType.registeredUsers
                ? roleFilter
                : null,
            onRoleFilterChanged: listType == AdminRecordListType.registeredUsers
                ? onRoleFilterChanged
                : null,
            empty: users.isEmpty
                ? AdminEmptyCollection(
                    icon: listType.icon,
                    title: !hasActiveFilters
                        ? listType.emptyTitle
                        : 'No matching users found',
                    description: !hasActiveFilters
                        ? listType.emptyDescription
                        : 'Try a different search or role filter.',
                  )
                : null,
            children: users
                .map((user) {
                  return Padding(
                    key: ValueKey<String>('admin_user_${user.userId}'),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AdminUserListCard(
                      user: user,
                      adminId: adminId,
                      hintLabel: listType.userHint(user),
                      onTap: () => AdminNavigation.openUserProfile(
                        context,
                        adminId: adminId,
                        userId: user.userId,
                      ),
                      onRestrict: user.isBanned
                          ? null
                          : () => _confirmAndRunUserAction(
                              context,
                              title: 'Restrict Account?',
                              message:
                                  'This will block ${user.fullName} from using verification-gated app features until access is restored.',
                              confirmLabel: 'Restrict',
                              icon: Icons.block_rounded,
                              confirmColor: AdminUi.primary,
                              action: () => AdminService.restrictUser(
                                userId: user.userId,
                                adminId: adminId,
                              ),
                              successMessage:
                                  '${user.fullName} has been restricted.',
                            ),
                      onRestore: user.isBanned
                          ? () => _runUserAction(
                              context,
                              action: () => AdminService.restoreUser(
                                userId: user.userId,
                                adminId: adminId,
                              ),
                              successMessage:
                                  '${user.fullName} has been restored.',
                            )
                          : null,
                    ),
                  );
                })
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _AdminBookingRecordList extends StatelessWidget {
  final AdminRecordListType listType;
  final String query;
  final AdminRecordSort sort;
  final TextEditingController searchController;
  final ValueChanged<AdminRecordSort> onSortChanged;

  const _AdminBookingRecordList({
    required this.listType,
    required this.query,
    required this.sort,
    required this.searchController,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AdminPageContainer(
      maxContentWidth: AdminUi.listContentWidth,
      child: StreamBuilder<List<AdminUserRecord>>(
        stream: AdminService.watchUsers(),
        builder: (context, usersSnapshot) {
          if (usersSnapshot.hasError) {
            return AdminErrorCard(
              message: 'Unable to load users: ${usersSnapshot.error}',
            );
          }

          if (!usersSnapshot.hasData) {
            return const AppSkeletonList(padding: EdgeInsets.zero);
          }

          final usersById = <String, AdminUserRecord>{
            for (final user in usersSnapshot.data!) user.userId: user,
          };

          return StreamBuilder<List<AdminBookingRecord>>(
            stream: AdminService.watchBookings(),
            builder: (context, bookingsSnapshot) {
              if (bookingsSnapshot.hasError) {
                return AdminErrorCard(
                  message:
                      'Unable to load ${listType.title}: ${bookingsSnapshot.error}',
                );
              }

              if (!bookingsSnapshot.hasData) {
                return const AppSkeletonList(padding: EdgeInsets.zero);
              }

              final bookings = bookingsSnapshot.data!
                  .where(listType.matchesBooking)
                  .where(
                    (booking) => _matchesBookingSearch(
                      booking,
                      query,
                      passengerName:
                          usersById[booking.passengerId]?.fullName ??
                          'Passenger',
                      driverName:
                          usersById[booking.driverId]?.fullName ?? 'Unassigned',
                    ),
                  )
                  .toList(growable: false);
              _sortBookings(bookings, sort, usersById);

              return _AdminRecordListLayout(
                listType: listType,
                count: bookings.length,
                searchController: searchController,
                searchHint: listType.bookingSearchHint,
                sort: sort,
                onSortChanged: onSortChanged,
                empty: bookings.isEmpty
                    ? AdminEmptyCollection(
                        icon: listType.icon,
                        title: query.isEmpty
                            ? listType.emptyTitle
                            : 'No matching trips found',
                        description: query.isEmpty
                            ? listType.emptyDescription
                            : 'Try searching by passenger, driver, location, status, payment, or fare.',
                      )
                    : null,
                children: bookings
                    .map((booking) {
                      final passenger =
                          usersById[booking.passengerId]?.fullName ??
                          'Passenger';
                      final driver =
                          usersById[booking.driverId]?.fullName ?? 'Unassigned';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdminBookingCard(
                          booking: booking,
                          passengerName: passenger,
                          driverName: driver,
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminRecordListLayout extends StatelessWidget {
  final AdminRecordListType listType;
  final int count;
  final TextEditingController searchController;
  final String searchHint;
  final AdminRecordSort sort;
  final ValueChanged<AdminRecordSort> onSortChanged;
  final AdminRegisteredUserRoleFilter? roleFilter;
  final ValueChanged<AdminRegisteredUserRoleFilter>? onRoleFilterChanged;
  final Widget? empty;
  final List<Widget> children;

  const _AdminRecordListLayout({
    required this.listType,
    required this.count,
    required this.searchController,
    required this.searchHint,
    required this.sort,
    required this.onSortChanged,
    this.roleFilter,
    this.onRoleFilterChanged,
    required this.empty,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminCountPageHeader(
          title: listType.title,
          subtitle: listType.metricHelper,
          count: count.toString(),
          countLabel: listType.metricLabel,
          accentColor: listType.accentColor,
        ),
        SizedBox(height: 12),
        _AdminRecordControls(
          searchController: searchController,
          searchHint: searchHint,
          sort: sort,
          onSortChanged: onSortChanged,
          roleFilter: roleFilter,
          onRoleFilterChanged: onRoleFilterChanged,
        ),
        SizedBox(height: 16),
        Text(listType.sectionTitle, style: AdminUi.sectionTitle),
        SizedBox(height: 12),
        if (empty != null) empty! else ...children,
      ],
    );
  }
}

class _AdminSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _AdminSearchField({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: AdminUi.inputDecoration(
        hintText: hintText,
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

class _AdminRecordControls extends StatelessWidget {
  final TextEditingController searchController;
  final String searchHint;
  final AdminRecordSort sort;
  final ValueChanged<AdminRecordSort> onSortChanged;
  final AdminRegisteredUserRoleFilter? roleFilter;
  final ValueChanged<AdminRegisteredUserRoleFilter>? onRoleFilterChanged;

  const _AdminRecordControls({
    required this.searchController,
    required this.searchHint,
    required this.sort,
    required this.onSortChanged,
    this.roleFilter,
    this.onRoleFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 820;
    final search = _AdminSearchField(
      controller: searchController,
      hintText: searchHint,
    );
    final sortField = _AdminSortField(sort: sort, onChanged: onSortChanged);
    final roleFilterField = roleFilter == null || onRoleFilterChanged == null
        ? null
        : _AdminRegisteredUserRoleFilterSegment(
            value: roleFilter!,
            onChanged: onRoleFilterChanged!,
          );

    if (compact) {
      return Column(
        children: [
          search,
          if (roleFilterField != null) ...[
            SizedBox(height: 10),
            roleFilterField,
          ],
          SizedBox(height: 10),
          sortField,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: search),
        SizedBox(width: 12),
        if (roleFilterField != null) ...[
          SizedBox(width: 342, child: roleFilterField),
          SizedBox(width: 12),
        ],
        SizedBox(width: 210, child: sortField),
      ],
    );
  }
}

class _AdminRegisteredUserRoleFilterSegment extends StatelessWidget {
  final AdminRegisteredUserRoleFilter value;
  final ValueChanged<AdminRegisteredUserRoleFilter> onChanged;

  const _AdminRegisteredUserRoleFilterSegment({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<AdminRegisteredUserRoleFilter>(
          selected: <AdminRegisteredUserRoleFilter>{value},
          showSelectedIcon: false,
          segments: AdminRegisteredUserRoleFilter.values
              .map(
                (filter) => ButtonSegment<AdminRegisteredUserRoleFilter>(
                  value: filter,
                  icon: Icon(filter.icon, size: 18),
                  label: Text(filter.label),
                ),
              )
              .toList(growable: false),
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ),
    );
  }
}

class _AdminSortField extends StatelessWidget {
  final AdminRecordSort sort;
  final ValueChanged<AdminRecordSort> onChanged;

  const _AdminSortField({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AdminRecordSort>(
      value: sort,
      isExpanded: true,
      decoration: AdminUi.inputDecoration(
        hintText: '',
        labelText: 'Sort',
        prefixIcon: const Icon(Icons.sort_rounded),
      ),
      items: AdminRecordSort.values
          .map(
            (value) => DropdownMenuItem<AdminRecordSort>(
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

class _AdminUserListCard extends StatelessWidget {
  final AdminUserRecord user;
  final String adminId;
  final String hintLabel;
  final VoidCallback onTap;
  final VoidCallback? onRestrict;
  final VoidCallback? onRestore;

  const _AdminUserListCard({
    required this.user,
    required this.adminId,
    required this.hintLabel,
    required this.onTap,
    required this.onRestrict,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;

    return AdminUserCard(
      user: user,
      onTap: onTap,
      hintLabel: hintLabel,
      actions: [
        AdminMessageUserButton(
          adminId: adminId,
          user: user,
          label: compact ? 'Message' : 'Message User',
        ),
        if (user.isBanned)
          AdminActionButton(
            label: 'Restore',
            icon: Icons.restart_alt_rounded,
            backgroundColor: AdminUi.successBackground,
            foregroundColor: AdminUi.successText,
            onPressed: onRestore,
          )
        else if (!user.isAdmin)
          AdminActionButton(
            label: 'Restrict',
            icon: Icons.block_rounded,
            backgroundColor: AdminUi.dangerSoft,
            foregroundColor: AdminUi.primary,
            onPressed: onRestrict,
          ),
      ],
    );
  }
}

Future<void> _runUserAction(
  BuildContext context, {
  required Future<void> Function() action,
  required String successMessage,
}) async {
  try {
    await action();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          userFacingErrorMessage(
            error,
            fallback: 'Action failed. Please try again.',
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmAndRunUserAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required IconData icon,
  required Color confirmColor,
  required Future<void> Function() action,
  required String successMessage,
}) async {
  final confirmed = await showConfirmationDialog(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    icon: icon,
    confirmColor: confirmColor,
  );

  if (!confirmed || !context.mounted) {
    return;
  }

  await _runUserAction(context, action: action, successMessage: successMessage);
}

bool _matchesUserSearch(AdminUserRecord user, String query) {
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

bool _matchesRegisteredUserRoleFilter(
  AdminUserRecord user,
  AdminRegisteredUserRoleFilter filter,
) {
  switch (filter) {
    case AdminRegisteredUserRoleFilter.all:
      return true;
    case AdminRegisteredUserRoleFilter.drivers:
      return user.isDriver;
    case AdminRegisteredUserRoleFilter.passengers:
      return user.isPassenger;
  }
}

bool _matchesBookingSearch(
  AdminBookingRecord booking,
  String query, {
  required String passengerName,
  required String driverName,
}) {
  if (query.isEmpty) {
    return true;
  }

  final haystack = <String>[
    booking.bookingId,
    booking.pickupLocation,
    booking.dropoffLocation,
    booking.statusLabel,
    booking.paymentMethod ?? '',
    booking.fareLabel ?? '',
    passengerName,
    driverName,
  ].join(' ').toLowerCase();

  return haystack.contains(query);
}

void _sortUsers(List<AdminUserRecord> users, AdminRecordSort sort) {
  switch (sort) {
    case AdminRecordSort.newest:
      users.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return;
    case AdminRecordSort.alphabetical:
      users.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
      return;
  }
}

void _sortBookings(
  List<AdminBookingRecord> bookings,
  AdminRecordSort sort,
  Map<String, AdminUserRecord> usersById,
) {
  switch (sort) {
    case AdminRecordSort.newest:
      bookings.sort((a, b) {
        final aDate = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return;
    case AdminRecordSort.alphabetical:
      bookings.sort((a, b) {
        final aName =
            usersById[a.passengerId]?.fullName.toLowerCase() ??
            a.dropoffLocation.toLowerCase();
        final bName =
            usersById[b.passengerId]?.fullName.toLowerCase() ??
            b.dropoffLocation.toLowerCase();
        return aName.compareTo(bName);
      });
      return;
  }
}

extension AdminRecordListTypeDetails on AdminRecordListType {
  bool get isUserList {
    return this == AdminRecordListType.registeredUsers ||
        this == AdminRecordListType.activeDrivers ||
        this == AdminRecordListType.expiredDriverDocuments ||
        this == AdminRecordListType.studentAccounts;
  }

  String get title {
    switch (this) {
      case AdminRecordListType.registeredUsers:
        return 'Registered Users';
      case AdminRecordListType.activeDrivers:
        return 'Active Drivers';
      case AdminRecordListType.expiredDriverDocuments:
        return 'Expired Driver Documents';
      case AdminRecordListType.studentAccounts:
        return 'Student Accounts';
      case AdminRecordListType.completedTrips:
        return 'Completed Trips';
      case AdminRecordListType.activeTrips:
        return 'Trips in Motion';
    }
  }

  String get metricLabel {
    switch (this) {
      case AdminRecordListType.registeredUsers:
        return 'Users';
      case AdminRecordListType.activeDrivers:
        return 'Drivers';
      case AdminRecordListType.expiredDriverDocuments:
        return 'Expired';
      case AdminRecordListType.studentAccounts:
        return 'Students';
      case AdminRecordListType.completedTrips:
        return 'Trips';
      case AdminRecordListType.activeTrips:
        return 'Active Trips';
    }
  }

  String get metricHelper {
    switch (this) {
      case AdminRecordListType.registeredUsers:
        return 'Passenger and driver accounts';
      case AdminRecordListType.activeDrivers:
        return 'Currently online or on active rides';
      case AdminRecordListType.expiredDriverDocuments:
        return 'Verified drivers needing document renewal';
      case AdminRecordListType.studentAccounts:
        return 'Passenger accounts marked as students';
      case AdminRecordListType.completedTrips:
        return 'Finished bookings in the system';
      case AdminRecordListType.activeTrips:
        return 'Accepted or ongoing bookings';
    }
  }

  String get sectionTitle {
    switch (this) {
      case AdminRecordListType.registeredUsers:
        return 'User List';
      case AdminRecordListType.activeDrivers:
        return 'Driver List';
      case AdminRecordListType.expiredDriverDocuments:
        return 'Drivers Requiring Renewal';
      case AdminRecordListType.studentAccounts:
        return 'Student List';
      case AdminRecordListType.completedTrips:
        return 'Trip List';
      case AdminRecordListType.activeTrips:
        return 'Live Trip List';
    }
  }

  String get emptyTitle {
    switch (this) {
      case AdminRecordListType.registeredUsers:
        return 'No registered users found';
      case AdminRecordListType.activeDrivers:
        return 'No active drivers found';
      case AdminRecordListType.expiredDriverDocuments:
        return 'No expired driver documents';
      case AdminRecordListType.studentAccounts:
        return 'No student accounts found';
      case AdminRecordListType.completedTrips:
        return 'No completed trips found';
      case AdminRecordListType.activeTrips:
        return 'No trips in motion';
    }
  }

  String get emptyDescription {
    switch (this) {
      case AdminRecordListType.registeredUsers:
        return 'New app accounts will appear here after signup.';
      case AdminRecordListType.activeDrivers:
        return 'Drivers will appear here after going active with a fresh location.';
      case AdminRecordListType.expiredDriverDocuments:
        return 'Verified drivers will appear here when their Driver\'s License or OR/CR expires.';
      case AdminRecordListType.studentAccounts:
        return 'Student passenger accounts will appear here after registration.';
      case AdminRecordListType.completedTrips:
        return 'Finished bookings will appear here after trips are completed.';
      case AdminRecordListType.activeTrips:
        return 'Accepted or ongoing bookings will appear here while rides are active.';
    }
  }

  String get userSearchHint {
    switch (this) {
      case AdminRecordListType.registeredUsers:
        return 'Search passengers or drivers by name, email, role, or status';
      case AdminRecordListType.activeDrivers:
        return 'Search active drivers';
      case AdminRecordListType.expiredDriverDocuments:
        return 'Search drivers with expired documents';
      case AdminRecordListType.studentAccounts:
        return 'Search student accounts';
      case AdminRecordListType.completedTrips:
      case AdminRecordListType.activeTrips:
        return 'Search';
    }
  }

  String get bookingSearchHint {
    switch (this) {
      case AdminRecordListType.completedTrips:
        return 'Search completed trips';
      case AdminRecordListType.activeTrips:
        return 'Search trips in motion';
      case AdminRecordListType.registeredUsers:
      case AdminRecordListType.activeDrivers:
      case AdminRecordListType.expiredDriverDocuments:
      case AdminRecordListType.studentAccounts:
        return 'Search';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminRecordListType.registeredUsers:
        return Icons.groups_rounded;
      case AdminRecordListType.activeDrivers:
        return Icons.local_taxi_rounded;
      case AdminRecordListType.expiredDriverDocuments:
        return Icons.event_busy_rounded;
      case AdminRecordListType.studentAccounts:
        return Icons.school_rounded;
      case AdminRecordListType.completedTrips:
        return Icons.route_rounded;
      case AdminRecordListType.activeTrips:
        return Icons.radar_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case AdminRecordListType.registeredUsers:
        return AdminUi.primary;
      case AdminRecordListType.activeDrivers:
        return AdminUi.secondary;
      case AdminRecordListType.expiredDriverDocuments:
        return AdminUi.danger;
      case AdminRecordListType.studentAccounts:
        return AdminUi.accentBlue;
      case AdminRecordListType.completedTrips:
        return AdminUi.successText;
      case AdminRecordListType.activeTrips:
        return AdminUi.accentBlue;
    }
  }

  bool matchesUser(AdminUserRecord user) {
    switch (this) {
      case AdminRecordListType.registeredUsers:
        return user.isPassengerOrDriver;
      case AdminRecordListType.activeDrivers:
        return user.isEligibleDriverAccount;
      case AdminRecordListType.expiredDriverDocuments:
        return user.hasExpiredDriverDocuments;
      case AdminRecordListType.studentAccounts:
        return user.isStudentPassenger;
      case AdminRecordListType.completedTrips:
      case AdminRecordListType.activeTrips:
        return false;
    }
  }

  bool matchesBooking(AdminBookingRecord booking) {
    switch (this) {
      case AdminRecordListType.completedTrips:
        return booking.isCompleted;
      case AdminRecordListType.activeTrips:
        return booking.isActiveTrip;
      case AdminRecordListType.registeredUsers:
      case AdminRecordListType.activeDrivers:
      case AdminRecordListType.expiredDriverDocuments:
      case AdminRecordListType.studentAccounts:
        return false;
    }
  }

  String userHint(AdminUserRecord user) {
    if (this != AdminRecordListType.expiredDriverDocuments) {
      return 'Open profile';
    }

    return 'License: ${formatDate(user.driverDocumentStatus.driversLicenseExpiry)}  •  OR/CR: ${formatDate(user.driverDocumentStatus.orCrExpiry)}  •  Open profile';
  }
}
