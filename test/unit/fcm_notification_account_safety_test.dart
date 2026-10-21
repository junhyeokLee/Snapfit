import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _alice = '11111111-1111-1111-1111-111111111111';
const _bob = '22222222-2222-2222-2222-222222222222';
const _settings = NotificationSettings(
  authorizationStatus: AuthorizationStatus.authorized,
  alert: AppleNotificationSetting.enabled,
  announcement: AppleNotificationSetting.disabled,
  badge: AppleNotificationSetting.enabled,
  carPlay: AppleNotificationSetting.disabled,
  lockScreen: AppleNotificationSetting.enabled,
  notificationCenter: AppleNotificationSetting.enabled,
  showPreviews: AppleShowPreviewSetting.always,
  timeSensitive: AppleNotificationSetting.disabled,
  criticalAlert: AppleNotificationSetting.disabled,
  sound: AppleNotificationSetting.enabled,
  providesAppNotificationSettings: AppleNotificationSetting.disabled,
);
const _deniedSettings = NotificationSettings(
  authorizationStatus: AuthorizationStatus.denied,
  alert: AppleNotificationSetting.disabled,
  announcement: AppleNotificationSetting.disabled,
  badge: AppleNotificationSetting.disabled,
  carPlay: AppleNotificationSetting.disabled,
  lockScreen: AppleNotificationSetting.disabled,
  notificationCenter: AppleNotificationSetting.disabled,
  showPreviews: AppleShowPreviewSetting.always,
  timeSensitive: AppleNotificationSetting.disabled,
  criticalAlert: AppleNotificationSetting.disabled,
  sound: AppleNotificationSetting.disabled,
  providesAppNotificationSettings: AppleNotificationSetting.disabled,
);

class _Messaging extends FirebaseMessagingPlatform {
  final refresh = StreamController<String>.broadcast();
  Completer<NotificationSettings>? permissionGate;
  Completer<void>? permissionStarted;
  NotificationSettings permission = _settings;
  RemoteMessage? initialMessage;
  int tokenRequests = 0, permissionRequests = 0;

  @override
  FirebaseMessagingPlatform delegateFor({FirebaseApp? app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
  @override
  bool get isAutoInitEnabled => true;
  @override
  Future<void> setAutoInitEnabled(bool enabled) async {}
  @override
  Future<String?> getAPNSToken() async => 'fixture-apns';
  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    tokenRequests++;
    return 'fixture-device-token';
  }

  @override
  Future<void> deleteToken() async {}
  @override
  Future<void> unsubscribeFromTopic(String topic) async {}
  @override
  Future<RemoteMessage?> getInitialMessage() async => initialMessage;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<NotificationSettings> getNotificationSettings() async {
    final started = permissionStarted;
    if (started != null && !started.isCompleted) started.complete();
    return permissionGate?.future ?? Future.value(permission);
  }

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    permissionRequests++;
    return permission;
  }
}

