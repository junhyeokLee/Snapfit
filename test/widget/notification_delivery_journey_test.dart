import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/notification/domain/entities/app_notification_item.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/notification/presentation/views/notification_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/notification_settings_screen.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

const _owner = '11111111-1111-1111-1111-111111111111';
const _permission = NotificationSettings(
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

class _Messaging extends FirebaseMessagingPlatform {
  final refresh = StreamController<String>.broadcast();
  @override
  FirebaseMessagingPlatform delegateFor({FirebaseApp? app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
  @override
  Future<void> setAutoInitEnabled(bool enabled) async {}
  @override
  Future<String?> getAPNSToken() async => 'fixture-apns';
  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async => 'fixture-token-no-real-device';
  @override
  Future<void> deleteToken() async {}
  @override
  Future<void> unsubscribeFromTopic(String topic) async {}
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
  @override
  Future<NotificationSettings> getNotificationSettings() async => _permission;
}

class _Action extends Mock implements NotificationAction {}

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> _signIn(SupabaseClient client) async {
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final jwt =
      '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.'
      '${base64Url.encode(utf8.encode(jsonEncode({'sub': _owner, 'exp': expiry, 'role': 'authenticated'})))}.fixture';
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': jwt,
      'token_type': 'bearer',
      'refresh_token': 'fixture-refresh',
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
}

void main() {
  _PaintBinding();
  setupFirebaseCoreMocks();
  final boundary = GlobalKey();
  final messaging = _Messaging();
  final requests = <http.Request>[];
  final opened = <Map<String, dynamic>>[];
  Completer<http.Response>? readReceipt;
  var readFails = false;
  late FirebaseMessagingPlatform previousMessaging;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'push_permission_requested': true});
    await loadCreationFonts();
    await Firebase.initializeApp();
    previousMessaging = FirebaseMessagingPlatform.instance;
    FirebaseMessagingPlatform.instance = messaging;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async => call.method == 'getNotificationAppLaunchDetails'
              ? {'notificationLaunchedApp': false}
              : call.method == 'initialize'
              ? true
              : null,
        );
    await Supabase.initialize(
      url: 'https://notification-delivery.invalid',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'PATCH' &&
            request.url.path.endsWith('/notifications')) {
          if (readReceipt != null) return readReceipt!.future;
          if (readFails)
            return http.Response(
              '{"message":"fixture read failure"}',
              503,
              request: request,
            );
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await _signIn(Supabase.instance.client);
    await FcmNotificationService.initialize(
      onNotificationTap: (data) async => opened.add(data),
    );
    await FcmNotificationService.syncSession();
  });

  setUp(() async {
    requests.clear();
    opened.clear();
    readReceipt = null;
    readFails = false;
    await FcmNotificationService.updateSettings(
      all: false,
      order: true,
      invite: true,
      comment: true,
      marketing: false,
      newTemplate: true,
      nightMute: true,
    );
    requests.clear();
  });

  tearDown(() async {
    if (readReceipt != null && !readReceipt!.isCompleted) {
      readReceipt!.complete(
        http.Response('[]', 200, headers: {'content-type': 'application/json'}),
      );
    }
    expect(
      requests.every(
        (request) => request.url.host == 'notification-delivery.invalid',
      ),
      true,
    );
  });

  tearDownAll(() async {
    await FcmNotificationService.clearDevicePushState();
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    await Supabase.instance.dispose();
    await messaging.refresh.close();
    FirebaseMessagingPlatform.instance = previousMessaging;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          null,
        );
  });

  void metrics(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = size.width > size.height
        ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
        : const FakeViewPadding(top: 24, bottom: 34);
  }

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool dark = false,
    double scale = 1,
    _Action? action,
  }) async {
    metrics(tester, size);
    addTearDown(tester.view.reset);
    final items = [
      for (var index = 1; index <= 12; index++)
        AppNotificationItem(
          id: index,
          type: index.isOdd ? 'order_status' : 'invite_accepted',
          title: index.isOdd ? '앨범 제작이 시작되었어요' : '공유 앨범에 새 멤버가 참여했어요',
          body: index.isOdd
              ? '주문한 앨범의 제작 소식을 확인해 보세요.'
              : '함께 남길 장면을 앨범에서 확인해 보세요.',
          createdAt: DateTime.now().subtract(Duration(minutes: index)),
          isRead: index > 3,
          userId: _owner,
          deeplink: 'snapfit://order/detail?orderId=fixture-order-$index',
          data: {'orderId': 'fixture-order-$index'},
        ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationInboxProvider.overrideWith((_) async => items),
          notificationUnreadCountProvider.overrideWith((_) async => 3),
          notificationRetentionDaysProvider.overrideWith((_) async => 90),
          if (action != null)
            notificationActionProvider.overrideWithValue(action),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: const NotificationScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark,
  ) async {
    expect(tester.takeException(), isNull);
    if (!const bool.fromEnvironment('NOTIFICATION_DELIVERY_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('output/all-screens-qa')
        ..createSync(recursive: true);
      File(
        '${directory.path}/notification-delivery-$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      for (final scale
          in size.width == 320 || size.width == 648 ? [1.0, 1.8] : [1.0]) {
        testWidgets(
          'saved opt-out and inbox remain usable $size dark=$dark scale=$scale',
          (tester) async {
            await mount(tester, size: size, dark: dark, scale: scale);
            final suffix = scale > 1 ? '-large' : '';
            await capture(tester, 'inbox$suffix', size, dark);
            await tester.tap(find.byKey(const ValueKey('inbox-settings')));
            // The SDK/storage futures originate in setUp's real async zone.
            // Drain both zones while the account read finishes; keep the UI's
            // loading indicator active instead of replacing the real screen.
            for (
              var attempt = 0;
              attempt < 8 &&
                  find.byType(NotificationSettingsContent).evaluate().isEmpty;
              attempt++
            ) {
              await tester.pump();
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 1)),
              );
            }
            await tester.pumpAndSettle();
            final content = tester.widget<NotificationSettingsContent>(
              find.byType(NotificationSettingsContent),
            );
            expect(content.settings.all, false);
            expect(content.settings.nightMute, true);
            expect(content.settings.permissionGranted, true);
            await capture(tester, 'settings$suffix', size, dark);
            final scrollable = find
                .descendant(
                  of: find.byKey(
                    const PageStorageKey('notification-preferences'),
                  ),
                  matching: find.byType(Scrollable),
                )
                .first;
            await tester.scrollUntilVisible(
              find.text('야간 알림 끄기'),
              120,
              scrollable: scrollable,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.tap(find.byTooltip('뒤로가기'));
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('inbox-item-1')), findsOneWidget);
            expect(
              requests.where(
                (request) =>
                    request.method == 'POST' &&
                    request.url.path.endsWith('/push_preferences'),
              ),
              isEmpty,
            );
          },
        );
      }
    }
  }

  for (final fails in [false, true]) {
    testWidgets(
      'inbox opens immediately when the read receipt ${fails ? 'fails' : 'is pending'}',
      (tester) async {
        final action = _Action();
        when(
          () => action.markRead(any()),
        ).thenThrow(StateError('must use the shared best-effort receipt'));
        await mount(tester, action: action);
        readFails = fails;
        if (!fails) readReceipt = Completer<http.Response>();
        await tester.tap(find.byKey(const ValueKey('inbox-item-1')));
        await tester.pump();
        await tester.pump();
        expect(opened, hasLength(1));
        expect(opened.single['orderId'], 'fixture-order-1');
        expect(opened.single['userId'], _owner);
        verifyNever(() => action.markRead(any()));
        expect(
          requests.where(
            (request) =>
                request.method == 'PATCH' &&
                request.url.path.endsWith('/notifications'),
          ),
          hasLength(1),
        );
        expect(find.text('알림을 열지 못했어요. 다시 시도해주세요.'), findsNothing);
        if (!fails) {
          expect(readReceipt!.isCompleted, false);
          readReceipt!.complete(
            http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
              request: requests.firstWhere(
                (request) => request.method == 'PATCH',
              ),
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
