import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/ride_tracking_controller.dart';
import '../firebase_options.dart';
import '../models/app_notification.dart';
import '../models/notification_preferences.dart';
import '../models/notification_sound_profile.dart';
import '../pages/admin/admin_user_review_page.dart';
import '../core/session/user_roles.dart';
import '../pages/driver/driver_queue.dart';
import '../pages/messages/chat_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/rides/ride_monitoring_page.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _accountChannelId = 'sakaynow_account';
  static const String _bookingChannelId = 'sakaynow_bookings';
  static const String _messageChannelId = 'sakaynow_messages';
  static const String _systemChannelId = 'sakaynow_system';
  static const String _prefsPushEnabledKey = 'notifications_push_enabled';
  static const String _prefsBookingKey = 'notifications_booking_updates';
  static const String _prefsMessagesKey = 'notifications_message_updates';
  static const String _prefsAccountKey = 'notifications_account_updates';
  static const String _prefsSystemKey = 'notifications_system_updates';
  static const List<AndroidNotificationChannel> _androidChannels =
      <AndroidNotificationChannel>[
        AndroidNotificationChannel(
          _accountChannelId,
          'Account alerts',
          description: 'Verification and account access notifications',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          _bookingChannelId,
          'Bookings',
          description: 'Ride booking and trip status notifications',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          _messageChannelId,
          'Messages',
          description: 'Ride and support message notifications',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          _systemChannelId,
          'System updates',
          description: 'Reviews, admin, and general app notifications',
          importance: Importance.defaultImportance,
        ),
        AndroidNotificationChannel(
          NotificationSoundProfile.messageChannelId,
          'Messages with sound',
          description:
              'Ride chat and support messages with the SakayNow message sound',
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound(
            NotificationSoundProfile.messageSoundResource,
          ),
        ),
        AndroidNotificationChannel(
          NotificationSoundProfile.bookingAcceptedChannelId,
          'Booking accepted alerts',
          description: 'Passenger alerts when a driver accepts a booking',
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound(
            NotificationSoundProfile.bookingAcceptedSoundResource,
          ),
        ),
        AndroidNotificationChannel(
          NotificationSoundProfile.driverArrivedChannelId,
          'Driver arrival alerts',
          description:
              'Passenger alerts when the assigned driver reaches pickup',
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound(
            NotificationSoundProfile.driverArrivedSoundResource,
          ),
        ),
        AndroidNotificationChannel(
          NotificationSoundProfile.bookingRequestChannelId,
          'Driver booking requests',
          description: 'New ride requests sent to available drivers',
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound(
            NotificationSoundProfile.bookingRequestSoundResource,
          ),
        ),
      ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  bool _initialized = false;

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    try {
      await _initializeLocalNotifications();
      final preferences = await loadNotificationPreferences(
        preferRemote: false,
      );
      if (preferences.pushEnabled) {
        await requestNotificationPermissions();
      }

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
      _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleRemoteMessageTap,
      );

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        unawaited(_handleRemoteMessageTap(initialMessage));
      }

      _authSubscription = _auth.authStateChanges().listen((user) {
        if (user == null) {
          return;
        }

        unawaited(syncCurrentToken());
      });
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((_) {
        unawaited(syncCurrentToken());
      });

      if (_auth.currentUser != null) {
        await syncCurrentToken();
      }
    } on Exception {
      _initialized = false;
    }
  }

  Future<void> syncCurrentToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final preferences = await loadNotificationPreferences(userId: user.uid);
      if (!preferences.pushEnabled) {
        await unregisterCurrentDevice();
        return;
      }

      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }

      final tokensRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcm_tokens');
      final existing = await tokensRef
          .where('token', isEqualTo: token)
          .limit(1)
          .get();
      final tokenRef = existing.docs.isEmpty
          ? tokensRef.doc()
          : existing.docs.first.reference;

      await tokenRef.set(<String, dynamic>{
        if (existing.docs.isEmpty) 'created_at': FieldValue.serverTimestamp(),
        'token': token,
        'user_id': user.uid,
        'platform': _platformLabel,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on Exception {
      // Token sync should never block app startup or login.
    }
  }

  Future<NotificationPreferences> loadNotificationPreferences({
    String? userId,
    bool preferRemote = true,
  }) async {
    final localPreferences = await _readLocalNotificationPreferences();
    final resolvedUserId = userId ?? _auth.currentUser?.uid;
    if (!preferRemote || resolvedUserId == null || resolvedUserId.isEmpty) {
      return localPreferences;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(resolvedUserId)
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final remotePreferences = data['notification_preferences'] is Map
          ? NotificationPreferences.fromMap(
              Map<String, dynamic>.from(
                data['notification_preferences'] as Map,
              ),
            )
          : localPreferences;
      await _cacheNotificationPreferences(remotePreferences);
      return remotePreferences;
    } on Exception {
      return localPreferences;
    }
  }

  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences, {
    String? userId,
  }) async {
    final resolvedUserId = userId ?? _auth.currentUser?.uid;
    if (resolvedUserId != null && resolvedUserId.isNotEmpty) {
      await _firestore
          .collection('users')
          .doc(resolvedUserId)
          .set(<String, dynamic>{
            'notification_preferences': preferences.toMap(),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }

    await _cacheNotificationPreferences(preferences);

    if (preferences.pushEnabled) {
      await requestNotificationPermissions();
      await syncCurrentToken();
    } else {
      await unregisterCurrentDevice();
    }
  }

  Future<void> unregisterCurrentDevice() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fcm_tokens')
          .where('token', isEqualTo: token)
          .get();

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    } on Exception {
      // Continue logout even if token cleanup cannot finish.
    }
  }

  Stream<List<AppNotification>> watchNotifications(
    String userId, {
    int limit = 80,
  }) {
    return _notifications
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AppNotification.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<int> watchUnreadCount(String userId) {
    return _notifications
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Future<void> markNotificationRead(String notificationId) async {
    final trimmedId = notificationId.trim();
    if (trimmedId.isEmpty) {
      return;
    }

    await _notifications.doc(trimmedId).update(<String, dynamic>{
      'is_read': true,
      'read_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllNotificationsRead(String userId) async {
    while (true) {
      final snapshot = await _notifications
          .where('user_id', isEqualTo: userId)
          .where('is_read', isEqualTo: false)
          .limit(400)
          .get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.update(document.reference, <String, dynamic>{
          'is_read': true,
          'read_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (snapshot.docs.length < 400) {
        return;
      }
    }
  }

  Future<void> openNotification(
    AppNotification notification, {
    BuildContext? context,
  }) async {
    final navigator = context == null ? null : Navigator.maybeOf(context);
    if (!notification.isRead) {
      await markNotificationRead(notification.id);
    }

    await _handleNotificationData(<String, String>{
      ...notification.data,
      'notification_id': notification.id,
      'type': notification.type,
      'channel': notification.channel,
      'title': notification.title,
      'body': notification.body,
    }, navigator: navigator);
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _openedMessageSubscription?.cancel();
    _initialized = false;
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('ic_stat_sakaynow');
    const iosSettings = DarwinInitializationSettings();
    const macOsSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macOsSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.trim().isEmpty) {
          return;
        }

        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          unawaited(_handleNotificationData(decoded));
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final channel in _androidChannels) {
      await androidPlugin?.createNotificationChannel(channel);
    }
  }

  Future<void> requestNotificationPermissions() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title']?.toString() ?? 'SakayNow';
    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        'You have a new update.';
    final payloadData = <String, String>{
      ...message.data.map((key, value) => MapEntry(key, value.toString())),
      'title': title,
      'body': body,
    };
    final channel = _channelForPayload(payloadData);
    final soundProfile = NotificationSoundProfile.fromPayload(payloadData);
    final preferences = await loadNotificationPreferences(preferRemote: false);
    if (!preferences.allowsChannel(channel)) {
      return;
    }

    final customAndroidChannelId = soundProfile.androidChannelId;
    final customAndroidSound = soundProfile.androidSoundResource;

    await _localNotifications.show(
      id: _notificationId(message),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          customAndroidChannelId ?? _androidChannelId(channel),
          soundProfile.usesCustomSound
              ? soundProfile.androidChannelName
              : _androidChannelName(channel),
          channelDescription: soundProfile.usesCustomSound
              ? soundProfile.androidChannelDescription
              : _androidChannelDescription(channel),
          importance: Importance.high,
          priority: Priority.high,
          sound: customAndroidSound == null
              ? null
              : RawResourceAndroidNotificationSound(customAndroidSound),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: soundProfile.appleSoundFile,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(payloadData),
    );
  }

  Future<void> _handleRemoteMessageTap(RemoteMessage message) {
    final payload = <String, String>{
      ...message.data.map((key, value) => MapEntry(key, value.toString())),
      if (message.notification?.title != null)
        'title': message.notification!.title!,
      if (message.notification?.body != null)
        'body': message.notification!.body!,
    };

    return _handleNotificationData(payload);
  }

  Future<void> _handleNotificationData(
    Map<dynamic, dynamic> data, {
    NavigatorState? navigator,
  }) async {
    final conversationId = data['conversation_id']?.toString().trim() ?? '';
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role')?.trim().toLowerCase() ?? 'passenger';

    if (conversationId.isEmpty) {
      _routeNonChatNotification(
        data: data,
        currentUserId: currentUser.uid,
        currentUserRole: role,
        navigator: navigator,
      );
      return;
    }

    final title = data['title']?.toString().trim();
    final conversationType = data['conversation_type']?.toString().trim();
    final subtitle = switch (conversationType) {
      'support' => isAdminStaffRole(role) ? 'Support request' : 'Admin',
      'admin_direct' => 'Admin staff',
      _ => 'Ride chat',
    };

    _pushChatWhenNavigatorIsReady(
      conversationId: conversationId,
      currentUserId: currentUser.uid,
      currentUserRole: role,
      title: title?.isNotEmpty == true ? title! : 'Messages',
      subtitle: subtitle,
      navigator: navigator,
    );
  }

  void _pushChatWhenNavigatorIsReady({
    required String conversationId,
    required String currentUserId,
    required String currentUserRole,
    required String title,
    required String subtitle,
    NavigatorState? navigator,
    int attempt = 0,
  }) {
    final resolvedNavigator = navigator?.mounted == true
        ? navigator
        : navigatorKey.currentState;
    if (resolvedNavigator == null) {
      if (attempt >= 12) {
        return;
      }

      Future<void>.delayed(const Duration(milliseconds: 250), () {
        _pushChatWhenNavigatorIsReady(
          conversationId: conversationId,
          currentUserId: currentUserId,
          currentUserRole: currentUserRole,
          title: title,
          subtitle: subtitle,
          navigator: navigator,
          attempt: attempt + 1,
        );
      });
      return;
    }

    resolvedNavigator.push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          currentUserId: currentUserId,
          currentUserRole: currentUserRole,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }

  void _routeNonChatNotification({
    required Map<dynamic, dynamic> data,
    required String currentUserId,
    required String currentUserRole,
    NavigatorState? navigator,
  }) {
    final type = data['type']?.toString().trim().toLowerCase() ?? '';
    final bookingId = data['booking_id']?.toString().trim() ?? '';
    if (bookingId.isNotEmpty) {
      if (type == 'booking_request' && currentUserRole == 'driver') {
        _pushPageWhenNavigatorIsReady(
          navigator: navigator,
          builder: (_) => DriverQueuePage(
            driverId: currentUserId,
            isVerified: true,
            isActive: true,
          ),
        );
        return;
      }

      final viewerRole = currentUserRole == 'driver'
          ? RideViewerRole.driver
          : RideViewerRole.passenger;
      _pushPageWhenNavigatorIsReady(
        navigator: navigator,
        builder: (_) => RideMonitoringPage(
          bookingId: bookingId,
          userId: currentUserId,
          viewerRole: viewerRole,
        ),
      );
      return;
    }

    if (type == 'review_received') {
      _pushPageWhenNavigatorIsReady(
        navigator: navigator,
        builder: (_) => ProfilePage(userId: currentUserId),
      );
      return;
    }

    if (type == 'verification_request' && isAdminStaffRole(currentUserRole)) {
      final userId = data['user_id']?.toString().trim() ?? '';
      if (userId.isNotEmpty) {
        _pushPageWhenNavigatorIsReady(
          navigator: navigator,
          builder: (_) =>
              AdminUserReviewPage(userId: userId, adminId: currentUserId),
        );
      }
    }
  }

  void _pushPageWhenNavigatorIsReady({
    required WidgetBuilder builder,
    NavigatorState? navigator,
    int attempt = 0,
  }) {
    final resolvedNavigator = navigator?.mounted == true
        ? navigator
        : navigatorKey.currentState;
    if (resolvedNavigator == null) {
      if (attempt >= 12) {
        return;
      }

      Future<void>.delayed(const Duration(milliseconds: 250), () {
        _pushPageWhenNavigatorIsReady(
          builder: builder,
          navigator: navigator,
          attempt: attempt + 1,
        );
      });
      return;
    }

    resolvedNavigator.push(MaterialPageRoute(builder: builder));
  }

  String _channelForPayload(Map<String, String> data) {
    final channel = data['channel']?.trim().toLowerCase();
    if (channel == 'account' ||
        channel == 'booking' ||
        channel == 'review' ||
        channel == 'system') {
      return channel!;
    }

    final type = data['type']?.trim().toLowerCase() ?? '';
    if (type.startsWith('booking_') ||
        type.startsWith('driver_') ||
        type.startsWith('ride_')) {
      return 'booking';
    }

    if (type.startsWith('account_')) {
      return 'account';
    }

    if (type == 'chat_message') {
      return 'message';
    }

    return 'system';
  }

  String _androidChannelId(String channel) {
    return switch (channel) {
      'account' => _accountChannelId,
      'booking' => _bookingChannelId,
      'message' => _messageChannelId,
      _ => _systemChannelId,
    };
  }

  String _androidChannelName(String channel) {
    return switch (channel) {
      'account' => 'Account alerts',
      'booking' => 'Bookings',
      'message' => 'Messages',
      _ => 'System updates',
    };
  }

  String _androidChannelDescription(String channel) {
    return switch (channel) {
      'account' => 'Verification and account access notifications',
      'booking' => 'Ride booking and trip status notifications',
      'message' => 'Ride and support message notifications',
      _ => 'Reviews, admin, and general app notifications',
    };
  }

  Future<NotificationPreferences> _readLocalNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      pushEnabled: prefs.getBool(_prefsPushEnabledKey) ?? true,
      bookingUpdatesEnabled: prefs.getBool(_prefsBookingKey) ?? true,
      messageUpdatesEnabled: prefs.getBool(_prefsMessagesKey) ?? true,
      accountUpdatesEnabled: prefs.getBool(_prefsAccountKey) ?? true,
      systemUpdatesEnabled: prefs.getBool(_prefsSystemKey) ?? true,
    );
  }

  Future<void> _cacheNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsPushEnabledKey, preferences.pushEnabled);
    await prefs.setBool(_prefsBookingKey, preferences.bookingUpdatesEnabled);
    await prefs.setBool(_prefsMessagesKey, preferences.messageUpdatesEnabled);
    await prefs.setBool(_prefsAccountKey, preferences.accountUpdatesEnabled);
    await prefs.setBool(_prefsSystemKey, preferences.systemUpdatesEnabled);
  }

  int _notificationId(RemoteMessage message) {
    final id = message.messageId;
    if (id != null && id.isNotEmpty) {
      return id.hashCode & 0x7fffffff;
    }

    return DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff);
  }

  String get _platformLabel {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
