enum NotificationDestination {
  conversation,
  driverQueue,
  ride,
  profile,
  adminUserReview,
  driverInfoHub,
  passengerVerification,
  details;

  String get actionLabel => switch (this) {
    NotificationDestination.conversation => 'Open conversation',
    NotificationDestination.driverQueue => 'View request',
    NotificationDestination.ride => 'View ride',
    NotificationDestination.profile => 'View profile',
    NotificationDestination.adminUserReview => 'Review update',
    NotificationDestination.driverInfoHub => 'Open Driver Info Hub',
    NotificationDestination.passengerVerification => 'View verification',
    NotificationDestination.details => 'View update',
  };
}

NotificationDestination resolveNotificationDestination({
  required Map<dynamic, dynamic> data,
  required String currentUserRole,
}) {
  String value(String key) => data[key]?.toString().trim() ?? '';

  final role = _normalizeRole(currentUserRole);
  final payloadRole = _normalizeRole(value('role'));
  final type = value('type').toLowerCase();
  final targetUserId = value('user_id').isNotEmpty
      ? value('user_id')
      : value('driver_id');

  if (value('conversation_id').isNotEmpty) {
    return NotificationDestination.conversation;
  }

  // Review payloads include their booking ID. Resolve the notification type
  // before the generic booking fallback so reviews open the profile content.
  if (type == 'review_received') {
    return NotificationDestination.profile;
  }

  if (<String>{
    'verification_request',
    'driver_renewal_submitted',
    'document_review_submitted',
    'driver_documents_expired_admin',
  }.contains(type)) {
    return _isAdminRole(role) && targetUserId.isNotEmpty
        ? NotificationDestination.adminUserReview
        : NotificationDestination.details;
  }

  if (<String>{
    'driver_documents_expiring',
    'driver_documents_expired',
    'driver_renewal_approved',
    'driver_renewal_rejected',
  }.contains(type)) {
    return NotificationDestination.driverInfoHub;
  }

  if (type == 'document_review_approved' ||
      type == 'document_review_rejected') {
    return (payloadRole.isEmpty ? role : payloadRole) == 'driver'
        ? NotificationDestination.driverInfoHub
        : NotificationDestination.passengerVerification;
  }

  if (<String>{
    'account_verified',
    'account_restricted',
    'account_deactivated',
    'account_restored',
  }.contains(type)) {
    return NotificationDestination.profile;
  }

  if (value('booking_id').isNotEmpty) {
    return type == 'booking_request' && role == 'driver'
        ? NotificationDestination.driverQueue
        : NotificationDestination.ride;
  }

  return NotificationDestination.details;
}

bool _isAdminRole(String role) => role == 'admin' || role == 'super_admin';

String _normalizeRole(String role) {
  final value = role.trim().toLowerCase().replaceAll(' ', '_');
  return value == 'superadmin' ? 'super_admin' : value;
}
