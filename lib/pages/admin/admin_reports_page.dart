import 'package:flutter/material.dart';

import '../../widgets/app_skeleton.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/time_ago_text.dart';
import 'admin_models.dart';
import 'admin_navigation.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

const String _allCategoryValue = '__all__';

const List<String> _defaultReportCategories = <String>[
  'Safety concern',
  'Unprofessional behavior',
  'Wrong route or fare issue',
  'Vehicle concern',
  'No-show or unreachable',
  'Incorrect pickup details',
  'Payment concern',
  'Other',
];

enum _ReportDateFilter { all, today, last7Days, last30Days, thisMonth, date }

class AdminReportsPage extends StatefulWidget {
  final String adminId;

  const AdminReportsPage({super.key, required this.adminId});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String _selectedCategory = _allCategoryValue;
  _ReportDateFilter _dateFilter = _ReportDateFilter.all;
  AdminReportStatus _selectedStatus = AdminReportStatus.pending;
  DateTime? _selectedDate;
  final Set<String> _updatingReportIds = <String>{};

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
    return AdminPageContainer(
      child: StreamBuilder<List<AdminReportRecord>>(
        stream: AdminService.watchReports(),
        builder: (context, reportsSnapshot) {
          if (reportsSnapshot.hasError) {
            return AdminErrorCard(
              message: 'Unable to load reports: ${reportsSnapshot.error}',
            );
          }

          if (!reportsSnapshot.hasData) {
            return const AppSkeletonList(padding: EdgeInsets.zero);
          }

          return StreamBuilder<List<AdminUserRecord>>(
            stream: AdminService.watchUsers(),
            builder: (context, usersSnapshot) {
              if (usersSnapshot.hasError) {
                return AdminErrorCard(
                  message:
                      'Unable to load reported user profiles: ${usersSnapshot.error}',
                );
              }

              if (!usersSnapshot.hasData) {
                return const AppSkeletonList(padding: EdgeInsets.zero);
              }

              final reports = reportsSnapshot.data!;
              final usersById = <String, AdminUserRecord>{
                for (final user in usersSnapshot.data!) user.userId: user,
              };
              final categories = _buildCategories(reports);
              final activeCategory = categories.contains(_selectedCategory)
                  ? _selectedCategory
                  : _allCategoryValue;
              final matchingReports = reports
                  .where(
                    (report) => _matchesReport(
                      report,
                      reportedUser: usersById[report.reportedUserId],
                      reporter: usersById[report.reporterId],
                      category: activeCategory,
                    ),
                  )
                  .toList(growable: false);
              final filteredReports = matchingReports
                  .where((report) => report.reportStatus == _selectedStatus)
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AdminSectionIntro(
                    title: 'Reports',
                    subtitle:
                        'Users reported by passengers and drivers, with the newest submissions shown first.',
                  ),
                  const SizedBox(height: 16),
                  _ReportsFilterPanel(
                    searchController: _searchController,
                    selectedCategory: activeCategory,
                    categories: categories,
                    selectedDateFilter: _dateFilter,
                    selectedDate: _selectedDate,
                    hasActiveFilters: _hasActiveFilters(activeCategory),
                    onCategoryChanged: (value) {
                      setState(
                        () => _selectedCategory = value ?? _allCategoryValue,
                      );
                    },
                    onDateFilterChanged: _handleDateFilterChanged,
                    onPickDate: _pickSpecificDate,
                    onClearFilters: _clearFilters,
                  ),
                  const SizedBox(height: 16),
                  _ReportMetrics(
                    reportCount: reports.length,
                    reportedUserCount: _reportedUserCount(reports),
                    openReportCount: reports
                        .where((report) => report.isOpen)
                        .length,
                    filteredCount: filteredReports.length,
                  ),
                  const SizedBox(height: 14),
                  _ReportStatusToggle(
                    selectedStatus: _selectedStatus,
                    counts: <AdminReportStatus, int>{
                      for (final status in AdminReportStatus.values)
                        status: matchingReports
                            .where((report) => report.reportStatus == status)
                            .length,
                    },
                    onChanged: (status) {
                      setState(() => _selectedStatus = status);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Reported Users',
                          style: AdminUi.sectionTitle,
                        ),
                      ),
                      AdminStatusChip(
                        label:
                            '${filteredReports.length} ${filteredReports.length == 1 ? 'result' : 'results'}',
                        textColor: AdminUi.accent,
                        backgroundColor: AdminUi.blueSoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filteredReports.isEmpty)
                    AdminEmptyCollection(
                      icon: Icons.report_off_outlined,
                      title: reports.isEmpty
                          ? 'No user reports yet'
                          : 'No matching reports found',
                      description: reports.isEmpty
                          ? 'Submitted passenger and driver reports will appear here.'
                          : 'No ${_selectedStatus.label.toLowerCase()} reports match the current filters.',
                    )
                  else
                    ...filteredReports.map(
                      (report) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReportUserCard(
                          report: report,
                          reportedUser: usersById[report.reportedUserId],
                          reporter: usersById[report.reporterId],
                          isUpdating: _updatingReportIds.contains(
                            report.reportId,
                          ),
                          onProfileTap: report.reportedUserId.isEmpty
                              ? null
                              : () => AdminNavigation.openUserProfile(
                                  context,
                                  adminId: widget.adminId,
                                  userId: report.reportedUserId,
                                ),
                          onDetailsTap: () => AdminNavigation.openReportDetails(
                            context,
                            adminId: widget.adminId,
                            report: report,
                          ),
                          onStatusSelected: (status) =>
                              _updateReportStatus(report, status),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  bool _hasActiveFilters(String activeCategory) {
    return _query.isNotEmpty ||
        activeCategory != _allCategoryValue ||
        _dateFilter != _ReportDateFilter.all ||
        _selectedStatus != AdminReportStatus.pending;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedCategory = _allCategoryValue;
      _dateFilter = _ReportDateFilter.all;
      _selectedStatus = AdminReportStatus.pending;
      _selectedDate = null;
    });
  }

  Future<void> _updateReportStatus(
    AdminReportRecord report,
    AdminReportStatus status,
  ) async {
    if (report.reportId.isEmpty ||
        _updatingReportIds.contains(report.reportId)) {
      return;
    }

    setState(() => _updatingReportIds.add(report.reportId));
    try {
      await AdminService.updateReportStatus(
        reportId: report.reportId,
        status: status,
        adminId: widget.adminId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report marked as ${status.label.toLowerCase()}.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update report: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingReportIds.remove(report.reportId));
      }
    }
  }

  void _handleDateFilterChanged(_ReportDateFilter? value) {
    if (value == null) {
      return;
    }

    if (value == _ReportDateFilter.date) {
      _pickSpecificDate();
      return;
    }

    setState(() {
      _dateFilter = value;
      _selectedDate = null;
    });
  }

  Future<void> _pickSpecificDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(2020),
      lastDate: today,
    );

    if (!mounted || pickedDate == null) {
      return;
    }

    setState(() {
      _dateFilter = _ReportDateFilter.date;
      _selectedDate = pickedDate;
    });
  }

  bool _matchesReport(
    AdminReportRecord report, {
    required AdminUserRecord? reportedUser,
    required AdminUserRecord? reporter,
    required String category,
  }) {
    if (category != _allCategoryValue &&
        report.categoryLabel.toLowerCase() != category.toLowerCase()) {
      return false;
    }

    if (!_matchesDate(report)) {
      return false;
    }

    if (_query.isEmpty) {
      return true;
    }

    final haystack = <String>[
      report.reportId,
      report.bookingId,
      report.reportedUserId,
      report.reportedUserRoleLabel,
      report.reporterId,
      report.reporterRoleLabel,
      report.reasonLabel,
      report.details,
      report.statusLabel,
      reportedUser?.fullName ?? '',
      reportedUser?.email ?? '',
      reportedUser?.roleLabel ?? '',
      reporter?.fullName ?? '',
      reporter?.email ?? '',
      reporter?.roleLabel ?? '',
    ].join(' ').toLowerCase();

    return haystack.contains(_query);
  }

  bool _matchesDate(AdminReportRecord report) {
    if (_dateFilter == _ReportDateFilter.all) {
      return true;
    }

    final date = report.createdAt ?? report.updatedAt;
    if (date == null) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reportDay = DateTime(date.year, date.month, date.day);

    switch (_dateFilter) {
      case _ReportDateFilter.all:
        return true;
      case _ReportDateFilter.today:
        return reportDay == today;
      case _ReportDateFilter.last7Days:
        return !reportDay.isBefore(today.subtract(const Duration(days: 6)));
      case _ReportDateFilter.last30Days:
        return !reportDay.isBefore(today.subtract(const Duration(days: 29)));
      case _ReportDateFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case _ReportDateFilter.date:
        final selected = _selectedDate;
        if (selected == null) {
          return true;
        }

        return reportDay ==
            DateTime(selected.year, selected.month, selected.day);
    }
  }

  List<String> _buildCategories(List<AdminReportRecord> reports) {
    final values = <String>{
      ..._defaultReportCategories,
      ...reports
          .map((report) => report.categoryLabel)
          .where((category) => category.trim().isNotEmpty),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return <String>[_allCategoryValue, ...values];
  }

  int _reportedUserCount(List<AdminReportRecord> reports) {
    return reports
        .map((report) => report.reportedUserId)
        .where((userId) => userId.trim().isNotEmpty)
        .toSet()
        .length;
  }
}

class _ReportsFilterPanel extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedCategory;
  final List<String> categories;
  final _ReportDateFilter selectedDateFilter;
  final DateTime? selectedDate;
  final bool hasActiveFilters;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<_ReportDateFilter?> onDateFilterChanged;
  final VoidCallback onPickDate;
  final VoidCallback onClearFilters;

  const _ReportsFilterPanel({
    required this.searchController,
    required this.selectedCategory,
    required this.categories,
    required this.selectedDateFilter,
    required this.selectedDate,
    required this.hasActiveFilters,
    required this.onCategoryChanged,
    required this.onDateFilterChanged,
    required this.onPickDate,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;

    final fields = <Widget>[
      _SearchField(controller: searchController),
      _CategoryFilter(
        value: selectedCategory,
        categories: categories,
        onChanged: onCategoryChanged,
      ),
      _DateFilter(
        value: selectedDateFilter,
        selectedDate: selectedDate,
        onChanged: onDateFilterChanged,
      ),
    ];

    return AdminSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            ...fields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: field,
              ),
            )
          else
            Row(
              children: [
                Expanded(flex: 3, child: fields[0]),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: fields[1]),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: fields[2]),
              ],
            ),
          if (selectedDateFilter == _ReportDateFilter.date ||
              hasActiveFilters) ...[
            if (!compact) const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (selectedDateFilter == _ReportDateFilter.date)
                  OutlinedButton.icon(
                    onPressed: onPickDate,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(_formatDate(selectedDate) ?? 'Choose date'),
                  ),
                if (hasActiveFilters)
                  TextButton.icon(
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                    label: const Text('Clear filters'),
                  ),
              ],
            ),
          ],
        ],
      ),
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
        hintText: 'Search reported users, reporters, reasons, or details',
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

