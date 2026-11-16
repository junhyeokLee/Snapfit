import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/profile/presentation/views/billing_management_screen.dart';

import '../support/point_purchase_fakes.dart';

const pointHistoryOwner = '11111111-1111-4111-8111-111111111111';

class _MemoryAuth extends Fake implements GoTrueClient {
  @override
  User get currentUser => const User(
    id: pointHistoryOwner,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-11-01T00:00:00Z',
  );
}

class _MemorySupabase extends Fake implements SupabaseClient {
  @override
  final GoTrueClient auth = _MemoryAuth();
}

class _UnusedTokens extends Fake implements TokenStorage {}

Map<String, dynamic> pointHistoryRow(int id, int delta, {String? reason}) => {
  'id': id,
  'created_at': DateTime.utc(2026, 11, id, 6).toIso8601String(),
  'amount_delta': delta,
  'reason': reason ?? (delta < 0 ? 'AI_ALBUM_DRAFT_CHARGE' : 'POINT_PURCHASE'),
};

List<Map<String, dynamic>> pointHistoryRows(int count) => [
  for (var id = count; id >= 1; id--) pointHistoryRow(id, 2500),
];

/// 실제 저장소의 필터·커서·조회 제한을 통과하는, 외부 연결 없는 원장이다.
class PointHistoryFixture {
  PointHistoryFixture({List<Map<String, dynamic>>? rows})
    : rows =
          rows ??
          [
            for (var id = 6; id >= 1; id--)
              pointHistoryRow(id, id == 1 ? -700 : 2500),
          ];

  final store = FakeStore();
  final requests = <Map<String, Object?>>[];
  final List<Map<String, dynamic>> rows;
  Completer<void>? nextPageGate;
  bool failNextPage = false;
  List<Map<String, Object?>> get pageRequests =>
      requests.where((request) => request['source'] == 'page').toList();

  late final repository = BillingRepository(
    tokenStorage: _UnusedTokens(),
    supabase: _MemorySupabase(),
    pointBalanceQuery: () async => {'balance': 11800},
    // 홈 등에서 사용하는 최근 내역 경로도 같은 저장소 fixture로 보존한다.
    pointLedgerQuery: ({required userId, required limit}) async {
      requests.add({'source': 'recent', 'userId': userId, 'limit': limit});
      return rows.take(limit).toList(growable: false);
    },
    pointLedgerPageQuery:
        ({
          required userId,
          required filter,
          required limit,
          required before,
        }) async {
          requests.add({
            'source': 'page',
            'userId': userId,
            'filter': filter.name,
            'limit': limit,
            'before': before == null
                ? null
                : {
                    'createdAtUtc': before.createdAtUtc.toIso8601String(),
                    'id': before.id,
                  },
          });
          if (before != null) {
            await nextPageGate?.future;
            if (failNextPage) {
              failNextPage = false;
              throw StateError('fixture_next_page_failed');
            }
          }
          final selected = rows.where((row) {
            final delta = row['amount_delta'] as int;
            final matches = switch (filter) {
              PointLedgerFilter.all => true,
              PointLedgerFilter.received => delta > 0,
              PointLedgerFilter.spent => delta < 0,
            };
            if (!matches || before == null) return matches;
            final createdAt = DateTime.parse(row['created_at'] as String);
            return createdAt.isBefore(before.createdAtUtc) ||
                createdAt.isAtSameMomentAs(before.createdAtUtc) &&
                    (row['id'] as int) < before.id;
          }).toList();
          selected.sort((a, b) {
            final byTime = DateTime.parse(
              b['created_at'] as String,
            ).compareTo(DateTime.parse(a['created_at'] as String));
            return byTime != 0
                ? byTime
                : (b['id'] as int).compareTo(a['id'] as int);
          });
          return selected.take(limit).toList(growable: false);
        },
  );
}

