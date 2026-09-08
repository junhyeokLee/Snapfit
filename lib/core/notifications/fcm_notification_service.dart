import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_logger.dart';
import 'notification_policy.dart';

class NotificationSettingsState {
  final bool all, order, invite, comment, marketing, newTemplate, nightMute;
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

typedef NotificationTapHandler =
    Future<void> Function(Map<String, dynamic> data);

/// Registers authenticated installations only. FCM outages never prevent app startup.
class FcmNotificationService {
  FcmNotificationService._();
  static const kAll = 'notify_all',
      kOrder = 'notify_order',
      kInvite = 'notify_invite',
      kComment = 'notify_comment',
      kMarketing = 'notify_marketing',
      kNewTemplate = 'notify_new_template',
      kNightMute = 'notify_night_mute';
  static const _columns = {
    kAll: 'all_enabled',
    kOrder: 'order_enabled',
    kInvite: 'invite_enabled',
    kComment: 'comment_enabled',
    kMarketing: 'marketing_enabled',
    kNewTemplate: 'new_template_enabled',
    kNightMute: 'night_mute',
  };
  static const _legacyTopics = [
    'snapfit_order_updates',
    'snapfit_invite_updates',
    'snapfit_comment_updates',
    'snapfit_marketing_updates',
    'snapfit_template_new',
  ];
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static SupabaseClient get _client => Supabase.instance.client;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static final _observer = _PushLifecycleObserver();
  static bool _initialized = false,
      _localInitialized = false,
      _signingOut = false;
  static Future<void>? _syncFuture;
  @visibleForTesting
  static void Function(Object, StackTrace)? onRegistrationErrorForTesting;
  static Timer? _retry;
  static int _retryCount = 0, _generation = 0;
  static String? _registeredToken, _preferencesUser, _lastRegistrationSignature;
  static DateTime? _lastRegisteredAt;
  static Future<void> _preferenceWrites = Future.value();
  static final _preferenceVersions = <String, int>{};
  static NotificationTapHandler? _onTap;
  static Map<String, dynamic>? _pendingTap;
  static final _received = StreamController<void>.broadcast();
  static Stream<void> get onNotificationReceived => _received.stream;
  static const _timeout = Duration(seconds: 10);
  static const _channel = AndroidNotificationChannel(
    'snapfit_push',
    'SnapFit 알림',
    description: '주문, 공유 앨범 및 새 템플릿 알림',
    importance: Importance.high,
  );

  static Future<void> initialize({
    NotificationTapHandler? onNotificationTap,
  }) async {
    _onTap = onNotificationTap ?? _onTap;
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addObserver(_observer);
      FirebaseMessaging.onMessage.listen((message) {
        unawaited(_receive(message));
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        unawaited(openNotification(message.data));
      });
      _messaging.onTokenRefresh.listen(
        (_) => unawaited(syncSession()),
        onError: (_) => _scheduleRetry(),
      );
      _client.auth.onAuthStateChange.listen((state) {
        _generation++;
        _preferencesUser = null;
        if (state.session == null) {
          _signingOut = true;
          _pendingTap = null;
          _retry?.cancel();
          unawaited(_localNotifications.cancelAll().catchError((_) {}));
        } else {
          _signingOut = false;
          final pending = _pendingTap;
          if (pending != null) unawaited(openNotification(pending));
          unawaited(syncSession());
        }
      });
      unawaited(_readLaunchNotification());
    }
    // Errors are handled inside syncSession; callers need not await network work.
    unawaited(syncSession());
  }

  static Future<void> _readLaunchNotification() async {
    try {
      await _initializeLocalNotifications();
      final initial = await _messaging.getInitialMessage();
      if (initial != null) await openNotification(initial.data);
      final local = await _localNotifications.getNotificationAppLaunchDetails();
      if (local?.didNotificationLaunchApp == true) {
        await _openPayload(local?.notificationResponse?.payload);
      }
    } catch (_) {
      AppLogger.debug('[FCM] launch notification unavailable');
    }
  }

  static Future<void> syncSession() {
    if (_syncFuture != null) return _syncFuture!;
    final generation = _generation;
    return _syncFuture = _sync(generation)
        .catchError((Object error, StackTrace stack) {
          onRegistrationErrorForTesting?.call(error, stack);
          AppLogger.debug('[FCM] registration deferred (${error.runtimeType})');
          _scheduleRetry();
        })
        .whenComplete(() {
          _syncFuture = null;
          if (generation != _generation && !_signingOut)
            unawaited(syncSession());
        });
  }

  static bool _current(String userId, int generation) =>
      !_signingOut &&
      generation == _generation &&
      _client.auth.currentUser?.id == userId;

