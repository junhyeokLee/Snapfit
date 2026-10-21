import 'dart:async';
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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:snap_fit/features/notification/domain/entities/app_notification_item.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/notification/presentation/views/notification_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/notification_settings_screen.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Action extends Mock implements NotificationAction {}

class _InboxOwner extends Notifier<String> {
  @override
  String build() => 'alice';
  void change(String value) => state = value;
}

final _inboxOwnerProvider = NotifierProvider<_InboxOwner, String>(
  _InboxOwner.new,
);

class _Messaging extends FirebaseMessagingPlatform {
  int settingsReads = 0;
  int permissionRequests = 0;
  int tokenRequests = 0;

  @override
  FirebaseMessagingPlatform delegateFor({FirebaseApp? app}) => this;

  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    tokenRequests++;
    return 'unused-fixture-token';
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
    return _settings;
  }

  @override
  Future<NotificationSettings> getNotificationSettings() async {
    settingsReads++;
    return _settings;
  }

  static const _settings = NotificationSettings(
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
}

List<AppNotificationItem> _items({
  int count = 12,
  int start = 1,
  String label = '우리의 여름 기록',
}) => List.generate(count, (index) {
  final today = DateTime.now();
  return AppNotificationItem(
    id: start + index,
    type: index.isEven ? 'album_comment' : 'order_status',
    title: '$label ${index + 1}',
    body: index.isEven
        ? '함께 남긴 장면에 새 댓글이 남았어요. 앨범에서 소식을 확인해 보세요.'
        : '주문한 앨범의 제작이 진행되고 있어요. 주문 내역에서 확인해 보세요.',
    createdAt: DateTime(
      today.year,
      today.month,
      today.day,
      12,
    ).subtract(Duration(minutes: index)),
    isRead: index.isOdd,
    userId: 'inbox-connections-fixture',
  );
});

_Action _action() {
  final action = _Action();
  when(action.markAllRead).thenAnswer((_) async {});
  when(() => action.markRead(any())).thenAnswer((_) async {});
  return action;
}

