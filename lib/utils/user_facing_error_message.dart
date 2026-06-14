String userFacingErrorMessage(Object? error, {required String fallback}) {
  if (error == null) {
    return fallback;
  }

  final rawMessage = _cleanMessage(error);
  if (rawMessage.isEmpty) {
    return fallback;
  }

  final lowerMessage = rawMessage.toLowerCase();
  if (_looksLikeNetworkIssue(lowerMessage)) {
    return 'Network error. Check your connection and try again.';
  }

  if (_looksLikePermissionIssue(lowerMessage)) {
    return 'You do not have access to this information right now.';
  }

  if (_looksLikeMapSetupIssue(lowerMessage)) {
    return 'Map services are unavailable right now. Please try again later.';
  }

  if (_looksLikeTemporaryServiceIssue(lowerMessage)) {
    return 'The service is temporarily unavailable. Please try again.';
  }

  if (_looksTechnical(lowerMessage)) {
    return fallback;
  }

  return rawMessage;
}

String _cleanMessage(Object error) {
  var message = error is StateError ? error.message : error.toString();

  const prefixes = <String>[
    'Exception: ',
    'Bad state: ',
    'StateError: ',
    'PlatformException: ',
  ];

  for (final prefix in prefixes) {
    if (message.startsWith(prefix)) {
      message = message.substring(prefix.length);
      break;
    }
  }

  return message.trim();
}

bool _looksLikeNetworkIssue(String message) {
  return message.contains('network-request-failed') ||
      message.contains('network error') ||
      message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('connection failed');
}

bool _looksLikePermissionIssue(String message) {
  return message.contains('permission-denied') ||
      message.contains('permission denied') ||
      message.contains('denied access') ||
      message.contains('insufficient permissions');
}

bool _looksLikeMapSetupIssue(String message) {
  return message.contains('google maps javascript') ||
      message.contains('google places javascript') ||
      message.contains('google_services_api_key') ||
      message.contains('api key') ||
      message.contains('dart-define');
}

bool _looksLikeTemporaryServiceIssue(String message) {
  return message.contains('unavailable') ||
      message.contains('deadline-exceeded') ||
      message.contains('internal') ||
      message.contains('service unavailable');
}

bool _looksTechnical(String message) {
  return message.contains('firebase') ||
      message.contains('firestore') ||
      message.contains('cloud_firestore') ||
      message.contains('firebaseauth') ||
      message.contains('firebasefunctions') ||
      message.contains('stacktrace') ||
      message.contains('null check operator') ||
      message.contains('nosuchmethoderror') ||
      message.contains('typeerror') ||
      message.contains('goexception') ||
      message.contains('documentreference') ||
      message.contains('collectionreference') ||
      message.contains('googleapis');
}
