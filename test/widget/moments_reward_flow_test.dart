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
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/moments/data/moment_engagement_repository.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/domain/monthly_album_builder.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_engagement_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_saved_preview_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/monthly_moment_preview_screen.dart';
import 'package:snap_fit/shared/snapfit_image.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

final _today = DateTime.utc(2026, 10, 26);
final _month = DateTime.utc(2026, 10);

MomentRecord _record(String id, {DateTime? date}) => MomentRecord(
  id: id,
  recordDate: date ?? _today,
  caption: '산책에서 만난 빛',
  photos: [
    MomentPhoto(
      id: '$id-photo',
      path: 'owner/moments/$id/photo.png',
      url: 'asset:assets/cover/cover1.png',
      width: 600,
      height: 800,
    ),
  ],
  revision: 1,
);

MomentJournal _journal({
  List<MomentRecord>? records,
  int? albumId,
  List<String> imported = const [],
}) => MomentJournal(
  today: _today,
  weekStart: momentWeekStart(_today),
  month: _month,
  records: records ?? [_record('saved')],
  weekPhotoCount: 1,
  monthlyAlbumId: albumId,
  monthlyAlbumPhotoIds: imported,
);

class _Engagement implements MomentEngagementRepository {
  final events = <({MomentActivity activity, DateTime? month})>[];
  @override
  Future<bool> recordActivity(
    MomentActivity activity, {
    DateTime? month,
  }) async {
    events.add((activity: activity, month: month));
    return true;
  }

  @override
  Future<MomentEngagement> load() async =>
      const MomentEngagement(reminder: MomentReminder(), hasRecords: true);
  @override
  Future<MomentEngagement> saveReminder(MomentReminder reminder) async =>
      MomentEngagement(reminder: reminder, hasRecords: true);
}

class _Repository implements MomentsRepository {
  String? actor = 'owner';
  final changes = StreamController<String?>.broadcast();
  final creates = <String>[];
  final appends = <List<String>>[];
  final fetches = <int>[];
  final reads = <DateTime>[];
  Future<Album> Function()? appendHandler;
  Future<Album> Function()? fetchHandler;
  Future<MomentJournal> Function(DateTime)? readHandler;
  Album stored = Album(
    id: 73,
    title: '내가 직접 꾸민 제주',
    userId: 'owner',
    coverLayersJson: jsonEncode({
      'pages': [
        {'isCover': true, 'backgroundColor': 0xFFF7F4EF, 'layers': []},
      ],
    }),
  );
  @override
  String? get currentUserId => actor;
  @override
  Stream<String?> get authChanges => changes.stream;
  void change(String? next) {
    actor = next;
    changes.add(next);
  }

  @override
  Future<MomentJournal> listMonth(DateTime month) async {
    reads.add(month);
    return readHandler?.call(month) ?? _journal();
  }

  @override
  Future<MomentRecord> save({
    required String id,
    required DateTime recordDate,
    required String caption,
    required List<MomentPhoto> existingPhotos,
    required List<MomentUpload> uploads,
    List<MomentPhoto> originalPhotos = const [],
    int? expectedRevision,
  }) => throw StateError('Preview must not save records');
  @override
  Future<void> delete(MomentRecord record) =>
      throw StateError('Preview must not delete records');
  @override
  Future<Album> fetchAlbum(int id) async {
    fetches.add(id);
    return fetchHandler?.call() ?? stored;
  }

  @override
  Future<Album> createMonthlyAlbum({
    required DateTime month,
    required List<MomentRecord> selectedRecords,
    required List<String> selectedPhotoIds,
    required String title,
  }) async {
    creates.add(title);
    return stored;
  }