void main() {
  _PaintBinding();
  setupFirebaseCoreMocks();
  final boundary = GlobalKey();
  final messaging = _Messaging();
  final networkCalls = <http.Request>[];
  late FirebaseMessagingPlatform originalMessaging;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await loadCreationFonts();
    await Firebase.initializeApp();
    originalMessaging = FirebaseMessagingPlatform.instance;
    FirebaseMessagingPlatform.instance = messaging;
    await Supabase.initialize(
      url: 'https://inbox-connections.invalid',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        networkCalls.add(request);
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    // The service retains SDK futures across screens. Initialize them outside
    // individual widget-test fake clocks, as an app-wide service would be.
    await FcmNotificationService.loadSettings();
  });

  tearDownAll(() async {
    FirebaseMessagingPlatform.instance = originalMessaging;
    await Supabase.instance.dispose();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    networkCalls.clear();
    messaging.settingsReads = 0;
    messaging.permissionRequests = 0;
    messaging.tokenRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    expect(
      networkCalls,
      isEmpty,
      reason: 'UI checks do not send HTTP requests',
    );
    expect(messaging.permissionRequests, 0);
    expect(messaging.tokenRequests, 0);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Finder key(String value) => find.byKey(ValueKey(value));
  Finder inboxScroll() => find
      .descendant(
        of: find.byKey(const PageStorageKey('inbox-list')),
        matching: find.byType(Scrollable),
      )
      .first;

  void metrics(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = size.width > size.height
        ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
        : const FakeViewPadding(top: 24, bottom: 34);
  }

  void viewport(WidgetTester tester, [Size size = const Size(390, 844)]) {
    metrics(tester, size);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
  }

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    Future<List<AppNotificationItem>> Function()? inbox,
    Future<List<AppNotificationItem>> Function(Ref ref)? watchedInbox,
    Future<int> Function()? unread,
    _Action? action,
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          notificationInboxProvider.overrideWith(
            (ref) =>
                watchedInbox?.call(ref) ??
                inbox?.call() ??
                Future.value(_items()),
          ),
          notificationUnreadCountProvider.overrideWith(
            (_) => unread?.call() ?? Future.value(6),
          ),
          notificationRetentionDaysProvider.overrideWith((_) async => 90),
          notificationActionProvider.overrideWithValue(action ?? _action()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
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
    return ProviderScope.containerOf(
      tester.element(find.byType(NotificationScreen)),
    );
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    // Shared SDK/storage futures can originate in a previous real async zone.
    // Keep pumping both zones until the actual settings form has resolved.
    await tester.pump();
    for (
      var attempt = 0;
      attempt < 8 &&
          find.byType(NotificationSettingsContent).evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  void safe(WidgetTester tester, Finder finder, Size size) {
    final rect = tester.getRect(finder);
    final landscape = size.width > size.height;
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.left, greaterThanOrEqualTo(landscape ? 32 : 0));
    expect(rect.right, lessThanOrEqualTo(size.width - (landscape ? 48 : 0)));
    expect(rect.top, greaterThanOrEqualTo(landscape ? 0 : 24));
    expect(rect.bottom, lessThanOrEqualTo(size.height - (landscape ? 24 : 34)));
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark,
  ) async {
    expect(tester.takeException(), isNull, reason: name);
    if (!const bool.fromEnvironment('NOTIFICATION_CONNECTIONS_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('output/all-screens-qa')
        ..createSync(recursive: true);
      File(
        '${dir.path}/inbox-connect-$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> settingsJourney(
    WidgetTester tester,
    Size size,
    bool dark, {
    bool large = false,
  }) async {
    viewport(tester, size);
    await mount(tester, dark: dark, scale: large ? 1.8 : 1);
    expect(find.byTooltip('알림 새로고침'), findsOneWidget);
    expect(find.byTooltip('알림 설정'), findsOneWidget);
    safe(tester, key('inbox-refresh'), size);
    safe(tester, key('inbox-settings'), size);
    safe(tester, key('inbox-mark-all'), size);
    expect(find.text('새로운 소식'), findsOneWidget);
    expect(key('inbox-item-1'), findsOneWidget);
    await capture(tester, large ? 'inbox-large' : 'inbox', size, dark);
    await tap(tester, key('inbox-settings'));
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    expect(find.byType(NotificationSettingsContent), findsOneWidget);
    expect(find.text('알림 설정'), findsOneWidget);
    expect(find.text('전체 알림'), findsOneWidget);
    expect(find.text('기기 알림이 꺼져 있어요'), findsOneWidget);
    expect(find.byTooltip('알림 새로고침'), findsNothing);
    await capture(tester, large ? 'settings-large' : 'settings', size, dark);
    await tester.scrollUntilVisible(
      find.text('야간 알림 끄기'),
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('notification-preferences')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('야간 알림 끄기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tap(tester, find.byTooltip('뒤로가기'));
    expect(find.byType(NotificationSettingsScreen), findsNothing);
    expect(key('inbox-item-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('inbox connects to real settings at $size dark=$dark', (
        tester,
      ) async {
        await settingsJourney(tester, size, dark);
      });
    }
  }

  for (final size in [const Size(320, 568), const Size(648, 320)]) {
    for (final dark in [false, true]) {
      testWidgets('inbox and settings support 1.8 text at $size dark=$dark', (
        tester,
      ) async {
        await settingsJourney(tester, size, dark, large: true);
      });
    }
  }

  testWidgets('inbox announces each read state with its actionable content', (
    tester,
  ) async {
    viewport(tester);
    final semantics = tester.ensureSemantics();
    try {
      var items = _items(count: 2);
      final container = await mount(tester, inbox: () async => items);

      void checkItem(int id, String state) {
        final node = tester.getSemantics(key('inbox-item-$id'));
        final data = node.getSemanticsData();
        expect(data.value, state);
        expect(data.label, contains(items[id - 1].title));
        expect(data.label, contains(items[id - 1].body));
        expect(data.hasAction(ui.SemanticsAction.tap), true);
      }

      checkItem(1, '읽지 않음');
      checkItem(2, '읽음');
      items = [items.first.copyWith(isRead: true), items.last];
      container.invalidate(notificationInboxProvider);
      await tester.pumpAndSettle();
      checkItem(1, '읽음');
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('settings round trip preserves list position through rotation', (
    tester,
  ) async {
    viewport(tester);
    await mount(tester, inbox: () async => _items(count: 60));
    await tester.scrollUntilVisible(
      key('inbox-item-24'),
      250,
      scrollable: inboxScroll(),
    );
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(inboxScroll()).position.pixels;
    expect(before, greaterThan(1000));
    await tap(tester, key('inbox-settings'));
    expect(find.byType(NotificationSettingsContent), findsOneWidget);
    metrics(tester, const Size(648, 320));
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('뒤로가기'));
    expect(
      tester.state<ScrollableState>(inboxScroll()).position.pixels,
      greaterThan(1000),
    );
    expect(key('inbox-item-1'), findsNothing);
    metrics(tester, const Size(390, 844));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(inboxScroll()).position.pixels,
      closeTo(before, 1),
    );
    expect(messaging.settingsReads, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh waits for list and unread and rejects stale callbacks', (
    tester,
  ) async {
    viewport(tester);
    var inboxReads = 0;
    var unreadReads = 0;
    final pendingInbox = Completer<List<AppNotificationItem>>();
    final pendingUnread = Completer<int>();
    final action = _action();
    final container = await mount(
      tester,
      action: action,
      inbox: () =>
          ++inboxReads == 1 ? Future.value(_items()) : pendingInbox.future,
      unread: () {
        unreadReads++;
        return pendingUnread.future;
      },
    );
    final refresh = tester.widget<IconButton>(key('inbox-refresh')).onPressed!;
    final markAll = tester.widget<TextButton>(key('inbox-mark-all')).onPressed!;
    refresh();
    refresh();
    markAll();
    await tester.pump();
    expect(inboxReads, 2);
    expect(unreadReads, 1);
    expect(key('inbox-item-1'), findsOneWidget);
    expect(tester.widget<IconButton>(key('inbox-refresh')).onPressed, isNull);
    expect(tester.widget<TextButton>(key('inbox-mark-all')).onPressed, isNull);
    verifyNever(action.markAllRead);
    await capture(tester, 'refreshing', const Size(390, 844), false);
    metrics(tester, const Size(648, 320));
    await tester.pump();
    pendingInbox.complete(_items(start: 101, label: '새로 도착한 소식'));
    await tester.pump();
    await tester.pump();
    expect(key('inbox-item-101'), findsOneWidget);
    expect(tester.widget<IconButton>(key('inbox-refresh')).onPressed, isNull);
    pendingUnread.complete(3);
    await tester.pumpAndSettle();
    expect(await container.read(notificationUnreadCountProvider.future), 3);
    expect(
      tester.widget<IconButton>(key('inbox-refresh')).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<TextButton>(key('inbox-mark-all')).onPressed,
      isNotNull,
    );
    expect(inboxReads, 2);
    expect(unreadReads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty inbox can refresh into new notifications and unread count',
    (tester) async {
      viewport(tester);
      var inboxReads = 0;
      var unreadReads = 0;
      final container = await mount(
        tester,
        inbox: () async => ++inboxReads == 1 ? [] : _items(start: 101),
        unread: () async {
          unreadReads++;
          return 6;
        },
      );
      expect(find.text('알림이 없습니다.'), findsOneWidget);
      expect(
        tester.widget<TextButton>(key('inbox-mark-all')).onPressed,
        isNull,
      );
      await capture(tester, 'empty', const Size(390, 844), false);
      await tap(tester, key('inbox-refresh'));
      expect(find.text('알림이 없습니다.'), findsNothing);
      expect(key('inbox-item-101'), findsOneWidget);
      expect(inboxReads, 2);
      expect(unreadReads, 1);
      expect(await container.read(notificationUnreadCountProvider.future), 6);
      expect(
        tester.widget<TextButton>(key('inbox-mark-all')).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'error retry refreshes list and unread with duplicate protection',
    (tester) async {
      viewport(tester);
      var inboxReads = 0;
      var unreadReads = 0;
      final pending = Completer<List<AppNotificationItem>>();
      await mount(
        tester,
        inbox: () {
          if (++inboxReads == 1) {
            return Future.error(StateError('private-server-error'));
          }
          return pending.future;
        },
        unread: () async {
          unreadReads++;
          return 2;
        },
      );
      expect(find.text('알림을 불러오지 못했어요.'), findsOneWidget);
      expect(find.textContaining('private-server-error'), findsNothing);
      await capture(tester, 'load-error', const Size(390, 844), false);
      final retry = tester
          .widget<OutlinedButton>(key('inbox-retry'))
          .onPressed!;
      final refresh = tester
          .widget<IconButton>(key('inbox-refresh'))
          .onPressed!;
      retry();
      refresh();
      retry();
      await tester.pump();
      expect(inboxReads, 2);
      expect(unreadReads, 1);
      expect(tester.widget<IconButton>(key('inbox-refresh')).onPressed, isNull);
      pending.complete(_items(start: 101));
      await tester.pumpAndSettle();
      expect(key('inbox-item-101'), findsOneWidget);
      expect(key('inbox-retry'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed refresh preserves the scrolled list and offers retry', (
    tester,
  ) async {
    viewport(tester);
    var reads = 0;
    await mount(
      tester,
      inbox: () async {
        reads++;
        if (reads == 2) throw StateError('private-refresh-error');
        return _items(count: 60, label: reads == 1 ? '우리의 기록' : '다시 받은 기록');
      },
    );
    await tester.scrollUntilVisible(
      key('inbox-item-20'),
      250,
      scrollable: inboxScroll(),
    );
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(inboxScroll()).position.pixels;
    await tap(tester, key('inbox-refresh'));
    expect(find.byKey(const PageStorageKey('inbox-list')), findsOneWidget);
    expect(key('inbox-item-1'), findsNothing);
    expect(
      tester.state<ScrollableState>(inboxScroll()).position.pixels,
      closeTo(before, 1),
    );
    expect(find.text('알림을 새로고침하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
    expect(find.textContaining('private-refresh-error'), findsNothing);
    expect(
      tester.widget<IconButton>(key('inbox-refresh')).onPressed,
      isNotNull,
    );
    await capture(tester, 'refresh-error', const Size(390, 844), false);
    await tap(tester, key('inbox-refresh'));
    expect(reads, 3);
    expect(find.textContaining('다시 받은 기록'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unread-only failure leaves the refreshed list usable for retry',
    (tester) async {
      viewport(tester);
      var inboxReads = 0;
      var unreadReads = 0;
      await mount(
        tester,
        inbox: () async => _items(start: 1 + 100 * inboxReads++),
        unread: () async {
          if (++unreadReads == 1) throw StateError('private-unread-error');
          return 2;
        },
      );
      await tap(tester, key('inbox-refresh'));
      expect(key('inbox-item-101'), findsOneWidget);
      expect(find.text('알림을 새로고침하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
      expect(find.textContaining('private-unread-error'), findsNothing);
      expect(
        tester.widget<IconButton>(key('inbox-refresh')).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<TextButton>(key('inbox-mark-all')).onPressed,
        isNotNull,
      );
      await tap(tester, key('inbox-refresh'));
      expect(key('inbox-item-201'), findsOneWidget);
      expect(unreadReads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a list failure retains items while unread refresh is pending', (
    tester,
  ) async {
    viewport(tester);
    var reads = 0;
    final pendingInbox = Completer<List<AppNotificationItem>>();
    final pendingUnread = Completer<int>();
    await mount(
      tester,
      inbox: () => ++reads == 1 ? Future.value(_items()) : pendingInbox.future,
      unread: () => pendingUnread.future,
    );
    await tester.tap(key('inbox-refresh'));
    await tester.pump();
    pendingInbox.completeError(StateError('private-list-error'));
    await tester.pump();
    await tester.pump();
    expect(key('inbox-item-1'), findsOneWidget);
    expect(find.text('알림을 불러오지 못했어요.'), findsNothing);
    expect(tester.widget<IconButton>(key('inbox-refresh')).onPressed, isNull);
    pendingUnread.complete(6);
    await tester.pumpAndSettle();
    expect(key('inbox-item-1'), findsOneWidget);
    expect(find.text('알림을 새로고침하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
    expect(
      tester.widget<IconButton>(key('inbox-refresh')).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mark-all blocks refresh callbacks until its failed request ends',
    (tester) async {
      viewport(tester);
      final action = _action();
      final pending = Completer<void>();
      when(action.markAllRead).thenAnswer((_) => pending.future);
      var reads = 0;
      await mount(
        tester,
        action: action,
        inbox: () async {
          reads++;
          return _items();
        },
      );
      final refresh = tester
          .widget<IconButton>(key('inbox-refresh'))
          .onPressed!;
      await tester.tap(key('inbox-mark-all'));
      await tester.pump();
      refresh();
      await tester.pump();
      expect(tester.widget<IconButton>(key('inbox-refresh')).onPressed, isNull);
      expect(reads, 1);
      verify(action.markAllRead).called(1);
      pending.completeError(StateError('private-mark-all-error'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<IconButton>(key('inbox-refresh')).onPressed,
        isNotNull,
      );
      expect(find.text('읽음 처리를 완료하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
      await tap(tester, key('inbox-refresh'));
      expect(reads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh completion after leaving inbox has no stale UI effects',
    (tester) async {
      viewport(tester);
      var reads = 0;
      final pendingInbox = Completer<List<AppNotificationItem>>();
      final pendingUnread = Completer<int>();
      await mount(
        tester,
        inbox: () =>
            ++reads == 1 ? Future.value(_items()) : pendingInbox.future,
        unread: () => pendingUnread.future,
      );
      await tester.tap(key('inbox-refresh'));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: Text('다른 화면')));
      pendingInbox.completeError(StateError('disposed-inbox-error'));
      pendingUnread.completeError(StateError('disposed-unread-error'));
      await tester.pumpAndSettle();
      expect(find.text('다른 화면'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account reload rejects old lists and stale refresh errors', (
    tester,
  ) async {
    viewport(tester);
    var reads = 0;
    final container = await mount(
      tester,
      watchedInbox: (ref) async {
        final owner = ref.watch(_inboxOwnerProvider);
        if (++reads == 1) return _items(label: '이전 계정의 소식');
        throw StateError('$owner-private-error');
      },
    );
    await tap(tester, key('inbox-refresh'));
    expect(key('inbox-item-1'), findsOneWidget);
    container.read(_inboxOwnerProvider.notifier).change('bob');
    await tester.pumpAndSettle();
    expect(key('inbox-item-1'), findsNothing);
    expect(find.textContaining('이전 계정의 소식'), findsNothing);
    expect(find.text('알림을 불러오지 못했어요.'), findsOneWidget);
    await tap(tester, key('inbox-refresh'));
    expect(key('inbox-item-1'), findsNothing);
    expect(find.textContaining('이전 계정의 소식'), findsNothing);
    expect(find.text('알림을 불러오지 못했어요.'), findsOneWidget);

    final pending = Completer<List<AppNotificationItem>>();
    reads = 0;
    final nextContainer = await mount(
      tester,
      watchedInbox: (ref) {
        final owner = ref.watch(_inboxOwnerProvider);
        if (owner == 'bob') return Future.error(StateError('new-owner-error'));
        return ++reads == 1
            ? Future.value(_items(label: '이전 계정의 소식'))
            : pending.future;
      },
    );
    await tester.tap(key('inbox-refresh'));
    await tester.pump();
    nextContainer.read(_inboxOwnerProvider.notifier).change('bob');
    await tester.pump();
    await tester.pump();
    pending.completeError(StateError('stale-refresh-error'));
    await tester.pumpAndSettle();
    expect(key('inbox-item-1'), findsNothing);
    expect(find.textContaining('이전 계정의 소식'), findsNothing);
    expect(find.text('알림을 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('알림을 새로고침하지 못했어요. 다시 시도해주세요.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
