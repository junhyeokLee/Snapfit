import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_moment_month_cover_picker.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_report_sheet.dart';

class _Viewer extends Notifier<String?> {
  @override
  String? build() => 'me';
  void change(String? user) => state = user;
}

final _viewer = NotifierProvider<_Viewer, String?>(_Viewer.new);
final _month = DateTime.utc(2026, 10);

SocialWork _record(
  String id, {
  String status = 'published',
  String kind = 'moment',
  String author = 'me',
  int month = 10,
}) => SocialWork(
  id: id,
  title: '기록 $id',
  author: SocialProfile(userId: author, displayName: '오늘의 나', handle: 'days'),
  createdAt: DateTime.utc(2026, 10, 28),
  recordDate: DateTime.utc(2026, month, 28),
  status: status,
  kind: kind,
);

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  SocialReportSubmit? report,
  Future<void> Function(String?)? select,
  String? selectedWorkId,
  FutureOr<SocialWorkPage> Function(SocialMomentMonthQuery)? load,
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final container = ProviderContainer(
    overrides: [
      socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_viewer)),
      socialMomentMonthPageProvider.overrideWith(
        (_, query) async => load == null
            ? SocialWorkPage(
                items: [_record('one')],
                hasMore: false,
                nextOffset: 1,
              )
            : await load(query),
      ),
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
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showSocialReportSheet(
                    context,
                    title: '기록 신고',
                    ownerId: 'me',
                    onSubmit: report ?? (_, _, _) async {},
                  ),
                  child: const Text('신고 열기'),
                ),
                TextButton(
                  onPressed: () => showSocialMomentMonthCoverPicker(
                    context,
                    userId: 'me',
                    month: _month,
                    selectedWorkId: selectedWorkId,
                    onSelect: select ?? (_) async {},
                  ),
                  child: const Text('표지 열기'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'server abuse limits are shown without discarding the selected report',
    (tester) async {
      await _mount(
        tester,
        report: (_, _, _) async =>
            throw const SocialActionException('신고가 잠시 많아요. 잠시 후 다시 시도해 주세요.'),
      );
      await tester.tap(find.text('신고 열기'));
      await tester.pumpAndSettle();
      await _tap(tester, 'social-report-reason-spam');
      await _tap(tester, 'social-report-submit');
      expect(find.text('신고가 잠시 많아요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('social-report-submit')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'report requires a reason and retries with the same request identity',
    (tester) async {
      final requests = <(String, String, String)>[];
      await _mount(
        tester,
        report: (reason, detail, request) async {
          requests.add((reason, detail, request));
          if (requests.length == 1) throw StateError('lost reply');
        },
      );
      await tester.tap(find.text('신고 열기'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('social-report-submit')),
            )
            .onPressed,
        isNull,
      );
      await _tap(tester, 'social-report-reason-privacy');
      await tester.enterText(
        find.byKey(const ValueKey('social-report-detail')),
        '사진에 연락처가 보여요.',
      );
      await _tap(tester, 'social-report-submit');
      expect(
        find.text('신고 접수를 확인하지 못했어요. 같은 내용으로 다시 시도해 주세요.'),
        findsOneWidget,
      );
      await _tap(tester, 'social-report-submit');
      expect(requests, hasLength(2));
      expect(requests[0], requests[1]);
      expect(requests.first.$1, 'privacy');
      expect(requests.first.$2, '사진에 연락처가 보여요.');
      expect(find.byType(SocialReportSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account change closes only its report sheet and rejects late success after ABA',
    (tester) async {
      final pending = Completer<void>();
      final container = await _mount(
        tester,
        report: (_, _, _) => pending.future,
      );
      await tester.tap(find.text('신고 열기'));
      await tester.pumpAndSettle();
      await _tap(tester, 'social-report-reason-spam');
      final send = tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('social-report-submit')),
          )
          .onPressed!;
      send();
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('social-report-submit')),
            )
            .onPressed,
        isNull,
      );
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(SocialReportSheet)),
          builder: (_) => const AlertDialog(content: Text('유지할 다른 창')),
        ),
      );
      await tester.pumpAndSettle();
      container.read(_viewer.notifier).change('other');
      await tester.pumpAndSettle();
      container.read(_viewer.notifier).change('me');
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('유지할 다른 창'), findsOneWidget);
      expect(find.byType(SocialReportSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cover chooser filters snapshots and applies only on confirmation',
    (tester) async {
      final selected = <String?>[];
      await _mount(
        tester,
        select: (id) async => selected.add(id),
        load: (_) => SocialWorkPage(
          items: [
            _record('one'),
            _record('one'),
            _record('private', status: 'private'),
            _record('album', kind: 'album'),
            _record('someone', author: 'other'),
            _record('september', month: 9),
          ],
          hasMore: false,
          nextOffset: 6,
        ),
      );
      await tester.tap(find.text('표지 열기'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('month-cover-photo-one')),
        findsOneWidget,
      );
      for (final hidden in ['private', 'album', 'someone', 'september']) {
        expect(find.byKey(ValueKey('month-cover-photo-$hidden')), findsNothing);
      }
      await _tap(tester, 'month-cover-photo-one');
      expect(selected, isEmpty);
      await _tap(tester, 'month-cover-apply');
      expect(selected, ['one']);
      expect(find.byType(SocialMomentMonthCoverPicker), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'automatic cover is restored explicitly and cancelling never writes',
    (tester) async {
      final selected = <String?>[];
      await _mount(
        tester,
        selectedWorkId: 'one',
        select: (id) async => selected.add(id),
      );
      await tester.tap(find.text('표지 열기'));
      await tester.pumpAndSettle();
      await _tap(tester, 'month-cover-automatic');
      await _tap(tester, 'month-cover-close');
      expect(selected, isEmpty);
      await tester.tap(find.text('표지 열기'));
      await tester.pumpAndSettle();
      await _tap(tester, 'month-cover-automatic');
      await _tap(tester, 'month-cover-apply');
      expect(selected, [null]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cover chooser can retry loading and a failed write without losing selection',
    (tester) async {
      var reads = 0, writes = 0;
      await _mount(
        tester,
        load: (_) {
          if (++reads == 1) throw StateError('offline');
          return SocialWorkPage(
            items: [_record('one')],
            hasMore: false,
            nextOffset: 1,
          );
        },
        select: (id) async {
          if (++writes == 1) throw StateError('offline write');
        },
      );
      await tester.tap(find.text('표지 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      await _tap(tester, 'month-cover-photo-one');
      await _tap(tester, 'month-cover-apply');
      expect(find.text('표지를 저장하지 못했어요. 선택한 사진으로 다시 시도해 주세요.'), findsOneWidget);
      await _tap(tester, 'month-cover-apply');
      expect(writes, 2);
      expect(find.byType(SocialMomentMonthCoverPicker), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cover write finishing after account change cannot close a different route',
    (tester) async {
      final pending = Completer<void>();
      final container = await _mount(tester, select: (_) => pending.future);
      await tester.tap(find.text('표지 열기'));
      await tester.pumpAndSettle();
      await _tap(tester, 'month-cover-photo-one');
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('month-cover-apply')))
          .onPressed!();
      await tester.pump();
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(SocialMomentMonthCoverPicker)),
          builder: (_) => const AlertDialog(content: Text('표지 외 다른 창')),
        ),
      );
      await tester.pumpAndSettle();
      container.read(_viewer.notifier).change('other');
      await tester.pumpAndSettle();
      container.read(_viewer.notifier).change('me');
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('표지 외 다른 창'), findsOneWidget);
      expect(find.byType(SocialMomentMonthCoverPicker), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('both sheets remain reachable at 320 with large dark text', (
    tester,
  ) async {
    await _mount(tester, size: const Size(320, 568), scale: 1.8, dark: true);
    await tester.tap(find.text('신고 열기'));
    await tester.pumpAndSettle();
    await _tap(tester, 'social-report-reason-other');
    await _tap(tester, 'social-report-submit');
    await tester.tap(find.text('표지 열기'));
    await tester.pumpAndSettle();
    await _tap(tester, 'month-cover-photo-one');
    await _tap(tester, 'month-cover-apply');
    expect(tester.takeException(), isNull);
  });
}
