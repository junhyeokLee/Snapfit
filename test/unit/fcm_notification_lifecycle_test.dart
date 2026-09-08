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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';

class _Messaging extends FirebaseMessagingPlatform {
  String? apns;
  String token = 'test-installation-token-one';
  int tokenRequests = 0, deletes = 0, apnsRequests = 0;
  final refresh = StreamController<String>.broadcast();
  final unsubscribed = <String>[];
  @override
  FirebaseMessagingPlatform delegateFor({FirebaseApp? app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
  @override
  bool get isAutoInitEnabled => true;
  @override
  Future<void> setAutoInitEnabled(bool enabled) async {}
  @override
  Future<String?> getAPNSToken() async {
    apnsRequests++;
    return apns;
  }

  @override
  Future<String?> getToken({String? vapidKey}) async {
    tokenRequests++;
    return token;
  }

  @override
  Future<void> deleteToken() async {
    deletes++;
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    unsubscribed.add(topic);
  }

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
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

Future<void> _session(SupabaseClient client, String user) async {
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final jwt =
      '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': user, 'exp': expiry, 'role': 'authenticated'})))}.test';
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': jwt,
      'token_type': 'bearer',
      'refresh_token': 'test-refresh',
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
  test(
    'APNs defers safely, token refresh rebinds, logout unregisters, relogin and taps stay scoped',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({
        'push_permission_requested': true,
      });
      await Firebase.initializeApp();
      final messaging = _Messaging();
      FirebaseMessagingPlatform.instance = messaging;
      final requests = <http.Request>[];
      final localCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              localCalls.add(call);
              if (call.method == 'getNotificationAppLaunchDetails')
                return {'notificationLaunchedApp': false};
              return call.method == 'initialize' ? true : null;
            },
          );
      await Supabase.initialize(
        url: 'https://push-test.invalid',
        anonKey: 'test',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/push_preferences') &&
              request.method == 'GET') {
            return http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          if (request.url.path.endsWith('/register_push_device'))
            return http.Response('', 204, request: request);
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final client = Supabase.instance.client;
      const alice = '11111111-1111-1111-1111-111111111111';
      const bob = '22222222-2222-2222-2222-222222222222';
      final taps = <Map<String, dynamic>>[];
      final errors = <Object>[];
      FcmNotificationService.onRegistrationErrorForTesting = (error, stack) {
        errors.add(error);
      };
      try {
        await _session(client, alice);
        await FcmNotificationService.initialize(
          onNotificationTap: (data) async {
            taps.add(data);
          },
        );
        await FcmNotificationService.syncSession();
        await FcmNotificationService.syncSession();
        expect(messaging.apnsRequests, greaterThan(0));
        expect(errors, isNotEmpty);
        expect(
          messaging.tokenRequests,
          0,
          reason: 'FCM token calls must wait for APNs',
        );
        expect(
          requests.where((r) => r.url.path.endsWith('/register_push_device')),
          isEmpty,
        );
        expect(errors, everyElement(isA<StateError>()));
        messaging.apns = 'test-apns';
        await FcmNotificationService.syncSession();
        expect(
          requests.where((r) => r.url.path.endsWith('/register_push_device')),
          hasLength(1),
        );
        expect(messaging.unsubscribed, contains('snapfit_order_updates'));
        messaging.token = 'test-installation-token-two';
        messaging.refresh.add(messaging.token);
        await Future<void>.delayed(Duration.zero);
        await FcmNotificationService.syncSession();
        expect(
          requests.where(
            (r) =>
                r.method == 'DELETE' &&
                r.url.query.contains('test-installation-token-one'),
          ),
          hasLength(1),
        );
        await FcmNotificationService.openNotification({
          'userId': bob,
          'orderId': 'private-bob',
        });
        expect(taps, isEmpty);
        await FcmNotificationService.openNotification({
          'userId': alice,
          'orderId': 'alice-order',
        });
        expect(taps.single['orderId'], 'alice-order');
        await FcmNotificationService.clearDevicePushState();
        expect(messaging.deletes, 1);
        expect(
          requests.where(
            (r) =>
                r.method == 'DELETE' &&
                r.url.query.contains('test-installation-token-two'),
          ),
          hasLength(1),
        );
        await client.auth.signOut(scope: SignOutScope.local);
        await Future<void>.delayed(Duration.zero);
        await FcmNotificationService.openNotification({
          'userId': bob,
          'orderId': 'pending-bob-order',
        });
        messaging.apns = null;
        messaging.token = 'test-installation-token-three';
        await _session(client, bob);
        expect(
          taps.last['orderId'],
          'pending-bob-order',
          reason:
              'Opening a queued tap must not depend on a successful device registration',
        );
        messaging.apns = 'test-apns';
        await FcmNotificationService.syncSession();
        final registrations = requests
            .where((r) => r.url.path.endsWith('/register_push_device'))
            .toList();
        expect(
          jsonDecode(registrations.last.body)['p_token'],
          'test-installation-token-three',
        );
        await FcmNotificationService.openNotification({
          'userId': alice,
          'orderId': 'stale-alice',
        });
        expect(taps, hasLength(2));
        final before = localCalls.where((call) => call.method == 'show').length;
        FirebaseMessagingPlatform.onMessage.add(
          const RemoteMessage(
            data: {'userId': alice, 'category': 'order'},
            notification: RemoteNotification(
              title: 'private stale',
              body: 'ignored',
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          localCalls.where((call) => call.method == 'show').length,
          before,
        );
        FirebaseMessagingPlatform.onMessage.add(
          const RemoteMessage(
            data: {'userId': bob, 'category': 'order'},
            notification: RemoteNotification(
              title: 'current user',
              body: 'visible',
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          localCalls.where((call) => call.method == 'show').length,
          before + 1,
        );
        await FcmNotificationService.updateSettings(
          all: false,
          order: true,
          invite: true,
          comment: true,
          marketing: false,
          newTemplate: true,
          nightMute: false,
        );
        FirebaseMessagingPlatform.onMessage.add(
          const RemoteMessage(
            data: {'userId': bob, 'category': 'order'},
            notification: RemoteNotification(title: 'muted', body: 'ignored'),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          localCalls.where((call) => call.method == 'show').length,
          before + 1,
        );
        expect(localCalls.any((call) => call.method == 'cancelAll'), isTrue);
      } finally {
        await FcmNotificationService.clearDevicePushState();
        await client.auth.signOut(scope: SignOutScope.local);
        await Future<void>.delayed(Duration.zero);
        await Supabase.instance.dispose();
        await messaging.refresh.close();
        FcmNotificationService.onRegistrationErrorForTesting = null;
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
