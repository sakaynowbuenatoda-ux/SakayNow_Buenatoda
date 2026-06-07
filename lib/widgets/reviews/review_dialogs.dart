import 'package:flutter/material.dart';

import '../passenger_widgets/passenger_ui.dart';

class PassengerDriverReviewDraft {
  final int rating;
  final String comment;

  const PassengerDriverReviewDraft({
    required this.rating,
    required this.comment,
  });
}

Future<PassengerDriverReviewDraft?> showPassengerDriverReviewDialog(
  BuildContext context, {
  required String driverName,
  int initialRating = 5,
  String initialComment = '',
}) {
  return showDialog<PassengerDriverReviewDraft>(
    context: context,
    builder: (context) => _PassengerDriverReviewDialog(
      driverName: driverName,
      initialRating: initialRating,
      initialComment: initialComment,
    ),
  );
}

Future<int?> showDriverPassengerRatingDialog(
  BuildContext context, {
  required String passengerName,
  int? selectedRating,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _DriverPassengerRatingDialog(
      passengerName: passengerName,
      selectedRating: selectedRating,
    ),
  );
}

class _PassengerDriverReviewDialog extends StatefulWidget {
  final String driverName;
  final int initialRating;
  final String initialComment;

  const _PassengerDriverReviewDialog({
    required this.driverName,
    required this.initialRating,
    required this.initialComment,
  });

  @override
  State<_PassengerDriverReviewDialog> createState() =>
      _PassengerDriverReviewDialogState();
}

class _PassengerDriverReviewDialogState
    extends State<_PassengerDriverReviewDialog> {
  late final TextEditingController _controller;
  late int _selectedRating;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialComment);
    _selectedRating = widget.initialRating.clamp(1, 5);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CenteredReviewFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PassengerUi.warningSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.star_rate_rounded,
                  color: PassengerUi.highlightAmber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Review Driver',
                      style: PassengerUi.sectionTitle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PassengerUi.bodyText,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StarRatingSelector(
            selectedRating: _selectedRating,
            onChanged: (rating) => setState(() => _selectedRating = rating),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: 600,
            decoration: InputDecoration(
              labelText: 'Your review',
              hintText: 'Share what went well or what needs improvement.',
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
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    PassengerDriverReviewDraft(
                      rating: _selectedRating,
                      comment: _controller.text.trim(),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save Review'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverPassengerRatingDialog extends StatefulWidget {
  final String passengerName;
  final int? selectedRating;

  const _DriverPassengerRatingDialog({
    required this.passengerName,
    required this.selectedRating,
  });

  @override
  State<_DriverPassengerRatingDialog> createState() =>
      _DriverPassengerRatingDialogState();
}

class _DriverPassengerRatingDialogState
    extends State<_DriverPassengerRatingDialog> {
  late int _selectedRating;

  @override
  void initState() {
    super.initState();
    _selectedRating = (widget.selectedRating ?? 5).clamp(1, 5);
  }

  @override
  Widget build(BuildContext context) {
    return _CenteredReviewFrame(
      maxWidth: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Review Passenger',
            style: PassengerUi.sectionTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            widget.passengerName,
            style: PassengerUi.bodyText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          _StarRatingSelector(
            selectedRating: _selectedRating,
            onChanged: (rating) => setState(() => _selectedRating = rating),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(_selectedRating),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save Review'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarRatingSelector extends StatelessWidget {
  final int selectedRating;
  final ValueChanged<int> onChanged;

  const _StarRatingSelector({
    required this.selectedRating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (index) {
        final rating = index + 1;
        final isSelected = rating <= selectedRating;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(rating),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              isSelected ? Icons.star_rounded : Icons.star_border_rounded,
              size: 34,
              color: PassengerUi.highlightAmber,
            ),
          ),
        );
      }),
    );
  }
}

class _CenteredReviewFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const _CenteredReviewFrame({required this.child, this.maxWidth = 360});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: PassengerUi.surface,
      surfaceTintColor: PassengerUi.surface,
      elevation: 14,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: PassengerUi.border),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 18,
          top: 18,
          right: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
