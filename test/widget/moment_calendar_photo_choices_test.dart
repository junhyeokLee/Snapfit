import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, SynchronousFuture;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/private_moment_archive_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moments_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/monthly_moment_preview_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/weekly_moment_recap_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_month_calendar.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

import '../helpers/memory_moment_draft_store.dart';

const _asset = 'assets/cover/cover1.png';
final _today = DateTime.utc(2026, 11, 1);
final _october = DateTime.utc(2026, 10);
final _week = DateTime.utc(2026, 10, 26);

// Browser behavior tests keep the exact asset identity but provide an in-memory
// PNG/manifest, avoiding a fake-async asset HTTP request that needs frame pumps
// while a runAsync precache is waiting. Native tests and the separate exports
// still decode the original bundled photographs with their real fonts.
class _MemoryBrowserAssets extends CachingAssetBundle {
  static final _png = Uint8List.fromList(
    img.encodePng(
      img.Image(width: 2, height: 2)..setPixelRgba(0, 0, 36, 157, 166, 255),
    ),
  );
  static final _manifest = const StandardMessageCodec().encodeMessage(
    <String, Object?>{},
  )!;
  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') return SynchronousFuture(_manifest);
    if (key == 'AssetManifest.bin.json') {
      final bytes = _manifest.buffer.asUint8List(
        _manifest.offsetInBytes,
        _manifest.lengthInBytes,
      );
      return SynchronousFuture(
        ByteData.sublistView(
          Uint8List.fromList(utf8.encode(jsonEncode(base64Encode(bytes)))),
        ),
      );
    }
    if (_image(key)) return SynchronousFuture(ByteData.sublistView(_png));
    return rootBundle.load(key);
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) => _image(key)
      ? ui.ImmutableBuffer.fromUint8List(_png)
      : super.loadBuffer(key);
  bool _image(String key) =>
      RegExp(r'[.](png|jpg|jpeg|webp)$', caseSensitive: false).hasMatch(key);
}

class _AssetPhoto extends MomentPhoto {
  _AssetPhoto(String id)
    : super(
        id: id,
        path: 'owner/moments/sample/$id.png',
        url: 'asset:$_asset',
        width: 600,
        height: 800,
      );
  @override
  String get storageUri => url;
}

MomentRecord _record(String id, DateTime date, {int photos = 1}) =>
    MomentRecord(
      id: id,
      recordDate: date,
      caption: '$id 원래 기록',
      revision: 3,
      photos: [for (var i = 0; i < photos; i++) _AssetPhoto('$id-photo-$i')],
    );

class _Moments implements MomentsRepository {
  String? actor = 'owner';
  DateTime today = _today;
  final changes = StreamController<String?>.broadcast(sync: true);
  List<MomentRecord> records = [
    _record('week', DateTime.utc(2026, 10, 31), photos: 4),
  ];
  final monthReads = <DateTime>[];
  int mutations = 0;
  @override
  String? get currentUserId => actor;
  @override
  Stream<String?> get authChanges => changes.stream;
  void change(String? value) {
    actor = value;
    changes.add(value);
  }

