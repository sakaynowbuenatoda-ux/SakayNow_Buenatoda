import 'package:flutter/material.dart';

import '../../models/ride.dart';
import '../../pages/messages/chat_page.dart';
import '../../services/chat_service.dart';
import '../../services/ride_tracking_service.dart';
import '../../widgets/firebase_storage_image.dart';
import '../../widgets/passenger_widgets/passenger_ui.dart';
import '../../widgets/reviews/review_dialogs.dart';
import '../../widgets/reports/report_user_sheet.dart';
import 'models/profile_review_item.dart';
import 'widgets/profile_reviews_section.dart';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DriverHero(driver: driver),
                const SizedBox(height: 14),
                _DriverStats(driver: driver),
                SizedBox(height: showPassengerActions ? 14 : 18),
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
                  const SizedBox(height: 18),
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
                          if (!driver.isVerified)
                            PassengerStatusChip(
                              label: 'Pending verification',
                              textColor: PassengerUi.highlightAmber,
                              backgroundColor: PassengerUi.warningSoft,
                            ),
                          if (driver.isBanned)
                            PassengerStatusChip(
                              label: 'Restricted',
                              textColor: PassengerUi.primary,
                              backgroundColor: PassengerUi.dangerSoft,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _DriverRankingStrip(driver: driver),
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

class _DriverRankingStrip extends StatelessWidget {
  final DriverReviewProfile driver;

  const _DriverRankingStrip({required this.driver});

  @override
  Widget build(BuildContext context) {
    final ratingRank = driver.ratingRank;
    final hasTop20Rank =
        ratingRank != null && ratingRank >= 1 && ratingRank <= 20;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: PassengerUi.valueText.copyWith(fontSize: 11.5)),
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
    return PassengerSurfaceCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          ElevatedButton.icon(
            onPressed: isSaving ? null : onMessage,
            icon: const Icon(Icons.chat_bubble_rounded, size: 18),
            label: const Text('Message'),
          ),
          OutlinedButton.icon(
            onPressed: isSaving || isCheckingReview || !canAddReview
                ? null
                : onAddReview,
            icon: isCheckingReview
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    canAddReview
                        ? Icons.rate_review_rounded
                        : Icons.done_all_rounded,
                    size: 18,
                  ),
            label: Text(
              isCheckingReview
                  ? 'Checking'
                  : canAddReview
                  ? 'Add Review'
                  : 'No pending review',
            ),
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