  static Future<void> _sync(int generation) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || _signingOut || kIsWeb) return;
    await _initializeLocalNotifications();
    if (!_current(userId, generation)) return;
    await _syncPreferences(userId);
    if (!_current(userId, generation)) return;
    final permissionPrefs = await SharedPreferences.getInstance();
    if (!(permissionPrefs.getBool('push_permission_requested') ?? false)) {
      await permissionPrefs.setBool('push_permission_requested', true);
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    }
    if (!_current(userId, generation)) return;
    // APNs registration is asynchronous, even after the permission prompt closes.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      if (await _messaging.getAPNSToken().timeout(_timeout) == null) {
        throw StateError('APNs registration pending');
      }
    }
    await _messaging.setAutoInitEnabled(true);
    // Remove obsolete global subscriptions before any account receives private events.
    for (final topic in _legacyTopics) {
      await _messaging.unsubscribeFromTopic(topic).timeout(_timeout);
      if (!_current(userId, generation)) return;
    }
    final granted = await isPermissionGranted();
    final token = await _messaging.getToken().timeout(_timeout);
    if (!_current(userId, generation) || token == null || token.isEmpty) return;
    final signature =
        '$userId:$token:$granted:${DateTime.now().timeZoneOffset.inMinutes}';
    final recent =
        _lastRegisteredAt != null &&
        DateTime.now().difference(_lastRegisteredAt!) <
            const Duration(hours: 1);
    if (signature == _lastRegistrationSignature && recent) {
      _retry?.cancel();
      final pending = _pendingTap;
      if (pending != null) await openNotification(pending);
      return;
    }
    await _client
        .rpc(
          'register_push_device',
          params: {
            'p_token': token,
            'p_platform': defaultTargetPlatform.name,
            'p_timezone_offset_minutes':
                DateTime.now().timeZoneOffset.inMinutes,
            'p_enabled': granted,
          },
        )
        .timeout(_timeout);
    if (!_current(userId, generation)) {
      // Logout waits for this operation before its authenticated unregister call.
      return;
    }
    if (_registeredToken != null && _registeredToken != token) {
      await _client
          .from('push_devices')
          .delete()
          .eq('token', _registeredToken!)
          .eq('user_id', userId);
    }
    _registeredToken = token;
    _lastRegistrationSignature = signature;
    _lastRegisteredAt = DateTime.now();
    _retryCount = 0;
    _retry?.cancel();
    AppLogger.debug('[FCM] token registered=true');
    final pending = _pendingTap;
    if (pending != null) await openNotification(pending);
  }

  static void _scheduleRetry() {
    if (_signingOut || _client.auth.currentUser == null) return;
    _retry?.cancel();
    final seconds = [2, 5, 15, 30, 60, 300][_retryCount.clamp(0, 5)];
    _retryCount++;
    _retry = Timer(Duration(seconds: seconds), () => unawaited(syncSession()));
  }

  static Future<void> _syncPreferences(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final dirty = prefs.getBool('push_prefs_dirty_$userId') ?? false;
    if (_preferencesUser != userId && !dirty) {
      final version = _preferenceVersions[userId] ?? 0;
      final row = await _client
          .from('push_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(_timeout);
      if ((_preferenceVersions[userId] ?? 0) != version ||
          (prefs.getBool('push_prefs_dirty_$userId') ?? false)) {
        await _saveRemotePrefs(prefs, userId);
        return;
      }
      for (final entry in _columns.entries) {
        await prefs.setBool(
          '${entry.key}_$userId',
          row?[entry.value] as bool? ?? _default(entry.key),
        );
      }
      _preferencesUser = userId;
    }
    if (dirty) await _saveRemotePrefs(prefs, userId);
  }

  static bool _default(String key) => key != kMarketing && key != kNightMute;
  static String _prefKey(String key, String? userId) =>
      '${key}_${userId ?? 'signed_out'}';

  static Future<NotificationSettingsState> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _client.auth.currentUser?.id;
    bool read(String key) =>
        prefs.getBool(_prefKey(key, userId)) ?? _default(key);
    return NotificationSettingsState(
      all: read(kAll),
      order: read(kOrder),
      invite: read(kInvite),
      comment: read(kComment),
      marketing: read(kMarketing),
      newTemplate: read(kNewTemplate),
      nightMute: read(kNightMute),
      permissionGranted: await isPermissionGranted(),
    );
  }

  static Future<bool> isPermissionGranted() async {
    if (kIsWeb) return false;
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<bool> requestPermission() async {
    final current = await _messaging.getNotificationSettings();
    final prefs = await SharedPreferences.getInstance();
    if (current.authorizationStatus == AuthorizationStatus.denied &&
        (prefs.getBool('push_permission_requested') ?? false)) {
      await permissions.openAppSettings();
      return false; // Rechecked when the app resumes.
    }
    await prefs.setBool('push_permission_requested', true);
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    unawaited(syncSession());
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
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    _preferenceVersions[userId] = (_preferenceVersions[userId] ?? 0) + 1;
    final values = {
      kAll: all,
      kOrder: order,
      kInvite: invite,
      kComment: comment,
      kMarketing: marketing,
      kNewTemplate: newTemplate,
      kNightMute: nightMute,
    };
    for (final entry in values.entries) {
      await prefs.setBool(_prefKey(entry.key, userId), entry.value);
    }
    await prefs.setBool('push_prefs_dirty_$userId', true);
    try {
      await _saveRemotePrefs(prefs, userId);
    } catch (_) {
      _scheduleRetry();
      rethrow;
    }
  }

  static Future<void> _saveRemotePrefs(SharedPreferences prefs, String userId) {
    return _preferenceWrites = _preferenceWrites.catchError((_) {}).then((
      _,
    ) async {
      final version = _preferenceVersions[userId] ?? 0;
      await _client
          .from('push_preferences')
          .upsert({
            'user_id': userId,
            for (final entry in _columns.entries)
              entry.value:
                  prefs.getBool(_prefKey(entry.key, userId)) ??
                  _default(entry.key),
          })
          .timeout(_timeout);
      if ((_preferenceVersions[userId] ?? 0) == version) {
        await prefs.setBool('push_prefs_dirty_$userId', false);
      }
    });
  }

  static Future<void> clearDevicePushState() async {
    _signingOut = true;
    _generation++;
    _retry?.cancel();
    final userId = _client.auth.currentUser?.id;
    // Drain in-flight registration before signing out, so it cannot restore a stale binding.
    try {
      await _syncFuture?.timeout(const Duration(seconds: 12));
    } catch (_) {}
    try {
      final token =
          _registeredToken ?? await _messaging.getToken().timeout(_timeout);
      if (userId != null && token != null) {
        await _client
            .from('push_devices')
            .delete()
            .eq('token', token)
            .eq('user_id', userId)
            .timeout(_timeout);
      }
    } catch (_) {
      AppLogger.debug('[FCM] unregister deferred; token will be invalidated');
    }
    try {
      await _messaging.deleteToken().timeout(_timeout);
    } catch (_) {}
    try {
      await _messaging.setAutoInitEnabled(false);
    } catch (_) {}
    try {
      await _localNotifications.cancelAll();
    } catch (_) {}
    _registeredToken = null;
    _lastRegistrationSignature = null;
    _lastRegisteredAt = null;
    _pendingTap = null;
    _preferencesUser = null;
  }

  static Future<void> clearLocalNotificationPrefs() async {
    // Account preferences remain scoped by user ID; never reset another account's opt-outs.
    final prefs = await SharedPreferences.getInstance();
    for (final key in _columns.keys) {
      await prefs.remove(key);
    }
  }

  static Future<void> openNotification(Map<String, dynamic> data) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || _onTap == null) {
      _pendingTap = data;
      return;
    }
    if (data['userId'] != null && data['userId'] != userId) {
      _pendingTap = null;
      return;
    }
    _pendingTap = null;
    final notificationId = int.tryParse(
      data['notificationId']?.toString() ?? '',
    );
    if (notificationId != null) {
      unawaited(
        _client
            .from('notifications')
            .update({
              'is_read': true,
              'read_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', notificationId)
            .eq('user_id', userId)
            .eq('is_read', false)
            .timeout(_timeout)
            .then((_) {
              _received.add(null);
            })
            .catchError((_) {}),
      );
    }
    await _onTap!(data);
  }

  static Future<void> _openPayload(String? payload) async {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map) await openNotification(Map<String, dynamic>.from(data));
    } catch (_) {
      AppLogger.debug('[FCM] invalid local payload ignored');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_localInitialized || kIsWeb) return;
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          unawaited(_openPayload(response.payload)),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    _localInitialized = true;
  }

  static Future<void> _receive(RemoteMessage message) async {
    _received.add(null);
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || message.data['userId'] != userId) return;
      await showLocalNotification(
        title: message.notification?.title ?? 'SnapFit',
        body: message.notification?.body ?? '',
        data: message.data.map((k, v) => MapEntry(k, v.toString())),
      );
    } catch (_) {
      AppLogger.debug('[FCM] foreground notification deferred');
    }
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (_client.auth.currentUser == null || kIsWeb) return;
    final settings = await loadSettings();
    final category = notificationCategory(data ?? {});
    final enabled = switch (category) {
      'order' => settings.order,
      'invite' => settings.invite,
      'comment' => settings.comment,
      'marketing' => settings.marketing,
      'new_template' => settings.newTemplate,
      _ => true,
    };
    if (!settings.permissionGranted ||
        !allowsNotification(
          all: settings.all,
          categoryEnabled: enabled,
          nightMute: settings.nightMute,
          now: DateTime.now(),
        ))
      return;
    await _initializeLocalNotifications();
    final payload = <String, String>{
      ...?data,
      'userId': _client.auth.currentUser!.id,
    };
    final id =
        int.tryParse(payload['notificationId'] ?? '') ??
        DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    await _localNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'snapfit_push',
          'SnapFit 알림',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(payload),
    );
  }
}

class _PushLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FcmNotificationService._received.add(null);
      unawaited(FcmNotificationService.syncSession());
    }
  }
}
