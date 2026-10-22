import 'dart:async';

import 'package:app_links_platform_interface/app_links_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/main.dart';

import '../support/point_purchase_fakes.dart';

const _localNotifications = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

class _BootLinks extends AppLinksPlatform {
  final links = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => null;

  @override
  Stream<Uri> get uriLinkStream => links.stream;
}

class _BootMessaging extends FirebaseMessagingPlatform {
  final refresh = StreamController<String>.broadcast();

  @override
  FirebaseMessagingPlatform delegateFor({FirebaseApp? app}) => this;

  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;

  @override
  bool get isAutoInitEnabled => false;

  @override
  Future<void> setAutoInitEnabled(bool enabled) async {}

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async => null;

  @override
  Future<void> deleteToken() async {}

  @override
  Future<void> unsubscribeFromTopic(String topic) async {}

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<NotificationSettings> getNotificationSettings() async =>
      const NotificationSettings(
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
}

/// Actual app/SDK startup with local platform adapters and no remote session.
/// The production splash, auth notifier, and AuthGate remain in the tree.
class SnapFitAppTestSession {
  final requests = <http.Request>[];
  final store = FakeStore();
  final _links = _BootLinks();
  final _messaging = _BootMessaging();
  late AppLinksPlatform _previousLinks;
  late FirebaseMessagingPlatform _previousMessaging;

  Future<void> _initialize() async {
    setupFirebaseCoreMocks();
    SharedPreferences.setMockInitialValues({'push_permission_requested': true});
    FlutterSecureStorage.setMockInitialValues({});
    await Firebase.initializeApp();
    _previousLinks = AppLinksPlatform.instance;
    AppLinksPlatform.instance = _links;
    _previousMessaging = FirebaseMessagingPlatform.instance;
    FirebaseMessagingPlatform.instance = _messaging;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _localNotifications,
          (call) async => call.method == 'initialize'
              ? true
              : call.method == 'getNotificationAppLaunchDetails'
              ? {'notificationLaunchedApp': false}
              : null,
        );
    await Supabase.initialize(
      url: 'https://app-boot-fixture.invalid',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        throw StateError('Anonymous app boot must not call a backend.');
      }),
    );
  }

  PointPurchaseService _createPurchases() => PointPurchaseService(
    store: store,
    storage: MemoryReceipts(),
    currentUserId: () => Supabase.instance.client.auth.currentUser?.id,
    ensureServerAvailable: () async =>
        throw StateError('App boot must not start a purchase.'),
    verify: (_) async =>
        throw StateError('App boot must not verify a purchase.'),
    onBalanceChanged: () {},
  );

  Future<void> _dispose() async {
    await FcmNotificationService.clearDevicePushState();
    await Supabase.instance.dispose();
    AppLinksPlatform.instance = _previousLinks;
    FirebaseMessagingPlatform.instance = _previousMessaging;
    await _links.links.close();
    await _messaging.refresh.close();
    await store.controller.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotifications, null);
    expect(requests, isEmpty, reason: 'App boot must stay offline.');
  }
}

/// Pumps the production app with initialized SDKs and isolated native services.
/// Repository providers can still be replaced using [overrides].
Future<SnapFitAppTestSession> pumpSnapFitApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  final session = SnapFitAppTestSession();
  await tester.runAsync(session._initialize);
  addTearDown(() async {
    // Dispose the app's listeners before disposing their SDK/platform sources.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(session._dispose);
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pointPurchaseServiceProvider.overrideWith((ref) {
          final purchases = session._createPurchases();
          ref.onDispose(purchases.dispose);
          return purchases;
        }),
        ...overrides,
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => const MoaEditorApp(),
      ),
    ),
  );
  // Let storage resolve first, then advance the real splash's minimum duration
  // and route transition separately so the anonymous AuthGate is exercised.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1000));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 500));
  return session;
}
