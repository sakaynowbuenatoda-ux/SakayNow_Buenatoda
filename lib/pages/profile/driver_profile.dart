import 'package:flutter/material.dart';

import '../../models/ride.dart';
import '../../pages/messages/chat_page.dart';
import '../../services/chat_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/reviews/review_dialogs.dart';
import '../../widgets/reports/report_user_sheet.dart';
import 'models/profile_review_item.dart';
import 'widgets/profile_reviews_section.dart';
import 'widgets/public_profile_components.dart';

class DriverProfilePage extends StatefulWidget {
  final String driverId;
  final String? passengerId;
  final String? bookingId;
  final bool openReviewOnLoad;

  const DriverProfilePage({
    super.key,
    required this.driverId,
    this.passengerId,
    this.bookingId,
    this.openReviewOnLoad = false,
  });

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  final RideTrackingService _rideTrackingService = RideTrackingService();
  bool _isSaving = false;
  bool _openedInitialReview = false;
  int _reviewEligibilityRefresh = 0;
  String? _pendingReviewFutureKey;
  Future<Ride?>? _pendingReviewFuture;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassengerUi.background,
      appBar: PublicProfileAppBar(
        title: 'Driver Profile',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: StreamBuilder<DriverReviewProfile>(
        stream: _rideTrackingService.watchDriverProfile(widget.driverId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppSkeletonProfile();
          }

          if (snapshot.hasError) {
            return PassengerPageContainer(
              child: PassengerEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load driver',
                description:
                    'Driver profile could not be loaded. Please try again.',
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

          _openInitialReviewIfNeeded(driver);
          final showPassengerActions = _hasPassengerContext;

          return PassengerPageContainer(
            maxContentWidth: PassengerUi.settingsContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DriverHero(driver: driver),
                const SizedBox(height: 10),
                _DriverStats(driver: driver),
                SizedBox(height: showPassengerActions ? 10 : 12),
                if (showPassengerActions) ...<Widget>[
                  FutureBuilder<Ride?>(
                    key: ValueKey(_reviewEligibilityRefresh),
                    future: _pendingReviewRideFutureFor(driver),
                    builder: (context, snapshot) {
                      final isCheckingReview =
                          snapshot.connectionState == ConnectionState.waiting;
                      final pendingReviewRide = snapshot.data;

                      return _DriverActions(
                        isSaving: _isSaving,
                        isCheckingReview: isCheckingReview,
                        canAddReview: pendingReviewRide != null,
                        onMessage: () => _handleMessage(driver),
                        onAddReview: pendingReviewRide == null
                            ? null
                            : () => _handleAddReview(
                                driver,
                                pendingReviewRide: pendingReviewRide,
                              ),
                        onReport: () => _handleReport(driver),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                _ReviewsPanel(
                  driver: driver,
                  rideTrackingService: _rideTrackingService,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String? get _passengerId {
    final passengerId = widget.passengerId?.trim();
    return passengerId == null || passengerId.isEmpty ? null : passengerId;
  }

  bool get _hasPassengerContext => _passengerId != null;

  Future<Ride?> _pendingReviewRideFutureFor(DriverReviewProfile driver) {
    final passengerId = _passengerId;
    if (passengerId == null) {
      return Future<Ride?>.value(null);
    }

    final key =
        '${driver.driverId}:$passengerId:${widget.bookingId ?? ''}:$_reviewEligibilityRefresh';
    if (_pendingReviewFutureKey != key) {
      _pendingReviewFutureKey = key;
      _pendingReviewFuture = _rideTrackingService
          .findPendingPassengerDriverReviewRide(
            passengerId: passengerId,
            driverId: driver.driverId,
            preferredBookingId: widget.bookingId,
          );
    }

    return _pendingReviewFuture!;
  }

  Future<void> _handleAddReview(
    DriverReviewProfile driver, {
    Ride? pendingReviewRide,
  }) async {
    final passengerId = _passengerId;
    if (passengerId == null) {
      _showSnackBar('Open this profile from a completed trip to add a review.');
      return;
    }

    final ride =
        pendingReviewRide ??
        await _rideTrackingService.findPendingPassengerDriverReviewRide(
          passengerId: passengerId,
          driverId: driver.driverId,
          preferredBookingId: widget.bookingId,
        );

    if (ride == null) {
      _showSnackBar('No completed ride is pending review for this driver.');
      return;
    }

    if (!mounted) {
      return;
    }

    final draft = await showPassengerDriverReviewDialog(
      context,
      driverName: driver.fullName,
    );
    if (draft == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _rideTrackingService.savePassengerDriverReview(
        bookingId: ride.bookingId,
        passengerId: passengerId,
        driverId: driver.driverId,
        rating: draft.rating,
        comment: draft.comment,
      );

      if (mounted) {
        setState(() => _reviewEligibilityRefresh++);
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

  Future<void> _handleMessage(DriverReviewProfile driver) async {
    final passengerId = _passengerId;
    final bookingId = widget.bookingId;
    if (passengerId == null || bookingId == null || bookingId.trim().isEmpty) {
      _showSnackBar('Open this profile from a trip to message the driver.');
      return;
    }

    try {
      final conversationId = await ChatService()
          .createRideConversationFromBooking(bookingId);
      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            currentUserId: passengerId,
            currentUserRole: 'passenger',
            title: driver.fullName,
            subtitle: 'Driver',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showSnackBar('Unable to open driver chat: $error');
      }
    }
  }

  void _openInitialReviewIfNeeded(DriverReviewProfile driver) {
    if (!_hasPassengerContext ||
        !widget.openReviewOnLoad ||
        _openedInitialReview) {
      return;
    }

    _openedInitialReview = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleAddReview(driver);
      }
    });
  }

  Future<void> _handleReport(DriverReviewProfile driver) async {
    final passengerId = _passengerId;
    final bookingId = widget.bookingId;
    if (passengerId == null || bookingId == null || bookingId.trim().isEmpty) {
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
        passengerId: passengerId,
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

  Future<UserReportDraft?> _showReportSheet(DriverReviewProfile driver) {
    return showUserReportSheet(
      context,
      title: 'Report ${driver.fullName}',
      reasons: _reportReasons,
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
  final DriverReviewProfile driver;

  const _DriverHero({required this.driver});

  @override
  Widget build(BuildContext context) {
    return PublicProfileHeroCard(
      name: driver.fullName,
      imageUrl: driver.profileImageUrl,
      fallbackInitial: 'D',
      isVerified: driver.isVerified,
      badges: <PublicProfileBadgeData>[
        PublicProfileBadgeData(
          label: 'Driver',
          foregroundColor: PassengerUi.primary,
          backgroundColor: PassengerUi.dangerSoft,
        ),
        if (!driver.isVerified)
          PublicProfileBadgeData(
            label: 'Pending verification',
            foregroundColor: PassengerUi.highlightAmber,
            backgroundColor: PassengerUi.warningSoft,
          ),
        if (driver.isBanned)
          PublicProfileBadgeData(
            label: 'Restricted',
            foregroundColor: PassengerUi.primary,
            backgroundColor: PassengerUi.dangerSoft,
          ),
      ],
      footer: _DriverRankingStrip(driver: driver),
    );
  }
}

class _DriverRankingStrip extends StatelessWidget {
  final DriverReviewProfile driver;

  const _DriverRankingStrip({required this.driver});

  @override
  Widget build(BuildContext context) {
    final ratingRank = driver.ratingRank;
    final hasTop20Rank =
        ratingRank != null && ratingRank >= 1 && ratingRank <= 20;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        if (hasTop20Rank)
          _MiniRankChip(
            icon: Icons.leaderboard_rounded,
            label: '#$ratingRank',
            color: PassengerUi.highlightAmber,
          ),
        _MiniRankChip(
          icon: Icons.trending_up_rounded,
          label: 'Rank Score ${driver.weightedRatingLabel}',
          color: PassengerUi.secondary,
        ),
      ],
    );
  }
}

class _MiniRankChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniRankChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: PassengerUi.valueText.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverStats extends StatelessWidget {
  final DriverReviewProfile driver;

  const _DriverStats({required this.driver});

  @override
  Widget build(BuildContext context) {
    return PublicProfileStats(
      metrics: <PublicProfileMetricData>[
        PublicProfileMetricData(
          icon: Icons.star_rate_rounded,
          label: 'Rating',
          value: driver.ratingLabel,
          color: PassengerUi.highlightAmber,
        ),
        PublicProfileMetricData(
          icon: Icons.reviews_outlined,
          label: 'Reviews',
          value: driver.reviewCount.toString(),
          color: PassengerUi.accentBlue,
        ),
      ],
    );
  }
}

class _DriverActions extends StatelessWidget {
  final bool isSaving;
  final bool isCheckingReview;
  final bool canAddReview;
  final VoidCallback onMessage;
  final VoidCallback? onAddReview;
  final VoidCallback onReport;

  const _DriverActions({
    required this.isSaving,
    required this.isCheckingReview,
    required this.canAddReview,
    required this.onMessage,
    required this.onAddReview,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final messageButton = _ProfileActionButton(
      child: ElevatedButton.icon(
        onPressed: isSaving ? null : onMessage,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.chat_bubble_rounded, size: 16),
        label: const Text('Message'),
      ),
    );
    final reviewButton = _ProfileActionButton(
      child: OutlinedButton.icon(
        onPressed: isSaving || isCheckingReview || !canAddReview
            ? null
            : onAddReview,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        icon: isCheckingReview
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                canAddReview
                    ? Icons.rate_review_rounded
                    : Icons.done_all_rounded,
                size: 16,
              ),
        label: Text(
          isCheckingReview
              ? 'Checking'
              : canAddReview
              ? 'Add Review'
              : 'No pending review',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    final reportButton = _ProfileActionButton(
      child: OutlinedButton.icon(
        onPressed: isSaving ? null : onReport,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.report_gmailerrorred_rounded, size: 16),
        label: const Text('Report'),
      ),
    );

    return PassengerSurfaceCard(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            return Row(
              children: <Widget>[
                Expanded(child: messageButton),
                const SizedBox(width: 8),
                Expanded(child: reviewButton),
                const SizedBox(width: 8),
                Expanded(child: reportButton),
              ],
            );
          }

          if (constraints.maxWidth >= 390) {
            return Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: messageButton),
                    const SizedBox(width: 8),
                    Expanded(child: reviewButton),
                  ],
                ),
                const SizedBox(height: 8),
                reportButton,
              ],
            );
          }

          return Column(
            children: <Widget>[
              messageButton,
              const SizedBox(height: 8),
              reviewButton,
              const SizedBox(height: 8),
              reportButton,
            ],
          );
        },
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  final Widget child;

  const _ProfileActionButton({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity, height: 40, child: child);
  }
}

class _ReviewsPanel extends StatelessWidget {
  final DriverReviewProfile driver;
  final RideTrackingService rideTrackingService;

  const _ReviewsPanel({
    required this.driver,
    required this.rideTrackingService,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileReviewsPreview(
      title: 'Recent Reviews',
      profileName: driver.fullName,
      emptyDescription: 'Passenger reviews will appear here.',
      reviewsLoader: () => rideTrackingService
          .watchDriverReviews(driver.driverId)
          .map(
            (reviews) => reviews
                .map(ProfileReviewItem.fromRideReview)
                .toList(growable: false),
          ),
    );
  }
}
