import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/private_moment_archive_providers.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/widgets/my_moment_archive.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

class _Moments extends Mock implements MomentsRepository {}

class _Archive extends Mock implements PrivateMomentArchiveRepository {}

class _Auth extends AuthViewModel {
  _Auth(this.owner);
  final String owner;
  @override
  FutureOr<UserInfo?> build() => UserInfo(
    id: owner,
    name: 'My account',
    email: 'my@example.test',
    provider: 'EMAIL',
  );
}

MomentMonthSummary _month(
  int month, {
  int year = 2026,
  String owner = 'owner-a',
  int records = 4,
}) => MomentMonthSummary(
  month: DateTime.utc(year, month),
  recordCount: records,
  photoCount: records + 2,
  coverPhoto: MomentPhoto(
    id: 'photo-$year-$month',
    path: '$owner/moments/record-$year-$month/photo.png',
    url: 'https://old-signed.example.test/must-not-be-used.png',
    width: 1200,
    height: 900,
  ),
  latestRecordDate: DateTime.utc(year, month, 10),
);

void main() {
  late _Moments moments;
  late _Archive archive;
  late String? owner;
  late StreamController<String?> auth;
  late StreamController<int> revisions;
  late int epoch;
  late List<PrivateMomentMonthsQuery> reads;
  late FutureOr<List<MomentMonthSummary>> Function(PrivateMomentMonthsQuery)
  load;

  setUp(() {
    owner = 'owner-a';
    epoch = 0;
    moments = _Moments();
    archive = _Archive();
    auth = StreamController<String?>.broadcast(sync: true);
    revisions = StreamController<int>.broadcast(sync: true);
    when(() => moments.currentUserId).thenAnswer((_) => owner);
    when(() => moments.authChanges).thenAnswer((_) => auth.stream);
    when(() => archive.currentUserId).thenAnswer((_) => owner);
    when(() => archive.sessionRevision).thenAnswer((_) => epoch);
    when(() => archive.sessionChanges).thenAnswer((_) => revisions.stream);
    reads = [];
    load = (_) => [_month(10), _month(9), _month(8)];
    SnapfitImage.storageOwnerForTesting = () => owner;
  });
  tearDown(() async {
    SnapfitImage.storageOwnerForTesting = null;
    await auth.close();
    await revisions.close();
  });

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    String socialOwner = 'owner-a',
    String accountOwner = 'owner-a',
    String? visibleOwner = 'owner-a',
    Future<void> Function(DateTime)? onOpen,
    VoidCallback? onCreate,
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = false,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        authViewModelProvider.overrideWith(() => _Auth(accountOwner)),
        socialCurrentUserIdProvider.overrideWith((_) => socialOwner),
        visibleOrderOwnerProvider.overrideWith((_) => visibleOwner),
        momentsRepositoryProvider.overrideWithValue(moments),
        privateMomentArchiveRepositoryProvider.overrideWithValue(archive),
        privateMomentMonthsProvider.overrideWith((ref, query) async {
          reads.add(query);
          return load(query);
        }),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    await container.read(authViewModelProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MyMomentArchive(
                ownerId: 'owner-a',
                today: DateTime.utc(2026, 10, 30),
                onOpenMonth: onOpen,
                onCreateRecord: onCreate,
                resolvePhotoForTesting: (_) async =>
                    'asset:assets/cover/cover1.png',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets(
    'private current month has a large original photo and older months form two columns',
    (tester) async {
      await mount(tester);
      await tester.pumpAndSettle();
      expect(find.text('나의 한 달'), findsOneWidget);
      expect(find.text('2026년 10월'), findsOneWidget);
      final hero = tester.getSize(
        find.byKey(const ValueKey('my-current-month-photo')),
      );
      expect(hero.width, greaterThan(330));
      expect(hero.height, greaterThan(240));
      final september = tester.getRect(
        find.byKey(const ValueKey('my-past-month-photo-2026-09-01')),
      );
      final august = tester.getRect(
        find.byKey(const ValueKey('my-past-month-photo-2026-08-01')),
      );
      expect(september.top, closeTo(august.top, .1));
      expect(september.width, greaterThan(150));
      expect(august.left, greaterThan(september.left));
      for (final image in tester.widgetList<SnapfitImage>(
        find.byType(SnapfitImage),
      )) {
        expect(
          image.urlOrGs,
          startsWith('supabase://album-assets/owner-a/moments/'),
        );
        expect(image.fallbackSources, isEmpty);
        expect(image.fit, BoxFit.contain);
      }
      expect(reads, [const PrivateMomentMonthsQuery('owner-a')]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a chosen older month opens that month rather than the current month',
    (tester) async {
      DateTime? opened;
      await mount(
        tester,
        onOpen: (month) async {
          opened = month;
        },
      );
      await tester.pumpAndSettle();
      final september = find.byKey(
        const ValueKey('my-moment-month-2026-09-01'),
      );
      await tester.ensureVisible(september);
      await tester.pumpAndSettle();
      await tester.tap(september);
      await tester.pumpAndSettle();
      expect(opened, DateTime.utc(2026, 9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty history offers a real first record without inventing a saved cover',
    (tester) async {
      load = (_) => [];
      var writes = 0;
      await mount(tester, onCreate: () => writes++);
      await tester.pumpAndSettle();
      expect(find.byType(SnapfitImage), findsNothing);
      expect(find.text('10월의 첫 장면'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('my-first-moment')));
      expect(writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed first page never falls back to cached photos and supports retry',
    (tester) async {
      var attempts = 0;
      load = (_) {
        if (++attempts == 1) throw StateError('unavailable');
        return [_month(10)];
      };
      await mount(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SnapfitImage), findsNothing);
      expect(find.text('기록을 불러오지 못했어요.'), findsOneWidget);
      await tester.tap(find.text('다시 확인'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('my-current-month-photo')),
        findsOneWidget,
      );
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mismatch in ['social', 'auth', 'visible', 'sdk']) {
    testWidgets(
      '$mismatch owner mismatch does not query or mount private photos',
      (tester) async {
        if (mismatch == 'sdk') owner = 'owner-b';
        await mount(
          tester,
          socialOwner: mismatch == 'social' ? 'owner-b' : 'owner-a',
          accountOwner: mismatch == 'auth' ? 'owner-b' : 'owner-a',
          visibleOwner: mismatch == 'visible' ? 'owner-b' : 'owner-a',
        );
        await tester.pumpAndSettle();
        expect(reads, isEmpty);
        expect(find.byType(SnapfitImage), findsNothing);
        expect(
          find.byKey(const ValueKey('my-current-month-photo')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'A to B to A blocks a late response until a fresh owner-scoped retry',
    (tester) async {
      final pending = Completer<List<MomentMonthSummary>>();
      var attempts = 0;
      load = (_) => ++attempts == 1 ? pending.future : [_month(9)];
      await mount(tester);
      await tester.pump();
      owner = 'owner-b';
      auth.add(owner);
      revisions.add(++epoch);
      owner = 'owner-a';
      auth.add(owner);
      revisions.add(++epoch);
      pending.complete([_month(10, records: 99)]);
      await tester.pumpAndSettle();
      expect(find.text('기록 99개 · 사진 101장'), findsNothing);
      expect(find.byType(SnapfitImage), findsNothing);
      await tester.tap(find.text('다시 확인'));
      await tester.pumpAndSettle();
      expect(find.text('2026년 9월'), findsOneWidget);
      expect(find.text('기록 99개 · 사진 101장'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'older-page loading uses a descending exclusive month cursor and no duplicate covers',
    (tester) async {
      load = (query) => query.beforeMonth == null
          ? [for (var month = 10; month >= 5; month--) _month(month)]
          : [_month(4), _month(3)];
      await mount(tester);
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('my-moment-months-more'));
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(reads, [
        const PrivateMomentMonthsQuery('owner-a'),
        PrivateMomentMonthsQuery('owner-a', beforeMonth: DateTime.utc(2026, 5)),
      ]);
      expect(find.text('2026년 4월'), findsOneWidget);
      expect(find.text('2026년 10월'), findsOneWidget);
      expect(find.byKey(const ValueKey('my-moment-months-more')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final config in [
    (const Size(320, 568), 1.6, false),
    (const Size(844, 390), 1.0, true),
    (const Size(1280, 900), 1.0, false),
  ]) {
    testWidgets(
      'large private photos remain usable at ${config.$1} scale ${config.$2}',
      (tester) async {
        await mount(tester, size: config.$1, scale: config.$2, dark: config.$3);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('my-current-month-photo')),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('my-current-month-photo')))
              .width,
          closeTo(config.$1.width - 32, .1),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
