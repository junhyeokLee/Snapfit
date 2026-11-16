import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/home_news/data/admin_home_news_repository.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/profile/presentation/providers/safety_management_providers.dart';
import 'package:snap_fit/features/profile/presentation/views/admin_point_shop_management_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/safety_management_screen.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Owner extends Notifier<String?> {
  @override
  String? build() => _a;
  void change(String? value) => state = value;
}

final _owner = NotifierProvider<_Owner, String?>(_Owner.new);

class _Auth extends Mock implements GoTrueClient {}

class _Client extends SupabaseClient {
  _Client(this.fixtureAuth)
    : super(
        'https://safety.invalid',
        'fixture',
        httpClient: MockClient(
          (_) async => throw StateError('Unexpected HTTP'),
        ),
        accessToken: () async => 'fixture',
      );
  final GoTrueClient fixtureAuth;
  @override
  GoTrueClient get auth => fixtureAuth;
}

class _AuthViewModel extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() {
    final id = ref.watch(_owner);
    return id == null
        ? null
        : UserInfo(id: id, name: '나의 계정', provider: 'email');
  }
}

class _Repository extends Mock implements SocialRepository {
  _Repository() {
    final auth = _Auth();
    when(() => auth.currentUser).thenAnswer((_) => session?.user);
    when(() => auth.currentSession).thenAnswer((_) => session);
    client = _Client(auth);
    switchSdk(_a);
  }
  @override
  late final _Client client;
  Session? session;
  int _sessionNumber = 0;
  void switchSdk(String? owner) {
    session = owner == null
        ? null
        : Session(
            accessToken: 'fixture-${_sessionNumber++}',
            tokenType: 'bearer',
            user: User(
              id: owner,
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-10-29',
            ),
          );
  }

  final blocked = <SocialProfile>[_profile('friend', '사진을 담는 친구')];
  FutureOr<List<SocialProfile>> Function(String owner)? blockedLoader;
  FutureOr<SocialReportsPage> Function(String owner, int offset)? reportsLoader;
  Future<void> Function(String target)? unblock;
  final blockedReads = <String>[];
  final reportReads = <(String, int)>[];
  final unblockCalls = <(String, String, bool)>[];
  int followCalls = 0;
  @override
  Future<List<SocialProfile>> fetchBlockedProfiles() async {
    final owner = session!.user.id;
    blockedReads.add(owner);
    return await (blockedLoader?.call(owner) ?? List.of(blocked));
  }

  @override
  Future<SocialReportsPage> fetchOwnReportsPage({
    int offset = 0,
    int limit = 12,
  }) async {
    final owner = session!.user.id;
    reportReads.add((owner, offset));
    return await (reportsLoader?.call(owner, offset) ??
        SocialReportsPage(
          items: [
            _report('one', status: 'open'),
            _report('two', status: 'hidden'),
            _report('three', status: 'dismissed'),
          ],
          hasMore: false,
          nextOffset: 3,
        ));
  }

  @override
  Future<void> setBlocked(String target, bool value) async {
    unblockCalls.add((session!.user.id, target, value));
    await unblock?.call(target);
    blocked.removeWhere((profile) => profile.userId == target);
  }

  @override
  Future<bool> setFollowing(String id, bool value) async {
    followCalls++;
    return value;
  }
}

SocialProfile _profile(
  String id,
  String name, {
  String handle = 'photo.days',
}) => SocialProfile(userId: id, displayName: name, handle: handle);

SocialReport _report(String id, {String status = 'open'}) => SocialReport(
  id: id,
  targetKind: id == 'two'
      ? 'comment'
      : id == 'three'
      ? 'user'
      : 'work',
  targetId: 'hidden-target',
  reason: id == 'two' ? 'spam' : 'privacy',
  details: 'PRIVATE REPORTER NOTE',
  status: status,
  revision: 3,
  createdAt: DateTime(2026, 10, 29, 13, 20),
  targetPreview: const {
    'title': 'PRIVATE TARGET TITLE',
    'body': 'PRIVATE COMMENT',
    'author': {'displayName': 'PRIVATE PERSON'},
  },
  resolutionNote: 'INTERNAL MODERATOR NOTE',
);

