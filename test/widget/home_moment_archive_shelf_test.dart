import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_moment_archive_shelf.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_moment_summary_card.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/widgets/first_book_next_step_card.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

import '../helpers/memory_moment_draft_store.dart';

const _assets = [
  'assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg',
  'assets/templates/jeju_travel/images/figma_small/jeju_sunset.jpg',
  'assets/templates/jeju_travel/images/figma_small/jeju_rocky_coast.jpg',
];
final _today = DateTime.utc(2026, 11, 4);
MomentRecord _record(
  String id,
  DateTime date, {
  int photos = 1,
  String caption = '그날 남겨둔 이야기',
  int asset = 0,
}) => MomentRecord(
  id: id,
  recordDate: date,
  caption: caption,
  revision: 1,
  photos: [
    for (var i = 0; i < photos; i++)
      MomentPhoto(
        id: '$id-$i',
        path: 'owner/moments/$id/$i.jpg',
        url: 'asset:${_assets[(asset + i) % _assets.length]}',
        width: 1200,
        height: 800,
      ),
  ],
);

class _Repository extends Fake implements MomentsRepository {
  String? owner = 'owner';
  int reads = 0;
  final changes = StreamController<String?>.broadcast();
  List<MomentRecord> records = [
    _record('today', _today),
    _record('third', DateTime.utc(2026, 11, 3), asset: 1),
    _record('third-extra', DateTime.utc(2026, 11, 3), asset: 2),
    _record('second', DateTime.utc(2026, 11, 2), asset: 2),
    _record(
      'note',
      DateTime.utc(2026, 11, 1),
      photos: 0,
      caption: '창가에서 듣던 노래를 적었어요.',
    ),
    _record('old', DateTime.utc(2026, 10, 31)),
    _record('future', DateTime.utc(2026, 11, 5)),
  ];
  @override
  String? get currentUserId => owner;
  @override
  Stream<String?> get authChanges => changes.stream;
  @override
  Future<MomentJournal> listMonth(DateTime? requestedMonth) async {
    final month = requestedMonth ?? momentMonth(_today);
    reads++;
    return MomentJournal(
      today: _today,
      weekStart: momentWeekStart(_today),
      month: month,
      records: records,
      weekPhotoCount: 4,
    );
  }

  void change(String? next) {
    owner = next;
    changes.add(next);
  }
}