Future<void> mountPointHistory(
  WidgetTester tester,
  PointHistoryFixture fixture, {
  GlobalKey? captureKey,
  bool dark = false,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        visibleOrderOwnerProvider.overrideWithValue(pointHistoryOwner),
        billingRepositoryProvider.overrideWithValue(fixture.repository),
        pointPurchaseServiceProvider.overrideWith((ref) {
          final service = fakePointPurchaseService(store: fixture.store);
          ref.onDispose(service.dispose);
          return service;
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: const EdgeInsets.only(top: 24, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 24, bottom: 34),
          ),
          child: RepaintBoundary(key: captureKey, child: child!),
        ),
        home: const BillingManagementScreen(initialPointsTabIndex: 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _row(int id) => find.byKey(ValueKey('points-ledger-$id'));
Finder get _more => find.byKey(const ValueKey('points-history-more'));
Finder get _scroll => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _show(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 350, scrollable: _scroll);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _mount(
  WidgetTester tester,
  PointHistoryFixture fixture, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await fixture.store.controller.close();
  });
  await mountPointHistory(tester, fixture, dark: dark, textScale: scale);
}

Future<void> _select(WidgetTester tester, String label) async {
  await _show(tester, find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'purchase history shows its stored product title and trailing amount',
    (tester) async {
      final fixture = PointHistoryFixture(
        rows: [
          {
            ...pointHistoryRow(14, -450, reason: 'DIGITAL_ITEM_PURCHASE'),
            'metadata': {'title': '제주의 바람 프레임'},
          },
        ],
      );
      await _mount(tester, fixture);
      expect(find.text('제주의 바람 프레임'), findsOneWidget);
      final title = tester.getRect(find.text('꾸미기 상품 구매'));
      final amount = tester.getRect(find.text('-450P'));
      expect(amount.left, greaterThan(title.right));
      expect(amount.right, greaterThan(300));
    },
  );
  testWidgets('spent history finds debit older than the latest five credits', (
    tester,
  ) async {
    final fixture = PointHistoryFixture();
    await _mount(tester, fixture);
    await _select(tester, '차감');

    expect(_row(1), findsOneWidget);
    expect(find.text('해당 포인트 내역이 없어요.'), findsNothing);
    expect(fixture.pageRequests.last['filter'], 'spent');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all history keeps zero entries while earned and spent use server filters',
    (tester) async {
      final fixture = PointHistoryFixture(
        rows: [
          pointHistoryRow(3, 0, reason: 'AI_ALBUM_DRAFT_FREE'),
          pointHistoryRow(2, 500),
          pointHistoryRow(1, -300),
        ],
      );
      await _mount(tester, fixture);
      expect(_row(3), findsOneWidget);
      await _select(tester, '적립');
      expect(_row(2), findsOneWidget);
      expect(_row(3), findsNothing);
      expect(_row(1), findsNothing);
      expect(fixture.pageRequests.last['filter'], 'received');
      await _select(tester, '차감');
      expect(_row(1), findsOneWidget);
      expect(_row(2), findsNothing);
      expect(fixture.pageRequests.last['filter'], 'spent');
      await _select(tester, '전체');
      expect(_row(3), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history loads older entries beyond twenty without dropping the first page',
    (tester) async {
      final fixture = PointHistoryFixture(rows: pointHistoryRows(25));
      await _mount(tester, fixture);
      await _show(tester, _more);
      expect(find.text('이전 내역 더 보기'), findsOneWidget);
      await tester.tap(_more);
      await tester.pumpAndSettle();
      await _show(tester, _row(1));
      expect(_row(1), findsOneWidget);
      expect(_more, findsNothing);
      tester.state<ScrollableState>(_scroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(_row(25), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending older page disables duplicate requests', (tester) async {
    final fixture = PointHistoryFixture(rows: pointHistoryRows(25));
    final gate = fixture.nextPageGate = Completer<void>();
    await _mount(tester, fixture);
    await _show(tester, _more);
    await tester.tap(_more);
    await tester.pump();
    final requests = fixture.pageRequests.length;
    expect(tester.widget<ButtonStyleButton>(_more).onPressed, isNull);
    await tester.tap(_more, warnIfMissed: false);
    await tester.pump();
    expect(fixture.pageRequests.length, requests);
    gate.complete();
    await tester.pumpAndSettle();
    await _show(tester, _row(1));
    expect(_row(1), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed older page keeps loaded rows and can retry', (
    tester,
  ) async {
    final fixture = PointHistoryFixture(rows: pointHistoryRows(25))
      ..failNextPage = true;
    await _mount(tester, fixture);
    await _show(tester, _more);
    await tester.tap(_more);
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(_more).onPressed, isNotNull);
    // 다음 쪽 실패로 기존 원장을 빈 화면으로 바꾸면 안 된다.
    tester.state<ScrollableState>(_scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(_row(25), findsOneWidget);
    await _show(tester, _more);
    await tester.tap(_more);
    await tester.pumpAndSettle();
    await _show(tester, _row(1));
    expect(_row(1), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'spent history stays usable at 320 with large text in dark mode',
    (tester) async {
      final fixture = PointHistoryFixture();
      await _mount(
        tester,
        fixture,
        size: const Size(320, 568),
        scale: 1.6,
        dark: true,
      );
      await _select(tester, '차감');
      await _show(tester, _row(1));
      final bounds = tester.getRect(_row(1));
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(320));
      expect(fixture.store.buyCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
