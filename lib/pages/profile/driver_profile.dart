import 'package:flutter/material.dart';

import '../../services/ride_tracking_service.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/time_ago_text.dart';

class DriverProfilePage extends StatefulWidget {
  final String driverId;
  final String passengerId;
  final String? bookingId;

  const DriverProfilePage({
    super.key,
    required this.driverId,
    required this.passengerId,
    this.bookingId,
  });

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  final RideTrackingService _rideTrackingService = RideTrackingService();
  bool _reviewsExpanded = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: AppBar(
        backgroundColor: PassengerUi.surface,
        surfaceTintColor: PassengerUi.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_rounded, color: PassengerUi.title),
        ),
        title: Text('Driver Profile', style: PassengerUi.cardTitle),
      ),
      body: StreamBuilder<DriverReviewProfile>(
        stream: _rideTrackingService.watchDriverProfile(widget.driverId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return PassengerPageContainer(
              child: PassengerEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load driver',
                description: snapshot.error.toString(),
              ),
            );
          }

          final driver = snapshot.data;
          if (driver == null) {
            return const PassengerPageContainer(
              child: PassengerEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Driver not found',
                description: 'This driver profile is no longer available.',
              ),
            );
          }

          return PassengerPageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DriverHero(driver: driver),
                const SizedBox(height: 14),
                _DriverStats(driver: driver),
                const SizedBox(height: 14),
                _DriverActions(
                  isSaving: _isSaving,
                  onAddReview: () => _handleAddReview(driver),
                  onReport: () => _handleReport(driver),
                ),
                const SizedBox(height: 18),
                _ReviewsPanel(
                  driverId: driver.driverId,
                  expanded: _reviewsExpanded,
                  onToggle: () {
                    setState(() => _reviewsExpanded = !_reviewsExpanded);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAddReview(DriverReviewProfile driver) async {
    final bookingId = widget.bookingId;
    if (bookingId == null || bookingId.trim().isEmpty) {
      _showSnackBar('Open this profile from a completed trip to add a review.');
      return;
    }

    final draft = await _showReviewSheet(driver);
    if (draft == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _rideTrackingService.savePassengerDriverReview(
        bookingId: bookingId,
        passengerId: widget.passengerId,
        driverId: driver.driverId,
        rating: draft.rating,
        comment: draft.comment,
      );

      if (mounted) {
        _showSnackBar('Driver review saved.');
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Unable to save review: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleReport(DriverReviewProfile driver) async {
    final bookingId = widget.bookingId;
    if (bookingId == null || bookingId.trim().isEmpty) {
      _showSnackBar('Open this profile from a trip to report a driver.');
      return;
    }

    final draft = await _showReportSheet(driver);
    if (draft == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _rideTrackingService.reportDriver(
        bookingId: bookingId,
        passengerId: widget.passengerId,
        driverId: driver.driverId,
        reason: draft.reason,
        details: draft.details,
      );

      if (mounted) {
        _showSnackBar('Report submitted for admin review.');
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Unable to submit report: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<_ReviewDraft?> _showReviewSheet(DriverReviewProfile driver) async {
    return showModalBottomSheet<_ReviewDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReviewSheet(driver: driver),
    );
  }

  Future<_ReportDraft?> _showReportSheet(DriverReviewProfile driver) async {
    return showModalBottomSheet<_ReportDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportSheet(driver: driver),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static const List<String> _reportReasons = <String>[
    'Safety concern',
    'Unprofessional behavior',
    'Wrong route or fare issue',
    'Vehicle concern',
    'Other',
  ];
}

class _DriverHero extends StatelessWidget {
  static const String _coverAssetPath = 'assets/images/full_logo.jpg';

  final DriverReviewProfile driver;

  const _DriverHero({required this.driver});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 132,
              width: double.infinity,
              child: Image.asset(
                _coverAssetPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Transform.translate(
                  offset: const Offset(0, -44),
                  child: _DriverAvatar(driver: driver),
                ),
                Transform.translate(
                  offset: const Offset(0, -26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              driver.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PassengerUi.sectionTitle.copyWith(
                                fontSize: 24,
                              ),
                            ),
                          ),
                          if (driver.isVerified)
                            Icon(
                              Icons.verified_rounded,
                              color: PassengerUi.accentBlue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          PassengerStatusChip(
                            label: 'Driver',
                            textColor: PassengerUi.primary,
                            backgroundColor: PassengerUi.dangerSoft,
                          ),
                          PassengerStatusChip(
                            label: driver.isVerified
                                ? 'Verified badge'
                                : 'Pending verification',
                            textColor: driver.isVerified
                                ? PassengerUi.successText
                                : PassengerUi.highlightAmber,
                            backgroundColor: driver.isVerified
                                ? PassengerUi.successBackground
                                : PassengerUi.warningSoft,
                          ),
                          if (driver.isBanned)
                            PassengerStatusChip(
                              label: 'Restricted',
                              textColor: PassengerUi.primary,
                              backgroundColor: PassengerUi.dangerSoft,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  final DriverReviewProfile driver;

  const _DriverAvatar({required this.driver});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      height: 98,
      decoration: BoxDecoration(
        color: PassengerUi.surface,
        shape: BoxShape.circle,
        border: Border.all(color: PassengerUi.surface, width: 4),
        boxShadow: PassengerUi.cardShadow,
      ),
      child: ClipOval(
        child: FirebaseStorageImage(
          imageUrl: driver.profileImageUrl,
          fit: BoxFit.cover,
          fallback: Container(
            color: PassengerUi.blueSoft,
            alignment: Alignment.center,
            child: Text(
              _initials(driver.fullName),
              style: PassengerUi.sectionTitle.copyWith(
                color: PassengerUi.accentBlue,
                fontSize: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .take(2)
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'D';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class _DriverStats extends StatelessWidget {
  final DriverReviewProfile driver;

  const _DriverStats({required this.driver});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(
            icon: Icons.star_rate_rounded,
            label: 'Rating',
            value: driver.ratingLabel,
            color: PassengerUi.highlightAmber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.reviews_outlined,
            label: 'Reviews',
            value: driver.reviewCount.toString(),
            color: PassengerUi.accentBlue,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value, style: PassengerUi.cardTitle),
          const SizedBox(height: 2),
          Text(label, style: PassengerUi.bodyText),
        ],
      ),
    );
  }
}

class _DriverActions extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onAddReview;
  final VoidCallback onReport;

  const _DriverActions({
    required this.isSaving,
    required this.onAddReview,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          ElevatedButton.icon(
            onPressed: isSaving ? null : onAddReview,
            icon: const Icon(Icons.rate_review_rounded, size: 18),
            label: const Text('Add Review'),
          ),
          OutlinedButton.icon(
            onPressed: isSaving ? null : onReport,
            icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18),
            label: const Text('Report'),
          ),
        ],
      ),
    );
  }
}

class _ReviewsPanel extends StatelessWidget {
  final String driverId;
  final bool expanded;
  final VoidCallback onToggle;

  const _ReviewsPanel({
    required this.driverId,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverReviewRecord>>(
      stream: RideTrackingService().watchDriverReviews(driverId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return PassengerEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Unable to load reviews',
            description: snapshot.error.toString(),
          );
        }

        if (!snapshot.hasData) {
          return const PassengerSurfaceCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final reviews = snapshot.data!;
        final visibleReviews = expanded
            ? reviews
            : reviews.take(3).toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PassengerSectionHeader(
              title: 'Recent Reviews',
              actionLabel: reviews.length > 3
                  ? (expanded ? 'See less' : 'See more')
                  : '',
              onActionTap: reviews.length > 3 ? onToggle : null,
            ),
            const SizedBox(height: 12),
            if (reviews.isEmpty)
              const PassengerEmptyState(
                icon: Icons.reviews_outlined,
                title: 'No reviews yet',
                description: 'Passenger reviews will appear here.',
              )
            else
              ...visibleReviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReviewCard(review: review),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final DriverReviewRecord review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  review.reviewerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassengerUi.cardTitle,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 18,
                    color: PassengerUi.highlightAmber,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(review.comment, style: PassengerUi.bodyText),
          ],
          const SizedBox(height: 8),
          TimeAgoText(
            dateTime: review.updatedAt ?? review.createdAt,
            style: PassengerUi.bodyText.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  final DriverReviewProfile driver;

  const _ReviewSheet({required this.driver});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final TextEditingController _controller = TextEditingController();
  int _selectedRating = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ActionSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Review ${widget.driver.fullName}',
            style: PassengerUi.sectionTitle.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final rating = index + 1;
              final isSelected = rating <= _selectedRating;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _selectedRating = rating),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 34,
                    color: PassengerUi.highlightAmber,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: 600,
            decoration: InputDecoration(
              labelText: 'Recent review',
              hintText: 'Share what went well or what needs improvement.',
              filled: true,
              fillColor: PassengerUi.mutedSurface,
              border: OutlineInputBorder(
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
                _ReviewDraft(
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
    );
  }
}

class _ReportSheet extends StatefulWidget {
  final DriverReviewProfile driver;

  const _ReportSheet({required this.driver});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final TextEditingController _controller = TextEditingController();
  String _selectedReason = _DriverProfilePageState._reportReasons.first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ActionSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Report ${widget.driver.fullName}',
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
            ),
            items: _DriverProfilePageState._reportReasons
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
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(
                _ReportDraft(
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

class _ActionSheetFrame extends StatelessWidget {
  final Widget child;

  const _ActionSheetFrame({required this.child});

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

class _ReviewDraft {
  final int rating;
  final String comment;

  const _ReviewDraft({required this.rating, required this.comment});
}

class _ReportDraft {
  final String reason;
  final String details;

  const _ReportDraft({required this.reason, required this.details});
}
