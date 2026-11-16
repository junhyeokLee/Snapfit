// 읽기 전용 UX 증거용. 실제 화면과 provider를 쓰고 계정/저장소만 로컬 대역으로 둔다.
import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/notification/data/notification_repository.dart';
import 'package:snap_fit/features/notification/domain/entities/app_notification_item.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/notification/presentation/views/notification_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/notification_settings_screen.dart';

import 'capture_support.dart';

const _owner = '11111111-1111-4111-8111-111111111111';

class _Auth extends AuthViewModel {
  @override
  UserInfo? build() => const UserInfo(
    id: _owner,
    name: '로컬 검수',
    provider: 'EMAIL',
  );
}

class _Messaging extends FirebaseMessagingPlatform {
  @override
  FirebaseMessagingPlatform delegateFor({FirebaseApp? app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
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
        showPreviews: AppleShowPreviewSetting.always,
        timeSensitive: AppleNotificationSetting.disabled,
        criticalAlert: AppleNotificationSetting.disabled,
        sound: AppleNotificationSetting.disabled,
        providesAppNotificationSettings: AppleNotificationSetting.disabled,
      );
}

List<AppNotificationItem> _items() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 12);
  return [
    AppNotificationItem(
      id: 1,
      type: 'social_comment',
      title: '공개한 기록에 새 댓글이 달렸어요',
      body: '함께 걷던 오후에 새 댓글이 남았어요. 댓글을 확인해 보세요.',
      createdAt: today,
      isRead: false,
      userId: _owner,
      data: const {'workId': '33333333-3333-4333-8333-333333333333'},
    ),
    AppNotificationItem(
      id: 2,
      type: 'order_status',
      title: '주문 상태가 변경되었어요',
      body: '주문한 앨범의 제작이 시작되었어요.',
      createdAt: today.subtract(const Duration(hours: 1)),
      isRead: true,
      userId: _owner,
      data: const {'orderId': 'local-order'},
    ),
    AppNotificationItem(
      id: 3,
      type: 'invite_accepted',
      title: '공유 앨범 알림',
      body: '우리의 여름 기록 앨범에 새 멤버가 참여했어요.',
      createdAt: today.subtract(const Duration(hours: 2)),
      isRead: false,
      userId: _owner,
      data: const {'albumId': 101},
    ),
    for (var index = 4; index <= 16; index++)
      AppNotificationItem(
        id: index,
        type: index.isEven ? 'template_new' : 'album_comment',
        title: index.isEven ? '새 템플릿이 등록됐어요' : '앨범에 새 댓글이 남았어요',
        body: index.isEven
            ? '도시의 수집가 템플릿을 확인해보세요.'
            : '함께 남긴 장면에 새 댓글이 남았어요. 앨범에서 소식을 확인해 보세요.',
        createdAt: today.subtract(Duration(days: index ~/ 4, minutes: index)),
        isRead: index % 3 != 0,
        userId: _owner,
        data: index.isEven ? {'templateId': 12} : {'albumId': 101},
      ),
  ];
}

class _Repository extends NotificationRepository {
  _Repository() : super(tokenStorage: TokenStorage());
  List<AppNotificationItem> items = _items();
  int reads = 0;
  int marks = 0;
  bool readFails = false;
  bool markFails = false;
  Completer<void>? markGate;

  @override
  Future<List<AppNotificationItem>> fetchInbox({int limit = 50}) async {
    reads++;
    if (readFails) throw StateError('local-audit-private-inbox-error');
    return items.take(limit).toList(growable: false);
  }
  @override
  Future<int> fetchUnreadCount() async => items.where((x) => !x.isRead).length;
  @override
  Future<int> fetchRetentionDays() async => 90;
  @override
  Future<void> markAllRead() async {
    marks++;
    await markGate?.future;
    if (markFails) throw StateError('local-audit-private-read-error');
    items = items.map((x) => x.copyWith(isRead: true)).toList(growable: false);
  }
  @override
  Future<void> markRead(int notificationId) async {
    items = [
      for (final item in items)
        item.id == notificationId ? item.copyWith(isRead: true) : item,
    ];
  }
}

