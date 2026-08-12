import 'package:cloud_firestore/cloud_firestore.dart';

class LoginActivityEntry {
  final String id;
  final String userId;
  final DateTime? signedInAt;
  final String platform;
  final String authMethod;

  const LoginActivityEntry({
    required this.id,
    required this.userId,
    required this.signedInAt,
    required this.platform,
    required this.authMethod,
  });

  factory LoginActivityEntry.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return LoginActivityEntry.fromMap(
      document.data() ?? const <String, dynamic>{},
      document.id,
    );
  }

  factory LoginActivityEntry.fromMap(Map<String, dynamic> data, String id) {
    return LoginActivityEntry(
      id: id,
      userId: (data['user_id'] ?? '').toString(),
      signedInAt: _readDate(data['signed_in_at']),
      platform: (data['platform'] ?? 'unknown').toString().toLowerCase(),
      authMethod: (data['auth_method'] ?? 'password').toString().toLowerCase(),
    );
  }

  String get platformLabel => switch (platform) {
    'android' => 'Android device',
    'ios' => 'iPhone or iPad',
    'web' => 'Web browser',
    'windows' => 'Windows device',
    'macos' => 'Mac device',
    'linux' => 'Linux device',
    _ => 'Unknown device',
  };

  String get authMethodLabel => switch (authMethod) {
    'password' => 'Email and password',
    _ => 'Account authentication',
  };

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