Future<void> _session(SupabaseClient client, String user) async {
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final jwt =
      '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': user, 'exp': expiry, 'role': 'authenticated'})))}.fixture';
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': jwt,
      'token_type': 'bearer',
      'refresh_token': 'fixture-refresh',
      'expires_in': 3600,
      'expires_at': expiry,
      'user': {
        'id': user,
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': {},
        'user_metadata': {},
      },
    }),
  );
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final messaging = _Messaging();
  final localCalls = <MethodCall>[];
  final requests = <http.Request>[];
  Completer<http.Response>? preferenceGate;
  Completer<void>? preferenceStarted;
  Completer<void>? writeGate, writeStarted;
  Completer<void>? localShowGate, localShowStarted;
  int preferenceStatus = 200;
  int writeStatus = 204;
  Map<String, dynamic> remotePreferences = {};
  final taps = <Map<String, dynamic>>[];
  late SupabaseClient client;

  http.Response jsonResponse(http.Request request, Object body) =>
      http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );

  setUpAll(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({'push_permission_requested': true});
    await Firebase.initializeApp();
    FirebaseMessagingPlatform.instance = messaging;
    messaging.initialMessage = const RemoteMessage(
      data: {'userId': _alice, 'orderId': 'terminated-alice-order'},
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async {
            localCalls.add(call);
            if (call.method == 'show') {
              final started = localShowStarted;
              if (started != null && !started.isCompleted) started.complete();
              await localShowGate?.future;
            }
            if (call.method == 'getNotificationAppLaunchDetails') {
              return {'notificationLaunchedApp': false};
            }
            return call.method == 'initialize' ? true : null;
          },
        );
    await Supabase.initialize(
      url: 'https://push-review.invalid',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path.endsWith('/push_preferences')) {
          final started = preferenceStarted;
          if (started != null && !started.isCompleted) started.complete();
          final gate = preferenceGate;
          if (gate != null) return await gate.future;
          return http.Response(
            jsonEncode(remotePreferences),
            preferenceStatus,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/push_preferences')) {
          final started = writeStarted;
          if (started != null && !started.isCompleted) started.complete();
          await writeGate?.future;
          return http.Response(
            writeStatus == 204
                ? ''
                : '{"code":"unavailable","message":"fixture offline"}',
            writeStatus,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/register_push_device')) {
          return http.Response('', 204, request: request);
        }
        return jsonResponse(request, []);
      }),
    );
    client = Supabase.instance.client;
    await FcmNotificationService.initialize(
      onNotificationTap: (data) async {
        taps.add(Map<String, dynamic>.from(data));
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'push_permission_requested': true});
    requests.clear();
    localCalls.clear();
    preferenceGate = null;
    preferenceStarted = null;
    messaging.permissionGate = null;
    messaging.permissionStarted = null;
    messaging.permission = _settings;
    messaging.permissionRequests = 0;
    remotePreferences = {};
    preferenceStatus = 200;
    writeStatus = 204;
    writeGate = null;
    writeStarted = null;
    localShowGate = null;
    localShowStarted = null;
    taps.clear();
  });

  tearDown(() async {
    if (preferenceGate != null && !preferenceGate!.isCompleted) {
      preferenceGate!.complete(
        http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
          request: requests.firstWhere(
            (request) =>
                request.method == 'GET' &&
                request.url.path.endsWith('/push_preferences'),
          ),
        ),
      );
    }
    if (messaging.permissionGate != null &&
        !messaging.permissionGate!.isCompleted) {
      messaging.permissionGate!.complete(_settings);
    }
    if (writeGate != null && !writeGate!.isCompleted) writeGate!.complete();
    if (localShowGate != null && !localShowGate!.isCompleted)
      localShowGate!.complete();
    await FcmNotificationService.syncSession();
    await FcmNotificationService.clearDevicePushState();
    await client.auth.signOut(scope: SignOutScope.local);
    await Future<void>.delayed(Duration.zero);
  });

  test('terminated app initial message waits for the matching login', () async {
    expect(taps, isEmpty);
    await _session(client, _alice);
    await FcmNotificationService.syncSession();
    expect(taps, hasLength(1));
    expect(taps.single['orderId'], 'terminated-alice-order');
    expect(taps.single['userId'], _alice);
    expect(messaging.permissionRequests, 0);
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
    await messaging.refresh.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          null,
        );
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'an unrelated native setting edit cannot re-enable a remote opt-out',
    () async {
      preferenceGate = Completer<http.Response>();
      preferenceStarted = Completer<void>();
      await _session(client, _alice);
      await preferenceStarted!.future;
      final syncing = FcmNotificationService.syncSession();
      NotificationSettingsState? displayed;
      final loading = FcmNotificationService.loadSettings().then((value) {
        displayed = value;
        return value;
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final earlyForm = displayed;
      try {
        // Mirror the real settings screen: its editable form forwards a full
        // snapshot when the user switches only the comment preference off.
        // A correct initial load keeps the form unavailable until the GET ends,
        // so there is no early form snapshot and no user action to submit here.
        if (earlyForm != null) {
          await FcmNotificationService.updateSettings(
            all: earlyForm.all,
            order: earlyForm.order,
            invite: earlyForm.invite,
            comment: false,
            marketing: earlyForm.marketing,
            newTemplate: earlyForm.newTemplate,
            nightMute: earlyForm.nightMute,
          );
        }
      } finally {
        preferenceGate!.complete(
          http.Response(
            jsonEncode({
              'user_id': _alice,
              'all_enabled': false,
              'order_enabled': false,
              'invite_enabled': true,
              'comment_enabled': true,
              'marketing_enabled': false,
              'new_template_enabled': false,
              'night_mute': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: requests.firstWhere(
              (request) =>
                  request.method == 'GET' &&
                  request.url.path.endsWith('/push_preferences'),
            ),
          ),
        );
        await syncing;
        await loading;
      }
      expect(
        earlyForm,
        isNull,
        reason:
            'The editable form must wait for the first remote settings read.',
      );
      final loaded = await loading;
      expect(loaded.all, false);
      expect(loaded.order, false);
      expect(loaded.nightMute, true);
      expect(loaded.ownerId, _alice);
      final preferenceWrites = requests
          .where(
            (request) =>
                request.method == 'POST' &&
                request.url.path.endsWith('/push_preferences'),
          )
          .map((request) => jsonDecode(request.body) as Map<String, dynamic>)
          .toList();
      expect(
        preferenceWrites.where((row) => row['all_enabled'] == true),
        isEmpty,
        reason:
            'The delayed remote row had all_enabled=false. Editing only '
            'comment must never send all_enabled=true. Actual authenticated '
            'upsert payloads: $preferenceWrites',
      );
    },
  );

  test('concurrent settings loads share one remote account read', () async {
    preferenceGate = Completer<http.Response>();
    preferenceStarted = Completer<void>();
    await _session(client, _alice);
    await preferenceStarted!.future;
    final loads = List.generate(
      3,
      (_) => FcmNotificationService.loadSettings(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      requests.where(
        (request) =>
            request.method == 'GET' &&
            request.url.path.endsWith('/push_preferences'),
      ),
      hasLength(1),
    );
    preferenceGate!.complete(
      http.Response(
        '{"all_enabled":false}',
        200,
        headers: {'content-type': 'application/json'},
        request: requests.firstWhere(
          (request) =>
              request.method == 'GET' &&
              request.url.path.endsWith('/push_preferences'),
        ),
      ),
    );
    final values = await Future.wait(loads);
    expect(values.map((value) => value.all), everyElement(false));
    expect(values.map((value) => value.ownerId), everyElement(_alice));
  });

  test(
    'failed first remote settings read never becomes editable defaults',
    () async {
      preferenceStatus = 503;
      remotePreferences = {'code': 'unavailable', 'message': 'fixture offline'};
      await _session(client, _alice);
      await expectLater(
        FcmNotificationService.loadSettings(),
        throwsA(isA<Object>()),
      );
      expect(
        requests.where(
          (request) =>
              request.method == 'POST' &&
              request.url.path.endsWith('/push_preferences'),
        ),
        isEmpty,
      );
      preferenceStatus = 200;
      remotePreferences = {'all_enabled': false, 'marketing_enabled': false};
      final restored = await FcmNotificationService.loadSettings();
      expect(restored.all, false);
      expect(restored.marketing, false);
      await FcmNotificationService.syncSession();
    },
  );

  test(
    'queued setting writes keep the latest local opt-out while offline',
    () async {
      await _session(client, _alice);
      await FcmNotificationService.syncSession();
      writeGate = Completer<void>();
      writeStarted = Completer<void>();
      final first = FcmNotificationService.updateSettings(
        all: true,
        order: true,
        invite: true,
        comment: false,
        marketing: false,
        newTemplate: true,
        nightMute: false,
        expectedOwnerId: _alice,
      );
      await writeStarted!.future;
      final second = FcmNotificationService.updateSettings(
        all: false,
        order: false,
        invite: true,
        comment: false,
        marketing: false,
        newTemplate: true,
        nightMute: true,
        expectedOwnerId: _alice,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('${FcmNotificationService.kAll}_$_alice'), false);
      expect(prefs.getBool('${FcmNotificationService.kOrder}_$_alice'), false);
      expect(prefs.getBool('push_prefs_dirty_$_alice'), true);
      writeGate!.complete();
      await Future.wait([first, second]);
      final rows = requests
          .where(
            (request) =>
                request.method == 'POST' &&
                request.url.path.endsWith('/push_preferences'),
          )
          .map((request) => jsonDecode(request.body) as Map)
          .toList();
      expect(rows.last['all_enabled'], false);
      expect(rows.last['order_enabled'], false);
      expect(rows.last['night_mute'], true);
      expect(prefs.getBool('push_prefs_dirty_$_alice'), false);
    },
  );

  test(
    'a stale settings form cannot update a newly signed-in account',
    () async {
      await _session(client, _alice);
      final aliceSettings = await FcmNotificationService.loadSettings();
      await client.auth.signOut(scope: SignOutScope.local);
      await _session(client, _bob);
      await FcmNotificationService.syncSession();
      final before = requests
          .where(
            (request) =>
                request.method == 'POST' &&
                request.url.path.endsWith('/push_preferences'),
          )
          .length;
      await expectLater(
        FcmNotificationService.updateSettings(
          all: false,
          order: false,
          invite: false,
          comment: false,
          marketing: false,
          newTemplate: false,
          nightMute: true,
          expectedOwnerId: aliceSettings.ownerId,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        requests.where(
          (request) =>
              request.method == 'POST' &&
              request.url.path.endsWith('/push_preferences'),
        ),
        hasLength(before),
      );
      expect((await FcmNotificationService.loadSettings()).all, true);
    },
  );

  test(
    'failed preference writes retain the local opt-out for a later retry',
    () async {
      await _session(client, _alice);
      await FcmNotificationService.syncSession();
      writeStatus = 503;
      await expectLater(
        FcmNotificationService.updateSettings(
          all: false,
          order: false,
          invite: true,
          comment: true,
          marketing: false,
          newTemplate: true,
          nightMute: true,
          expectedOwnerId: _alice,
        ),
        throwsA(isA<Object>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('${FcmNotificationService.kAll}_$_alice'), false);
      expect(prefs.getBool('push_prefs_dirty_$_alice'), true);
      writeStatus = 204;
      await FcmNotificationService.syncSession();
      expect(prefs.getBool('push_prefs_dirty_$_alice'), false);
      expect((await FcmNotificationService.loadSettings()).all, false);
    },
  );

  test(
    'an in-flight foreground message cannot be rebound to a new account',
    () async {
      await _session(client, _alice);
      await FcmNotificationService.syncSession();
      messaging.permissionGate = Completer<NotificationSettings>();
      messaging.permissionStarted = Completer<void>();
      FirebaseMessagingPlatform.onMessage.add(
        const RemoteMessage(
          data: {
            'userId': _alice,
            'category': 'order',
            'orderId': 'private-alice-order',
          },
          notification: RemoteNotification(
            title: 'Alice private order',
            body: 'Private order information for Alice',
          ),
        ),
      );
      await messaging.permissionStarted!.future;
      await client.auth.signOut(scope: SignOutScope.local);
      await _session(client, _bob);
      messaging.permissionGate!.complete(_settings);
      await FcmNotificationService.syncSession();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final shown = localCalls.where((call) => call.method == 'show').map((
        call,
      ) {
        final arguments = call.arguments as Map;
        return {
          'title': arguments['title'],
          'body': arguments['body'],
          'payload': jsonDecode(arguments['payload'] as String),
        };
      }).toList();
      expect(
        shown,
        isEmpty,
        reason:
            'Alice content must be dropped when the owner changes during '
            'permission loading. The present implementation also replaces the '
            'payload userId with Bob, allowing its stale tap through owner checks. '
            'Observed local content and decoded payloads: $shown',
      );
    },
  );

  test(
    'foreground messages preserve their original matching owner and content',
    () async {
      await _session(client, _alice);
      await FcmNotificationService.syncSession();
      FirebaseMessagingPlatform.onMessage.add(
        const RemoteMessage(
          data: {
            'userId': _alice,
            'category': 'order',
            'notificationId': '4321',
          },
          notification: RemoteNotification(
            title: 'Alice order',
            body: 'Alice body',
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final shown = localCalls.where((call) => call.method == 'show').toList();
      expect(shown, hasLength(1));
      final arguments = shown.single.arguments as Map;
      expect(arguments['title'], 'Alice order');
      expect(arguments['body'], 'Alice body');
      expect(jsonDecode(arguments['payload'] as String)['userId'], _alice);
      FirebaseMessagingPlatform.onMessage.add(
        const RemoteMessage(
          data: {'userId': _bob, 'category': 'order'},
          notification: RemoteNotification(
            title: 'Bob private',
            body: 'ignored',
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(localCalls.where((call) => call.method == 'show'), hasLength(1));
    },
  );

  test(
    'signing out during foreground permission loading drops the message',
    () async {
      await _session(client, _alice);
      await FcmNotificationService.syncSession();
      messaging.permissionGate = Completer<NotificationSettings>();
      messaging.permissionStarted = Completer<void>();
      FirebaseMessagingPlatform.onMessage.add(
        const RemoteMessage(
          data: {'userId': _alice, 'category': 'order'},
          notification: RemoteNotification(
            title: 'Alice private',
            body: 'ignored',
          ),
        ),
      );
      await messaging.permissionStarted!.future;
      await client.auth.signOut(scope: SignOutScope.local);
      messaging.permissionGate!.complete(_settings);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(localCalls.where((call) => call.method == 'show'), isEmpty);
    },
  );

  test(
    'a local display finishing after logout is cancelled by its original id',
    () async {
      await _session(client, _alice);
      await FcmNotificationService.syncSession();
      localShowGate = Completer<void>();
      localShowStarted = Completer<void>();
      final showing = FcmNotificationService.showLocalNotification(
        title: 'Alice order',
        body: 'Private Alice body',
        data: {'userId': _alice, 'category': 'order', 'notificationId': '7654'},
      );
      await localShowStarted!.future;
      await client.auth.signOut(scope: SignOutScope.local);
      localShowGate!.complete();
      await showing;
      final cancelled = localCalls
          .where((call) => call.method == 'cancel')
          .toList();
      expect(cancelled, hasLength(1));
      expect(cancelled.single.arguments, 7654);
    },
  );

  test(
    'denied device permission suppresses display and disables registration',
    () async {
      messaging.permission = _deniedSettings;
      await _session(client, _alice);
      await FcmNotificationService.syncSession();
      final settings = await FcmNotificationService.loadSettings();
      expect(settings.permissionGranted, false);
      final registrations = requests
          .where(
            (request) => request.url.path.endsWith('/register_push_device'),
          )
          .toList();
      expect(registrations, isNotEmpty);
      expect(jsonDecode(registrations.last.body)['p_enabled'], false);
      FirebaseMessagingPlatform.onMessage.add(
        const RemoteMessage(
          data: {'userId': _alice, 'category': 'order'},
          notification: RemoteNotification(title: 'denied', body: 'ignored'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(localCalls.where((call) => call.method == 'show'), isEmpty);
      expect(messaging.permissionRequests, 0);
    },
  );

  test(
    'background taps and pre-login pending taps remain owner scoped',
    () async {
      await _session(client, _alice);
      await FcmNotificationService.syncSession();
      FirebaseMessagingPlatform.onMessageOpenedApp.add(
        const RemoteMessage(
          data: {'userId': _alice, 'orderId': 'background-alice'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(taps.single['orderId'], 'background-alice');
      FirebaseMessagingPlatform.onMessageOpenedApp.add(
        const RemoteMessage(
          data: {'userId': _bob, 'orderId': 'wrong-background-bob'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(taps, hasLength(1));
      await client.auth.signOut(scope: SignOutScope.local);
      await FcmNotificationService.openNotification({
        'userId': _alice,
        'orderId': 'stale-pending-alice',
      });
      await _session(client, _bob);
      await FcmNotificationService.syncSession();
      expect(taps, hasLength(1));
      await client.auth.signOut(scope: SignOutScope.local);
      await FcmNotificationService.openNotification({
        'userId': _bob,
        'orderId': 'pending-bob',
      });
      preferenceStatus = 503;
      remotePreferences = {'code': 'unavailable', 'message': 'fixture offline'};
      await _session(client, _bob);
      expect(taps, hasLength(2));
      expect(taps.last['orderId'], 'pending-bob');
      await FcmNotificationService.syncSession();
    },
  );

  test(
    'a delayed settings read cannot return a prior account snapshot',
    () async {
      final aliceGate = Completer<http.Response>();
      preferenceGate = aliceGate;
      preferenceStarted = Completer<void>();
      await _session(client, _alice);
      await preferenceStarted!.future;
      final aliceLoad = FcmNotificationService.loadSettings();
      final rejected = expectLater(aliceLoad, throwsA(isA<StateError>()));
      await client.auth.signOut(scope: SignOutScope.local);
      preferenceGate = null;
      remotePreferences = {'all_enabled': true, 'night_mute': false};
      await _session(client, _bob);
      final bobSettings = await FcmNotificationService.loadSettings();
      aliceGate.complete(
        http.Response(
          '{"all_enabled":false,"night_mute":true}',
          200,
          headers: {'content-type': 'application/json'},
          request: requests.firstWhere(
            (request) =>
                request.method == 'GET' &&
                request.url.path.endsWith('/push_preferences'),
          ),
        ),
      );
      await rejected;
      await FcmNotificationService.syncSession();
      expect(bobSettings.ownerId, _bob);
      expect(bobSettings.all, true);
      expect(bobSettings.nightMute, false);
      expect((await FcmNotificationService.loadSettings()).all, true);
    },
  );

  test(
    'app resume refreshes device state without prompting or duplicate registration',
    () async {
      await _session(client, _alice);
      await FcmNotificationService.syncSession();
      final registrations = requests
          .where(
            (request) => request.url.path.endsWith('/register_push_device'),
          )
          .length;
      final tokenRequests = messaging.tokenRequests;
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await FcmNotificationService.syncSession();
      expect(messaging.tokenRequests, greaterThan(tokenRequests));
      expect(messaging.permissionRequests, 0);
      expect(
        requests.where(
          (request) => request.url.path.endsWith('/register_push_device'),
        ),
        hasLength(registrations),
      );
    },
  );
}