void main() {
  setupFirebaseCoreMocks();
  late FirebaseMessagingPlatform previousMessaging;
  final requests = <http.Request>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'push_permission_requested': true});
    FlutterSecureStorage.setMockInitialValues({});
    await auditFonts();
    await Firebase.initializeApp();
    previousMessaging = FirebaseMessagingPlatform.instance;
    FirebaseMessagingPlatform.instance = _Messaging();
    await Supabase.initialize(
      url: 'https://next-notifications.invalid',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        // HTTP는 로컬 핸들러가 받는다. 수신 설정 읽기 이외의 호출은 금지한다.
        requests.add(request);
        if (request.method != 'GET' ||
            !request.url.path.endsWith('/push_preferences')) {
          throw StateError('unexpected local audit request');
        }
        return http.Response(
          jsonEncode({
            'user_id': _owner,
            'all_enabled': true,
            'order_enabled': true,
            'invite_enabled': true,
            'comment_enabled': false,
            'marketing_enabled': false,
            'new_template_enabled': true,
            'night_mute': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final jwt =
        '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.'
        '${base64Url.encode(utf8.encode(jsonEncode({'sub': _owner, 'exp': expiry, 'role': 'authenticated'})))}.fixture';
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
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
    }));
    // 프로세스 범위 SDK future를 실제 비동기 영역에서 먼저 완료한다.
    await FcmNotificationService.loadSettings();
  });

  tearDownAll(() async {
    expect(requests.every((x) => x.method == 'GET'), isTrue);
    FirebaseMessagingPlatform.instance = previousMessaging;
    await Supabase.instance.dispose();
  });

  Future<void> mount(
    WidgetTester tester,
    _Repository repository, {
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(ProviderScope(
      retry: (_, __) => null,
      overrides: [
        authViewModelProvider.overrideWith(_Auth.new),
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: auditFrame(child!),
          ),
          home: const NotificationScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  void recordSnackColors(WidgetTester tester, String message) {
    final textElement = tester.element(find.text(message));
    final textStyle = DefaultTextStyle.of(textElement).style;
    final snackFinder = find.ancestor(
      of: find.text(message),
      matching: find.byType(SnackBar),
    );
    final snack = tester.widget<SnackBar>(snackFinder.first);
    final theme = Theme.of(textElement);
    final foreground = textStyle.color!;
    final background = snack.backgroundColor ?? theme.snackBarTheme.backgroundColor!;
    final light = foreground.computeLuminance();
    final dark = background.computeLuminance();
    final contrast = (light > dark ? light + .05 : dark + .05) /
        (light > dark ? dark + .05 : light + .05);
    String hex(Color color) =>
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    // 실제 Text가 상속한 값으로 기록한다. 스크린샷 픽셀 확인과 교차 검증한다.
    debugPrint(
      'NOTIFICATION_ERROR_COLORS '
      'brightness=${theme.brightness.name} '
      'foreground=${hex(foreground)} background=${hex(background)} '
      'fontSize=${textStyle.fontSize} fontWeight=${textStyle.fontWeight} '
      'contrast=${contrast.toStringAsFixed(4)}',
    );
  }

  testWidgets('next audit notification mixed, refresh and mark all', (tester) async {
    auditViewport(tester);
    final repository = _Repository();
    await mount(tester, repository);
    expect(find.byKey(const ValueKey('inbox-item-1')), findsOneWidget);
    expect(repository.reads, 1);
    await auditCapture(tester, 'notifications-01-mixed');
    await tester.tap(find.byKey(const ValueKey('inbox-refresh')));
    await tester.pumpAndSettle();
    expect(repository.reads, 2);
    repository.markGate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('inbox-mark-all')));
    await tester.pump();
    expect(find.text('읽음 처리 중'), findsOneWidget);
    expect(repository.marks, 1);
    await auditCapture(tester, 'notifications-02-marking-all', settle: false);
    repository.markGate!.complete();
    await tester.pumpAndSettle();
    expect(repository.items.every((x) => x.isRead), isTrue);
    expect(
      tester.widget<TextButton>(find.byKey(const ValueKey('inbox-mark-all'))).onPressed,
      isNull,
    );
    await auditCapture(tester, 'notifications-03-all-read');
    final scrollable = find.descendant(
      of: find.byKey(const PageStorageKey('inbox-list')),
      matching: find.byType(Scrollable),
    ).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('inbox-item-12')),
      250,
      scrollable: scrollable,
    );
    await auditCapture(tester, 'notifications-04-older-section');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('next audit notification narrow dark large text settings round trip', (tester) async {
    auditViewport(tester, size: const Size(320, 568));
    final repository = _Repository();
    await mount(tester, repository, dark: true, scale: 1.8);
    await auditCapture(tester, 'notifications-05-dark-narrow-large');
    await tester.tap(find.byKey(const ValueKey('inbox-settings')));
    // SDK queue 영역을 번갈아 진행하며 로딩 화면 무한 settle을 피한다.
    for (var attempt = 0;
        attempt < 20 && find.byType(NotificationSettingsContent).evaluate().isEmpty;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
    }
    expect(find.byType(NotificationSettingsContent), findsOneWidget);
    expect(find.text('기기 알림이 꺼져 있어요'), findsOneWidget);
    await auditCapture(tester, 'notifications-06-settings-denied-large');
    await tester.scrollUntilVisible(
      find.text('야간 알림 끄기'),
      140,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey('notification-preferences')),
        matching: find.byType(Scrollable),
      ).first,
    );
    await auditCapture(tester, 'notifications-07-settings-categories-large');
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsNothing);
    expect(find.byKey(const ValueKey('inbox-item-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('next audit notification failure recovery preserves inbox and position', (tester) async {
    auditViewport(tester);
    final repository = _Repository();
    await mount(tester, repository);
    repository.markFails = true;
    await tester.tap(find.byKey(const ValueKey('inbox-mark-all')));
    await tester.pumpAndSettle();
    expect(find.text('읽음 처리를 완료하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
    expect(repository.items.any((x) => !x.isRead), isTrue);
    expect(
      tester.widget<TextButton>(find.byKey(const ValueKey('inbox-mark-all'))).onPressed,
      isNotNull,
    );
    expect(find.textContaining('local-audit-private'), findsNothing);
    recordSnackColors(tester, '읽음 처리를 완료하지 못했어요. 다시 시도해주세요.');
    await auditCapture(tester, 'notifications-08-mark-failed');

    // 같은 버튼으로 재시도하고 실제 action provider의 무효화/다시 읽기까지 확인한다.
    repository.markFails = false;
    await tester.tap(find.byKey(const ValueKey('inbox-mark-all')));
    await tester.pumpAndSettle();
    expect(repository.marks, 2);
    expect(repository.items.every((x) => x.isRead), isTrue);
    final scrollable = find.descendant(
      of: find.byKey(const PageStorageKey('inbox-list')),
      matching: find.byType(Scrollable),
    ).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('inbox-item-12')),
      250,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(0));
    repository.readFails = true;
    await tester.tap(find.byKey(const ValueKey('inbox-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('알림을 새로고침하지 못했어요. 다시 시도해주세요.'), findsOneWidget);
    expect(find.byKey(const PageStorageKey('inbox-list')), findsOneWidget);
    expect(tester.state<ScrollableState>(scrollable).position.pixels, closeTo(before, 1));
    expect(find.text('알림을 불러오지 못했어요.'), findsNothing);
    expect(find.textContaining('local-audit-private'), findsNothing);
    expect(
      tester.widget<IconButton>(find.byKey(const ValueKey('inbox-refresh'))).onPressed,
      isNotNull,
    );
    recordSnackColors(tester, '알림을 새로고침하지 못했어요. 다시 시도해주세요.');
    await auditCapture(tester, 'notifications-09-refresh-failed-retained');

    // 실패 안내의 표시 시간이 지난 뒤 재조회 성공/목록 유지도 확인한다.
    await tester.pump(const Duration(seconds: 8));
    repository.readFails = false;
    final readsBeforeRetry = repository.reads;
    await tester.tap(find.byKey(const ValueKey('inbox-refresh')));
    await tester.pumpAndSettle();
    expect(repository.reads, readsBeforeRetry + 1);
    expect(tester.state<ScrollableState>(scrollable).position.pixels, closeTo(before, 1));
    expect(find.text('알림을 새로고침하지 못했어요. 다시 시도해주세요.'), findsNothing);
    await auditCapture(tester, 'notifications-10-refresh-recovered');
    await tester.pumpWidget(const SizedBox());
  });
}
