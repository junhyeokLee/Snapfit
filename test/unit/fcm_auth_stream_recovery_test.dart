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

const _owner = '11111111-1111-4111-8111-111111111111';

class _Messaging extends FirebaseMessagingPlatform {
  int tokenReads = 0, permissionPrompts = 0;
  @override
  FirebaseMessagingPlatform delegateFor({FirebaseApp? app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
  @override
  bool get isAutoInitEnabled => false;
  @override
  Future<void> setAutoInitEnabled(bool enabled) async {}
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
  @override
  Future<String?> getAPNSToken() async => 'fixture-apns';
  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    tokenReads++;
    // No real or fake installation is ever registered by this regression.
    return null;
  }

  @override
  Future<void> deleteToken() async {}
  @override
  Future<void> unsubscribeFromTopic(String topic) async {}
  @override
  Future<NotificationSettings> getNotificationSettings() async => _denied;
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
    permissionPrompts++;
    return _denied;
  }
}

const _denied = NotificationSettings(
  authorizationStatus: AuthorizationStatus.denied,
  alert: AppleNotificationSetting.disabled,
  announcement: AppleNotificationSetting.disabled,
  badge: AppleNotificationSetting.disabled,
  carPlay: AppleNotificationSetting.disabled,
  lockScreen: AppleNotificationSetting.disabled,
  notificationCenter: AppleNotificationSetting.disabled,
  showPreviews: AppleShowPreviewSetting.never,
  timeSensitive: AppleNotificationSetting.disabled,
  criticalAlert: AppleNotificationSetting.disabled,
  sound: AppleNotificationSetting.disabled,
  providesAppNotificationSettings: AppleNotificationSetting.disabled,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  test(
    'initialized push auth listener handles a refresh outage and retries without ending the account or changing permission',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({
        'push_permission_requested': true,
      });
      await Firebase.initializeApp();
      final previousMessaging = FirebaseMessagingPlatform.instance;
      final messaging = _Messaging();
      FirebaseMessagingPlatform.instance = messaging;
      final transportRequests = <http.Request>[];
      final registrationErrors = <Object>[];
      final channel = const MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getNotificationAppLaunchDetails') {
          return {'notificationLaunchedApp': false};
        }
        return call.method == 'initialize' ? true : null;
      });
      await Supabase.initialize(
        url: 'https://fcm-stream-fixture.invalid',
        anonKey: 'fixture',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
        httpClient: MockClient((request) async {
          transportRequests.add(request);
          return http.Response(
            request.url.path.endsWith('/logout') ? '' : '[]',
            request.url.path.endsWith('/logout') ? 204 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final client = Supabase.instance.client;
      FcmNotificationService.onRegistrationErrorForTesting = (error, _) {
        registrationErrors.add(error);
      };
      try {
        final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        final jwt =
            '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.'
            '${base64Url.encode(utf8.encode(jsonEncode({'sub': _owner, 'exp': expiry, 'role': 'authenticated'})))}.fixture';
        await client.auth.setInitialSession(
          jsonEncode({
            'access_token': jwt,
            'refresh_token': 'fixture-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'expires_at': expiry,
            'user': {
              'id': _owner,
              'aud': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          }),
        );
        await FcmNotificationService.initialize();
        await FcmNotificationService.syncSession();
        await FcmNotificationService.syncSession();
        final before = messaging.tokenReads;
        expect(before, greaterThan(0));
        // The real SDK dispatches auto-refresh failures through this exact stream.
        // Only this fixture invokes the internal event injection method.
        // ignore: invalid_use_of_internal_member
        client.auth.notifyException(
          AuthRetryableFetchException(
            message: 'temporary token refresh gateway timeout',
            statusCode: '504',
          ),
        );
        // The test framework fails on any unhandled stream/zone exception.
        await Future<void>.delayed(const Duration(milliseconds: 2250));
        expect(
          messaging.tokenReads,
          greaterThan(before),
          reason:
              'Push preparation should retry after the transient auth outage.',
        );
        expect(client.auth.currentUser?.id, _owner);
        expect(messaging.permissionPrompts, 0);
        expect(registrationErrors, isEmpty);
        expect(
          transportRequests.where(
            (r) => r.url.path.endsWith('/register_push_device'),
          ),
          isEmpty,
        );
        expect(
          transportRequests.where((r) => r.url.path.endsWith('/logout')),
          isEmpty,
        );
      } finally {
        // This is an isolated mocked SDK session, never the user's account.
        await client.auth.signOut(scope: SignOutScope.local);
        await Future<void>.delayed(Duration.zero);
        FcmNotificationService.onRegistrationErrorForTesting = null;
        await Supabase.instance.dispose();
        messenger.setMockMethodCallHandler(channel, null);
        FirebaseMessagingPlatform.instance = previousMessaging;
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: kIsWeb,
  );
}
