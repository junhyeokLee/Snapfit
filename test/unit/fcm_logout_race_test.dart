import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _alice = '11111111-1111-4111-8111-111111111111';
const _bob = '22222222-2222-4222-8222-222222222222';

class _Messaging extends FirebaseMessagingPlatform {
  String token = 'installation-a';
  final events = <String>[];
  Completer<void>? deleting, deleted;
  @override
  FirebaseMessagingPlatform delegateFor({FirebaseApp? app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
  @override
  bool get isAutoInitEnabled => true;
  @override
  Future<void> setAutoInitEnabled(bool enabled) async =>
      events.add('auto:$enabled');
  @override
  Future<String?> getAPNSToken() async => 'fixture-apns';
  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    events.add('token:$token');
    return token;
  }

  @override
  Future<void> deleteToken() async {
    events.add('delete-start');
    deleting?.complete();
    await deleted?.future;
    events.add('delete-finished');
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {}
  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<NotificationSettings> getNotificationSettings() async =>
      const NotificationSettings(
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
}

Future<void> _session(SupabaseClient client, String id) async {
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final jwt =
      '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.'
      '${base64Url.encode(utf8.encode(jsonEncode({'sub': id, 'exp': expiry, 'role': 'authenticated'})))}.fixture';
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': jwt,
      'refresh_token': 'fixture-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': expiry,
      'user': {
        'id': id,
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
  test(
    'old native logout drains token deletion before B registers, including owner ABA',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({
        'push_permission_requested': true,
      });
      await Firebase.initializeApp();
      final messaging = _Messaging();
      FirebaseMessagingPlatform.instance = messaging;
      final requests = <http.Request>[];
      final taps = <Map<String, dynamic>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              if (call.method == 'getNotificationAppLaunchDetails')
                return {'notificationLaunchedApp': false};
              return call.method == 'initialize' ? true : null;
            },
          );
      await Supabase.initialize(
        url: 'https://logout-race.invalid',
        anonKey: 'fixture',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            request.url.path.endsWith('/push_preferences') ? '{}' : '[]',
            request.method == 'DELETE' ? 204 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final client = Supabase.instance.client;
      try {
        await _session(client, _alice);
        await FcmNotificationService.initialize(
          onNotificationTap: (data) async => taps.add(Map.of(data)),
        );
        await FcmNotificationService.syncSession();
        await FcmNotificationService.syncSession();
        for (final owners in [
          [_bob],
          [_alice, _bob],
        ]) {
          final originalOwner = client.auth.currentUser!.id;
          final beforeRegistrations = requests
              .where((r) => r.url.path.endsWith('/register_push_device'))
              .length;
          messaging.events.clear();
          messaging.deleting = Completer<void>();
          messaging.deleted = Completer<void>();
          final oldToken = messaging.token;
          final clearing = FcmNotificationService.clearDevicePushState();
          await messaging.deleting!.future;
          // Capture the old owner's unregister before the replacement session
          // performs its own harmless old-token cleanup under its new owner.
          final deletion = requests.lastWhere(
            (request) =>
                request.method == 'DELETE' &&
                request.url.path.endsWith('/push_devices'),
          );
          expect(deletion.url.queryParameters['token'], 'eq.$oldToken');
          expect(deletion.url.queryParameters['user_id'], 'eq.$originalOwner');
          for (final next in owners) {
            messaging.token = 'installation-$next';
            await _session(client, next);
          }
          final syncing = FcmNotificationService.syncSession();
          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(
            messaging.events.where((event) => event.startsWith('token:')),
            isEmpty,
            reason:
                'No newer account can register while the old SDK deletion is in flight.',
          );
          messaging.deleted!.complete();
          await clearing;
          await syncing;
          await FcmNotificationService.syncSession();
          expect(messaging.events, isNot(contains('auto:false')));
          expect(
            messaging.events.indexOf('delete-finished'),
            lessThan(messaging.events.indexOf('token:${messaging.token}')),
          );
          expect(
            requests
                .where((r) => r.url.path.endsWith('/register_push_device'))
                .length,
            greaterThan(beforeRegistrations),
          );
          final registered = requests.lastWhere(
            (request) => request.url.path.endsWith('/register_push_device'),
          );
          expect(jsonDecode(registered.body)['p_token'], messaging.token);
        }
        const data = {
          'userId': _bob,
          'workId': '33333333-3333-4333-8333-333333333333',
          'commentId': '44444444-4444-4444-8444-444444444444',
          'showComments': 'true',
          'category': 'comment',
          'type': 'social_comment',
        };
        FirebaseMessagingPlatform.onMessageOpenedApp.add(
          const RemoteMessage(data: data),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(taps.single, data);
        FirebaseMessagingPlatform.onMessageOpenedApp.add(
          RemoteMessage(data: {...data, 'userId': _alice}),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(taps, hasLength(1));
      } finally {
        messaging.deleting = null;
        messaging.deleted = null;
        await FcmNotificationService.clearDevicePushState();
        await client.auth.signOut(scope: SignOutScope.local);
        await Supabase.instance.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