  @override
  Future<MomentJournal> listMonth(DateTime? requestedMonth) async {
    final month = requestedMonth ?? momentMonth(today);
    monthReads.add(month);
    return MomentJournal(
      today: today,
      weekStart: momentWeekStart(today),
      month: month,
      records: records
          .where(
            (record) => momentMonth(record.recordDate) == momentMonth(month),
          )
          .toList(),
      weekRecords: records,
      weekPhotoCount: records.fold(
        0,
        (total, record) => total + record.photos.length,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    mutations++;
    throw StateError(
      'Unexpected album/record mutation: ${invocation.memberName}',
    );
  }
}

class _Archive implements PrivateMomentArchiveRepository {
  _Archive(this.moments);
  final _Moments moments;
  int revision = 0;
  final changes = StreamController<int>.broadcast(sync: true);
  List<String> weekly = [], monthly = [];
  Completer<List<String>>? pendingWeekly, pendingMonthly;
  Completer<void>? pendingSave;
  final saves = <({String owner, DateTime week, List<String> ids})>[];
  @override
  String? get currentUserId => moments.actor;
  @override
  int get sessionRevision => revision;
  @override
  Stream<int> get sessionChanges => changes.stream;
  void change() {
    revision++;
    changes.add(revision);
  }

  @override
  Future<List<MomentMonthSummary>> listMonths({
    required String ownerId,
    DateTime? beforeMonth,
    int limit = 6,
  }) async => [];
  @override
  Future<List<String>> monthlyPhotoChoices({
    required String ownerId,
    required DateTime month,
  }) => pendingMonthly?.future ?? Future.value(List.of(monthly));
  @override
  Future<List<String>> weeklyPhotoChoices({
    required String ownerId,
    required DateTime weekStart,
  }) => pendingWeekly?.future ?? Future.value(List.of(weekly));
  @override
  Future<void> saveWeeklyPhotoChoices({
    required String ownerId,
    required DateTime weekStart,
    required List<String> photoIds,
  }) async {
    saves.add((owner: ownerId, week: weekStart, ids: List.of(photoIds)));
    await pendingSave?.future;
    weekly = List.of(photoIds);
  }
}

Future<void> _settle(WidgetTester tester) async {
  if (kIsWeb) {
    // Browser image codecs need real event-loop turns interleaved with Flutter
    // frames; never await precache completion while no frame can advance.
    for (var pass = 0; pass < 80; pass++) {
      await tester.pump(const Duration(milliseconds: 40));
      await tester.runAsync(
        () => Future<void>.delayed(
          const Duration(milliseconds: 20),
        ).timeout(const Duration(seconds: 10)),
      );
      final raw = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
      final pending = raw.where((image) => image.image == null).length;
      if (pending == 0 &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 50),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 10),
        );
        return;
      }
    }
    final sources = tester
        .widgetList<SnapfitImage>(find.byType(SnapfitImage))
        .map((image) => image.urlOrGs)
        .toList();
    throw TestFailure(
      'Browser sample images did not finish after bounded frame pumps: $sources',
    );
  }
  // 날짜 이동으로 뒤늦게 마운트되는 실제 지면의 디코딩까지 기다린다.
  for (var pass = 0; pass < 60; pass++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      for (final image in tester.widgetList<SnapfitImage>(
        find.byType(SnapfitImage),
      )) {
        for (final source in [image.urlOrGs, ...image.fallbackSources]) {
          if (!source.startsWith('asset:')) continue;
          await precacheImage(
            ResizeImage.resizeIfNeeded(
              image.memCacheWidth,
              image.memCacheHeight,
              AssetImage(
                source.substring(6),
                bundle: DefaultAssetBundle.of(context),
              ),
            ),
            context,
          ).timeout(const Duration(seconds: 10));
        }
      }
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(
          image.image,
          context,
        ).timeout(const Duration(seconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 15));
    });
    await tester.pump();
    if (pass >= 3 &&
        !tester.binding.hasScheduledFrame &&
        PaintingBinding.instance.imageCache.pendingImageCount == 0)
      return;
  }
  throw TestFailure('날짜로 펼친 기록의 이미지와 스크롤이 정착하지 않았어요.');
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Moments moments,
  _Archive archive,
  Widget screen, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final container = ProviderContainer(
    overrides: [
      momentsRepositoryProvider.overrideWithValue(moments),
      privateMomentArchiveRepositoryProvider.overrideWithValue(archive),
      momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSans'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: DefaultAssetBundle(
            bundle: kIsWeb ? _MemoryBrowserAssets() : rootBundle,
            child: child!,
          ),
        ),
        home: screen,
      ),
    ),
  );
  await _settle(tester);
  return container;
}

Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 350,
}) async {
  final scrollable = find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: scrollable,
    maxScrolls: 60,
  );
  await _settle(tester);
}

