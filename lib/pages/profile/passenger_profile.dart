import 'package:flutter/material.dart';

import '../../services/ride_tracking_service.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/reports/report_user_sheet.dart';
import 'models/profile_review_item.dart';
import 'widgets/profile_reviews_section.dart';
import 'widgets/public_profile_components.dart';

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
      appBar: PublicProfileAppBar(
        title: 'Passenger Profile',
        onBack: () => Navigator.of(context).pop(),
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
            maxContentWidth: PassengerUi.settingsContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PassengerHero(passenger: passenger),
                const SizedBox(height: 10),
                _PassengerStats(passenger: passenger),
                const SizedBox(height: 10),
                _PassengerActions(
                  isSaving: _isSaving,
                  onReport: () => _handleReport(passenger),
                ),
                const SizedBox(height: 12),
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
  final PassengerReviewProfile passenger;

  const _PassengerHero({required this.passenger});

  @override
  Widget build(BuildContext context) {
    return PublicProfileHeroCard(
      name: passenger.fullName,
      imageUrl: passenger.profileImageUrl,
      fallbackInitial: 'P',
      isVerified: passenger.isVerified,
      badges: <PublicProfileBadgeData>[
        PublicProfileBadgeData(
          label: passenger.roleLabel,
          foregroundColor: PassengerUi.accentBlue,
          backgroundColor: PassengerUi.blueSoft,
        ),
        PublicProfileBadgeData(
          label: passenger.isVerified ? 'Verified' : 'Pending verification',
          foregroundColor: passenger.isVerified
              ? PassengerUi.successText
              : PassengerUi.highlightAmber,
          backgroundColor: passenger.isVerified
              ? PassengerUi.successBackground
              : PassengerUi.warningSoft,
        ),
      ],
    );
  }
}

class _PassengerStats extends StatelessWidget {
  final PassengerReviewProfile passenger;

  const _PassengerStats({required this.passenger});

  @override
  Widget build(BuildContext context) {
    return PublicProfileStats(
      metrics: <PublicProfileMetricData>[
        PublicProfileMetricData(
          icon: Icons.star_rate_rounded,
          label: 'Rating',
          value: passenger.ratingLabel,
          color: PassengerUi.highlightAmber,
        ),
        PublicProfileMetricData(
          icon: Icons.reviews_outlined,
          label: 'Reviews',
          value: passenger.reviewCount.toString(),
          color: PassengerUi.accentBlue,
        ),
      ],
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
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: OutlinedButton.icon(
          onPressed: isSaving ? null : onReport,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: const Icon(Icons.report_gmailerrorred_rounded, size: 16),
          label: Text(isSaving ? 'Submitting' : 'Report'),
        ),
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
