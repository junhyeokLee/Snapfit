import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_moment_summary_card.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';
import 'package:snap_fit/features/onboarding/presentation/widgets/first_home_guide.dart';
import 'package:snap_fit/shared/snapfit_image.dart';
import 'package:snap_fit/shared/widgets/album_stage_style.dart';

import '../helpers/first_visit_fixtures.dart';

const _photo = 'assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg';
final _today = DateTime.utc(2026, 11, 4);

// 실제 사진으로 지면을 검증하되 스토리지 연결은 요청하지 않는다.
class _ArtworkPhoto extends MomentPhoto {
  _ArtworkPhoto(MomentPhotoDesign? design, {super.id = 'artwork-photo'})
    : super(
        path: '',
        url: 'asset:$_photo',
        width: 1200,
        height: 800,
        design: design,
      );

  @override
  String get storageUri => 'asset:$_photo';
}

MomentRecord _record(String id, DateTime date, int count, String caption) =>
    MomentRecord(
      id: id,
      recordDate: date,
      caption: caption,
      revision: 1,
      photos: List.generate(count, (i) => _ArtworkPhoto(null, id: '$id-$i')),
    );

class _Repository extends Fake implements MomentsRepository {
  String? owner = 'owner';
  DateTime today = _today;
  int reads = 0;
  bool fail = false;
  Future<MomentJournal>? pending;
  final changes = StreamController<String?>.broadcast();
  List<MomentRecord> records = [
    _record('today', _today, 2, '퇴근길, 오래 보고 싶었던 바다의 빛.'),
    _record('monday', DateTime.utc(2026, 11, 2), 1, '이번 주의 첫 기록'),
    _record('another', _today, 1, '한 번 더 남긴 순간'),
    _record('last-month', DateTime.utc(2026, 10, 31), 8, '지난달 기록'),
  ];

  @override
  String? get currentUserId => owner;
  @override
  Stream<String?> get authChanges => changes.stream;
  void change(String? next) {
    owner = next;
    changes.add(next);
  }

  @override
  Future<MomentJournal> listMonth(DateTime? requestedMonth) async {
    final month = requestedMonth ?? momentMonth(today);
    reads++;
    if (fail) throw const MomentException('연결 오류');
    if (pending != null) return pending!;
    return MomentJournal(
      today: today,
      weekStart: momentWeekStart(today),
      month: month,
      records: records,
      weekPhotoCount: 4,
    );
  }
}

typedef _Session = ({
  ProviderContainer container,
  Future<void> Function() close,
});

Future<_Session> _mount(
  WidgetTester tester,
  _Repository repository, {
  VoidCallback? onRecord,
  VoidCallback? onMonth,
  VoidCallback? onSignIn,
  ValueChanged<DateTime>? onDate,
  bool dark = false,
  double scale = 1,
  GlobalKey? captureKey,
  bool twice = false,
  Widget? firstUseGuide,
  MemoryFirstVisitStore? firstVisitStore,
}) async {
  final container = ProviderContainer(
    // Exercise the settled error/manual retry UI without Riverpod's timed
    // network retries keeping the upstream future pending in the fake clock.
    retry: (_, __) => null,
    overrides: [
      momentsRepositoryProvider.overrideWithValue(repository),
      if (firstVisitStore != null)
        firstVisitStoreProvider.overrideWithValue(firstVisitStore),
      // Deliberately differs from the server's fourth day of this month.
      momentEntryClockProvider.overrideWithValue(
        () => DateTime.utc(repository.today.year, repository.today.month, 1),
      ),
    ],
  );
  Widget card() => HomeMomentSummaryCard(
    onRecord: onRecord ?? () {},
    onOpenMonth: onMonth ?? () {},
    onSignIn: onSignIn ?? () {},
    onOpenDate: onDate ?? (_) {},
    firstUseGuide: firstUseGuide,
  );
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
            builder: (context) => RepaintBoundary(
              key: captureKey,
              child: ColoredBox(
                color: AlbumStageStyle.top(context),
                child: SingleChildScrollView(
                  child: Column(children: [card(), if (twice) card()]),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  var closed = false;
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await repository.changes.close();
    await tester.pump();
  }

  addTearDown(close);
  final widths = [112, scale > 1.5 ? 768 : 384];
  final prepared = <int>{};
  Object? imageError;
  await tester.runAsync(() async {
    for (final width in widths) {
      unawaited(
        precacheImage(
          ResizeImage(const AssetImage(_photo), width: width),
          tester.element(find.byType(MaterialApp)),
          onError: (error, _) => imageError = error,
        ).then((_) {
          prepared.add(width);
        }),
      );
    }
  });
  // 이미지 완료 콜백에도 가짜 프레임이 필요하므로 실제 IO와 pump를 번갈아 진행한다.
  for (var frame = 0; frame < 100 && prepared.length < widths.length; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 32));
  }
  expect(imageError, isNull);
  expect(
    prepared,
    unorderedEquals(widths),
    reason: 'Home fixture photos must decode at every requested width.',
  );
  await tester.pump();
  return (container: container, close: close);
}

