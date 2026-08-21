import 'package:flutter/material.dart';

import '../../widgets/app_skeleton.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

enum AdminBookingHistorySection { all, ongoing, completed, cancelled }

enum _BookingTimeFilter {
  all,
  pastHour,
  pastDay,
  pastWeek,
  pastMonth,
  pastYear,
  custom,
}

class AdminBookingHistoryPage extends StatefulWidget {
  final String adminId;
  final AdminBookingHistorySection initialSection;

  const AdminBookingHistoryPage({
    super.key,
    this.adminId = '',
    this.initialSection = AdminBookingHistorySection.all,
  });

  @override
  State<AdminBookingHistoryPage> createState() =>
      _AdminBookingHistoryPageState();
}

class _AdminBookingHistoryPageState extends State<AdminBookingHistoryPage> {
  final TextEditingController _searchController = TextEditingController();

  late AdminBookingHistorySection _section;
  String _query = '';
  _BookingTimeFilter _timeFilter = _BookingTimeFilter.all;
  DateTime? _startAt;
  DateTime? _endAt;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
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
    final now = DateTime.now();
    final effectiveStartAt = _timeFilter.resolveStartAt(now, _startAt);
    final effectiveEndAt = _timeFilter.resolveEndAt(now, _endAt);

    return Scaffold(
      backgroundColor: AdminUi.background,
      appBar: const AdminDetailAppBar(title: 'Booking History'),
      body: AdminPageContainer(
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
              stream: AdminService.watchBookingHistory(
                statuses: _section.statuses,
                startAt: effectiveStartAt,
                endAt: effectiveEndAt,
              ),
              builder: (context, bookingsSnapshot) {
                if (bookingsSnapshot.hasError) {
                  return AdminErrorCard(
                    message:
                        'Unable to load booking history: ${bookingsSnapshot.error}',
                  );
                }

                if (!bookingsSnapshot.hasData) {
                  return const AppSkeletonList(padding: EdgeInsets.zero);
                }

                final bookings = bookingsSnapshot.data!
                    .where(_section.matchesBooking)
                    .where(
                      (booking) => _matchesSearch(
                        booking,
                        passengerName:
                            usersById[booking.passengerId]?.fullName ??
                            'Passenger',
                        driverName:
                            usersById[booking.driverId]?.fullName ??
                            'Unassigned',
                      ),
                    )
                    .toList(growable: false);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AdminCountPageHeader(
                      title: 'Booking History',
                      subtitle: _section.subtitle,
                      count: bookings.length.toString(),
                      countLabel: bookings.length == 1 ? 'Result' : 'Results',
                      accentColor: _section.accentColor,
                    ),
                    const SizedBox(height: 12),
                    _BookingHistoryFilterPanel(
                      searchController: _searchController,
                      section: _section,
                      timeFilter: _timeFilter,
                      startAt: effectiveStartAt,
                      endAt: effectiveEndAt,
                      hasActiveFilters: _hasActiveFilters,
                      onSectionChanged: (value) {
                        setState(() => _section = value);
                      },
                      onTimeFilterChanged: _handleTimeFilterChanged,
                      onPickStart: _pickStartDateTime,
                      onPickEnd: _pickEndDateTime,
                      onClearFilters: _clearFilters,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _section.listTitle,
                            style: AdminUi.sectionTitle,
                          ),
                        ),
                        AdminStatusChip(
                          label:
                              '${bookings.length} ${bookings.length == 1 ? 'trip' : 'trips'}',
                          textColor: _section.accentColor,
                          backgroundColor: AdminUi.soft(
                            _section.accentColor,
                            alpha: 0.10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (bookings.isEmpty)
                      AdminEmptyCollection(
                        icon: _section.icon,
                        title: _emptyTitle,
                        description: _emptyDescription,
                      )
                    else
                      ...bookings.map((booking) {
                        final passenger =
                            usersById[booking.passengerId]?.fullName ??
                            'Passenger';
                        final driver =
                            usersById[booking.driverId]?.fullName ??
                            'Unassigned';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AdminBookingCard(
                            booking: booking,
                            passengerName: passenger,
                            driverName: driver,
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool get _hasActiveFilters {
    return _query.isNotEmpty ||
        _section != AdminBookingHistorySection.all ||
        _timeFilter != _BookingTimeFilter.all ||
        _startAt != null ||
        _endAt != null;
  }

  String get _emptyTitle {
    if (_hasActiveFilters) {
      return 'No matching bookings found';
    }

    return 'No booking history yet';
  }

  String get _emptyDescription {
    if (_hasActiveFilters) {
      return 'Try a different status, search term, or date-time range.';
    }

    return 'Trips will appear here after passengers start booking rides.';
  }

  bool _matchesSearch(
    AdminBookingRecord booking, {
    required String passengerName,
    required String driverName,
  }) {
    if (_query.isEmpty) {
      return true;
    }

    final haystack = <String>[
      booking.bookingId,
      booking.passengerId,
      booking.driverId,
      booking.pickupLocation,
      booking.dropoffLocation,
      booking.statusLabel,
      booking.paymentMethod ?? '',
      booking.paymentStatus ?? '',
      booking.fareLabel ?? '',
      passengerName,
      driverName,
    ].join(' ').toLowerCase();

    return haystack.contains(_query);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _section = AdminBookingHistorySection.all;
      _timeFilter = _BookingTimeFilter.all;
      _startAt = null;
      _endAt = null;
    });
  }

  void _handleTimeFilterChanged(_BookingTimeFilter? value) {
    if (value == null) {
      return;
    }

    if (value == _BookingTimeFilter.custom) {
      _pickStartDateTime();
      return;
    }

    setState(() {
      _timeFilter = value;
      _startAt = null;
      _endAt = null;
    });
  }

  Future<void> _pickStartDateTime() async {
    final picked = await _pickDateTime(
      initialDateTime: _timeFilter == _BookingTimeFilter.custom
          ? _startAt
          : null,
      useEndOfDayDefault: false,
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _timeFilter = _BookingTimeFilter.custom;
      _startAt = picked;
      if (_endAt != null && _endAt!.isBefore(picked)) {
        _endAt = null;
      }
    });
  }

  Future<void> _pickEndDateTime() async {
    final initialEnd = _timeFilter == _BookingTimeFilter.custom
        ? _endAt ??
              (_startAt == null
                  ? null
                  : DateTime(
                      _startAt!.year,
                      _startAt!.month,
                      _startAt!.day,
                      23,
                      59,
                    ))
        : null;
    final picked = await _pickDateTime(
      initialDateTime: initialEnd,
      useEndOfDayDefault: true,
    );
    if (picked == null || !mounted) {
      return;
    }

    if (_startAt != null && picked.isBefore(_startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date-time must be after start.')),
      );
      return;
    }

    setState(() {
      _timeFilter = _BookingTimeFilter.custom;
      _endAt = picked;
    });
  }

  Future<DateTime?> _pickDateTime({
    required DateTime? initialDateTime,
    required bool useEndOfDayDefault,
  }) async {
    final now = DateTime.now();
    final fallback = useEndOfDayDefault
        ? DateTime(now.year, now.month, now.day, 23, 59)
        : DateTime(now.year, now.month, now.day);
    final initial = initialDateTime ?? fallback;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );

    if (!mounted || pickedDate == null) {
      return null;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (pickedTime == null) {
      return null;
    }

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }
}

class _BookingHistoryFilterPanel extends StatelessWidget {
  final TextEditingController searchController;
  final AdminBookingHistorySection section;
  final _BookingTimeFilter timeFilter;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool hasActiveFilters;
  final ValueChanged<AdminBookingHistorySection> onSectionChanged;
  final ValueChanged<_BookingTimeFilter?> onTimeFilterChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClearFilters;

  const _BookingHistoryFilterPanel({
    required this.searchController,
    required this.section,
    required this.timeFilter,
    required this.startAt,
    required this.endAt,
    required this.hasActiveFilters,
    required this.onSectionChanged,
    required this.onTimeFilterChanged,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;

    return AdminSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<AdminBookingHistorySection>(
              selected: <AdminBookingHistorySection>{section},
              showSelectedIcon: false,
              segments: AdminBookingHistorySection.values
                  .map(
                    (value) => ButtonSegment<AdminBookingHistorySection>(
                      value: value,
                      icon: Icon(value.icon, size: 18),
                      label: Text(value.label),
                    ),
                  )
                  .toList(growable: false),
              onSelectionChanged: (values) {
                onSectionChanged(values.first);
              },
            ),
          ),
          const SizedBox(height: 14),
          if (compact)
            Column(
              children: <Widget>[
                _HistorySearchField(controller: searchController),
                const SizedBox(height: 10),
                _RelativeTimeFilter(
                  value: timeFilter,
                  onChanged: onTimeFilterChanged,
                ),
                const SizedBox(height: 10),
                _DateTimeFilterButton(
                  label: 'Start',
                  value: _formatDateTimeFilter(startAt) ?? 'Any time',
                  isActive: startAt != null,
                  onPressed: onPickStart,
                ),
                const SizedBox(height: 10),
                _DateTimeFilterButton(
                  label: 'End',
                  value: _formatDateTimeFilter(endAt) ?? 'Any time',
                  isActive: endAt != null,
                  onPressed: onPickEnd,
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: _HistorySearchField(controller: searchController),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _RelativeTimeFilter(
                    value: timeFilter,
                    onChanged: onTimeFilterChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _DateTimeFilterButton(
                    label: 'Start',
                    value: _formatDateTimeFilter(startAt) ?? 'Any time',
                    isActive: startAt != null,
                    onPressed: onPickStart,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _DateTimeFilterButton(
                    label: 'End',
                    value: _formatDateTimeFilter(endAt) ?? 'Any time',
                    isActive: endAt != null,
                    onPressed: onPickEnd,
                  ),
                ),
              ],
            ),
          if (hasActiveFilters) ...<Widget>[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RelativeTimeFilter extends StatelessWidget {
  final _BookingTimeFilter value;
  final ValueChanged<_BookingTimeFilter?> onChanged;

  const _RelativeTimeFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<_BookingTimeFilter>(
      value: value,
      isExpanded: true,
      decoration: AdminUi.inputDecoration(
        hintText: 'Time',
        labelText: 'Time',
        prefixIcon: const Icon(Icons.history_toggle_off_rounded),
      ),
      items: _BookingTimeFilter.values
          .map(
            (filter) => DropdownMenuItem<_BookingTimeFilter>(
              value: filter,
              child: Text(
                filter.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}

class _HistorySearchField extends StatelessWidget {
  final TextEditingController controller;

  const _HistorySearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: AdminUi.inputDecoration(
        hintText: 'Search passenger, driver, location, payment, or fare',
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

class _DateTimeFilterButton extends StatelessWidget {
  final String label;
  final String value;
  final bool isActive;
  final VoidCallback onPressed;

  const _DateTimeFilterButton({
    required this.label,
    required this.value,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AdminUi.accent : AdminUi.muted;

    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: color,
          side: BorderSide(color: isActive ? AdminUi.accent : AdminUi.border),
          shape: RoundedRectangleBorder(borderRadius: AdminUi.radius),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.schedule_rounded, size: 19, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminUi.labelText.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminUi.bodyText.copyWith(
                      color: isActive ? AdminUi.title : AdminUi.body,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _BookingTimeFilterDetails on _BookingTimeFilter {
  String get label {
    switch (this) {
      case _BookingTimeFilter.all:
        return 'All time';
      case _BookingTimeFilter.pastHour:
        return 'Past 1 hour';
      case _BookingTimeFilter.pastDay:
        return 'Past 1 day';
      case _BookingTimeFilter.pastWeek:
        return 'Past 1 week';
      case _BookingTimeFilter.pastMonth:
        return 'Past 1 month';
      case _BookingTimeFilter.pastYear:
        return 'Past 1 year';
      case _BookingTimeFilter.custom:
        return 'Custom range';
    }
  }

  DateTime? resolveStartAt(DateTime now, DateTime? customStartAt) {
    switch (this) {
      case _BookingTimeFilter.all:
        return null;
      case _BookingTimeFilter.pastHour:
        return now.subtract(const Duration(hours: 1));
      case _BookingTimeFilter.pastDay:
        return now.subtract(const Duration(days: 1));
      case _BookingTimeFilter.pastWeek:
        return now.subtract(const Duration(days: 7));
      case _BookingTimeFilter.pastMonth:
        return _subtractMonths(now, 1);
      case _BookingTimeFilter.pastYear:
        return _subtractMonths(now, 12);
      case _BookingTimeFilter.custom:
        return customStartAt;
    }
  }

  DateTime? resolveEndAt(DateTime now, DateTime? customEndAt) {
    switch (this) {
      case _BookingTimeFilter.all:
        return null;
      case _BookingTimeFilter.pastHour:
      case _BookingTimeFilter.pastDay:
      case _BookingTimeFilter.pastWeek:
      case _BookingTimeFilter.pastMonth:
      case _BookingTimeFilter.pastYear:
        return now;
      case _BookingTimeFilter.custom:
        return customEndAt;
    }
  }
}

extension AdminBookingHistorySectionDetails on AdminBookingHistorySection {
  String get label {
    switch (this) {
      case AdminBookingHistorySection.all:
        return 'All';
      case AdminBookingHistorySection.ongoing:
        return 'Ongoing';
      case AdminBookingHistorySection.completed:
        return 'Completed';
      case AdminBookingHistorySection.cancelled:
        return 'Cancelled';
    }
  }

  String get subtitle {
    switch (this) {
      case AdminBookingHistorySection.all:
        return 'All trips sorted by newest booking time.';
      case AdminBookingHistorySection.ongoing:
        return 'Accepted, arriving, ongoing, and assigned trips.';
      case AdminBookingHistorySection.completed:
        return 'Finished trips ready for service review.';
      case AdminBookingHistorySection.cancelled:
        return 'Cancelled and rejected trips for follow-up.';
    }
  }

  String get listTitle {
    switch (this) {
      case AdminBookingHistorySection.all:
        return 'All Bookings';
      case AdminBookingHistorySection.ongoing:
        return 'Ongoing Bookings';
      case AdminBookingHistorySection.completed:
        return 'Completed Bookings';
      case AdminBookingHistorySection.cancelled:
        return 'Cancelled Bookings';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminBookingHistorySection.all:
        return Icons.history_rounded;
      case AdminBookingHistorySection.ongoing:
        return Icons.radar_rounded;
      case AdminBookingHistorySection.completed:
        return Icons.task_alt_rounded;
      case AdminBookingHistorySection.cancelled:
        return Icons.cancel_outlined;
    }
  }

  Color get accentColor {
    switch (this) {
      case AdminBookingHistorySection.all:
        return AdminUi.accentBlue;
      case AdminBookingHistorySection.ongoing:
        return AdminUi.accentBlue;
      case AdminBookingHistorySection.completed:
        return AdminUi.successText;
      case AdminBookingHistorySection.cancelled:
        return AdminUi.danger;
    }
  }

  List<String> get statuses {
    switch (this) {
      case AdminBookingHistorySection.all:
        return const <String>[];
      case AdminBookingHistorySection.ongoing:
        return const <String>[
          'accepted',
          'driver_arriving',
          'arrived',
          'ongoing',
          'in_progress',
          'assigned',
        ];
      case AdminBookingHistorySection.completed:
        return const <String>['completed'];
      case AdminBookingHistorySection.cancelled:
        return const <String>['cancelled', 'canceled', 'rejected'];
    }
  }

  bool matchesBooking(AdminBookingRecord booking) {
    switch (this) {
      case AdminBookingHistorySection.all:
        return true;
      case AdminBookingHistorySection.ongoing:
        return booking.isActiveTrip;
      case AdminBookingHistorySection.completed:
        return booking.isCompleted;
      case AdminBookingHistorySection.cancelled:
        return booking.isCancelled;
    }
  }
}

String? _formatDateTimeFilter(DateTime? value) {
  if (value == null) {
    return null;
  }

  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';

  return '${_monthLabel(value.month)} ${value.day}, ${value.year} $hour:$minute $period';
}

DateTime _subtractMonths(DateTime value, int months) {
  final targetMonthIndex = (value.year * 12) + value.month - 1 - months;
  final targetYear = targetMonthIndex ~/ 12;
  final targetMonth = (targetMonthIndex % 12) + 1;
  final targetDay = value.day.clamp(1, _daysInMonth(targetYear, targetMonth));

  return DateTime(
    targetYear,
    targetMonth,
    targetDay,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

int _daysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

String _monthLabel(int month) {
  const labels = <String>[
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

  return labels[month - 1];
}
