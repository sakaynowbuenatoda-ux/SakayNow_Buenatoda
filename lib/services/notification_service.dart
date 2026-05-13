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

import '../firebase_options.dart';
import '../pages/messages/chat_page.dart';

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

  static const String _messageChannelId = 'sakaynow_messages';
  static const AndroidNotificationChannel _androidMessageChannel =
      AndroidNotificationChannel(
        _messageChannelId,
        'Messages',
        description: 'Ride and support message notifications',
        importance: Importance.high,
      );

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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
      await _requestNotificationPermissions();

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
    await androidPlugin?.createNotificationChannel(_androidMessageChannel);
  }

  Future<void> _requestNotificationPermissions() async {
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

    await _localNotifications.show(
      id: _notificationId(message),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _messageChannelId,
          'Messages',
          channelDescription: 'Ride and support message notifications',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
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

  Future<void> _handleNotificationData(Map<dynamic, dynamic> data) async {
    final conversationId = data['conversation_id']?.toString().trim() ?? '';
    if (conversationId.isEmpty) {
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role')?.trim().toLowerCase() ?? 'passenger';
    final title = data['title']?.toString().trim();
    final conversationType = data['conversation_type']?.toString().trim();
    final subtitle = conversationType == 'support'
        ? (role == 'admin' ? 'Support request' : 'Admin')
        : 'Ride chat';

    _pushChatWhenNavigatorIsReady(
      conversationId: conversationId,
      currentUserId: currentUser.uid,
      currentUserRole: role,
      title: title?.isNotEmpty == true ? title! : 'Messages',
      subtitle: subtitle,
    );
  }

  void _pushChatWhenNavigatorIsReady({
    required String conversationId,
    required String currentUserId,
    required String currentUserRole,
    required String title,
    required String subtitle,
    int attempt = 0,
  }) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
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
          attempt: attempt + 1,
        );
      });
      return;
    }

    navigator.push(
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
