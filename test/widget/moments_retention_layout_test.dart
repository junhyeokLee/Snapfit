import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/shared/snapfit_image.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/moments/data/moment_engagement_repository.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_engagement_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_publication_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moments_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_compose_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_saved_preview_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/weekly_moment_recap_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_entry_card.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_book_cover.dart';
import 'package:snap_fit/features/moments/presentation/widgets/web_moments_journal_layout.dart';

import '../helpers/memory_moment_draft_store.dart';
import '../helpers/memory_moment_publication_repository.dart';

const _assets = [
  'assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg',
  'assets/templates/jeju_travel/images/figma_small/jeju_sunset.jpg',
  'assets/templates/jeju_travel/images/figma_small/jeju_rocky_coast.jpg',
];
final _today = DateTime.utc(2026, 10, 26);
MomentRecord _record(
  String id,
  DateTime date, {
  int count = 1,
  String? caption,
}) => MomentRecord(
  id: id,
  recordDate: date,
  caption: caption ?? '바람이 좋았던 오후, 천천히 걸었어요.',
  revision: 1,
  photos: List.generate(
    count,
    (index) => MomentPhoto(
      id: '$id-$index',
      path: 'owner/moments/$id/$index.jpg',
      url: 'asset:${_assets[index % _assets.length]}',
      width: index == 1 ? 600 : 1600,
      height: index == 1 ? 800 : 900,
    ),
  ),
);

class _Repository implements MomentsRepository {
  String? actor = 'owner';
  final changes = StreamController<String?>.broadcast();
  List<MomentRecord> records = [_record('one', _today, count: 3)];
  List<MomentRecord>? weekRecords;
  DateTime today = _today;
  int? albumId;
  List<String> imported = [];
  int reads = 0;
  Future<MomentJournal> Function(DateTime)? readHandler;
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
    reads++;
    if (readHandler != null) return readHandler!(month);
    return MomentJournal(
      today: today,
      weekStart: momentWeekStart(today),
      month: month,
      records: records,
      weekPhotoCount: (weekRecords ?? records).fold<int>(
        0,
        (sum, record) => sum + record.photos.length,
      ),
      weekRecords: weekRecords,
      monthlyAlbumId: albumId,
      monthlyAlbumPhotoIds: imported,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    mutations++;
    throw StateError('Unexpected mutation ${invocation.memberName}');
  }
}

class _Engagement implements MomentEngagementRepository {
  final events = <MomentActivity>[];
  @override
  Future<bool> recordActivity(
    MomentActivity activity, {
    DateTime? month,
  }) async {
    events.add(activity);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Repository repository,
  Widget child, {
  Size size = const Size(390, 844),
  bool dark = false,
  double scale = 1,
  GlobalKey? capture,
  _Engagement? engagement,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final container = ProviderContainer(
    overrides: [
      momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
      momentsRepositoryProvider.overrideWithValue(repository),
      momentPublicationRepositoryProvider.overrideWithValue(
        MemoryMomentPublicationRepository(),
      ),
      momentEngagementRepositoryProvider.overrideWithValue(
        engagement ?? _Engagement(),
      ),
    ],
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
          child: RepaintBoundary(key: capture, child: child!),
        ),
        home: child,
      ),
    ),
  );
  await tester.runAsync(() async {
    final context = tester.element(find.byType(MaterialApp));
    for (final asset in _assets) {
      await precacheImage(
        ResizeImage.resizeIfNeeded(1200, null, AssetImage(asset)),
        context,
      );
    }
  });
  for (var frame = 0; frame < 2; frame++) {
    await tester.pump(const Duration(milliseconds: 400));
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
              AssetImage(source.substring(6)),
            ),
            context,
          );
        }
      }
    });
  }
  await tester.pumpAndSettle();
  return container;
}

