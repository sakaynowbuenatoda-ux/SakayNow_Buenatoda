import 'package:flutter_test/flutter_test.dart';
import 'package:sakaynow_buenatoda/pages/admin/admin_models.dart';

void main() {
  AdminReportRecord reportWithStatus(String status) {
    return AdminReportRecord(
      reportId: 'report-1',
      bookingId: 'booking-1',
      reporterId: 'passenger-1',
      reporterRole: 'passenger',
      reportedUserId: 'driver-1',
      reportedUserRole: 'driver',
      reason: 'Safety concern',
      details: 'Test report',
      status: status,
      createdAt: DateTime(2026, 8, 21),
      updatedAt: null,
    );
  }

  group('Admin report status', () {
    test('normalizes legacy and current values into four visible states', () {
      expect(reportWithStatus('open').reportStatus, AdminReportStatus.pending);
      expect(
        reportWithStatus('reviewing').reportStatus,
        AdminReportStatus.pending,
      );
      expect(
        reportWithStatus('closed').reportStatus,
        AdminReportStatus.resolved,
      );
      expect(
        reportWithStatus('dismissed').reportStatus,
        AdminReportStatus.ignored,
      );
      expect(reportWithStatus('spam').reportStatus, AdminReportStatus.spam);
      expect(reportWithStatus('unexpected').statusLabel, 'Pending');
    });

    test('keeps pending out of the three-dot moderation actions', () {
      expect(AdminReportStatus.moderationActions, <AdminReportStatus>[
        AdminReportStatus.resolved,
        AdminReportStatus.ignored,
        AdminReportStatus.spam,
      ]);
      expect(
        AdminReportStatus.moderationActions,
        isNot(contains(AdminReportStatus.pending)),
      );
    });
  });
}
