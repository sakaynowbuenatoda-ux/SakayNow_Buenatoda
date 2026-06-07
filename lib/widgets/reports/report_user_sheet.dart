import 'package:flutter/material.dart';

import '../passenger_widgets/passenger_ui.dart';

class UserReportDraft {
  final String reason;
  final String details;

  const UserReportDraft({required this.reason, required this.details});
}

Future<UserReportDraft?> showUserReportSheet(
  BuildContext context, {
  required String title,
  required List<String> reasons,
}) {
  return showModalBottomSheet<UserReportDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _UserReportSheet(title: title, reasons: reasons),
  );
}

class _UserReportSheet extends StatefulWidget {
  final String title;
  final List<String> reasons;

  const _UserReportSheet({required this.title, required this.reasons});

  @override
  State<_UserReportSheet> createState() => _UserReportSheetState();
}

class _UserReportSheetState extends State<_UserReportSheet> {
  final TextEditingController _controller = TextEditingController();
  late String _selectedReason;

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.reasons.isEmpty ? 'Other' : widget.reasons.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.reasons.isEmpty
        ? const <String>['Other']
        : widget.reasons;

    return _ReportSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.title,
            style: PassengerUi.sectionTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedReason,
            decoration: InputDecoration(
              labelText: 'Reason',
              filled: true,
              fillColor: PassengerUi.mutedSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: PassengerUi.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: PassengerUi.border),
              ),
            ),
            items: reasons
                .map(
                  (reason) => DropdownMenuItem<String>(
                    value: reason,
                    child: Text(reason),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedReason = value);
              }
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: 800,
            decoration: InputDecoration(
              labelText: 'Details',
              hintText: 'Add context for the admin team.',
              filled: true,
              fillColor: PassengerUi.mutedSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: PassengerUi.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: PassengerUi.border),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(
                UserReportDraft(
                  reason: _selectedReason,
                  details: _controller.text.trim(),
                ),
              ),
              icon: const Icon(Icons.report_gmailerrorred_rounded),
              label: const Text('Submit Report'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSheetFrame extends StatelessWidget {
  final Widget child;

  const _ReportSheetFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              color: PassengerUi.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PassengerUi.border),
              boxShadow: PassengerUi.cardShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