Future<void> _expandRecord(WidgetTester tester, String id) async {
  final toggle = find.byKey(ValueKey('moment-record-toggle-$id'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  for (var frame = 0; frame < 6; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
  await tester.pumpAndSettle();
}

Future<void> _close(
  WidgetTester tester,
  ProviderContainer container,
  _Repository repository,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  container.dispose();
  await repository.changes.close();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['MOMENTS_CAPTURE'] != '1') return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory =
        Platform.environment['MOMENTS_CAPTURE_OUTPUT'] ??
        'output/moments-retention-20261026';
    final file = File('$directory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (Platform.environment['MOMENTS_CAPTURE'] == '1') {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      for (final family in ['Pretendard', 'NotoSansKR', 'NotoSans']) {
        final loader = FontLoader(family)
          ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'));
        await loader.load();
      }
    }
  });
  for (final dark in [false, true]) {
    testWidgets(
      'month calendar and one album entry precede photos in ${dark ? 'dark' : 'light'} journal',
      (tester) async {
        final repo = _Repository();
        final capture = GlobalKey();
        final container = await _mount(
          tester,
          repo,
          MomentsScreen(initialMonth: momentMonth(_today)),
          dark: dark,
          capture: capture,
        );
        try {
          final photo = find.byKey(const ValueKey('moment-photo-frame-one'));
          final monthAction = find.byKey(
            const ValueKey('home-monthly-album-entry'),
          );
          final calendar = find.byKey(const ValueKey('moments-photo-calendar'));
          expect(monthAction, findsOneWidget);
          expect(calendar, findsOneWidget);
          expect(
            find.byKey(const ValueKey('moments-monthly-album')),
            findsNothing,
          );
          expect(
            tester.getTopLeft(monthAction).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(calendar).dy),
          );
          expect(photo, findsNothing);
          await _expandRecord(tester, 'one');
          await tester.ensureVisible(photo);
          await tester.pumpAndSettle();
          expect(tester.getSize(photo).width, greaterThan(320));
          expect(
            tester.getSize(photo).width / tester.getSize(photo).height,
            closeTo(defaultCoverSize.ratio, .01),
          );
          expect(repo.mutations, 0);
          expect(tester.takeException(), isNull);
          await _capture(
            tester,
            capture,
            dark ? 'journal-dark' : 'journal-light',
          );
          await tester.tap(find.byTooltip('다음 기록 사진'));
          await tester.pumpAndSettle();
          expect(
            tester.getSize(photo).width / tester.getSize(photo).height,
            closeTo(defaultCoverSize.ratio, .01),
          );
          expect(find.text('2 / 3'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, container, repo);
        }
      },
    );
  }
  testWidgets(
    'empty journal explains a dated photo and a line before offering a monthly album',
    (tester) async {
      final repo = _Repository()..records = [];
      final capture = GlobalKey();
      final container = await _mount(
        tester,
        repo,
        MomentsScreen(initialMonth: momentMonth(_today)),
        capture: capture,
      );
      try {
        await _capture(tester, capture, 'journal-empty');
        final action = find.byKey(const ValueKey('moments-first-photo'));
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(find.text('사진 한 장 + 짧은 한 줄'), findsOneWidget);
        expect(find.text('오늘의 기록'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('moments-daily-note-preview')),
            matching: find.text('${_today.year}년 ${_today.month}월'),
          ),
          findsOneWidget,
        );
        expect(find.text('사진 아래에, 이날의 기분 한 줄'), findsOneWidget);
        expect(find.byType(MomentBookCover), findsNothing);
        expect(find.byType(MomentPhotoView), findsNothing);
        expect(
          find.byKey(const ValueKey('moments-first-photo')),
          findsOneWidget,
        );
        final note = find.byKey(const ValueKey('moments-daily-note-preview'));
        expect(tester.getSize(note).width, greaterThan(260));
        expect(action.hitTestable(), findsOneWidget);
        expect(find.text('날짜별 기록'), findsOneWidget);
        expect(find.text('월간 앨범'), findsOneWidget);
        expect(repo.mutations, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, repo);
      }
    },
  );
  testWidgets(
    'book previews keep actual official trim ratios, including landscape albums',
    (tester) async {
      for (final cover in coverSizes) {
        await tester.pumpWidget(
          MaterialApp(
            theme: SnapFitTheme.light(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 240,
                  child: MomentBookCover(
                    key: const ValueKey('physical-book'),
                    month: _today,
                    coverSize: cover,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final size = tester.getSize(
          find.byKey(const ValueKey('physical-book')),
        );
        final actual = coverCanvasBaseSize(cover);
        expect(
          size.width / size.height,
          closeTo(actual.width / actual.height, .001),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'desktop journal keeps large real photos beside secondary book actions in ${dark ? 'dark' : 'light'}',
      (tester) async {
        final repo = _Repository();
        final capture = GlobalKey();
        final record = repo.records.first;
        final container = await _mount(
          tester,
          repo,
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: WebMomentsJournalLayout(
                monthNavigation: const Text(
                  '2026년 10월',
                  style: TextStyle(fontSize: 24),
                ),
                records: [
                  MomentRecordCard(
                    record: record,
                    initiallyExpanded: true,
                    maxPhotoHeight: 560,
                    onEdit: () {},
                  ),
                ],
                weekly: MomentWeekCard(photoCount: 3, onRecord: () {}),
                album: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 180,
                        child: MomentBookCover(
                          month: _today,
                          photo: record.photos.first,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '나의 10월, 한 권으로',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      const Text('사진을 골라 월간 앨범 만들기'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          size: const Size(1280, 900),
          dark: dark,
          capture: capture,
        );
        try {
          final photo = find.byKey(const ValueKey('moment-photo-frame-one'));
          expect(
            find.byKey(const ValueKey('moments-desktop-columns')),
            findsOneWidget,
          );
          expect(tester.getSize(photo).width, greaterThan(760));
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('moments-add'))).dy,
            lessThan(tester.getBottomLeft(photo).dy),
          );
          expect(tester.takeException(), isNull);
          await _capture(
            tester,
            capture,
            dark ? 'journal-desktop-dark' : 'journal-desktop-light',
          );
        } finally {
          await _close(tester, container, repo);
        }
      },
    );
  }
  testWidgets(
    'compact web journal puts photo action before a tall record at large text',
    (tester) async {
      final repo = _Repository();
      final container = await _mount(
        tester,
        repo,
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: WebMomentsJournalLayout(
              monthNavigation: const Text('2026년 10월'),
              records: [
                MomentRecordCard(
                  record: repo.records.first,
                  initiallyExpanded: true,
                  onEdit: () {},
                ),
              ],
              weekly: MomentWeekCard(photoCount: 3, onRecord: () {}),
            ),
          ),
        ),
        size: const Size(320, 700),
        scale: 2,
      );
      try {
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('moments-add'))).dy,
          lessThan(
            tester
                .getTopLeft(
                  find.byKey(const ValueKey('moment-photo-frame-one')),
                )
                .dy,
          ),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, repo);
      }
    },
  );
  for (final recordedToday in [false, true]) {
    testWidgets(
      'daily action identifies adding another photo today=$recordedToday',
      (tester) async {
        final repo = _Repository()
          ..records = [
            _record(
              'sample',
              recordedToday ? _today : _today.subtract(const Duration(days: 1)),
            ),
          ];
        final container = await _mount(tester, repo, const MomentsScreen());
        try {
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('moments-add')),
              matching: find.text(recordedToday ? '오늘 한 장 더' : '오늘 기록하기'),
            ),
            findsOneWidget,
          );
          expect(repo.mutations, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, container, repo);
        }
      },
    );
  }

  testWidgets(
    'weekly recap includes cross month photos and excludes outside current server week',
    (tester) async {
      final today = DateTime.utc(2026, 11, 1);
      final repo = _Repository()
        ..today = today
        ..records = []
        ..weekRecords = [
          _record('oct', DateTime.utc(2026, 10, 31), caption: '10월의 마지막 바다'),
          _record('nov', today, caption: '11월의 첫 햇살'),
          _record('old', DateTime.utc(2026, 10, 25), caption: '지난 주'),
          _record('future', DateTime.utc(2026, 11, 2), caption: '미래'),
        ];
      final engagement = _Engagement();
      final capture = GlobalKey();
      final container = await _mount(
        tester,
        repo,
        const MomentsScreen(),
        engagement: engagement,
        capture: capture,
      );
      try {
        final recap = find.byKey(const ValueKey('moments-week-recap'));
        expect(find.widgetWithText(TextButton, '이번 주 돌아보기'), findsOneWidget);
        expect(tester.getSize(recap).height, greaterThanOrEqualTo(44));
        expect(
          tester.getTopLeft(recap).dy,
          greaterThanOrEqualTo(
            tester
                .getBottomLeft(
                  find.byKey(const ValueKey('moments-photo-calendar')),
                )
                .dy,
          ),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('moments-week-recap')),
        );
        await tester.tap(find.byKey(const ValueKey('moments-week-recap')));
        await tester.pumpAndSettle();
        expect(find.byType(WeeklyMomentRecapScreen), findsOneWidget);
        expect(find.text('1 / 2'), findsOneWidget);
        expect(find.text('10월의 마지막 바다'), findsOneWidget);
        expect(find.text('지난 주'), findsNothing);
        expect(find.text('미래'), findsNothing);
        expect(engagement.events, [MomentActivity.recapViewed]);
        expect(repo.mutations, 0);
        await _capture(tester, capture, 'weekly-recap');
        await tester.tap(find.byTooltip('다음 돌아보기 사진'));
        await tester.pumpAndSettle();
        expect(find.text('11월의 첫 햇살'), findsOneWidget);
        expect(find.text('2 / 2'), findsOneWidget);
        repo.change('another');
        await tester.pumpAndSettle();
        expect(find.text('계정이 변경되었어요'), findsOneWidget);
        expect(find.text('11월의 첫 햇살'), findsNothing);
        repo.change('owner');
        await tester.pumpAndSettle();
        expect(find.text('계정이 변경되었어요'), findsOneWidget);
        expect(find.text('11월의 첫 햇살'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, repo);
      }
    },
  );
  testWidgets(
    'narrow dark journal and recap tolerate large accessibility text',
    (tester) async {
      final repo = _Repository();
      final container = await _mount(
        tester,
        repo,
        const MomentsScreen(),
        size: const Size(320, 720),
        dark: true,
        scale: 2,
      );
      try {
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('moments-week-recap')),
          180,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 20,
        );
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('moments-week-recap'))),
          alignment: .45,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('moments-week-recap')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(WeeklyMomentRecapScreen), findsOneWidget);
        await tester.tap(find.byTooltip('다음 돌아보기 사진'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, repo);
      }
    },
  );
  testWidgets(
    'completed save renders its book immediately while later journal reads are blocked',
    (tester) async {
      final repo = _Repository();
      final container = await _mount(tester, repo, const MomentsScreen());
      final pending = Completer<MomentJournal>();
      try {
        repo.readHandler = (_) => pending.future;
        await tester.tap(find.byKey(const ValueKey('moments-add')));
        await tester.pumpAndSettle();
        expect(find.byType(MomentComposeScreen), findsOneWidget);
        Navigator.of(
          tester.element(find.byType(MomentComposeScreen)),
        ).pop(_record('saved-now', _today));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(MomentSavedPreviewScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('moment-saved-book-cover')),
          findsOneWidget,
        );
        expect(
          pending.isCompleted,
          isFalse,
          reason: 'A blocked journal request must not delay the saved cover.',
        );
        expect(repo.mutations, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, repo);
      }
    },
  );
  testWidgets(
    'record editor deletion result returns to journal without a saved reward',
    (tester) async {
      final repo = _Repository();
      final container = await _mount(tester, repo, const MomentsScreen());
      try {
        await _expandRecord(tester, 'one');
        final edit = find.byKey(const ValueKey('moment-edit-one'));
        await tester.ensureVisible(edit);
        await tester.pumpAndSettle();
        expect(edit.hitTestable(), findsOneWidget);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        expect(find.byType(MomentComposeScreen), findsOneWidget);
        Navigator.of(
          tester.element(find.byType(MomentComposeScreen)),
        ).pop(true);
        await tester.pumpAndSettle();
        expect(find.byType(MomentsScreen), findsOneWidget);
        expect(find.byType(MomentSavedPreviewScreen), findsNothing);
        expect(repo.reads, greaterThan(1));
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, repo);
      }
    },
  );
  testWidgets('reminder action is optional and invokes supplied destination', (
    tester,
  ) async {
    final repo = _Repository();
    int taps = 0;
    final container = await _mount(
      tester,
      repo,
      MomentsScreen(onReminderSettings: () => taps++),
    );
    try {
      await tester.tap(find.byKey(const ValueKey('moments-reminder-settings')));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(repo.mutations, 0);
    } finally {
      await _close(tester, container, repo);
    }
  });
  testWidgets(
    'entry shares real current month records and clears thumbnail when logged out',
    (tester) async {
      final repo = _Repository();
      final container = await _mount(
        tester,
        repo,
        Scaffold(
          body: Column(
            children: [
              MomentsEntryCard(onTap: () {}),
              MomentsEntryCard(onTap: () {}),
            ],
          ),
        ),
      );
      try {
        expect(find.text('오늘 남긴 순간을 다시 펼쳐보세요.'), findsNWidgets(2));
        expect(repo.reads, 1);
        expect(find.byType(SnapfitImage), findsNWidgets(2));
        repo.change(null);
        await tester.pumpAndSettle();
        expect(find.text('사진 한 장과 한 줄로, 하루씩 쌓는 나의 기록'), findsNWidgets(2));
        expect(find.byType(SnapfitImage), findsNothing);
        expect(repo.reads, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, repo);
      }
    },
  );
}
