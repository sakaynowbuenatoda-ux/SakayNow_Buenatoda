import 'package:flutter/material.dart';

import '../../widgets/time_ago_text.dart';
import 'admin_models.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';

class AdminReportDetailsPage extends StatelessWidget {
  final String adminId;
  final AdminReportRecord report;

  const AdminReportDetailsPage({
    super.key,
    required this.adminId,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminUi.background,
      appBar: AppBar(
        backgroundColor: AdminUi.surface,
        surfaceTintColor: AdminUi.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: AdminUi.title),
        ),
        title: Text('Report Details', style: AdminUi.cardTitle),
      ),
      body: AdminPageContainer(
        maxContentWidth: AdminUi.detailContentWidth,
        child: StreamBuilder<AdminBookingRecord?>(
          stream: AdminService.watchBooking(report.bookingId),
          builder: (context, bookingSnapshot) {
            if (bookingSnapshot.hasError) {
              return AdminErrorCard(
                message:
                    'Unable to load the linked ride: ${bookingSnapshot.error}',
              );
            }

            return StreamBuilder<List<AdminUserRecord>>(
              stream: AdminService.watchUsers(),
              builder: (context, usersSnapshot) {
                if (usersSnapshot.hasError) {
                  return AdminErrorCard(
                    message:
                        'Unable to load the passenger and driver details: ${usersSnapshot.error}',
                  );
                }

                if (!usersSnapshot.hasData ||
                    bookingSnapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final usersById = <String, AdminUserRecord>{
                  for (final user in usersSnapshot.data!) user.userId: user,
                };
                final booking = bookingSnapshot.data;
                final reporterName =
                    usersById[report.reporterId]?.fullName ??
                    report.reporterRoleLabel;
                final reportedName =
                    usersById[report.reportedUserId]?.fullName ??
                    report.reportedUserRoleLabel;

                return _ReportDetailsContent(
                  report: report,
                  reporterName: reporterName,
                  reportedName: reportedName,
                  booking: booking,
                  passengerName: booking == null
                      ? 'Passenger'
                      : (usersById[booking.passengerId]?.fullName ??
                            'Passenger'),
                  driverName: booking == null
                      ? 'Unassigned'
                      : (usersById[booking.driverId]?.fullName ?? 'Unassigned'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReportDetailsContent extends StatelessWidget {
  final AdminReportRecord report;
  final String reporterName;
  final String reportedName;
  final AdminBookingRecord? booking;
  final String passengerName;
  final String driverName;

  const _ReportDetailsContent({
    required this.report,
    required this.reporterName,
    required this.reportedName,
    required this.booking,
    required this.passengerName,
    required this.driverName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AdminSectionIntro(
          title: 'Report Details',
          subtitle: 'Review the report and the ride connected to it.',
          actions: <Widget>[
            AdminStatusChip(
              label: report.statusLabel,
              textColor: _statusColor(report),
              backgroundColor: _statusBackgroundColor(report),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminSurfaceCard(
          child: Column(
            children: <Widget>[
              _ReportDetailRow(label: 'Reported user', value: reportedName),
              _ReportDetailRow(
                label: 'Reported role',
                value: report.reportedUserRoleLabel,
              ),
              _ReportDetailRow(label: 'Reported by', value: reporterName),
              _ReportDetailRow(label: 'Reason', value: report.reasonLabel),
              if (report.details.isNotEmpty)
                _ReportDetailRow(label: 'Details', value: report.details),
              _ReportDetailRow(
                label: 'Report ID',
                value: report.reportId.isEmpty
                    ? 'Not available'
                    : report.reportId,
              ),
              _ReportDetailRow(
                label: 'Booking ID',
                value: report.bookingId.isEmpty
                    ? 'No linked booking'
                    : report.bookingId,
                isLast: report.createdAt == null && report.updatedAt == null,
              ),
              if (report.createdAt != null || report.updatedAt != null)
                _ReportTimeRow(
                  label: 'Reported',
                  value: report.createdAt ?? report.updatedAt,
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Linked Ride', style: AdminUi.sectionTitle),
        const SizedBox(height: 6),
        Text(
          'Latest booking details for the passenger and driver named in this report.',
          style: AdminUi.bodyText,
        ),
        const SizedBox(height: 12),
        if (report.bookingId.isEmpty)
          const AdminEmptyCollection(
            icon: Icons.link_off_rounded,
            title: 'No ride is linked to this report',
            description:
                'This report was submitted without a booking reference.',
          )
        else if (booking == null)
          const AdminEmptyCollection(
            icon: Icons.directions_car_filled_outlined,
            title: 'Linked ride not found',
            description:
                'The booking connected to this report is no longer available.',
          )
        else
          AdminBookingCard(
            booking: booking!,
            passengerName: passengerName,
            driverName: driverName,
          ),
      ],
    );
  }
}

class _ReportDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _ReportDetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: AdminUi.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: AdminUi.bodyText)),
        ],
      ),
    );
  }
}

class _ReportTimeRow extends StatelessWidget {
  final String label;
  final DateTime? value;

  const _ReportTimeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: AdminUi.bodyText.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TimeAgoText(dateTime: value, style: AdminUi.bodyText),
        ),
      ],
    );
  }
}

Color _statusColor(AdminReportRecord report) {
  switch (report.reportStatus) {
    case AdminReportStatus.resolved:
      return AdminUi.successText;
    case AdminReportStatus.ignored:
      return AdminUi.neutral;
    case AdminReportStatus.spam:
      return AdminUi.danger;
    case AdminReportStatus.pending:
      return AdminUi.highlightAmber;
  }
}

Color _statusBackgroundColor(AdminReportRecord report) {
  switch (report.reportStatus) {
    case AdminReportStatus.resolved:
      return AdminUi.successBackground;
    case AdminReportStatus.ignored:
      return AdminUi.mutedSurface;
    case AdminReportStatus.spam:
      return AdminUi.dangerSoft;
    case AdminReportStatus.pending:
      return AdminUi.warningSoft;
  }
}