// 월 경계와 관계없이 서버의 오늘이 속한 월~일 일곱 칸만 표시한다.
void _expectCurrentWeek(WidgetTester tester, DateTime today) {
  final week = find.byKey(const ValueKey('home-monthly-feed-week'));
  expect(week, findsOneWidget);
  expect(find.byKey(const ValueKey('moments-photo-calendar')), findsNothing);
  final cells = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey &&
        (widget.key as ValueKey).value.toString().startsWith('home-week-day-'),
  );
  expect(cells, findsNWidgets(7));
  final monday = momentWeekStart(today);
  double? previousLeft;
  for (var offset = 0; offset < 7; offset++) {
    final date = monday.add(Duration(days: offset));
    final cell = find.byKey(ValueKey('home-week-day-${momentDateKey(date)}'));
    expect(cell, findsOneWidget);
    final left = tester.getRect(cell).left;
    if (previousLeft != null) expect(left, greaterThan(previousLeft));
    previousLeft = left;
  }
  expect(find.byKey(const ValueKey('home-monthly-feed-counts')), findsNothing);
  expect(find.byKey(const ValueKey('home-monthly-reward')), findsNothing);
}

void main() {
  setUp(() {
    // 이전 테스트의 완료되지 않은 이미지 스트림을 다음 fake clock에서 재사용하지 않는다.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  for (final recorded in [false, true]) {
    testWidgets(
      'narrow large-text journal keeps date caption and record action readable: recorded=$recorded',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var records = 0;
        final journal = MomentJournal(
          today: _today,
          weekStart: momentWeekStart(_today),
          month: momentMonth(_today),
          weekPhotoCount: recorded ? 1 : 0,
          records: [
            if (recorded)
              MomentRecord(
                id: 'today',
                recordDate: _today,
                caption: '잠깐 멈춰 바라본 바다',
                photos: [_ArtworkPhoto(null)],
                revision: 1,
              ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              momentEntryJournalProvider.overrideWith((_) async => journal),
            ],
            child: MaterialApp(
              theme: SnapFitTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: const TextScaler.linear(2),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: HomeMomentSummaryCard(
                    onRecord: () => records++,
                    onOpenMonth: () {},
                    onOpenDate: (_) {},
                    onSignIn: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final date = find.byKey(const ValueKey('home-monthly-feed-date'));
        final caption = find.byKey(
          const ValueKey('home-monthly-feed-today-preview'),
        );
        final action = find.byKey(const ValueKey('home-monthly-feed-record'));
        // 큰 글씨에서도 사진 옆의 좁은 폭 때문에 날짜와 본문이 잘리지 않아야 한다.
        expect(tester.getSize(date).width, greaterThanOrEqualTo(240));
        expect(tester.getSize(caption).width, greaterThanOrEqualTo(240));
        final dateText = tester.widget<Text>(date).data!;
        final weekdayStart = dateText.indexOf('수요일');
        final dateParagraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: date, matching: find.byType(RichText)),
        );
        expect(
          dateParagraph.getBoxesForSelection(
            TextSelection(
              baseOffset: weekdayStart,
              extentOffset: weekdayStart + 3,
            ),
          ),
          hasLength(1),
        );
        expect(
          tester
              .renderObject<RenderParagraph>(
                find.descendant(of: caption, matching: find.byType(RichText)),
              )
              .didExceedMaxLines,
          isFalse,
        );
        expect(tester.getSize(action).width, closeTo(272, .5));
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        await tester.ensureVisible(action);
        await tester.tap(action);
        expect(records, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('the first-use guide takes space before the current week', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryFirstVisitStore(1);
    var records = 0, creates = 0;
    final session = await _mount(
      tester,
      _Repository()..records = [],
      firstVisitStore: store,
      firstUseGuide: FirstHomeGuide(
        onRecord: () => records++,
        onCreate: () => creates++,
      ),
    );
    await tester.pumpAndSettle();
    final guide = find.byKey(const ValueKey('first-home-guide'));
    final week = find.byKey(const ValueKey('home-monthly-feed-week'));
    expect(guide, findsOneWidget);
    expect(store.flags, 3);
    expect(
      tester.getRect(guide).bottom,
      lessThanOrEqualTo(tester.getRect(week).top),
    );
    _expectCurrentWeek(tester, _today);
    await tester.tap(find.byKey(const ValueKey('first-home-guide-record')));
    await tester.pumpAndSettle();
    expect(records, 1);
    expect(creates, 0);
    expect(guide, findsNothing);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  for (final sample in [
    (name: 'empty today', recorded: false, scale: 1.0),
    (name: 'recorded today', recorded: true, scale: 1.0),
    (name: 'large text', recorded: false, scale: 2.0),
    (name: 'recorded large text', recorded: true, scale: 2.0),
  ]) {
    testWidgets(
      'short home has one record action after the compact week: ${sample.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repository = _Repository();
        if (!sample.recorded) {
          repository.records.removeWhere(
            (record) => record.recordDate == _today,
          );
        }
        var recordTaps = 0;
        DateTime? selected;
        final session = await _mount(
          tester,
          repository,
          scale: sample.scale,
          onRecord: () => recordTaps++,
          onDate: (date) => selected = date,
        );
        await tester.pumpAndSettle();
        _expectCurrentWeek(tester, _today);
        final entry = find.byKey(const ValueKey('home-monthly-feed-record'));
        expect(entry, findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-monthly-feed-compact-record')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: entry,
            matching: find.text(sample.recorded ? '오늘 한 장 더' : '오늘 기록하기'),
          ),
          findsOneWidget,
        );
        expect(tester.getSize(entry).height, greaterThanOrEqualTo(44));
        expect(
          tester.getRect(entry).top,
          greaterThanOrEqualTo(
            tester
                .getRect(find.byKey(const ValueKey('home-monthly-feed-week')))
                .bottom,
          ),
        );
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        expect(recordTaps, 1);
        expect(selected, isNull);
        expect(tester.takeException(), isNull);
        await session.close();
      },
    );
  }

  testWidgets('tall home keeps the same single record action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await _mount(tester, _Repository());
    await tester.pumpAndSettle();
    _expectCurrentWeek(tester, _today);
    expect(
      find.byKey(const ValueKey('home-monthly-feed-compact-record')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('home-monthly-feed-record')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets(
    'home shows the current Monday to Sunday and locks missed and future dates',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        DateTime? selected;
        final session = await _mount(
          tester,
          _Repository(),
          onDate: (date) => selected = date,
        );
        await tester.pumpAndSettle();
        _expectCurrentWeek(tester, _today);
        expect(
          find.byKey(const ValueKey('home-week-day-2026-11-01')),
          findsNothing,
        );
        for (final key in ['2026-11-03', '2026-11-05']) {
          expect(
            tester
                .getSemantics(
                  find.bySemanticsLabel(
                    key == '2026-11-03'
                        ? '11월 3일, 사진 추가 마감'
                        : '11월 5일, 아직 오지 않은 날',
                  ),
                )
                .getSemanticsData()
                .hasAction(ui.SemanticsAction.tap),
            isFalse,
          );
        }
        final recorded = find.byKey(const ValueKey('home-week-day-2026-11-02'));
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('11월 2일, 기록 있음'))
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        await tester.tap(recorded);
        expect(selected, DateTime.utc(2026, 11, 2));
        expect(tester.takeException(), isNull);
        await session.close();
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'priority: today calendar slot starts a record without opening a past date',
    (tester) async {
      final repository = _Repository()
        ..records.removeWhere((record) => record.recordDate == _today);
      var records = 0;
      DateTime? selected;
      final session = await _mount(
        tester,
        repository,
        onRecord: () => records++,
        onDate: (date) => selected = date,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-week-day-2026-11-04')));
      expect(records, 1);
      expect(selected, isNull);
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );

  testWidgets(
    'priority: a photo anywhere in today opens its record even after a text-only entry',
    (tester) async {
      final repository = _Repository()
        ..records.insert(0, _record('text-first', _today, 0, '오늘 적어둔 글'));
      var records = 0;
      DateTime? selected;
      final session = await _mount(
        tester,
        repository,
        onRecord: () => records++,
        onDate: (date) => selected = date,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-week-day-2026-11-04')));
      expect(selected, _today);
      expect(records, 0);
      await session.close();
    },
  );

  for (final today in [
    DateTime.utc(2026, 2, 1),
    DateTime.utc(2028, 2, 29),
    DateTime.utc(2027, 1, 1),
  ]) {
    testWidgets(
      'current week crosses month and year boundaries at ${momentDateKey(today)}',
      (tester) async {
        final repository = _Repository()
          ..today = today
          ..records = [];
        final session = await _mount(tester, repository);
        await tester.pumpAndSettle();
        _expectCurrentWeek(tester, today);
        expect(tester.takeException(), isNull);
        await session.close();
      },
    );
  }

  testWidgets(
    'home uses server dates and today photos without monthly counts',
    (tester) async {
      final repository = _Repository();
      var recordTaps = 0, monthTaps = 0;
      DateTime? selected;
      final session = await _mount(
        tester,
        repository,
        onRecord: () => recordTaps++,
        onMonth: () => monthTaps++,
        onDate: (date) => selected = date,
      );
      await tester.pumpAndSettle();
      expect(find.text('11월 4일 수요일'), findsOneWidget);
      _expectCurrentWeek(tester, _today);
      expect(find.text('기록 완료'), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('home-monthly-feed-today-status')),
            )
            .properties
            .label,
        '오늘의 순간을 남겼어요',
      );
      final preview = tester.widget<Text>(
        find.byKey(const ValueKey('home-monthly-feed-today-preview')),
      );
      expect(preview.semanticsLabel, '퇴근길, 오래 보고 싶었던 바다의 빛.');
      expect(preview.data!.replaceAll('\u2060', ''), preview.semanticsLabel);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-monthly-feed-today-photo')),
          matching: find.byType(SnapfitImage),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('home-monthly-feed-record')));
      await tester.tap(find.byKey(const ValueKey('home-monthly-feed-open')));
      expect(recordTaps, 1);
      expect(monthTaps, 1);
      await tester.tap(find.byKey(const ValueKey('home-week-day-2026-11-02')));
      expect(selected, DateTime.utc(2026, 11, 2));
      selected = null;
      await tester.tap(find.byKey(const ValueKey('home-week-day-2026-11-05')));
      expect(selected, isNull);
      await tester.tap(
        find.byKey(const ValueKey('home-monthly-feed-today-photo')),
      );
      expect(selected, _today);
      expect(repository.reads, 1);
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );

  testWidgets('genuine empty month differs from loading and a failed fetch', (
    tester,
  ) async {
    final repository = _Repository();
    final pending = Completer<MomentJournal>();
    repository.pending = pending.future;
    final session = await _mount(tester, repository);
    final container = session.container;
    await tester.pump();
    expect(find.text('이번 달의 기록을 불러오고 있어요'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-monthly-feed-compact-record')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('home-monthly-feed-counts')),
      findsNothing,
    );
    pending.completeError(const MomentException('연결 오류'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(find.text('기록을 불러오지 못했어요'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-monthly-feed-compact-record')),
      findsNothing,
    );
    expect(find.textContaining('기록 0일'), findsNothing);
    repository.pending = null;
    repository.records = [];
    await tester.tap(find.byKey(const ValueKey('home-monthly-feed-recover')));
    await tester.pumpAndSettle();
    _expectCurrentWeek(tester, _today);
    expect(find.text('오늘의 한 장을 남겨볼까요?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-monthly-feed-record')),
        matching: find.text('오늘 기록하기'),
      ),
      findsOneWidget,
    );
    expect(repository.reads, 2);
    expect(container.read(momentEntryJournalProvider).hasError, isFalse);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('two entries share a read and logout removes private content', (
    tester,
  ) async {
    final repository = _Repository();
    final session = await _mount(tester, repository, twice: true);
    await tester.pumpAndSettle();
    expect(repository.reads, 1);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-monthly-feed-today-photo')),
        matching: find.byType(SnapfitImage),
      ),
      findsNWidgets(2),
    );
    repository.change(null);
    await tester.pumpAndSettle();
    expect(find.byType(SnapfitImage), findsNothing);
    expect(
      find.byKey(const ValueKey('home-monthly-feed-today-preview')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('home-monthly-feed-counts')),
      findsNothing,
    );
    expect(find.text('로그인하고 시작하기'), findsNWidgets(2));
    expect(repository.reads, 1);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets(
    'guest call to action requests sign-in rather than an empty feed',
    (tester) async {
      final repository = _Repository()..owner = null;
      var signIns = 0, monthOpens = 0;
      final session = await _mount(
        tester,
        repository,
        onSignIn: () => signIns++,
        onMonth: () => monthOpens++,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-monthly-feed-compact-record')),
        findsNothing,
      );
      await tester.tap(find.text('로그인하고 시작하기'));
      expect(signIns, 1);
      expect(monthOpens, 0);
      expect(repository.reads, 0);
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );

  for (final canvas in [const Size(64, 640), const Size(640, 64)]) {
    testWidgets(
      'extreme saved artboard ${canvas.width}:${canvas.height} stays compact on home',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final design = MomentPhotoDesign.fromLayers(
          canvasSize: canvas,
          backgroundColor: Colors.white,
          photoSource: momentPhotoOriginalSource,
          layers: [
            LayerModel(
              id: 'original',
              type: LayerType.image,
              position: Offset.zero,
              width: canvas.width,
              height: canvas.height,
              originalUrl: momentPhotoOriginalSource,
            ),
          ],
        );
        final photo = _ArtworkPhoto(design);
        final repository = _Repository()
          ..records = [
            MomentRecord(
              id: 'artwork',
              recordDate: _today,
              caption: '저장한 지면',
              revision: 1,
              photos: [photo],
            ),
          ];
        final session = await _mount(tester, repository, scale: 2);
        await tester.pumpAndSettle();
        final preview = find.byKey(
          const ValueKey('home-monthly-feed-today-photo'),
        );
        final size = tester.getSize(preview);
        // 긴 기존 지면도 잘라내거나 홈 한 화면 높이까지 키우지 않는다.
        expect(size.width, lessThanOrEqualTo(104));
        expect(size.height, lessThanOrEqualTo(120));
        expect(size.aspectRatio, closeTo(canvas.aspectRatio, .0001));
        final view = tester.widget<MomentPhotoView>(
          find.descendant(of: preview, matching: find.byType(MomentPhotoView)),
        );
        expect(view.photo?.design, same(design));
        expect(view.fit, BoxFit.contain);
        expect(view.aspectRatio, closeTo(canvas.aspectRatio, .0001));
        expect(
          tester.getRect(preview).bottom,
          lessThanOrEqualTo(
            tester
                .getRect(find.byKey(const ValueKey('home-monthly-feed-date')))
                .top,
          ),
        );
        expect(tester.takeException(), isNull);
        await session.close();
      },
    );
  }

  for (final sample in [
    (name: '390-light', width: 390.0, dark: false, scale: 1.0),
    (name: '390-dark', width: 390.0, dark: true, scale: 1.0),
    (name: '320-large-text', width: 320.0, dark: false, scale: 2.0),
  ]) {
    testWidgets('compact weekly summary stays readable at ${sample.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(sample.width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = Size(sample.width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      final session = await _mount(
        tester,
        _Repository(),
        dark: sample.dark,
        scale: sample.scale,
        captureKey: key,
      );
      await tester.pumpAndSettle();
      final recordButton = find.byKey(
        const ValueKey('home-monthly-feed-record'),
      );
      await tester.ensureVisible(recordButton);
      expect(tester.getSize(recordButton).height, greaterThanOrEqualTo(44));
      final photo = find.byKey(const ValueKey('home-monthly-feed-today-photo'));
      final photoSize = tester.getSize(photo);
      expect(photoSize.width, inInclusiveRange(96, 104));
      final savedPhoto = tester.widget<MomentPhotoView>(
        find.descendant(of: photo, matching: find.byType(MomentPhotoView)),
      );
      expect(
        photoSize.aspectRatio,
        closeTo(momentPhotoAspect(savedPhoto.photo!), .0001),
      );
      expect(savedPhoto.fit, BoxFit.contain);
      final date = find.byKey(const ValueKey('home-monthly-feed-date'));
      if (sample.scale > 1.5) {
        expect(
          tester.getRect(photo).bottom,
          lessThanOrEqualTo(tester.getRect(date).top),
        );
      } else {
        expect(
          tester.getRect(photo).right,
          lessThan(tester.getRect(date).left),
        );
        expect(
          tester.getRect(photo).top,
          lessThan(tester.getRect(date).bottom),
        );
      }
      _expectCurrentWeek(tester, _today);
      if (sample.scale == 1) {
        expect(
          tester.getSize(find.byType(HomeMomentSummaryCard)).height,
          lessThanOrEqualTo(420),
        );
      }
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('EXPORT_HOME_DAILY_REVIEW')) {
        await tester.runAsync(() async {
          final manifest =
              jsonDecode(await rootBundle.loadString('FontManifest.json'))
                  as List;
          for (final entry in manifest.cast<Map>().where(
            (font) => ['NotoSans', 'MaterialIcons'].contains(font['family']),
          )) {
            final loader = FontLoader(entry['family'] as String);
            for (final font in entry['fonts'] as List) {
              loader.addFont(rootBundle.load(font['asset'] as String));
            }
            await loader.load();
          }
          await precacheImage(
            ResizeImage(
              const AssetImage(_photo),
              width: sample.scale > 1.5 ? 768 : 384,
            ),
            tester.element(find.byType(HomeMomentSummaryCard)),
          );
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            const out = String.fromEnvironment('HOME_DAILY_REVIEW_OUTPUT');
            if (out.isEmpty)
              throw StateError('An external review path is required');
            final file = File('$out/${sample.name}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
      await session.close();
    });
  }
}
