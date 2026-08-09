import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../utils/user_facing_error_message.dart';
import 'admin_action_logs_page.dart';
import 'admin_create_account_page.dart';
import 'admin_models.dart';
import 'admin_navigation.dart';
import 'admin_service.dart';
import 'widgets/admin_shared.dart';
import 'widgets/fare_settings_editor.dart';

class AdminManagementPage extends StatelessWidget {
  final String adminId;

  const AdminManagementPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return AdminPageContainer(
      child: StreamBuilder<AdminUserRecord>(
        stream: AdminService.watchUser(adminId),
        builder: (context, adminSnapshot) {
          if (adminSnapshot.hasError) {
            return AdminErrorCard(
              message: 'Unable to load admin profile. Please try again.',
            );
          }

          if (!adminSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentAdmin = adminSnapshot.data!;

          return StreamBuilder<List<AdminBookingRecord>>(
            stream: AdminService.watchBookings(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AdminErrorCard(
                  message: 'Unable to load management data. Please try again.',
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final bookings = snapshot.data!;
              final fareTaggedTrips = bookings
                  .where((booking) => booking.fareLabel != null)
                  .length;
              final cashlessTrips = bookings.where(_usesCashlessPayment).length;
              final pendingPaymentTrips = bookings
                  .where(_hasPendingPayment)
                  .length;
              final settledPaymentTrips = bookings
                  .where(_hasSettledPayment)
                  .length;
              final closedTripRecords = bookings
                  .where(
                    (booking) => booking.isCompleted || booking.isCancelled,
                  )
                  .length;
              final systemCommissionTotal = bookings
                  .where((booking) => booking.isCompleted)
                  .fold<int>(
                    0,
                    (total, booking) => total + booking.commissionAmount,
                  );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AdminSectionIntro(
                    title: 'Management',
                    subtitle:
                        'Manage service-wide fare and payment rules separately from live monitoring and account management.',
                    actions: [
                      if (currentAdmin.isMainAdmin)
                        ElevatedButton.icon(
                          onPressed: () => _openAdminCreationFlow(context),
                          icon: const Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 18,
                          ),
                          label: const Text('Create Admin Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminUi.primary,
                            foregroundColor: AdminUi.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: AdminUi.radius,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ManagementTopGrid(
                    metrics: _ManagementMetricsPanel(
                      fareTaggedTrips: fareTaggedTrips,
                      cashlessTrips: cashlessTrips,
                      pendingPaymentTrips: pendingPaymentTrips,
                      closedTripRecords: closedTripRecords,
                      systemCommissionTotal: systemCommissionTotal,
                    ),
                    fareEditor: _ManagementSurfacePanel(
                      title: 'Fare Management',
                      subtitle:
                          'Update the service-wide fare rules admins control.',
                      accentColor: AdminUi.accentBlue,
                      child: FareSettingsEditor(adminId: adminId),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (currentAdmin.isMainAdmin)
                    _ManagementAdminGrid(
                      left: _AdminAccountsPreviewCard(adminId: adminId),
                      right: const _AdminLogsPreviewCard(),
                    )
                  else
                    const _AdminLogsPreviewCard(),
                  const SizedBox(height: 20),
                  _ManagementBottomGrid(
                    payment: _ManagementSurfacePanel(
                      title: 'Payment Management',
                      subtitle:
                          'Review cashless readiness and settlement status.',
                      accentColor: AdminUi.secondary,
                      child: Column(
                        children: [
                          AdminInfoPanel(
                            title: 'Cashless readiness',
                            description:
                                '$cashlessTrips trip(s) use a cashless method such as GCash, Maya, or card checkout. Payment setup remains separate from account management.',
                          ),
                          const SizedBox(height: 12),
                          AdminInfoPanel(
                            title: 'Payment settlement',
                            description:
                                '$settledPaymentTrips payment(s) are settled, while $pendingPaymentTrips still need checkout completion or cash collection.',
                          ),
                        ],
                      ),
                    ),
                    records: _ManagementSurfacePanel(
                      title: 'Ride History Management',
                      subtitle: 'Keep closed trips ready for review.',
                      accentColor: AdminUi.accentBlue,
                      child: AdminInfoPanel(
                        title: 'Trip history readiness',
                        description:
                            '$closedTripRecords closed trip(s) are available for reports, payment review, and fare transparency checks. Live dispatch stays in Monitoring.',
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

  Future<void> _openAdminCreationFlow(BuildContext context) async {
    final authenticated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _MainAdminReauthDialog(),
    );

    if (authenticated != true || !context.mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminCreateAccountPage()));
  }

  static bool _usesCashlessPayment(AdminBookingRecord booking) {
    final method = booking.paymentMethod?.toLowerCase().trim() ?? '';
    return method.contains('gcash') ||
        method.contains('maya') ||
        method.contains('card') ||
        method.contains('xendit');
  }

  static bool _hasPendingPayment(AdminBookingRecord booking) {
    if (booking.isCancelled) {
      return false;
    }

    final status = booking.paymentStatus?.toLowerCase().trim() ?? '';
    return status.contains('pending') || status == 'checkout_failed';
  }

  static bool _hasSettledPayment(AdminBookingRecord booking) {
    if (booking.isCancelled) {
      return false;
    }

    final status = booking.paymentStatus?.toLowerCase().trim() ?? '';
    return status == 'paid' || status == 'cash_collected';
  }
}

class _AdminAccountsPreviewCard extends StatelessWidget {
  final String adminId;

  const _AdminAccountsPreviewCard({required this.adminId});

  @override
  Widget build(BuildContext context) {
    return _ManagementSurfacePanel(
      title: 'Admin Accounts',
      subtitle: 'Message or deactivate secondary admin accounts.',
      accentColor: AdminUi.primary,
      child: StreamBuilder<List<AdminUserRecord>>(
        stream: AdminService.watchManagedAdmins(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _InlinePanelState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load admin accounts',
              description:
                  'Admin accounts could not be loaded. Please try again.',
              accentColor: AdminUi.danger,
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final admins = snapshot.data!;
          final activeAdmins = admins
              .where((admin) => !admin.isDeactivated && !admin.isDeleted)
              .length;
          final deactivatedAdmins = admins
              .where((admin) => admin.isDeactivated && !admin.isDeleted)
              .length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 12.0;
                  final twoColumns = constraints.maxWidth >= 420;
                  final width = twoColumns
                      ? (constraints.maxWidth - spacing) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _MiniAdminMetric(
                        width: width,
                        label: 'Active admins',
                        value: activeAdmins.toString(),
                        icon: Icons.verified_user_rounded,
                        accentColor: AdminUi.successText,
                      ),
                      _MiniAdminMetric(
                        width: width,
                        label: 'Deactivated',
                        value: deactivatedAdmins.toString(),
                        icon: Icons.no_accounts_rounded,
                        accentColor: AdminUi.danger,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: AdminActionButton(
                  label: 'Open Admin Accounts',
                  icon: Icons.arrow_forward_rounded,
                  backgroundColor: AdminUi.mutedSurface,
                  foregroundColor: AdminUi.primary,
                  onPressed: () => AdminNavigation.openAdminAccounts(
                    context,
                    adminId: adminId,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminLogsPreviewCard extends StatelessWidget {
  const _AdminLogsPreviewCard();

  @override
  Widget build(BuildContext context) {
    return _ManagementSurfacePanel(
      title: 'Admin Action Logs',
      subtitle: 'Recent admin account, fare, and moderation actions.',
      accentColor: AdminUi.accentBlue,
      child: StreamBuilder<List<AdminActionLogRecord>>(
        stream: AdminService.watchAdminLogs(limit: 3),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _InlinePanelState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load logs',
              description: 'Admin logs could not be loaded. Please try again.',
              accentColor: AdminUi.danger,
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final logs = snapshot.data!;
          if (logs.isEmpty) {
            return _InlinePanelState(
              icon: Icons.history_rounded,
              title: 'No admin actions logged yet',
              description:
                  'Actions will appear here after admins review users, restore accounts, update fares, or create admin accounts.',
              accentColor: AdminUi.accentBlue,
            );
          }

          return Column(
            children: [
              ...logs.map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AdminLogPreviewRow(log: log),
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: AdminActionButton(
                  label: 'Open Logs',
                  icon: Icons.arrow_forward_rounded,
                  backgroundColor: AdminUi.blueSoft,
                  foregroundColor: AdminUi.accentBlue,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminActionLogsPage(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminLogPreviewRow extends StatelessWidget {
  final AdminActionLogRecord log;

  const _AdminLogPreviewRow({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdminUi.surface.withValues(alpha: AdminUi.isDarkMode ? 0.55 : 1),
        borderRadius: AdminUi.radius,
        border: Border.all(color: AdminUi.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.actionLabel, style: AdminUi.cardTitle),
                const SizedBox(height: 3),
                Text(
                  log.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AdminUi.bodyText,
                ),
                const SizedBox(height: 6),
                Text(
                  '${log.adminName} - ${formatDateTime(log.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminUi.labelText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAdminMetric extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  const _MiniAdminMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AdminUi.surface.withValues(
            alpha: AdminUi.isDarkMode ? 0.55 : 1,
          ),
          borderRadius: AdminUi.radius,
          border: Border.all(color: AdminUi.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AdminUi.soft(accentColor, alpha: 0.12),
                borderRadius: AdminUi.radius,
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: AdminUi.valueText),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminUi.labelText,
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

class _InlinePanelState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  const _InlinePanelState({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AdminUi.surface.withValues(alpha: AdminUi.isDarkMode ? 0.55 : 1),
        borderRadius: AdminUi.radius,
        border: Border.all(color: AdminUi.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdminUi.cardTitle),
                const SizedBox(height: 4),
                Text(description, style: AdminUi.bodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MainAdminReauthDialog extends StatefulWidget {
  const _MainAdminReauthDialog();

  @override
  State<_MainAdminReauthDialog> createState() => _MainAdminReauthDialogState();
}

class _MainAdminReauthDialogState extends State<_MainAdminReauthDialog> {
  final _formKey = GlobalKey<FormState>();
  final _adminNameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _adminNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email?.trim();
      if (user == null || email == null || email.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-current-user',
          message: 'Unable to confirm the current admin session.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: _passwordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _authErrorMessage(error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = userFacingErrorMessage(
          error,
          fallback: 'Unable to confirm admin password. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Invalid admin password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }

  String? _validateAdminName(String? value) {
    if ((value ?? '').trim().toLowerCase() != 'admin') {
      return 'Enter the main admin name.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AdminUi.radius),
      title: const Text('Confirm Main Admin'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _adminNameController,
              textInputAction: TextInputAction.next,
              decoration: AdminUi.inputDecoration(
                labelText: 'Admin Name',
                hintText: 'admin',
                prefixIcon: const Icon(Icons.admin_panel_settings_rounded),
              ),
              validator: _validateAdminName,
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: AdminUi.inputDecoration(
                labelText: 'Password',
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Password is required' : null,
              enabled: !_isSubmitting,
              onFieldSubmitted: (_) {
                if (!_isSubmitting) {
                  _submit();
                }
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: AdminUi.bodyText.copyWith(color: AdminUi.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: AdminUi.radius),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }
}

class _ManagementAdminGrid extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _ManagementAdminGrid({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final twoColumns = constraints.maxWidth >= 920;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            SizedBox(width: itemWidth, child: left),
            SizedBox(width: itemWidth, child: right),
          ],
        );
      },
    );
  }
}

class _ManagementTopGrid extends StatelessWidget {
  final Widget metrics;
  final Widget fareEditor;

  const _ManagementTopGrid({required this.metrics, required this.fareEditor});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final twoColumns = constraints.maxWidth >= 1040;
        final leftWidth = twoColumns
            ? ((constraints.maxWidth - spacing) * 0.50)
            : constraints.maxWidth;
        final rightWidth = twoColumns
            ? constraints.maxWidth - spacing - leftWidth
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            SizedBox(width: leftWidth, child: metrics),
            SizedBox(width: rightWidth, child: fareEditor),
          ],
        );
      },
    );
  }
}

class _ManagementBottomGrid extends StatelessWidget {
  final Widget payment;
  final Widget records;

  const _ManagementBottomGrid({required this.payment, required this.records});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final twoColumns = constraints.maxWidth >= 920;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            SizedBox(width: itemWidth, child: payment),
            SizedBox(width: itemWidth, child: records),
          ],
        );
      },
    );
  }
}

class _ManagementMetricsPanel extends StatelessWidget {
  final int fareTaggedTrips;
  final int cashlessTrips;
  final int pendingPaymentTrips;
  final int closedTripRecords;
  final int systemCommissionTotal;

  const _ManagementMetricsPanel({
    required this.fareTaggedTrips,
    required this.cashlessTrips,
    required this.pendingPaymentTrips,
    required this.closedTripRecords,
    required this.systemCommissionTotal,
  });

  @override
  Widget build(BuildContext context) {
    return _ManagementSurfacePanel(
      title: 'Management Metrics',
      subtitle:
          'A quick snapshot of fare, payment, and ride history readiness.',
      accentColor: AdminUi.accentBlue,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final twoColumns = constraints.maxWidth >= 540;
          final cardWidth = twoColumns
              ? (constraints.maxWidth - spacing) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: <Widget>[
              _MetricFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'System commission',
                  value: 'PHP $systemCommissionTotal',
                  helper: 'Completed ride deductions',
                  icon: Icons.savings_rounded,
                  accentColor: AdminUi.secondary,
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Fare-ready trips',
                  value: fareTaggedTrips.toString(),
                  helper: 'Bookings with visible fare labels',
                  icon: Icons.receipt_long_rounded,
                  accentColor: AdminUi.accentBlue,
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Cashless trips',
                  value: cashlessTrips.toString(),
                  helper: 'Bookings using GCash, Maya, or checkout',
                  icon: Icons.account_balance_wallet_rounded,
                  accentColor: AdminUi.secondary,
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Pending payments',
                  value: pendingPaymentTrips.toString(),
                  helper: 'Checkout or cash collection still pending',
                  icon: Icons.pending_actions_rounded,
                  accentColor: AdminUi.highlightAmber,
                ),
              ),
              _MetricFrame(
                width: cardWidth,
                child: AdminMetricCard(
                  label: 'Closed trips',
                  value: closedTripRecords.toString(),
                  helper: 'Completed or cancelled trips',
                  icon: Icons.inventory_2_rounded,
                  accentColor: AdminUi.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ManagementSurfacePanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final Widget child;

  const _ManagementSurfacePanel({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final background = AdminUi.isDarkMode
        ? Color.lerp(AdminUi.surface, accentColor, 0.10)
        : AdminUi.surface;

    return AdminSurfaceCard(
      color: background,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AdminUi.cardTitle),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AdminUi.bodyText.copyWith(
                        color: AdminUi.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricFrame extends StatelessWidget {
  final double width;
  final Widget child;

  const _MetricFrame({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: 132, child: child);
  }
}