Future<({ProviderContainer container, Future<void> Function() close})> _boot(
  WidgetTester tester,
  _Repository repo, {
  bool withToday = false,
  Widget? child,
  ValueChanged<DateTime>? onDate,
  ValueChanged<DateTime>? onMonth,
  double width = 390,
  double scale = 1,
  GlobalKey? captureKey,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    retry: (_, __) => null,
    overrides: [
      momentsRepositoryProvider.overrideWithValue(repo),
      momentEntryClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 11, 4),
      ),
      momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: captureKey,
          child: Scaffold(
            body: SingleChildScrollView(
              child:
                  child ??
                  Column(
                    children: [
                      if (withToday)
                        HomeMomentSummaryCard(
                          onRecord: () {},
                          onOpenMonth: () {},
                          onOpenDate: (_) {},
                          onSignIn: () {},
                        ),
                      HomeMomentArchiveShelf(
                        onOpenDate: onDate ?? (_) {},
                        onOpenMonth: onMonth ?? (_) {},
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final asset in _assets) {
      await precacheImage(
        ResizeImage(AssetImage(asset), width: 384),
        tester.element(find.byType(MaterialApp)),
      );
    }
  });
  await tester.pumpAndSettle();
  var closed = false;
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await repo.changes.close();
    await tester.pump();
  }

  addTearDown(close);
  return (container: container, close: close);
}

void main() {
  testWidgets(
    'recent personal days share the journal and include real written notes',
    (tester) async {
      final repo = _Repository();
      DateTime? date, month;
      final session = await _boot(
        tester,
        repo,
        withToday: true,
        onDate: (value) => date = value,
        onMonth: (value) => month = value,
      );
      expect(repo.reads, 1);
      for (final day in ['2026-11-03', '2026-11-02', '2026-11-01']) {
        expect(
          find.byKey(ValueKey('home-moment-archive-$day')),
          findsOneWidget,
        );
      }
      for (final day in ['2026-11-04', '2026-10-31', '2026-11-05']) {
        expect(find.byKey(ValueKey('home-moment-archive-$day')), findsNothing);
      }
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HomeMomentArchiveShelf),
          matching: find.byType(SnapfitImage),
        ),
        findsNWidgets(2),
      );
      await tester.tap(
        find.byKey(const ValueKey('home-moment-archive-2026-11-03')),
      );
      await tester.tap(find.byKey(const ValueKey('home-moment-archive-month')));
      expect(date, DateTime.utc(2026, 11, 3));
      expect(month, DateTime.utc(2026, 11));
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );

  testWidgets(
    'one today photograph is not duplicated, another real photo can appear',
    (tester) async {
      final repo = _Repository()..records = [_record('today', _today)];
      final session = await _boot(tester, repo);
      expect(
        find.byKey(const ValueKey('home-moment-archive-section')),
        findsNothing,
      );
      repo.records = [_record('today', _today, photos: 2)];
      session.container.invalidate(momentsMonthProvider);
      session.container.invalidate(momentEntryJournalProvider);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-moment-archive-2026-11-04')),
        findsOneWidget,
      );
      final image = tester.widget<SnapfitImage>(find.byType(SnapfitImage));
      expect(image.urlOrGs, repo.records.single.photos[1].storageUri);
      expect(image.fallbackSources, ['asset:${_assets[1]}']);
      expect(image.fit, BoxFit.contain);
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );

  testWidgets('logout removes every private archive thumbnail', (tester) async {
    final repo = _Repository();
    final session = await _boot(tester, repo);
    expect(
      find.byKey(const ValueKey('home-moment-archive-section')),
      findsOneWidget,
    );
    repo.change(null);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('home-moment-archive-section')),
      findsNothing,
    );
    expect(find.byType(SnapfitImage), findsNothing);
    expect(repo.reads, 1);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets('a quiet workbench ends with a real new album action', (
    tester,
  ) async {
    var created = 0;
    final session = await _boot(
      tester,
      _Repository(),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FirstBookNextStepCard(
          ownerId: 'owner',
          albums: const [],
          sectionTitle: '이어서 만드는 이야기',
          onMoments: () {},
          onDraft: (_) {},
          onContinueAlbum: (_) {},
          idleContent: HomeNextStoryEntry(onCreate: () => created++),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('first-book-section-title')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('home-next-story-create')));
    expect(created, 1);
    expect(tester.takeException(), isNull);
    await session.close();
  });

  testWidgets(
    'an actual creation draft keeps its resume route and section heading',
    (tester) async {
      var resumed = 0;
      final session = await _boot(
        tester,
        _Repository(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FirstBookNextStepCard(
            ownerId: 'owner',
            albums: const [],
            sectionTitle: '이어서 만드는 이야기',
            creationDraftTitle: '여름의 기록',
            onResumeCreation: () => resumed++,
            onMoments: () {},
            onDraft: (_) {},
            onContinueAlbum: (_) {},
            idleContent: const SizedBox.shrink(),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('first-book-section-title')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('first-book-next-step')));
      expect(resumed, 1);
      expect(tester.takeException(), isNull);
      await session.close();
    },
  );

  for (final sample in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'archive and note tiles remain readable at ${sample.$1} scale ${sample.$2}',
      (tester) async {
        if (const bool.fromEnvironment('EXPORT_HOME_DAILY_REVIEW')) {
          await tester.runAsync(() async {
            await (FontLoader('NotoSans')
                  ..addFont(
                    rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'),
                  )
                  ..addFont(
                    rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf'),
                  )
                  ..addFont(
                    rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'),
                  ))
                .load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
        }
        final key = GlobalKey();
        final session = await _boot(
          tester,
          _Repository(),
          width: sample.$1,
          scale: sample.$2,
          captureKey: key,
        );
        if (sample.$2 == 1)
          expect(
            tester.getSize(find.byType(HomeMomentArchiveShelf)).height,
            lessThanOrEqualTo(230),
          );
        expect(tester.takeException(), isNull);
        if (sample.$2 == 2 &&
            const bool.fromEnvironment('EXPORT_HOME_DAILY_REVIEW')) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            try {
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              const out = String.fromEnvironment('HOME_DAILY_REVIEW_OUTPUT');
              if (out.isEmpty)
                throw StateError('An external review path is required');
              final file = File('$out/archive-320-large-text.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(png!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
        await session.close();
      },
    );
  }
}