void main() {
  _PaintBinding();
  final exceptionReporter = reportTestException;
  setUpAll(() {
    reportTestException = (details, description) {
      // Browser formatting otherwise omits the failing layout/assertion.
      // ignore: avoid_print
      print('Safety failure: ${details.exceptionAsString()}');
      if (details.stack != null) {
        // ignore: avoid_print
        print(details.stack.toString().split('\n').take(12).join('\n'));
      }
      exceptionReporter(details, description);
    };
  });
  tearDownAll(() => reportTestException = exceptionReporter);
  final captureKey = GlobalKey();
  late _Repository repository;
  setUpAll(() async {
    if (!kIsWeb) await loadCreationFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _Repository();
  });
  tearDown(() async => repository.client.dispose());

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    Widget screen = const SafetyManagementScreen(),
    Size size = const Size(390, 844),
    bool dark = false,
    double scale = 1,
    bool settle = true,
    String? actor = _a,
    ValueChanged<WebAppLocation>? onPublicNavigate,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repository.switchSdk(actor);
    final container = ProviderContainer(
      retry: (_, __) => null,
      overrides: [
        socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_owner)),
        visibleOrderOwnerProvider.overrideWith((ref) => ref.watch(_owner)),
        socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
        socialRepositoryProvider.overrideWithValue(repository),
        authViewModelProvider.overrideWith(_AuthViewModel.new),
        notificationUnreadCountProvider.overrideWith((_) async => 0),
        pointShopAdminAccessProvider.overrideWithValue(false),
        adminHomeNewsAccessProvider.overrideWithValue(false),
      ],
    );
    container.read(_owner.notifier).change(actor);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: captureKey, child: child!),
            ),
            home: WebNavigationScope(
              onNavigate: (_) {},
              onNotifications: () {},
              onPublicNavigate: onPublicNavigate,
              child: screen,
            ),
          ),
        ),
      ),
    );
    if (settle)
      await tester.pumpAndSettle();
    else
      await tester.pump();
    return container;
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) =>
      tap(tester, find.byKey(const ValueKey('safety-unblock-confirm')));

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    const path = String.fromEnvironment('SAFETY_MANAGEMENT_CAPTURE_DIR');
    if (kIsWeb || path.isEmpty) return;
    await tester.runAsync(() async {
      final image =
          await (captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(path).createSync(recursive: true);
      File('$path/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('settings entry opens the owner safety destination', (
    tester,
  ) async {
    await mount(tester, screen: const MyPageScreen());
    await tap(tester, find.text('안전 관리'));
    expect(find.byType(SafetyManagementScreen), findsOneWidget);
    expect(find.text('사진을 담는 친구'), findsOneWidget);
    expect(
      ModalRoute.of(
        tester.element(find.byType(SafetyManagementScreen)),
      )!.settings,
      isA<WebAppRouteSettings>().having(
        (settings) => settings.location,
        'location',
        WebAppLocation.safety,
      ),
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final dark in [false, true]) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(1440, 900),
    ]) {
      testWidgets('owner safety lists remain readable at $size dark=$dark', (
        tester,
      ) async {
        await mount(
          tester,
          size: size,
          dark: dark,
          scale: size.width == 320 ? 1.8 : 1,
        );
        final action = find.byKey(const ValueKey('safety-unblock-friend'));
        final blockedScroll = find
            .descendant(
              of: find.byKey(const ValueKey('safety-list-$_a-blocked')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(action, 120, scrollable: blockedScroll);
        await tester.pumpAndSettle();
        expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
        await capture(
          tester,
          'blocked-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        tester.state<ScrollableState>(blockedScroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tap(tester, find.byKey(const ValueKey('safety-tab-reports')));
        final reportsScroll = find
            .descendant(
              of: find.byKey(const ValueKey('safety-list-$_a-reports')),
              matching: find.byType(Scrollable),
            )
            .first;
        for (final label in ['접수됨', '조치 완료', '확인 완료']) {
          await tester.scrollUntilVisible(
            find.text(label),
            120,
            scrollable: reportsScroll,
          );
          await tester.pumpAndSettle();
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('개인정보 노출'), findsWidgets);
        expect(find.textContaining('접수 2026.10.29'), findsWidgets);
        for (final secret in [
          'PRIVATE TARGET TITLE',
          'PRIVATE COMMENT',
          'PRIVATE PERSON',
          'INTERNAL MODERATOR NOTE',
        ]) {
          expect(find.textContaining(secret), findsNothing);
        }
        tester.state<ScrollableState>(reportsScroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        await capture(
          tester,
          'reports-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        if (kIsWeb) {
          expect(
            find.byKey(const ValueKey('web-utility-header')),
            findsOneWidget,
          );
          if (size.width < 1100) {
            expect(
              find.byKey(const ValueKey('web-navigation-account')),
              findsNothing,
            );
            await tap(
              tester,
              find.byKey(const ValueKey('web-navigation-menu')),
            );
          }
          final account = find.byKey(const ValueKey('web-navigation-account'));
          await tester.ensureVisible(account);
          await tester.pumpAndSettle();
          expect(account, findsOneWidget);
          expect(tester.getSize(account).height, greaterThanOrEqualTo(44));
          expect(
            tester
                .widget<Semantics>(
                  find
                      .descendant(
                        of: find.byKey(
                          const ValueKey('web-navigation-semantics-account'),
                        ),
                        matching: find.byType(Semantics),
                      )
                      .first,
                )
                .properties
                .selected,
            isTrue,
          );
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
    'unblock confirmation is single-use and never restores following',
    (tester) async {
      final waiting = Completer<void>();
      repository.unblock = (_) => waiting.future;
      await mount(tester);
      await tap(tester, find.byKey(const ValueKey('safety-unblock-friend')));
      expect(repository.unblockCalls, isEmpty);
      final decide = tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('safety-unblock-confirm')),
          )
          .onPressed!;
      decide();
      decide();
      await tester.pumpAndSettle();
      expect(repository.unblockCalls, [(_a, 'friend', false)]);
      expect(find.byType(SafetyManagementScreen), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('safety-unblock-friend')),
            )
            .onPressed,
        isNull,
      );
      waiting.complete();
      await tester.pumpAndSettle();
      expect(find.text('차단한 사용자가 없어요.'), findsOneWidget);
      expect(repository.followCalls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'ambiguous unblock failure rechecks the list and permits an explicit retry',
    (tester) async {
      repository.unblock = (_) async => throw StateError('offline');
      await mount(tester);
      await tap(tester, find.byKey(const ValueKey('safety-unblock-friend')));
      await confirm(tester);
      expect(find.byKey(const ValueKey('safety-action-error')), findsOneWidget);
      expect(find.text('사진을 담는 친구'), findsOneWidget);
      repository.unblock = (_) async {};
      await tap(tester, find.byKey(const ValueKey('safety-unblock-friend')));
      await confirm(tester);
      expect(repository.unblockCalls.length, 2);
      expect(find.text('차단한 사용자가 없어요.'), findsOneWidget);
      expect(repository.followCalls, 0);
    },
  );

  testWidgets(
    'inactive profile fallback retains the real target unblock action',
    (tester) async {
      repository.blocked
        ..clear()
        ..add(_profile('inactive', '', handle: ''));
      await mount(tester);
      expect(find.text('프로필 정보가 없는 사용자'), findsOneWidget);
      expect(find.text('@'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('safety-unblock-inactive')));
      await confirm(tester);
      expect(repository.unblockCalls, [(_a, 'inactive', false)]);
    },
  );

  testWidgets('blocked read failure retries without changing destinations', (
    tester,
  ) async {
    repository.blockedLoader = (_) => throw StateError('offline');
    await mount(tester);
    expect(find.text('차단 목록을 불러오지 못했어요.'), findsOneWidget);
    repository.blockedLoader = (_) => List.of(repository.blocked);
    await tap(tester, find.widgetWithText(OutlinedButton, '다시 확인'));
    expect(find.text('사진을 담는 친구'), findsOneWidget);
    expect(repository.blockedReads.length, 2);
  });

  testWidgets(
    'report pagination deduplicates and retries only the failed exact page',
    (tester) async {
      var failSecond = true;
      repository.reportsLoader = (_, offset) {
        if (offset == 0)
          return SocialReportsPage(
            items: [_report('one')],
            hasMore: true,
            nextOffset: 12,
          );
        if (failSecond) throw StateError('offline');
        return SocialReportsPage(
          items: [
            _report('one'),
            _report('two', status: 'hidden'),
          ],
          hasMore: false,
          nextOffset: 14,
        );
      };
      await mount(
        tester,
        screen: const SafetyManagementScreen(initialReports: true),
      );
      await tap(tester, find.byKey(const ValueKey('safety-reports-more')));
      expect(find.byKey(const ValueKey('safety-report-one')), findsOneWidget);
      expect(find.text('신고 내역을 불러오지 못했어요.'), findsOneWidget);
      failSecond = false;
      await tap(tester, find.widgetWithText(OutlinedButton, '다시 확인'));
      expect(find.byKey(const ValueKey('safety-report-one')), findsOneWidget);
      expect(find.byKey(const ValueKey('safety-report-two')), findsOneWidget);
      expect(repository.reportReads, [(_a, 0), (_a, 12), (_a, 12)]);
      expect(repository.blockedReads, isEmpty);
    },
  );

  testWidgets(
    'old owner load cannot return after an A B A session replacement',
    (tester) async {
      final old = Completer<List<SocialProfile>>();
      var readsA = 0;
      repository.blockedLoader = (owner) => owner == _a && readsA++ == 0
          ? old.future
          : [_profile(owner, owner == _a ? '새로운 A 목록' : 'B 목록')];
      final container = await mount(tester, settle: false);
      repository.switchSdk(_b);
      container.read(_owner.notifier).change(_b);
      await tester.pumpAndSettle();
      expect(find.text('B 목록'), findsOneWidget);
      repository.switchSdk(_a);
      container.read(_owner.notifier).change(_a);
      await tester.pumpAndSettle();
      old.complete([_profile('stale', '이전 A 개인정보')]);
      await tester.pumpAndSettle();
      expect(find.text('새로운 A 목록'), findsOneWidget);
      expect(find.text('이전 A 개인정보'), findsNothing);
    },
  );

  testWidgets(
    'SDK-only account change fences an old action before auth providers notify',
    (tester) async {
      await mount(tester);
      final oldAction = tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('safety-unblock-friend')),
          )
          .onPressed!;
      repository.switchSdk(_b);
      oldAction();
      await tester.pump();
      expect(repository.unblockCalls, isEmpty);
      expect(
        find.byKey(const ValueKey('safety-unblock-confirm')),
        findsNothing,
      );
    },
  );

  testWidgets('SDK-only account change refuses a new old-owner report query', (
    tester,
  ) async {
    final container = await mount(tester);
    repository.switchSdk(_b);
    final page = await container.read(
      safetyOwnReportsProvider(const SocialPageQuery(ownerId: _a)).future,
    );
    expect(page.items, isEmpty);
    expect(repository.reportReads, isEmpty);
  });

  testWidgets(
    'SDK-only account change suppresses a late read before any B query starts',
    (tester) async {
      final waiting = Completer<List<SocialProfile>>();
      repository.blockedLoader = (_) => waiting.future;
      await mount(tester, settle: false);
      repository.switchSdk(_b);
      waiting.complete([_profile('stale', '이전 계정 개인정보')]);
      await tester.pumpAndSettle();
      expect(find.text('이전 계정 개인정보'), findsNothing);
      expect(find.text('로그인하고 안전 관리를 확인하세요.'), findsOneWidget);
      expect(repository.blockedReads, [_a]);
    },
  );

  testWidgets(
    'late unblock after account replacement neither refreshes B nor shows A success',
    (tester) async {
      final waiting = Completer<void>();
      repository.unblock = (_) => waiting.future;
      repository.blockedLoader = (owner) => [
        _profile(owner, owner == _a ? 'A 대상' : 'B 대상'),
      ];
      final container = await mount(tester);
      await tap(tester, find.byKey(const ValueKey('safety-unblock-$_a')));
      await confirm(tester);
      repository.switchSdk(_b);
      container.read(_owner.notifier).change(_b);
      await tester.pumpAndSettle();
      final reads = repository.blockedReads.length;
      waiting.complete();
      await tester.pumpAndSettle();
      expect(find.text('B 대상'), findsOneWidget);
      expect(repository.blockedReads.length, reads);
      expect(find.text('차단을 해제했어요. 팔로우는 자동으로 복원되지 않아요.'), findsNothing);
    },
  );

  testWidgets(
    'a completed unblock refreshes domain cache after its page was removed',
    (tester) async {
      final waiting = Completer<void>();
      repository.unblock = (_) => waiting.future;
      final container = await mount(
        tester,
        screen: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openSafetyManagement(Navigator.of(context)),
                child: const Text('안전 관리 열기'),
              ),
            ),
          ),
        ),
      );
      final subscription = container.listen(
        socialBlockedProfilesProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);
      await container.read(socialBlockedProfilesProvider.future);
      await tap(tester, find.text('안전 관리 열기'));
      await tap(tester, find.byKey(const ValueKey('safety-unblock-friend')));
      await confirm(tester);
      final reads = repository.blockedReads.length;
      Navigator.of(tester.element(find.byType(SafetyManagementScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text('안전 관리 열기'), findsOneWidget);
      waiting.complete();
      await tester.pumpAndSettle();
      expect(
        await container.read(socialBlockedProfilesProvider.future),
        isEmpty,
      );
      expect(repository.blockedReads.length, greaterThan(reads));
      await tap(tester, find.text('안전 관리 열기'));
      expect(find.text('차단한 사용자가 없어요.'), findsOneWidget);
    },
  );

  testWidgets(
    'guest lists never query a repository and can resume the reports tab',
    (tester) async {
      final locations = <WebAppLocation>[];
      await mount(
        tester,
        actor: null,
        screen: const SafetyManagementScreen(initialReports: true),
        onPublicNavigate: locations.add,
      );
      expect(find.text('로그인하고 안전 관리를 확인하세요.'), findsOneWidget);
      expect(repository.blockedReads, isEmpty);
      expect(repository.reportReads, isEmpty);
      if (kIsWeb) {
        await tap(tester, find.widgetWithText(FilledButton, '로그인'));
        expect(locations, [WebAppLocation.safetyReports]);
      }
    },
  );
}
