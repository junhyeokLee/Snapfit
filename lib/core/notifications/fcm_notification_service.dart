import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

class NotificationSettingsState {
  final bool all;
  final bool order;
  final bool invite;
  final bool comment;
  final bool marketing;
  final bool newTemplate;
  final bool nightMute;
  final bool permissionGranted;

  const NotificationSettingsState({
    required this.all,
    required this.order,
    required this.invite,
    required this.comment,
    required this.marketing,
    required this.newTemplate,
    required this.nightMute,
    required this.permissionGranted,
  });
}

class FcmNotificationService {
  FcmNotificationService._();

  static const String kAll = 'notify_all';
  static const String kOrder = 'notify_order';
  static const String kInvite = 'notify_invite';
  static const String kComment = 'notify_comment';
  static const String kMarketing = 'notify_marketing';
  static const String kNewTemplate = 'notify_new_template';
  static const String kNightMute = 'notify_night_mute';

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _localInitialized = false;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'snapfit_push',
        'SnapFit Push',
        description: 'SnapFit push notifications',
        importance: Importance.high,
      );

  static const Map<String, String> _topicByKey = {
    kOrder: 'snapfit_order_updates',
    kInvite: 'snapfit_invite_updates',
    kComment: 'snapfit_comment_updates',
    kMarketing: 'snapfit_marketing_updates',
    kNewTemplate: 'snapfit_template_new',
  };

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.setAutoInitEnabled(true);
    await _requestPermissionIfNeeded();
    await _initializeLocalNotifications();
    await _syncTopicsFromPrefs();

    final token = await _messaging.getToken();
    AppLogger.debug('[FCM] token: $token');

    FirebaseMessaging.onMessage.listen((message) {
      _showForegroundNotification(message);
      AppLogger.debug(
        '[FCM] onMessage title=${message.notification?.title} body=${message.notification?.body}',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      AppLogger.debug('[FCM] onMessageOpenedApp data=${message.data}');
    });
  }

  static Future<NotificationSettingsState> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final order = prefs.getBool(kOrder) ?? true;
    final invite = prefs.getBool(kInvite) ?? true;
    final comment = prefs.getBool(kComment) ?? true;
    final marketing = prefs.getBool(kMarketing) ?? false;
    final newTemplate = prefs.getBool(kNewTemplate) ?? true;
    final nightMute = prefs.getBool(kNightMute) ?? false;
    final all =
        prefs.getBool(kAll) ??
        (order && invite && comment && marketing && newTemplate);
    final permissionGranted = await isPermissionGranted();

    return NotificationSettingsState(
      all: all,
      order: order,
      invite: invite,
      comment: comment,
      marketing: marketing,
      newTemplate: newTemplate,
      nightMute: nightMute,
      permissionGranted: permissionGranted,
    );
  }

  static Future<bool> requestPermission() async {
    final settings = await _requestPermissionIfNeeded();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (granted) {
      await _syncTopicsFromPrefs();
    }
    return granted;
  }

  static Future<bool> isPermissionGranted() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<void> updateSettings({
    required bool all,
    required bool order,
    required bool invite,
    required bool comment,
    required bool marketing,
    required bool newTemplate,
    required bool nightMute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAll, all);
    await prefs.setBool(kOrder, order);
    await prefs.setBool(kInvite, invite);
    await prefs.setBool(kComment, comment);
    await prefs.setBool(kMarketing, marketing);
    await prefs.setBool(kNewTemplate, newTemplate);
    await prefs.setBool(kNightMute, nightMute);
    await _syncTopicsFromPrefs();
  }

  static Future<void> _syncTopicsFromPrefs() async {
    final granted = await isPermissionGranted();
    if (!granted) return;

    final prefs = await SharedPreferences.getInstance();
    for (final entry in _topicByKey.entries) {
      final enabled = prefs.getBool(entry.key) ?? (entry.key != kMarketing);
      if (enabled) {
        await _messaging.subscribeToTopic(entry.value);
      } else {
        await _messaging.unsubscribeFromTopic(entry.value);
      }
    }
  }

  static Future<NotificationSettings> _requestPermissionIfNeeded() async {
    final current = await _messaging.getNotificationSettings();
    if (current.authorizationStatus == AuthorizationStatus.authorized ||
        current.authorizationStatus == AuthorizationStatus.provisional) {
      return current;
    }

    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_localInitialized) return;
    _localInitialized = true;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString() ?? 'SnapFit';
    final body =
        message.notification?.body ??
        message.data['body']?.toString() ??
        '새 알림이 도착했어요.';

    const androidDetails = AndroidNotificationDetails(
      'snapfit_push',
      'SnapFit Push',
      channelDescription: 'SnapFit push notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data.toString(),
    );
  }
}
