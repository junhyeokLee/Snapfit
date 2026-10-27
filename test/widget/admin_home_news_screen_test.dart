import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/home_news/data/admin_home_news_repository.dart';
import 'package:snap_fit/features/home_news/domain/home_news.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_providers.dart';
import 'package:snap_fit/features/home_news/presentation/views/admin_home_news_screen.dart';

final _owner = StateProvider<String?>((ref) => 'admin-a');
final _allowed = StateProvider<bool>((ref) => true);

class _Repository implements AdminHomeNewsRepository {
  @override
  String? currentUserId = 'admin-a';
  var reads = 0;
  bool failRead = false, failSave = false;
  List<HomeNewsCampaign> campaigns = List.of(defaultHomeNewsCampaigns);
  final saves = <HomeNewsCampaign>[];
  Completer<AdminHomeNewsSnapshot>? pending;
  AdminHomeNewsSnapshot get snapshot => AdminHomeNewsSnapshot(
    serverNow: DateTime.utc(2026, 10, 27, 3),
    campaigns: campaigns,
  );
  @override
  Future<AdminHomeNewsSnapshot> getCampaigns() async {
    reads++;
    if (failRead) throw StateError('fixture unavailable');
    return pending != null ? pending!.future : snapshot;
  }

  @override
  Future<AdminHomeNewsSnapshot> updateCampaign(
    HomeNewsCampaign campaign,
  ) async {
    if (failSave) throw StateError('fixture denied');
    saves.add(campaign);
    campaigns = [
      for (final existing in campaigns)
        existing.kind == campaign.kind ? campaign : existing,
    ];
    return snapshot;
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Repository repository, {
  bool allowed = true,
  double scale = 1,
  bool dark = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      _allowed.overrideWith((ref) => allowed),
      homeNewsCurrentOwnerProvider.overrideWith((ref) => ref.watch(_owner)),
      adminHomeNewsAccessProvider.overrideWith((ref) => ref.watch(_allowed)),
      adminHomeNewsRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
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
        home: const AdminHomeNewsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('non-admin cannot fetch or edit operations', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository, allowed: false);
    expect(find.text('새 소식을 관리할 관리자 권한이 필요합니다.'), findsOneWidget);
    expect(repository.reads, 0);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets(
    'four event controls save enabled state without changing other settings',
    (tester) async {
      final repository = _Repository();
      await _pump(tester, repository);
      expect(find.byType(Switch), findsNWidgets(4));
      final toggle = find.byKey(
        const ValueKey('admin-news-enabled-monthReview'),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      expect(repository.saves, isEmpty);
      final save = find.byKey(const ValueKey('admin-news-save-monthReview'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.saves, hasLength(1));
      expect(repository.saves.single.kind, HomeNewsKind.monthReview);
      expect(repository.saves.single.enabled, false);
      expect(repository.saves.single.sortOrder, 0);
      expect(
        repository.campaigns
            .where((c) => c.kind != HomeNewsKind.monthReview)
            .every((c) => c.enabled),
        true,
      );
      expect(find.text('꺼짐'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('read errors retry and save errors preserve the editable draft', (
    tester,
  ) async {
    final repository = _Repository()..failRead = true;
    await _pump(tester, repository);
    expect(find.text('새 소식 설정을 불러오지 못했습니다.'), findsOneWidget);
    repository.failRead = false;
    await tester.tap(find.byKey(const ValueKey('admin-home-news-retry')));
    await tester.pumpAndSettle();
    expect(repository.reads, 2);
    final toggle = find.byKey(const ValueKey('admin-news-enabled-monthReview'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    repository.failSave = true;
    final save = find.byKey(const ValueKey('admin-news-save-monthReview'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text('저장하지 못했습니다. 관리자 권한과 연결 상태를 확인한 뒤 다시 시도해 주세요.'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(toggle).value, false);
    expect(repository.saves, isEmpty);
  });

  testWidgets(
    'sign-out removes operations and a late snapshot is not exposed',
    (tester) async {
      final repository = _Repository();
      final container = await _pump(tester, repository);
      repository.pending = Completer<AdminHomeNewsSnapshot>();
      container.invalidate(adminHomeNewsSnapshotProvider);
      await tester.pump();
      container.read(_owner.notifier).state = null;
      container.read(_allowed.notifier).state = false;
      repository.currentUserId = null;
      await tester.pump();
      repository.pending!.complete(repository.snapshot);
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNothing);
      expect(find.text('새 소식을 관리할 관리자 권한이 필요합니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'all controls remain reachable at 320px with large type ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(tester, _Repository(), scale: 1.6, dark: dark);
        for (final kind in HomeNewsKind.values) {
          await tester.ensureVisible(
            find.byKey(ValueKey('admin-news-save-${kind.name}')),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