Future<void> _close(
  WidgetTester tester,
  ProviderContainer container,
  _Moments moments,
  _Archive archive,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  container.dispose();
  await moments.changes.close();
  await archive.changes.close();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  testWidgets(
    'month calendar starts open, uses original photo identities at small decode, and supports leap dates',
    (tester) async {
      final moments = _Moments()
        ..today = DateTime.utc(2028, 2, 29)
        ..records = [_record('leap', DateTime.utc(2028, 2, 29))];
      final archive = _Archive(moments);
      final container = await _mount(
        tester,
        moments,
        archive,
        MomentsScreen(initialMonth: DateTime.utc(2028, 2)),
      );
      try {
        expect(find.byType(MomentMonthCalendar), findsOneWidget);
        expect(
          find.byKey(const ValueKey('moments-calendar-toggle')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('moments-calendar-2028-02-29')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('moments-calendar-2028-02-30')),
          findsNothing,
        );
        final thumbnails = tester.widgetList<SnapfitImage>(
          find.descendant(
            of: find.byType(MomentMonthCalendar),
            matching: find.byType(SnapfitImage),
          ),
        );
        expect(thumbnails, hasLength(1));
        expect(
          thumbnails.single.urlOrGs,
          moments.records.single.photos.single.storageUri,
        );
        expect(thumbnails.single.memCacheWidth, 112);
        expect(moments.mutations, 0);
        expect(archive.saves, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, moments, archive);
      }
    },
  );

  testWidgets(
    'choosing a date reaches the real large record and a pushed route preserves month and calendar state',
    (tester) async {
      final moments = _Moments()
        ..records = [
          for (var day = 20; day >= 1; day--)
            _record('day-$day', DateTime.utc(2026, 10, day)),
        ];
      final archive = _Archive(moments);
      final container = await _mount(
        tester,
        moments,
        archive,
        MomentsScreen(initialMonth: _october),
      );
      try {
        await tester.tap(
          find.byKey(const ValueKey('moments-calendar-2026-10-01')),
        );
        await _settle(tester);
        final target = find.byKey(const ValueKey('moment-record-day-1'));
        expect(target, findsOneWidget);
        expect(tester.getTopLeft(target).dy, inInclusiveRange(0, 650));
        final targetTop = tester.getTopLeft(target).dy;
        final navigator = tester.state<NavigatorState>(
          find.byType(Navigator).first,
        );
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('temporary route')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        navigator.pop();
        await _settle(tester);
        expect(tester.getTopLeft(target).dy, closeTo(targetTop, 1));
        // The header is deliberately lazy while the large selected record is
        // visible. Scroll back to prove its selected state survived.
        await _reveal(
          tester,
          find.byKey(const ValueKey('moments-month-title')),
          delta: -600,
        );
        expect(find.byType(MomentMonthCalendar), findsOneWidget);
        expect(find.text('2026년 10월'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.selected == true &&
                (widget.properties.label?.contains('2026년 10월 1일,') ?? false),
          ),
          findsOneWidget,
        );
        expect(moments.mutations, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, moments, archive);
      }
    },
  );

  testWidgets(
    'weekly selection saves up to three private candidates without changing records or creating an album',
    (tester) async {
      final moments = _Moments();
      final archive = _Archive(moments);
      final original = moments.records.single;
      final container = await _mount(
        tester,
        moments,
        archive,
        WeeklyMomentRecapScreen(
          today: _today,
          weekStart: _week,
          records: moments.records,
          ownerUserId: 'owner',
        ),
      );
      try {
        for (var i = 0; i < 4; i++) {
          await tester.tap(
            find.byKey(ValueKey('weekly-photo-choice-week-photo-$i')),
          );
          await tester.pumpAndSettle();
          if (i < 3) {
            await tester.tap(find.byTooltip('다음 돌아보기 사진'));
            await _settle(tester);
          }
        }
        expect(find.text('이번 주 후보 3 / 3'), findsOneWidget);
        expect(find.text('이번 주에는 세 장까지 고를 수 있어요.'), findsOneWidget);
        // This limit notice temporarily occupies the standard bottom snackbar
        // area. Let it close before tapping the real fixed save control.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        final save = find.byKey(const ValueKey('weekly-choices-save'));
        expect(save.hitTestable(), findsOneWidget);
        await tester.tap(save);
        await _settle(tester);
        expect(archive.saves.single.ids, [
          'week-photo-0',
          'week-photo-1',
          'week-photo-2',
        ]);
        expect(archive.saves.single.week, _week);
        expect(moments.records.single, same(original));
        expect(moments.mutations, 0);
        expect(find.text('비공개 후보로 저장됨'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, moments, archive);
      }
    },
  );

  testWidgets(
    'clearing saved weekly candidates uses an explicit empty weekly replacement',
    (tester) async {
      final moments = _Moments();
      final archive = _Archive(moments)..weekly = ['week-photo-0'];
      final container = await _mount(
        tester,
        moments,
        archive,
        WeeklyMomentRecapScreen(
          today: _today,
          weekStart: _week,
          records: moments.records,
          ownerUserId: 'owner',
        ),
      );
      try {
        await tester.tap(
          find.byKey(const ValueKey('weekly-photo-choice-week-photo-0')),
        );
        await tester.pumpAndSettle();
        expect(find.text('이번 주 후보 선택 해제'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('weekly-choices-save')));
        await _settle(tester);
        expect(archive.saves.single.ids, isEmpty);
        expect(moments.mutations, 0);
      } finally {
        await _close(tester, container, moments, archive);
      }
    },
  );

  testWidgets(
    'A to B to A before a pending weekly response keeps the old recap closed',
    (tester) async {
      final moments = _Moments();
      final archive = _Archive(moments)
        ..pendingWeekly = Completer<List<String>>();
      final container = await _mount(
        tester,
        moments,
        archive,
        WeeklyMomentRecapScreen(
          today: _today,
          weekStart: _week,
          records: moments.records,
          ownerUserId: 'owner',
        ),
      );
      try {
        moments.change('other');
        archive.change();
        moments.change('owner');
        archive.change();
        archive.pendingWeekly!.complete(['week-photo-0']);
        await _settle(tester);
        expect(find.text('계정이 변경되었어요'), findsOneWidget);
        expect(find.text('week 원래 기록'), findsNothing);
        expect(find.byKey(const ValueKey('weekly-choices-save')), findsNothing);
        expect(archive.saves, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, moments, archive);
      }
    },
  );

  testWidgets(
    'monthly preview places private choices first without automatically creating or publishing an album',
    (tester) async {
      final moments = _Moments()
        ..records = [_record('month', DateTime.utc(2026, 10, 31), photos: 9)];
      final archive = _Archive(moments)
        ..monthly = ['month-photo-8', 'month-photo-7'];
      final container = await _mount(
        tester,
        moments,
        archive,
        MonthlyMomentPreviewScreen(
          month: _october,
          records: moments.records,
          today: _today,
        ),
      );
      try {
        await _reveal(
          tester,
          find.byKey(const ValueKey('monthly-choices-summary')),
        );
        expect(find.text('돌아보기에서 고른 후보 2장을 먼저 모았어요.'), findsOneWidget);
        await _reveal(
          tester,
          find.byKey(const ValueKey('moment-photo-select-month-photo-8')),
        );
        final first = tester
            .widgetList<InkWell>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is InkWell &&
                    widget.key.toString().contains('moment-photo-select-'),
              ),
            )
            .first;
        expect(first.key, const ValueKey('moment-photo-select-month-photo-8'));
        final cover = tester.widget<TextButton>(
          find.byKey(const ValueKey('moment-photo-cover-month-photo-8')),
        );
        expect(cover.onPressed, isNull);
        expect(moments.mutations, 0);
        expect(archive.saves, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, moments, archive);
      }
    },
  );

  testWidgets(
    'a late monthly candidate response cannot replace an explicitly chosen cover',
    (tester) async {
      final moments = _Moments()
        ..records = [_record('month', DateTime.utc(2026, 10, 31), photos: 9)];
      final archive = _Archive(moments)
        ..pendingMonthly = Completer<List<String>>();
      final container = await _mount(
        tester,
        moments,
        archive,
        MonthlyMomentPreviewScreen(
          month: _october,
          records: moments.records,
          today: _today,
        ),
      );
      try {
        final coverFinder = find.byKey(
          const ValueKey('moment-photo-cover-month-photo-8'),
        );
        await _reveal(tester, coverFinder);
        expect(coverFinder.hitTestable(), findsOneWidget);
        await tester.tap(coverFinder);
        await tester.pumpAndSettle();
        archive.pendingMonthly!.complete(['month-photo-0']);
        await _settle(tester);
        expect(tester.widget<TextButton>(coverFinder).onPressed, isNull);
        expect(
          tester
              .widget<TextButton>(
                find.byKey(const ValueKey('moment-photo-cover-month-photo-0')),
              )
              .onPressed,
          isNotNull,
        );
        expect(moments.mutations, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, moments, archive);
      }
    },
  );

  testWidgets(
    'pending monthly choices cannot revive private photos after an account round trip',
    (tester) async {
      final moments = _Moments()
        ..records = [_record('month', DateTime.utc(2026, 10, 31), photos: 3)];
      final archive = _Archive(moments)
        ..pendingMonthly = Completer<List<String>>();
      final container = await _mount(
        tester,
        moments,
        archive,
        MonthlyMomentPreviewScreen(
          month: _october,
          records: moments.records,
          today: _today,
        ),
      );
      try {
        moments.change('other');
        archive.change();
        moments.change('owner');
        archive.change();
        archive.pendingMonthly!.complete(['month-photo-2']);
        await _settle(tester);
        expect(find.text('계정이 변경되었어요'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('moment-photo-select-month-photo-2')),
          findsNothing,
        );
        expect(moments.mutations, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, moments, archive);
      }
    },
  );
}