class _CategoryFilter extends StatelessWidget {
  final String value;
  final List<String> categories;
  final ValueChanged<String?> onChanged;

  const _CategoryFilter({
    required this.value,
    required this.categories,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: AdminUi.inputDecoration(
        hintText: 'Category',
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category_outlined),
      ),
      items: categories
          .map(
            (category) => DropdownMenuItem<String>(
              value: category,
              child: Text(
                category == _allCategoryValue ? 'All categories' : category,
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

class _DateFilter extends StatelessWidget {
  final _ReportDateFilter value;
  final DateTime? selectedDate;
  final ValueChanged<_ReportDateFilter?> onChanged;

  const _DateFilter({
    required this.value,
    required this.selectedDate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<_ReportDateFilter>(
      value: value,
      isExpanded: true,
      decoration: AdminUi.inputDecoration(
        hintText: 'Date',
        labelText: 'Date',
        prefixIcon: const Icon(Icons.event_outlined),
      ),
      items: _ReportDateFilter.values
          .map(
            (filter) => DropdownMenuItem<_ReportDateFilter>(
              value: filter,
              child: Text(
                filter.label(selectedDate),
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

class _ReportStatusToggle extends StatelessWidget {
  final AdminReportStatus selectedStatus;
  final Map<AdminReportStatus, int> counts;
  final ValueChanged<AdminReportStatus> onChanged;

  const _ReportStatusToggle({
    required this.selectedStatus,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<AdminReportStatus>(
          selected: <AdminReportStatus>{selectedStatus},
          showSelectedIcon: false,
          segments: AdminReportStatus.values
              .map(
                (status) => ButtonSegment<AdminReportStatus>(
                  value: status,
                  icon: Icon(status.icon, size: 17),
                  label: Text('${status.label} ${counts[status] ?? 0}'),
                ),
              )
              .toList(growable: false),
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ),
    );
  }
}

class _ReportMetrics extends StatelessWidget {
  final int reportCount;
  final int reportedUserCount;
  final int openReportCount;
  final int filteredCount;

  const _ReportMetrics({
    required this.reportCount,
    required this.reportedUserCount,
    required this.openReportCount,
    required this.filteredCount,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = <_ReportMetricData>[
      _ReportMetricData(
        label: 'Reports',
        value: reportCount.toString(),
        icon: Icons.report_problem_rounded,
        color: AdminUi.danger,
      ),
      _ReportMetricData(
        label: 'Reported Users',
        value: reportedUserCount.toString(),
        icon: Icons.person_search_rounded,
        color: AdminUi.accent,
      ),
      _ReportMetricData(
        label: 'Pending',
        value: openReportCount.toString(),
        icon: Icons.pending_actions_rounded,
        color: AdminUi.warning,
      ),
      _ReportMetricData(
        label: 'Showing',
        value: filteredCount.toString(),
        icon: Icons.filter_list_rounded,
        color: AdminUi.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final tileWidth = constraints.maxWidth < 440
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;

        return AdminSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: compact
              ? Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: metrics
                      .map(
                        (metric) => SizedBox(
                          width: tileWidth,
                          child: _CompactReportMetric(metric: metric),
                        ),
                      )
                      .toList(growable: false),
                )
              : Row(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      if (index > 0)
                        Container(
                          width: 1,
                          height: 38,
                          color: AdminUi.border,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      Expanded(
                        child: _CompactReportMetric(metric: metrics[index]),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _CompactReportMetric extends StatelessWidget {
  final _ReportMetricData metric;

  const _CompactReportMetric({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AdminUi.soft(metric.color),
            borderRadius: AdminUi.radius,
          ),
          child: Icon(metric.icon, size: 17, color: metric.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminUi.sectionTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 1),
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminUi.labelText,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportMetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ReportMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _ReportUserCard extends StatelessWidget {
  final AdminReportRecord report;
  final AdminUserRecord? reportedUser;
  final AdminUserRecord? reporter;
  final bool isUpdating;
  final VoidCallback? onProfileTap;
  final VoidCallback onDetailsTap;
  final ValueChanged<AdminReportStatus> onStatusSelected;

  const _ReportUserCard({
    required this.report,
    required this.reportedUser,
    required this.reporter,
    required this.isUpdating,
    required this.onProfileTap,
    required this.onDetailsTap,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = reportedUser?.fullName ?? _fallbackUserName(report);
    final roleLabel = reportedUser?.roleLabel ?? report.reportedUserRoleLabel;
    final reporterName = reporter?.fullName ?? _fallbackReporterName(report);

    return AdminInteractiveCard(
      onTap: onDetailsTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      accentColor: report.reportStatus.color,
      semanticLabel: 'Open report and linked ride details for $displayName',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportProfileTrigger(
            onTap: onProfileTap,
            semanticLabel: 'Open $displayName profile',
            child: _ReportAvatar(
              imageUrl: reportedUser?.profileImageUrl,
              name: displayName,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ReportCardContent(
              report: report,
              displayName: displayName,
              roleLabel: roleLabel,
              reporterName: reporterName,
              onProfileTap: onProfileTap,
            ),
          ),
          const SizedBox(width: 6),
          if (isUpdating)
            const SizedBox.square(
              dimension: 38,
              child: Padding(
                padding: EdgeInsets.all(9),
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else
            PopupMenuButton<AdminReportStatus>(
              tooltip: 'Change report status',
              icon: Icon(Icons.more_vert_rounded, color: AdminUi.neutral),
              onSelected: onStatusSelected,
              itemBuilder: (context) => AdminReportStatus.moderationActions
                  .map(
                    (status) => PopupMenuItem<AdminReportStatus>(
                      value: status,
                      enabled: status != report.reportStatus,
                      child: Row(
                        children: <Widget>[
                          Icon(status.icon, size: 19, color: status.color),
                          const SizedBox(width: 10),
                          Text(status.actionLabel),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  static String _fallbackUserName(AdminReportRecord report) {
    if (report.reportedUserId.isEmpty) {
      return 'Unknown user';
    }

    return 'User ${_shortId(report.reportedUserId)}';
  }

  static String _fallbackReporterName(AdminReportRecord report) {
    if (report.reporterId.isEmpty) {
      return report.reporterRoleLabel;
    }

    return '${report.reporterRoleLabel} ${_shortId(report.reporterId)}';
  }
}

class _ReportCardContent extends StatelessWidget {
  final AdminReportRecord report;
  final String displayName;
  final String roleLabel;
  final String reporterName;
  final VoidCallback? onProfileTap;

  const _ReportCardContent({
    required this.report,
    required this.displayName,
    required this.roleLabel,
    required this.reporterName,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ReportProfileTrigger(
              onTap: onProfileTap,
              semanticLabel: 'Open $displayName profile',
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminUi.cardTitle.copyWith(
                  fontSize: 15,
                  color: onProfileTap == null ? null : AdminUi.accent,
                  decoration: onProfileTap == null
                      ? TextDecoration.none
                      : TextDecoration.underline,
                ),
              ),
            ),
            AdminStatusChip(
              label: roleLabel,
              textColor: AdminUi.accent,
              backgroundColor: AdminUi.blueSoft,
            ),
            AdminStatusChip(
              label: report.statusLabel,
              textColor: _statusColor(report),
              backgroundColor: _statusBackgroundColor(report),
            ),
            AdminStatusChip(
              label: report.categoryLabel,
              textColor: AdminUi.neutral,
              backgroundColor: AdminUi.mutedSurface,
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          report.details.isEmpty
              ? 'Reason: ${report.reasonLabel}'
              : 'Reason: ${report.reasonLabel} - ${report.details}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AdminUi.valueText.copyWith(fontSize: 13.5),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 10,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ReportMetaItem(
              icon: Icons.person_outline_rounded,
              child: Text('Reported by $reporterName', style: AdminUi.bodyText),
            ),
            _ReportMetaItem(
              icon: Icons.schedule_rounded,
              child: TimeAgoText(
                dateTime: report.createdAt ?? report.updatedAt,
                style: AdminUi.bodyText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportProfileTrigger extends StatelessWidget {
  final VoidCallback? onTap;
  final String semanticLabel;
  final Widget child;

  const _ReportProfileTrigger({
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return child;
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _ReportMetaItem extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const _ReportMetaItem({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AdminUi.muted),
        const SizedBox(width: 5),
        Flexible(child: child),
      ],
    );
  }
}

class _ReportAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;

  const _ReportAvatar({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    const size = 44.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AdminUi.blueSoft,
        border: Border.all(color: AdminUi.surface, width: 2),
      ),
      child: ClipOval(
        child: FirebaseStorageImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          fallback: Container(
            color: AdminUi.blueSoft,
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: TextStyle(
                color: AdminUi.accent,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _ReportDateFilterLabel on _ReportDateFilter {
  String label(DateTime? selectedDate) {
    switch (this) {
      case _ReportDateFilter.all:
        return 'All dates';
      case _ReportDateFilter.today:
        return 'Today';
      case _ReportDateFilter.last7Days:
        return 'Last 7 days';
      case _ReportDateFilter.last30Days:
        return 'Last 30 days';
      case _ReportDateFilter.thisMonth:
        return 'This month';
      case _ReportDateFilter.date:
        return _formatDate(selectedDate) ?? 'Specific date';
    }
  }
}

Color _statusColor(AdminReportRecord report) {
  return report.reportStatus.color;
}

Color _statusBackgroundColor(AdminReportRecord report) {
  return report.reportStatus.backgroundColor;
}

extension _AdminReportStatusPresentation on AdminReportStatus {
  String get actionLabel {
    switch (this) {
      case AdminReportStatus.pending:
        return 'Pending';
      case AdminReportStatus.resolved:
        return 'Resolved';
      case AdminReportStatus.ignored:
        return 'Ignore';
      case AdminReportStatus.spam:
        return 'Spam';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminReportStatus.pending:
        return Icons.schedule_rounded;
      case AdminReportStatus.resolved:
        return Icons.check_circle_rounded;
      case AdminReportStatus.ignored:
        return Icons.visibility_off_rounded;
      case AdminReportStatus.spam:
        return Icons.report_gmailerrorred_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AdminReportStatus.pending:
        return AdminUi.highlightAmber;
      case AdminReportStatus.resolved:
        return AdminUi.successText;
      case AdminReportStatus.ignored:
        return AdminUi.neutral;
      case AdminReportStatus.spam:
        return AdminUi.danger;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case AdminReportStatus.pending:
        return AdminUi.warningSoft;
      case AdminReportStatus.resolved:
        return AdminUi.successBackground;
      case AdminReportStatus.ignored:
        return AdminUi.mutedSurface;
      case AdminReportStatus.spam:
        return AdminUi.dangerSoft;
    }
  }
}

String _initials(String name) {
  final parts = name
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'U';
  }

  return parts.map((part) => part[0].toUpperCase()).join();
}

String _shortId(String id) {
  final value = id.trim();
  if (value.length <= 6) {
    return value;
  }

  return value.substring(0, 6);
}

String? _formatDate(DateTime? value) {
  if (value == null) {
    return null;
  }

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
