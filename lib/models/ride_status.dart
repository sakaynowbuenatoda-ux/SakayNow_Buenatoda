enum RideStatus {
  searching,
  accepted,
  driverArriving,
  arrived,
  inProgress,
  completed,
  cancelled,
}

extension RideStatusX on RideStatus {
  String get firestoreValue {
    switch (this) {
      case RideStatus.searching:
        return 'searching';
      case RideStatus.accepted:
        return 'accepted';
      case RideStatus.driverArriving:
        return 'driver_arriving';
      case RideStatus.arrived:
        return 'arrived';
      case RideStatus.inProgress:
        return 'in_progress';
      case RideStatus.completed:
        return 'completed';
      case RideStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case RideStatus.searching:
        return 'Searching';
      case RideStatus.accepted:
        return 'Accepted';
      case RideStatus.driverArriving:
        return 'Driver arriving';
      case RideStatus.arrived:
        return 'Arrived';
      case RideStatus.inProgress:
        return 'In progress';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isTerminal =>
      this == RideStatus.completed || this == RideStatus.cancelled;

  bool canMoveTo(RideStatus next) {
    if (isTerminal) {
      return false;
    }

    return switch (this) {
      RideStatus.searching =>
        next == RideStatus.accepted || next == RideStatus.cancelled,
      RideStatus.accepted =>
        next == RideStatus.driverArriving || next == RideStatus.cancelled,
      RideStatus.driverArriving =>
        next == RideStatus.arrived || next == RideStatus.cancelled,
      RideStatus.arrived =>
        next == RideStatus.inProgress || next == RideStatus.cancelled,
      RideStatus.inProgress =>
        next == RideStatus.completed || next == RideStatus.cancelled,
      RideStatus.completed || RideStatus.cancelled => false,
    };
  }
}

RideStatus rideStatusFromString(Object? value) {
  final normalized = (value ?? '')
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');

  switch (normalized) {
    case 'accepted':
    case 'assigned':
      return RideStatus.accepted;
    case 'driver_arriving':
      return RideStatus.driverArriving;
    case 'arrived':
      return RideStatus.arrived;
    case 'in_progress':
    case 'ongoing':
      return RideStatus.inProgress;
    case 'completed':
      return RideStatus.completed;
    case 'cancelled':
    case 'canceled':
    case 'rejected':
      return RideStatus.cancelled;
    case 'searching':
    case 'pending':
    case 'queued':
    case 'new':
    default:
      return RideStatus.searching;
  }
}
