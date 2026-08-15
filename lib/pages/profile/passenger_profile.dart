import 'package:flutter/material.dart';

import '../../services/ride_tracking_service.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/reports/report_user_sheet.dart';
import 'models/profile_review_item.dart';
import 'widgets/profile_reviews_section.dart';

class PassengerProfilePage extends StatefulWidget {
  final String passengerId;
  final String driverId;
  final String? bookingId;

  const PassengerProfilePage({
    super.key,
    required this.passengerId,
    required this.driverId,
    this.bookingId,
  });

  @override
  State<PassengerProfilePage> createState() => _PassengerProfilePageState();
}

class _PassengerProfilePageState extends State<PassengerProfilePage> {
  final RideTrackingService _rideTrackingService = RideTrackingService();
  bool _isSaving = false;

  static const List<String> _reportReasons = <String>[
    'Safety concern',
    'No-show or unreachable',
    'Incorrect pickup details',
    'Unprofessional behavior',
    'Payment concern',
    'Other',
  ];

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
        title: Text('Passenger Profile', style: PassengerUi.cardTitle),
      ),
      body: StreamBuilder<PassengerReviewProfile>(
        stream: _rideTrackingService.watchPassengerProfile(widget.passengerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return PassengerPageContainer(
              child: PassengerEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load passenger',
                description:
                    'Passenger profile could not be loaded. Please try again.',
              ),
            );
          }

          final passenger = snapshot.data;
          if (passenger == null) {
            return const PassengerPageContainer(
              child: PassengerEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Passenger not found',
                description: 'This passenger profile is no longer available.',
              ),
            );
          }

          return PassengerPageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PassengerHero(passenger: passenger),
                const SizedBox(height: 14),
                _PassengerStats(passenger: passenger),
                const SizedBox(height: 14),
                _PassengerActions(
                  isSaving: _isSaving,
                  onReport: () => _handleReport(passenger),
                ),
                const SizedBox(height: 18),
                _ReviewsPanel(
                  passenger: passenger,
                  rideTrackingService: _rideTrackingService,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleReport(PassengerReviewProfile passenger) async {
    final bookingId = widget.bookingId;
    if (bookingId == null || bookingId.trim().isEmpty) {
      _showSnackBar('Open this profile from a booking to report a passenger.');
      return;
    }

    final draft = await showUserReportSheet(
      context,
      title: 'Report ${passenger.fullName}',
      reasons: _reportReasons,
    );
    if (draft == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _rideTrackingService.reportPassenger(
        bookingId: bookingId,
        driverId: widget.driverId,
        passengerId: passenger.userId,
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PassengerHero extends StatelessWidget {
  static const String _coverAssetPath = 'assets/images/full_logo.jpg';

  final PassengerReviewProfile passenger;

  const _PassengerHero({required this.passenger});

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
                  child: _PassengerAvatar(passenger: passenger),
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
                              passenger.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PassengerUi.sectionTitle.copyWith(
                                fontSize: 24,
                              ),
                            ),
                          ),
                          if (passenger.isVerified)
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
                            label: passenger.roleLabel,
                            textColor: PassengerUi.accentBlue,
                            backgroundColor: PassengerUi.blueSoft,
                          ),
                          PassengerStatusChip(
                            label: passenger.isVerified
                                ? 'Verified'
                                : 'Pending verification',
                            textColor: passenger.isVerified
                                ? PassengerUi.successText
                                : PassengerUi.highlightAmber,
                            backgroundColor: passenger.isVerified
                                ? PassengerUi.successBackground
                                : PassengerUi.warningSoft,
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

class _PassengerAvatar extends StatelessWidget {
  final PassengerReviewProfile passenger;

  const _PassengerAvatar({required this.passenger});

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
          imageUrl: passenger.profileImageUrl,
          fit: BoxFit.cover,
          fallback: Container(
            color: PassengerUi.blueSoft,
            alignment: Alignment.center,
            child: Text(
              _initials(passenger.fullName),
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
}

class _PassengerStats extends StatelessWidget {
  final PassengerReviewProfile passenger;

  const _PassengerStats({required this.passenger});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(
            icon: Icons.star_rate_rounded,
            label: 'Rating',
            value: passenger.ratingLabel,
            color: PassengerUi.highlightAmber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.reviews_outlined,
            label: 'Reviews',
            value: passenger.reviewCount.toString(),
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

class _PassengerActions extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onReport;

  const _PassengerActions({required this.isSaving, required this.onReport});

  @override
  Widget build(BuildContext context) {
    return PassengerSurfaceCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: isSaving ? null : onReport,
            icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18),
            label: Text(isSaving ? 'Submitting' : 'Report'),
          ),
        ],
      ),
    );
  }
}

class _ReviewsPanel extends StatelessWidget {
  final PassengerReviewProfile passenger;
  final RideTrackingService rideTrackingService;

  const _ReviewsPanel({
    required this.passenger,
    required this.rideTrackingService,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileReviewsPreview(
      title: 'Passenger Reviews',
      profileName: passenger.fullName,
      emptyDescription: 'Driver reviews for this passenger will appear here.',
      reviewsLoader: () => rideTrackingService
          .watchUserReviews(passenger.userId)
          .map(
            (reviews) => reviews
                .map(ProfileReviewItem.fromRideReview)
                .toList(growable: false),
          ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'P';
  }

  return parts.map((part) => part[0].toUpperCase()).join();
}
