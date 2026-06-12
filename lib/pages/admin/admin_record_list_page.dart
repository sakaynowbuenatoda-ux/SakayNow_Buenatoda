import 'package:flutter/material.dart';

import '../../widgets/confirmation_dialog.dart';
import 'admin_models.dart';
import 'admin_navigation.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

enum AdminRecordListType {
  registeredUsers,
  activeDrivers,
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
        title: Text(widget.listType.title, style: AdminUi.cardTitle),
      ),
      body: widget.listType.isUserList
          ? _AdminUserRecordList(
              adminId: widget.adminId,
              listType: widget.listType,
              query: _query,
              sort: _sort,
              searchController: _searchController,
              onSortChanged: (value) => setState(() => _sort = value),
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
  final TextEditingController searchController;
  final ValueChanged<AdminRecordSort> onSortChanged;

  const _AdminUserRecordList({
    required this.adminId,
    required this.listType,
    required this.query,
    required this.sort,
    required this.searchController,
    required this.onSortChanged,
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
              message: 'Unable to load ${listType.title}: ${snapshot.error}',
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!
              .where(listType.matchesUser)
              .where((user) => _matchesUserSearch(user, query))
              .toList(growable: false);
          _sortUsers(users, sort);

          return _AdminRecordListLayout(
            listType: listType,
            count: users.length,
            searchController: searchController,
            searchHint: listType.userSearchHint,
            sort: sort,
            onSortChanged: onSortChanged,
            empty: users.isEmpty
                ? AdminEmptyCollection(
                    icon: listType.icon,
                    title: query.isEmpty
                        ? listType.emptyTitle
                        : 'No matching users found',
                    description: query.isEmpty
                        ? listType.emptyDescription
                        : 'Try searching by name, email, role, or account status.',
                  )
                : null,
            children: users
                .map((user) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AdminUserListCard(
                      user: user,
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
            return const Center(child: CircularProgressIndicator());
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
                return const Center(child: CircularProgressIndicator());
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
  final Widget? empty;
  final List<Widget> children;

  const _AdminRecordListLayout({
    required this.listType,
    required this.count,
    required this.searchController,
    required this.searchHint,
    required this.sort,
    required this.onSortChanged,
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
          icon: listType.icon,
          accentColor: listType.accentColor,
        ),
        SizedBox(height: 12),
        _AdminRecordControls(
          searchController: searchController,
          searchHint: searchHint,
          sort: sort,
          onSortChanged: onSortChanged,
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
      decoration: InputDecoration(
        hintText: hintText,
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

class _AdminRecordControls extends StatelessWidget {
  final TextEditingController searchController;
  final String searchHint;
  final AdminRecordSort sort;
  final ValueChanged<AdminRecordSort> onSortChanged;

  const _AdminRecordControls({
    required this.searchController,
    required this.searchHint,
    required this.sort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final search = _AdminSearchField(
      controller: searchController,
      hintText: searchHint,
    );
    final sortField = _AdminSortField(sort: sort, onChanged: onSortChanged);

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
  final VoidCallback onTap;
  final VoidCallback? onRestrict;
  final VoidCallback? onRestore;

  const _AdminUserListCard({
    required this.user,
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
      hintLabel: 'Open profile',
      actions: [
        OutlinedButton.icon(
          onPressed: () => _showMessageComingSoon(context, user),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: Text(compact ? 'Message' : 'Message User'),
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

  void _showMessageComingSoon(BuildContext context, AdminUserRecord user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Messaging ${user.fullName} will be available when admin messaging is connected.',
        ),
      ),
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
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
        this == AdminRecordListType.studentAccounts;
  }

  String get title {
    switch (this) {
      case AdminRecordListType.registeredUsers:
        return 'Registered Users';
      case AdminRecordListType.activeDrivers:
        return 'Active Drivers';
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
        return 'Currently available for bookings';
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
      case AdminRecordListType.studentAccounts:
        return false;
    }
  }
}