  @override
  Future<Album> appendMonthlyAlbum({
    required DateTime month,
    required List<MomentRecord> selectedRecords,
    required List<String> selectedPhotoIds,
  }) async {
    appends.add(List.of(selectedPhotoIds));
    return appendHandler?.call() ?? stored;
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Repository repository,
  _Engagement engagement,
  Widget screen, {
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  final container = ProviderContainer(
    overrides: [
      momentsRepositoryProvider.overrideWithValue(repository),
      momentEngagementRepositoryProvider.overrideWithValue(engagement),
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
          child: RepaintBoundary(
            key: const ValueKey('moment-capture-root'),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push<void>(MaterialPageRoute<void>(builder: (_) => screen)),
              child: const Text('화면 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await precacheImage(
      ResizeImage.resizeIfNeeded(
        1200,
        null,
        const AssetImage('assets/cover/cover1.png'),
      ),
      tester.element(find.text('화면 열기')),
    );
  });
  await tester.tap(find.text('화면 열기'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    for (final image in tester.widgetList<SnapfitImage>(
      find.byType(SnapfitImage),
    )) {
      if (!image.urlOrGs.startsWith('asset:')) continue;
      await precacheImage(
        ResizeImage.resizeIfNeeded(
          image.memCacheWidth,
          image.memCacheHeight,
          AssetImage(image.urlOrGs.substring(6)),
        ),
        tester.element(find.byType(SnapfitImage).first),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 60));
  });
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(
        image.image,
        tester.element(find.byType(Image).first),
      );
    }
  });
  await tester.pumpAndSettle();
  return container;
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

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  if (target.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(
    target,
    160,
    scrollable: scrollable,
    maxScrolls: 30,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  final captureDirectory = Platform.environment['MOMENTS_CAPTURE_DIR'];
  if (captureDirectory != null) {
    setUpAll(() async {
      for (final entry in {
        'NotoSans': [
          'assets/fonts/NotoSansKR-Regular.ttf',
          'assets/fonts/NotoSansKR-SemiBold.ttf',
          'assets/fonts/NotoSansKR-Bold.ttf',
        ],
        'Eulyoo': [
          'assets/fonts/Eulyoo1945-Regular.ttf',
          'assets/fonts/Eulyoo1945-SemiBold.ttf',
        ],
        'Poppins': [
          'assets/fonts/Poppins-Regular.otf',
          'assets/fonts/Poppins-SemiBold.otf',
        ],
        'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
      }.entries) {
        final loader = FontLoader(entry.key);
        for (final path in entry.value) {
          loader.addFont(rootBundle.load(path));
        }
        await loader.load();
      }
    });
    for (final dark in [false, true]) {
      testWidgets('capture saved reward ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        final repository = _Repository();
        final engagement = _Engagement();
        final container = await _mount(
          tester,
          repository,
          engagement,
          MomentSavedPreviewScreen(
            record: _record('saved'),
            journal: _journal(),
          ),
          dark: dark,
        );
        try {
          await _capture(
            tester,
            '$captureDirectory/reward-${dark ? 'dark' : 'light'}.png',
          );
        } finally {
          await _close(tester, container, repository);
        }
      });
    }
    testWidgets('capture safe monthly photo append', (tester) async {
      final repository = _Repository();
      final engagement = _Engagement();
      final draft = buildMonthlyMomentAlbum(
        month: _month,
        records: [_record('old')],
        selectedPhotoIds: ['old-photo'],
        title: '도시를 걷는 작은 장면들',
      );
      repository.stored = repository.stored.copyWith(
        title: '도시를 걷는 작은 장면들',
        coverLayersJson: draft.coverLayersJson,
      );
      final container = await _mount(
        tester,
        repository,
        engagement,
        MonthlyMomentPreviewScreen(
          month: _month,
          records: [_record('old'), _record('new')],
          existingAlbumId: 73,
          importedPhotoIds: const ['old-photo'],
        ),
      );
      try {
        await _reveal(
          tester,
          find.byKey(const ValueKey('monthly-moment-append')),
        );
        await _capture(tester, '$captureDirectory/append-light.png');
      } finally {
        await _close(tester, container, repository);
      }
    });
  }
  testWidgets(
    'saved cover uses the generated paper color instead of a stale green canvas',
    (tester) async {
      final repository = _Repository();
      final engagement = _Engagement();
      final container = await _mount(
        tester,
        repository,
        engagement,
        MomentSavedPreviewScreen(record: _record('saved'), journal: _journal()),
      );
      try {
        final cover = tester.widget<Container>(
          find.byKey(const ValueKey('moment-saved-book-cover')),
        );
        final generated = buildMonthlyMomentAlbum(
          month: _month,
          records: [_record('saved')],
          selectedPhotoIds: const ['saved-photo'],
        );
        final document = jsonDecode(generated.coverLayersJson) as Map;
        final color = Color(
          ((document['pages'] as List).first as Map)['backgroundColor'] as int,
        );
        expect((cover.decoration as BoxDecoration).color, color);
        expect(color, const Color(0xFFE7F8FB));
        expect(repository.creates, isEmpty);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );
  for (final cover in [coverSizes[1], coverSizes[2]]) {
    testWidgets(
      'saved monthly preview preserves ${cover.productId} physical shape and existing paper',
      (tester) async {
        final repository = _Repository();
        final engagement = _Engagement();
        final generated = buildMonthlyMomentAlbum(
          month: _month,
          records: [_record('old')],
          selectedPhotoIds: const ['old-photo'],
        );
        final document =
            jsonDecode(generated.coverLayersJson) as Map<String, dynamic>;
        document['printProduct'] = cover.printProduct;
        ((document['pages'] as List).first as Map)['backgroundColor'] =
            0xFFD9E9DF;
        final original = jsonEncode(document);
        repository.stored = repository.stored.copyWith(
          ratio: cover.ratio.toString(),
          coverLayersJson: original,
        );
        final container = await _mount(
          tester,
          repository,
          engagement,
          MonthlyMomentPreviewScreen(
            month: _month,
            records: [_record('old')],
            existingAlbumId: 73,
            importedPhotoIds: const ['old-photo'],
          ),
        );
        try {
          final preview = find.byKey(const ValueKey('monthly-moment-preview'));
          final size = tester.getSize(preview);
          final canvas = coverCanvasBaseSize(cover);
          expect(size.width / size.height, closeTo(canvas.aspectRatio, .001));
          final renderer = tester.widget<TemplatePageRenderer>(
            find.byType(TemplatePageRenderer).first,
          );
          expect(renderer.designCanvasSize, canvas);
          expect(repository.stored.coverLayersJson, original);
          expect(repository.creates, isEmpty);
          expect(repository.appends, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await _close(tester, container, repository);
        }
      },
    );
  }
  testWidgets(
    'first save renders actual saved photo and never automatically creates an album',
    (tester) async {
      final repository = _Repository();
      final engagement = _Engagement();
      final container = await _mount(
        tester,
        repository,
        engagement,
        MomentSavedPreviewScreen(record: _record('saved'), journal: _journal()),
      );
      try {
        expect(find.text('내 한 달의\n첫 장이 생겼어요.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('moment-saved-book-cover')),
          findsOneWidget,
        );
        expect(
          tester.widget<SnapfitImage>(find.byType(SnapfitImage).first).urlOrGs,
          'asset:assets/cover/cover1.png',
        );
        expect(repository.creates, isEmpty);
        expect(repository.appends, isEmpty);
        expect(repository.fetches, isEmpty);
        expect(engagement.events.single.activity, MomentActivity.rewardViewed);
        await _tap(tester, 'moment-saved-return');
        expect(find.text('화면 열기'), findsOneWidget);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'subsequent save merges only its month and uses saved month for backdated previews',
    (tester) async {
      final repository = _Repository();
      final engagement = _Engagement();
      final record = _record('september', date: DateTime.utc(2026, 9, 20));
      repository.readHandler = (month) async => MomentJournal(
        today: _today,
        weekStart: momentWeekStart(_today),
        month: month,
        records: [record],
        weekPhotoCount: 1,
        monthlyAlbumId: 88,
        monthlyAlbumPhotoIds: const ['earlier-photo'],
      );
      final container = await _mount(
        tester,
        repository,
        engagement,
        MomentSavedPreviewScreen(
          record: record,
          journal: _journal(
            records: [_record('october')],
            albumId: 73,
            imported: ['october-photo'],
          ),
        ),
      );
      try {
        expect(find.text('이 순간이,\n한 달의 책이 될 거예요.'), findsOneWidget);
        expect(repository.reads, isEmpty);
        await _tap(tester, 'moment-saved-preview');
        final preview = tester.widget<MonthlyMomentPreviewScreen>(
          find.byType(MonthlyMomentPreviewScreen),
        );
        expect(preview.month, DateTime.utc(2026, 9));
        expect(preview.existingAlbumId, 88);
        expect(preview.importedPhotoIds, ['earlier-photo']);
        expect(preview.records.map((record) => record.id), ['september']);
        expect(repository.creates, isEmpty);
        expect(repository.reads, [DateTime.utc(2026, 9)]);
        expect(repository.fetches, [88]);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'reward stays private after account changes even when original account returns',
    (tester) async {
      final repository = _Repository();
      final engagement = _Engagement();
      final container = await _mount(
        tester,
        repository,
        engagement,
        MomentSavedPreviewScreen(record: _record('saved'), journal: _journal()),
      );
      try {
        repository.change('other');
        await tester.pumpAndSettle();
        repository.change('owner');
        await tester.pumpAndSettle();
        expect(find.text('계정이 변경되었어요'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('moment-saved-book-cover')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('moment-saved-preview')),
          findsNothing,
        );
        expect(engagement.events.length, 1);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'monthly lookup failure keeps saved cover and allows explicit retry',
    (tester) async {
      final repository = _Repository();
      final engagement = _Engagement();
      repository.readHandler = (_) async =>
          throw const MomentException('연결을 확인해 주세요. 기록은 저장됐어요.');
      final container = await _mount(
        tester,
        repository,
        engagement,
        MomentSavedPreviewScreen(record: _record('saved'), journal: _journal()),
      );
      try {
        expect(repository.reads, isEmpty);
        await _tap(tester, 'moment-saved-preview');
        expect(find.text('연결을 확인해 주세요. 기록은 저장됐어요.'), findsOneWidget);
        await _reveal(
          tester,
          find.byKey(const ValueKey('moment-saved-book-cover')),
        );
        expect(
          find.byKey(const ValueKey('moment-saved-book-cover')),
          findsOneWidget,
        );
        repository.readHandler = null;
        await _tap(tester, 'moment-saved-preview');
        expect(find.byType(MonthlyMomentPreviewScreen), findsOneWidget);
        expect(repository.creates, isEmpty);
        expect(repository.appends, isEmpty);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets('late fresh-month lookup cannot open another accounts preview', (
    tester,
  ) async {
    final repository = _Repository();
    final engagement = _Engagement();
    final pending = Completer<MomentJournal>();
    repository.readHandler = (_) => pending.future;
    final container = await _mount(
      tester,
      repository,
      engagement,
      MomentSavedPreviewScreen(record: _record('saved'), journal: _journal()),
    );
    try {
      await _tap(tester, 'moment-saved-preview');
      expect(repository.reads.length, 1);
      repository.change('other');
      await tester.pumpAndSettle();
      repository.change('owner');
      await tester.pumpAndSettle();
      pending.complete(_journal());
      await tester.pumpAndSettle();
      expect(find.text('계정이 변경되었어요'), findsOneWidget);
      expect(find.byType(MonthlyMomentPreviewScreen), findsNothing);
      expect(repository.creates, isEmpty);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets(
    'existing album shows saved title and offers only unimported photos',
    (tester) async {
      final repository = _Repository();
      final engagement = _Engagement();
      final container = await _mount(
        tester,
        repository,
        engagement,
        MonthlyMomentPreviewScreen(
          month: _month,
          records: [_record('old'), _record('new')],
          existingAlbumId: 73,
          importedPhotoIds: const ['old-photo'],
        ),
      );
      try {
        expect(find.text('내가 직접 꾸민 제주'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('monthly-moment-title')),
          findsNothing,
        );
        await _reveal(
          tester,
          find.byKey(const ValueKey('moment-photo-select-new-photo')),
        );
        expect(
          find.byKey(const ValueKey('moment-photo-select-old-photo')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('moment-photo-cover-new-photo')),
          findsNothing,
        );
        expect(repository.appends, isEmpty);
        expect(repository.creates, isEmpty);
        expect(
          engagement.events.single.activity,
          MomentActivity.monthlyPreviewed,
        );
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'append selection is announced as a new photo and never as the cover',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _Repository();
      final engagement = _Engagement();
      final container = await _mount(
        tester,
        repository,
        engagement,
        MonthlyMomentPreviewScreen(
          month: _month,
          records: [_record('new')],
          existingAlbumId: 73,
        ),
      );
      try {
        await _reveal(
          tester,
          find.byKey(const ValueKey('moment-photo-select-new-photo')),
        );
        expect(find.bySemanticsLabel(RegExp('10월 26일 사진')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('10월 26일 사진.*표지')), findsNothing);
        expect(
          find.byKey(const ValueKey('moment-photo-cover-new-photo')),
          findsNothing,
        );
      } finally {
        await _close(tester, container, repository);
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'append is explicit single flight and opens same preserved album',
    (tester) async {
      final repository = _Repository();
      final engagement = _Engagement();
      final pending = Completer<Album>();
      repository.appendHandler = () => pending.future;
      Album? opened;
      final container = await _mount(
        tester,
        repository,
        engagement,
        MonthlyMomentPreviewScreen(
          month: _month,
          records: [_record('old'), _record('new')],
          existingAlbumId: 73,
          importedPhotoIds: const ['old-photo'],
          onAlbumCreated: (album) async {
            opened = album;
          },
        ),
      );
      try {
        final target = find.byKey(const ValueKey('monthly-moment-append'));
        await _reveal(tester, target);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pump();
        await tester.tap(target, warnIfMissed: false);
        await tester.pump();
        expect(repository.appends, [
          ['new-photo'],
        ]);
        expect(opened, isNull);
        pending.complete(repository.stored);
        await tester.pumpAndSettle();
        expect(opened?.id, 73);
        expect(opened?.title, '내가 직접 꾸민 제주');
        expect(opened?.coverLayersJson, repository.stored.coverLayersJson);
        expect(repository.creates, isEmpty);
        expect(find.text('앨범 이어서 편집하기'), findsOneWidget);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'open without adding fetches latest existing album without append',
    (tester) async {
      final repository = _Repository();
      final engagement = _Engagement();
      Album? opened;
      final container = await _mount(
        tester,
        repository,
        engagement,
        MonthlyMomentPreviewScreen(
          month: _month,
          records: [_record('new')],
          existingAlbumId: 73,
          onAlbumCreated: (album) async {
            opened = album;
          },
        ),
      );
      try {
        repository.stored = repository.stored.copyWith(title: '다른 기기에서 바꾼 제목');
        await _tap(tester, 'monthly-moment-open-existing');
        expect(opened?.title, '다른 기기에서 바꾼 제목');
        expect(repository.appends, isEmpty);
        expect(repository.fetches.length, greaterThanOrEqualTo(2));
        await _reveal(tester, find.text('다른 기기에서 바꾼 제목'));
        expect(find.text('다른 기기에서 바꾼 제목'), findsOneWidget);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets('failed append keeps selected photo for safe retry', (
    tester,
  ) async {
    final repository = _Repository();
    final engagement = _Engagement();
    repository.appendHandler = () async =>
        throw const MomentException('연결을 확인해 주세요.');
    final container = await _mount(
      tester,
      repository,
      engagement,
      MonthlyMomentPreviewScreen(
        month: _month,
        records: [_record('new')],
        existingAlbumId: 73,
      ),
    );
    try {
      await _tap(tester, 'monthly-moment-append');
      expect(find.text('연결을 확인해 주세요.'), findsOneWidget);
      expect(find.text('새 사진 1장 추가하기'), findsOneWidget);
      repository.appendHandler = null;
      await _tap(tester, 'monthly-moment-append');
      expect(repository.appends, [
        ['new-photo'],
        ['new-photo'],
      ]);
      expect(find.text('앨범 이어서 편집하기'), findsOneWidget);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets(
    'late append result cannot open private album after account switch',
    (tester) async {
      final repository = _Repository();
      final engagement = _Engagement();
      final pending = Completer<Album>();
      var opened = false;
      repository.appendHandler = () => pending.future;
      final container = await _mount(
        tester,
        repository,
        engagement,
        MonthlyMomentPreviewScreen(
          month: _month,
          records: [_record('new')],
          existingAlbumId: 73,
          onAlbumCreated: (_) async {
            opened = true;
          },
        ),
      );
      try {
        final target = find.byKey(const ValueKey('monthly-moment-append'));
        await _reveal(tester, target);
        await tester.tap(target);
        await tester.pump();
        repository.change('other');
        await tester.pump();
        pending.complete(repository.stored);
        await tester.pumpAndSettle();
        expect(opened, false);
        expect(find.text('계정이 변경되었어요'), findsOneWidget);
        expect(find.text('내가 직접 꾸민 제주'), findsNothing);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'existing album fetch error can retry without creating or appending',
    (tester) async {
      final repository = _Repository();
      final engagement = _Engagement();
      repository.fetchHandler = () async =>
          throw const MomentException('앨범 연결이 늦어지고 있어요.');
      final container = await _mount(
        tester,
        repository,
        engagement,
        MonthlyMomentPreviewScreen(
          month: _month,
          records: [_record('new')],
          existingAlbumId: 73,
        ),
      );
      try {
        await _reveal(tester, find.text('다시 불러오기'));
        repository.fetchHandler = null;
        await tester.tap(find.text('다시 불러오기'));
        await tester.pumpAndSettle();
        await _reveal(tester, find.text('내가 직접 꾸민 제주'));
        expect(find.text('내가 직접 꾸민 제주'), findsOneWidget);
        expect(repository.creates, isEmpty);
        expect(repository.appends, isEmpty);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets('reward supports dark theme and large text without overflow', (
    tester,
  ) async {
    final repository = _Repository();
    final engagement = _Engagement();
    final container = await _mount(
      tester,
      repository,
      engagement,
      MomentSavedPreviewScreen(
        record: _record('saved'),
        journal: _journal(records: [_record('older'), _record('saved')]),
      ),
      dark: true,
      scale: 1.6,
    );
    try {
      expect(find.text('나의 한 달에\n한 장이 더 쌓였어요.'), findsOneWidget);
      await _tap(tester, 'moment-saved-return');
      expect(tester.takeException(), isNull);
    } finally {
      await _close(tester, container, repository);
    }
  });
}

Future<void> _capture(WidgetTester tester, String path) async {
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('moment-capture-root')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final target = File(path);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
