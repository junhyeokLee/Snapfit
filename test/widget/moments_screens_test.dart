import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/shared/snapfit_image.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/data/moment_draft_store.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_compose_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/moments_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/monthly_moment_preview_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';

import '../helpers/memory_moment_draft_store.dart';
import '../helpers/load_moment_capture_fonts.dart';

final _today = DateTime.utc(2026, 10, 26);
final _month = DateTime.utc(2026, 10);
MomentRecord _record({String id = 'record-1', int photos = 1}) => MomentRecord(
  id: id,
  recordDate: _today,
  caption: '기억하고 싶은 조용한 산책',
  revision: 3,
  photos: List.generate(
    photos,
    (index) => MomentPhoto(
      id: '$id-photo-$index',
      path: 'owner/moments/$id/photo-$index.png',
      url: 'asset:assets/cover/cover1.png',
      width: 600,
      height: 800,
    ),
  ),
);

MomentDraft _draft({
  String id = 'local-record',
  String caption = '이어 쓸 한 줄',
  MomentRecord? original,
  bool upload = false,
}) => MomentDraft(
  ownerId: 'owner',
  recordId: original?.id ?? id,
  recordDate: _today,
  caption: caption,
  existingPhotos: original?.photos ?? const [],
  uploads: upload
      ? [
          MomentDraftUpload(
            id: 'local-photo',
            filename: 'moment.png',
            bytes: img.encodePng(img.Image(width: 2, height: 2)),
          ),
        ]
      : const [],
  originalRecord: original,
  updatedAt: _today,
);

class _Repository implements MomentsRepository {
  String? actor = 'owner';
  final changes = StreamController<String?>.broadcast();
  List<MomentRecord> records = [_record()];
  int weekCount = 4;
  int? albumId;
  final reads = <DateTime>[];
  final saves =
      <
        ({String id, String caption, int? revision, List<MomentUpload> uploads})
      >[];
  final creates = <({List<String> photos, String title})>[];
  final albumFetches = <int>[];
  Album? fetchedAlbum;
  int deletes = 0;
  Future<MomentRecord> Function()? saveHandler;
  Future<Album> Function()? createHandler;
  Future<Album> Function(int)? fetchHandler;
  Future<MomentJournal> Function(DateTime)? readHandler;
  @override
  String? get currentUserId => actor;
  @override
  Stream<String?> get authChanges => changes.stream;
  void change(String? value) {
    actor = value;
    changes.add(value);
  }

  @override
  Future<MomentJournal> listMonth(DateTime month) async {
    reads.add(month);
    return readHandler?.call(month) ??
        MomentJournal(
          today: _today,
          weekStart: momentWeekStart(_today),
          month: month,
          records: records,
          weekPhotoCount: weekCount,
          monthlyAlbumId: albumId,
        );
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
  }) async {
    saves.add((
      id: id,
      caption: caption,
      revision: expectedRevision,
      uploads: uploads,
    ));
    return saveHandler?.call() ?? _record();
  }

  @override
  Future<void> delete(MomentRecord record) async {
    deletes++;
  }

  @override
  Future<Album> fetchAlbum(int id) async {
    albumFetches.add(id);
    return fetchHandler?.call(id) ??
        fetchedAlbum ??
        Album(id: id, title: '저장된 월간 앨범', userId: 'owner');
  }

  @override
  Future<Album> appendMonthlyAlbum({
    required DateTime month,
    required List<MomentRecord> selectedRecords,
    required List<String> selectedPhotoIds,
  }) =>
      throw UnimplementedError('append is covered by moments_reward_flow_test');

  @override
  Future<Album> createMonthlyAlbum({
    required DateTime month,
    required List<MomentRecord> selectedRecords,
    required List<String> selectedPhotoIds,
    required String title,
  }) async {
    creates.add((photos: List.of(selectedPhotoIds), title: title));
    return createHandler?.call() ??
        const Album(id: 73, title: '월간 앨범', userId: 'owner');
  }
}

class _Picker extends ImagePicker {
  bool fails = false;
  List<XFile>? selected;
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    if (fails) throw StateError('permission denied');
    if (selected != null) return selected!;
    return [
      XFile.fromData(
        img.encodePng(img.Image(width: 2, height: 2)),
        // Native XFile.fromData ignores name; path determines its basename.
        path: 'moment.png',
        name: 'moment.png',
        mimeType: 'image/png',
      ),
    ];
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Repository repository,
  Widget screen, {
  bool dark = false,
  double scale = 1,
  GlobalKey<NavigatorState>? navigatorKey,
  MomentDraftStore? draftStore,
  GlobalKey? capture,
}) async {
  final container = ProviderContainer(
    overrides: [
      momentsRepositoryProvider.overrideWithValue(repository),
      momentDraftStoreProvider.overrideWithValue(
        draftStore ?? MemoryMomentDraftStore(),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        builder: (context, child) => RepaintBoundary(
          key: capture,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push<void>(MaterialPageRoute(builder: (_) => screen)),
              child: const Text('기록 열기'),
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
      tester.element(find.text('기록 열기')),
    );
  });
  await tester.tap(find.text('기록 열기'));
  // PageView mounts adjacent pages after its first layout. Warm the exact
  // providers from each completed layout, including their decode-size keys.
  for (var frame = 0; frame < 3; frame++) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
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
            tester.element(find.byType(SnapfitImage).first),
          );
        }
      }
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(
          image.image,
          tester.element(find.byType(Image).first),
        );
      }
    });
  }
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
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: scrollable,
      maxScrolls: 60,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Finder target, String text) async {
  await _reveal(tester, target);
  await tester.enterText(target, text);
  await tester.pumpAndSettle();
}

void main() {
  final captureDirectory = Platform.environment['FIRST_BOOK_CAPTURE_DIR'];
  setUpAll(() async {
    if (captureDirectory != null) await loadMomentCaptureFonts();
  });
  if (captureDirectory != null) {
    for (final dark in [false, true]) {
      testWidgets(
        'capture recovered compose in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final data = (await tester.runAsync(
            () => rootBundle.load(
              'assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg',
            ),
          ))!;
          final draft = MomentDraft(
            ownerId: 'owner',
            recordId: 'recovered-photo-record',
            recordDate: _today,
            caption: '바람이 좋았던 제주 바다. 잠깐 멈춰서 이 순간을 남겼어요.',
            existingPhotos: const [],
            uploads: [
              MomentDraftUpload(
                id: 'recovered-photo',
                filename: 'jeju_ocean.jpg',
                bytes: data.buffer.asUint8List(
                  data.offsetInBytes,
                  data.lengthInBytes,
                ),
              ),
            ],
            updatedAt: _today,
          );
          final store = MemoryMomentDraftStore()..seed(draft);
          final repo = _Repository();
          final capture = GlobalKey();
          final container = await _mount(
            tester,
            repo,
            MomentComposeScreen(today: _today, draftRecordId: draft.recordId),
            dark: dark,
            draftStore: store,
            capture: capture,
          );
          Future<void> screenshot(String suffix) async {
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final rendered = await boundary.toImage(pixelRatio: 2);
              try {
                final png = await rendered.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  '$captureDirectory/compose-recovered-${dark ? 'dark' : 'light'}$suffix.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(png!.buffer.asUint8List());
              } finally {
                rendered.dispose();
              }
            });
          }

          try {
            expect(find.text('보관한 기록을 이어서 작성하고 있어요'), findsOneWidget);
            expect(repo.saves, isEmpty);
            await screenshot('');
            await _reveal(tester, find.byKey(const ValueKey('moment-caption')));
            await screenshot('-caption');
            expect(tester.takeException(), isNull);
          } finally {
            await _close(tester, container, repo);
          }
        },
      );
    }
  }
  testWidgets(
    'journal uses server week count and opens no automatic mutations',
    (tester) async {
      final repository = _Repository();
      final container = await _mount(tester, repository, const MomentsScreen());
      try {
        expect(find.textContaining('이번 주 사진 4장'), findsOneWidget);
        await _reveal(tester, find.text('기억하고 싶은 조용한 산책'));
        expect(find.text('기억하고 싶은 조용한 산책'), findsOneWidget);
        expect(repository.saves, isEmpty);
        expect(repository.creates, isEmpty);
        await _tap(tester, 'moments-previous-month');
        expect(repository.reads.last.month, repository.reads.first.month - 1);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets('month load failure has an actionable retry', (tester) async {
    final repository = _Repository()
      ..readHandler = (_) => Future.error(const MomentException('연결 실패'));
    final container = await _mount(tester, repository, const MomentsScreen());
    try {
      expect(find.text('다시 불러오기'), findsOneWidget);
      repository.readHandler = null;
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('이번 주 사진 4장'), findsOneWidget);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets('save requires a photo and picker failure keeps caption', (
    tester,
  ) async {
    final repository = _Repository();
    final picker = _Picker()..fails = true;
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(today: _today, imagePicker: picker),
    );
    try {
      await _enter(
        tester,
        find.byKey(const ValueKey('moment-caption')),
        '잊고 싶지 않은 한 줄',
      );
      await _tap(tester, 'moment-save');
      expect(repository.saves, isEmpty);
      expect(find.textContaining('사진을 한 장 이상'), findsOneWidget);
      await _tap(tester, 'moment-pick-photos');
      expect(find.textContaining('사진 접근 권한'), findsOneWidget);
      expect(find.text('잊고 싶지 않은 한 줄'), findsOneWidget);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets('failed save keeps input and revision for safe retry', (
    tester,
  ) async {
    final repository = _Repository()
      ..saveHandler = () =>
          Future.error(const MomentException('일시적으로 저장할 수 없어요.'));
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(record: _record(), today: _today),
    );
    try {
      await _enter(
        tester,
        find.byKey(const ValueKey('moment-caption')),
        '수정한 기록',
      );
      await _tap(tester, 'moment-save');
      expect(find.text('수정한 기록'), findsOneWidget);
      expect(find.text('일시적으로 저장할 수 없어요.'), findsOneWidget);
      expect(repository.saves.single.revision, 3);
      await _tap(tester, 'moment-save');
      expect(repository.saves.length, 2);
      expect(repository.saves[0].id, repository.saves[1].id);
      expect(repository.saves[1].caption, '수정한 기록');
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets(
    'new record keeps selected photo and stable identifiers on retry',
    (tester) async {
      final repository = _Repository()
        ..saveHandler = () =>
            Future.error(const MomentException('연결이 잠시 끊겼어요.'));
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(today: _today, imagePicker: _Picker()),
      );
      try {
        await _tap(tester, 'moment-pick-photos');
        await _enter(
          tester,
          find.byKey(const ValueKey('moment-caption')),
          '처음 남긴 하루',
        );
        await _tap(tester, 'moment-save');
        expect(repository.saves.single.uploads.length, 1);
        expect(repository.saves.single.revision, isNull);
        expect(find.text('처음 남긴 하루'), findsOneWidget);
        expect(find.byTooltip('이 사진 빼기'), findsOneWidget);
        await _tap(tester, 'moment-save');
        expect(repository.saves.length, 2);
        expect(repository.saves[1].id, repository.saves[0].id);
        expect(
          repository.saves[1].uploads.single.id,
          repository.saves[0].uploads.single.id,
        );
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'compose keeps mixed photo proportions without portrait padding around landscapes',
    (tester) async {
      final landscape = img.encodePng(img.Image(width: 160, height: 90));
      final portrait = img.encodePng(img.Image(width: 90, height: 120));
      final repository = _Repository();
      final record = MomentRecord(
        id: 'landscape-record',
        recordDate: _today,
        caption: '',
        revision: 1,
        photos: [
          const MomentPhoto(
            id: 'existing-landscape',
            path: 'owner/moments/landscape/photo.png',
            url: 'asset:assets/cover/cover1.png',
            width: 1600,
            height: 900,
          ),
        ],
      );
      final picker = _Picker()
        ..selected = [
          XFile.fromData(
            landscape,
            name: 'landscape.png',
            mimeType: 'image/png',
          ),
          XFile.fromData(portrait, name: 'portrait.png', mimeType: 'image/png'),
        ];
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(record: record, today: _today, imagePicker: picker),
      );
      try {
        await tester.runAsync(() async {
          final context = tester.element(find.byType(MomentComposeScreen));
          await precacheImage(MemoryImage(landscape), context);
          await precacheImage(MemoryImage(portrait), context);
        });
        await _tap(tester, 'moment-pick-photos');
        for (final entry in <String, double>{
          'moment-existing-photo-0': 16 / 9,
          'moment-new-photo-0': 16 / 9,
          'moment-new-photo-1': 3 / 4,
        }.entries) {
          final photo = find.byKey(ValueKey(entry.key));
          await _reveal(tester, photo);
          final size = tester.getSize(photo);
          expect(size.width / size.height, closeTo(entry.value, .01));
          expect(tester.widget<MomentPhotoView>(photo).fit, BoxFit.contain);
          if (entry.value > 1) expect(size.height, lessThan(size.width));
        }
        expect(repository.saves, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'pending save disables repeat submissions and suppresses late account response',
    (tester) async {
      final pending = Completer<MomentRecord>();
      final repository = _Repository()..saveHandler = () => pending.future;
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(record: _record(), today: _today),
      );
      try {
        await _tap(tester, 'moment-save');
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('moment-save')),
        );
        expect(button.onPressed, isNull);
        expect(repository.saves.length, 1);
        repository.change('different-owner');
        await tester.pumpAndSettle();
        expect(find.text('계정이 변경되었어요'), findsOneWidget);
        expect(find.text('기억하고 싶은 조용한 산책'), findsNothing);
        pending.complete(_record());
        await tester.pumpAndSettle();
        expect(find.text('계정이 변경되었어요'), findsOneWidget);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'back commits recent caption locally and reopening restores the same edit',
    (tester) async {
      final repository = _Repository();
      final drafts = MemoryMomentDraftStore();
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(record: _record(), today: _today),
        draftStore: drafts,
      );
      try {
        await _enter(
          tester,
          find.byKey(const ValueKey('moment-caption')),
          '소중한 기록',
        );
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        expect(find.text('기록 열기'), findsOneWidget);
        expect((await drafts.load('owner', 'record-1'))?.caption, '소중한 기록');
        await tester.tap(find.text('기록 열기'));
        await tester.pumpAndSettle();
        await _reveal(tester, find.byKey(const ValueKey('moment-caption')));
        expect(find.text('소중한 기록'), findsOneWidget);
        expect(repository.saves, isEmpty);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'delete requires confirmation and cannot affect a changed account',
    (tester) async {
      final repository = _Repository();
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(record: _record(), today: _today),
      );
      try {
        await tester.tap(find.byTooltip('기록 삭제'));
        await tester.pumpAndSettle();
        expect(repository.deletes, 0);
        repository.change('different-owner');
        await tester.pumpAndSettle();
        await tester.tap(find.text('삭제'));
        await tester.pumpAndSettle();
        expect(repository.deletes, 0);
        expect(find.text('계정이 변경되었어요'), findsOneWidget);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'new draft restores original photo bytes and stable identity after leaving',
    (tester) async {
      final repository = _Repository();
      final drafts = MemoryMomentDraftStore();
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(today: _today, imagePicker: _Picker()),
        draftStore: drafts,
      );
      try {
        await _tap(tester, 'moment-pick-photos');
        await _enter(
          tester,
          find.byKey(const ValueKey('moment-caption')),
          '사진과 함께 보관할 글',
        );
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        final saved = (await drafts.list('owner')).single;
        expect(saved.caption, '사진과 함께 보관할 글');
        expect(saved.uploads.single.filename, 'moment.png');
        expect(saved.uploads.single.bytes, isNotEmpty);
        expect(repository.saves, isEmpty);
        await tester.tap(find.text('기록 열기'));
        await tester.pumpAndSettle();
        await _reveal(tester, find.byKey(const ValueKey('moment-caption')));
        expect(find.text('사진과 함께 보관할 글'), findsOneWidget);
        await _tap(tester, 'moment-save');
        expect(repository.saves.single.id, saved.recordId);
        expect(
          repository.saves.single.uploads.single.id,
          saved.uploads.single.id,
        );
        expect(
          repository.saves.single.uploads.single.bytes,
          saved.uploads.single.bytes,
        );
        expect(await drafts.list('owner'), isEmpty);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets('autosave queues edits made while an earlier write is pending', (
    tester,
  ) async {
    final repository = _Repository();
    final gate = Completer<void>();
    final drafts = MemoryMomentDraftStore()..beforeSave = () => gate.future;
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(today: _today),
      draftStore: drafts,
    );
    try {
      await _enter(
        tester,
        find.byKey(const ValueKey('moment-caption')),
        '먼저 작성',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await _enter(
        tester,
        find.byKey(const ValueKey('moment-caption')),
        '저장 중에도 이어 쓴 마지막 글',
      );
      gate.complete();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect((await drafts.list('owner')).single.caption, '저장 중에도 이어 쓴 마지막 글');
      expect(drafts.writes, 2);
      expect(repository.saves, isEmpty);
    } finally {
      if (!gate.isCompleted) gate.complete();
      await _close(tester, container, repository);
    }
  });

  testWidgets(
    'failed local write blocks silent exit and can be retried without losing input',
    (tester) async {
      final repository = _Repository();
      final drafts = MemoryMomentDraftStore()
        ..writeError = const MomentDraftException('기기 저장 공간이 부족해요.');
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(today: _today),
        draftStore: drafts,
      );
      try {
        await _enter(
          tester,
          find.byKey(const ValueKey('moment-caption')),
          '잃으면 안 되는 글',
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        expect(find.text('임시 저장을 확인하지 못했어요'), findsOneWidget);
        expect(await drafts.list('owner'), isEmpty);
        await tester.tap(find.text('계속 작성'));
        await tester.pumpAndSettle();
        drafts.writeError = null;
        await _tap(tester, 'moment-draft-retry');
        expect((await drafts.list('owner')).single.caption, '잃으면 안 되는 글');
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        expect(find.text('기록 열기'), findsOneWidget);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets('stale tab cannot overwrite or delete a newer local draft', (
    tester,
  ) async {
    final repository = _Repository();
    final drafts = MemoryMomentDraftStore()..seed(_draft());
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(today: _today, draftRecordId: 'local-record'),
      draftStore: drafts,
    );
    try {
      final first = (await drafts.list('owner')).single;
      final newer = await drafts.save(
        'owner',
        first.copyWith(caption: '다른 창의 새 글'),
        expectedVersion: first.version,
      );
      await _enter(
        tester,
        find.byKey(const ValueKey('moment-caption')),
        '이전 창에서 바꾼 글',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect((await drafts.list('owner')).single.version, newer.version);
      await _reveal(tester, find.byKey(const ValueKey('moment-save')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('moment-save')))
            .onPressed,
        isNull,
      );
      await _tap(tester, 'moment-draft-discard');
      await tester.tap(find.text('이 화면 닫기'));
      await tester.pumpAndSettle();
      expect((await drafts.list('owner')).single.caption, '다른 창의 새 글');
      expect(drafts.removals, 0);
      expect(repository.saves, isEmpty);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets('restored edit never overwrites a newer server revision', (
    tester,
  ) async {
    final original = _record();
    final repository = _Repository()
      ..records = [
        MomentRecord(
          id: original.id,
          caption: '다른 기기에서 저장한 글',
          recordDate: _today,
          photos: original.photos,
          revision: 4,
        ),
      ];
    final drafts = MemoryMomentDraftStore()
      ..seed(_draft(original: original, caption: '보관 중이던 글'));
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(today: _today, draftRecordId: original.id),
      draftStore: drafts,
    );
    try {
      await _reveal(tester, find.byKey(const ValueKey('moment-caption')));
      expect(find.text('보관 중이던 글'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('moment-caption')),
      );
      expect(field.readOnly, isTrue);
      await _reveal(tester, find.byKey(const ValueKey('moment-save')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('moment-save')))
            .onPressed,
        isNull,
      );
      expect(repository.saves, isEmpty);
      expect((await drafts.list('owner')).single.caption, '보관 중이던 글');
      await _tap(tester, 'moment-draft-discard');
      await tester.tap(find.widgetWithText(TextButton, '임시 작성 지우기').last);
      await tester.pumpAndSettle();
      expect(await drafts.list('owner'), isEmpty);
      expect(repository.deletes, 0);
      expect(repository.records.single.revision, 4);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets(
    'save clears only its matching draft and a failed server request keeps it',
    (tester) async {
      final repository = _Repository()
        ..saveHandler = () => Future.error(const MomentException('연결 실패'));
      final drafts = MemoryMomentDraftStore()
        ..seed(_draft(original: _record()))
        ..seed(_draft(id: 'another-new-record', caption: '다른 임시 작성'));
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(record: _record(), today: _today),
        draftStore: drafts,
      );
      try {
        await _tap(tester, 'moment-save');
        expect(await drafts.list('owner'), hasLength(2));
        expect(repository.saves.single.revision, 3);
        repository.saveHandler = null;
        await _tap(tester, 'moment-save');
        expect(
          (await drafts.list('owner')).single.recordId,
          'another-new-record',
        );
        expect(drafts.removals, 1);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'account change hides draft immediately while an old owner write finishes safely',
    (tester) async {
      final repository = _Repository();
      final gate = Completer<void>();
      final drafts = MemoryMomentDraftStore()..beforeSave = () => gate.future;
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(today: _today),
        draftStore: drafts,
      );
      try {
        await _enter(
          tester,
          find.byKey(const ValueKey('moment-caption')),
          '이전 계정의 비공개 글',
        );
        await tester.pump(const Duration(milliseconds: 400));
        repository.change('different-owner');
        await tester.pumpAndSettle();
        expect(find.text('계정이 변경되었어요'), findsOneWidget);
        expect(find.text('이전 계정의 비공개 글'), findsNothing);
        gate.complete();
        await tester.pumpAndSettle();
        expect((await drafts.list('owner')).single.caption, '이전 계정의 비공개 글');
        expect(await drafts.list('different-owner'), isEmpty);
        expect(repository.saves, isEmpty);
      } finally {
        if (!gate.isCompleted) gate.complete();
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'draft load failure requires retry before editing unknown local work',
    (tester) async {
      final repository = _Repository();
      final drafts = MemoryMomentDraftStore()
        ..seed(_draft())
        ..loadError = const MomentDraftException('저장한 기록을 읽을 수 없어요.');
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(today: _today),
        draftStore: drafts,
      );
      try {
        expect(find.byKey(const ValueKey('moment-caption')), findsNothing);
        expect(drafts.writes, 0);
        drafts.loadError = null;
        await tester.tap(find.byKey(const ValueKey('moment-draft-load-retry')));
        await tester.pumpAndSettle();
        await _reveal(tester, find.byKey(const ValueKey('moment-caption')));
        expect(find.text('이어 쓸 한 줄'), findsOneWidget);
        expect(drafts.writes, 0);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets('removing all new content removes an empty recovery draft', (
    tester,
  ) async {
    final repository = _Repository();
    final drafts = MemoryMomentDraftStore()
      ..seed(_draft(caption: '', upload: true));
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(today: _today),
      draftStore: drafts,
    );
    try {
      await _reveal(tester, find.byTooltip('이 사진 빼기'));
      await tester.tap(find.byTooltip('이 사진 빼기'));
      await tester.pumpAndSettle();
      expect(await drafts.list('owner'), isEmpty);
      expect(drafts.removals, 1);
      expect(repository.saves, isEmpty);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets(
    'removing all edit content retains its removal intent and original revision',
    (tester) async {
      final repository = _Repository();
      final drafts = MemoryMomentDraftStore()
        ..seed(_draft(caption: '', original: _record()));
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(record: _record(), today: _today),
        draftStore: drafts,
      );
      try {
        await _reveal(tester, find.byTooltip('이 사진 빼기'));
        await tester.tap(find.byTooltip('이 사진 빼기'));
        await tester.pumpAndSettle();
        final saved = (await drafts.list('owner')).single;
        expect(saved.existingPhotos, isEmpty);
        expect(saved.originalRecord?.revision, 3);
        expect(drafts.removals, 0);
        expect(repository.saves, isEmpty);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'account switch during draft loading still allows leaving the locked screen',
    (tester) async {
      final repository = _Repository();
      final drafts = MemoryMomentDraftStore()..seed(_draft());
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(today: _today),
        draftStore: drafts,
      );
      final gate = Completer<void>();
      try {
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        drafts.beforeLoad = () => gate.future;
        await tester.tap(find.text('기록 열기'));
        await tester.pump(const Duration(milliseconds: 400));
        repository.change('different-owner');
        await tester.pumpAndSettle();
        expect(find.text('계정이 변경되었어요'), findsOneWidget);
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        expect(find.text('기록 열기'), findsOneWidget);
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('이어 쓸 한 줄'), findsNothing);
      } finally {
        if (!gate.isCompleted) gate.complete();
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'backgrounding flushes the latest text before the debounce delay',
    (tester) async {
      final repository = _Repository();
      final drafts = MemoryMomentDraftStore();
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(today: _today),
        draftStore: drafts,
      );
      try {
        await _enter(
          tester,
          find.byKey(const ValueKey('moment-caption')),
          '바로 이어 쓸 수 있는 글',
        );
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        expect((await drafts.list('owner')).single.caption, '바로 이어 쓸 수 있는 글');
        expect(repository.saves, isEmpty);
      } finally {
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets('record date picker excludes future dates', (tester) async {
    final repository = _Repository();
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(today: _today),
    );
    try {
      await _tap(tester, 'moment-date');
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate.year, 2026);
      expect(picker.lastDate.month, 10);
      expect(picker.lastDate.day, 26);
      expect(repository.saves, isEmpty);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets(
    'monthly preview renders real pages and preserves choices after failure',
    (tester) async {
      final repository = _Repository()
        ..createHandler = () =>
            Future.error(const MomentException('다시 시도해 주세요.'));
      final record = _record(photos: 3);
      final container = await _mount(
        tester,
        repository,
        MonthlyMomentPreviewScreen(
          month: _month,
          today: _today,
          records: [record],
        ),
      );
      try {
        expect(
          find.byKey(const ValueKey('monthly-moment-preview')),
          findsOneWidget,
        );
        await _reveal(tester, find.text('표지  ·  1 / 4'));
        expect(find.text('표지  ·  1 / 4'), findsOneWidget);
        await _enter(
          tester,
          find.byKey(const ValueKey('monthly-moment-title')),
          '우리의 가을',
        );
        await _tap(tester, 'moment-photo-select-record-1-photo-2');
        await _tap(tester, 'moment-photo-cover-record-1-photo-1');
        await _tap(tester, 'monthly-moment-create');
        expect(repository.creates.single.title, '우리의 가을');
        expect(repository.creates.single.photos, [
          'record-1-photo-1',
          'record-1-photo-0',
        ]);
        await _reveal(
          tester,
          find.byKey(const ValueKey('monthly-moment-title')),
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('monthly-moment-title')),
              )
              .controller!
              .text,
          '우리의 가을',
        );
        await _tap(tester, 'monthly-moment-create');
        expect(repository.creates[1].photos, repository.creates[0].photos);
        expect(tester.takeException(), isNull);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'monthly creation retains saved album when editor navigation fails',
    (tester) async {
      final repository = _Repository();
      final opened = <Album>[];
      final container = await _mount(
        tester,
        repository,
        MonthlyMomentPreviewScreen(
          month: _month,
          today: _today,
          records: [_record()],
          onAlbumCreated: (album) async {
            opened.add(album);
            throw StateError('editor unavailable');
          },
        ),
      );
      try {
        await _tap(tester, 'monthly-moment-create');
        expect(repository.creates.length, 1);
        expect(repository.albumFetches, isEmpty);
        expect(find.text('앨범은 저장됐어요. 편집 화면을 다시 열어 주세요.'), findsOneWidget);
        repository.fetchedAlbum = const Album(
          id: 73,
          title: '다른 화면에서 수정한 월간 앨범',
          coverLayersJson: '{"pages":[{"id":"latest"}]}',
        );
        await _tap(tester, 'monthly-moment-create');
        expect(repository.creates.length, 1);
        expect(repository.albumFetches, [73]);
        expect(opened, hasLength(2));
        expect(opened.last, repository.fetchedAlbum);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets('new account never opens a previous account monthly album', (
    tester,
  ) async {
    final pending = Completer<Album>();
    final repository = _Repository()..createHandler = () => pending.future;
    var opens = 0;
    final container = await _mount(
      tester,
      repository,
      MonthlyMomentPreviewScreen(
        month: _month,
        today: _today,
        records: [_record()],
        onAlbumCreated: (_) async {
          opens++;
        },
      ),
    );
    try {
      await _tap(tester, 'monthly-moment-create');
      repository.change('different-owner');
      await tester.pumpAndSettle();
      pending.complete(const Album(id: 73));
      await tester.pumpAndSettle();
      expect(opens, 0);
      expect(find.text('계정이 변경되었어요'), findsOneWidget);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets('opening editor does not pop the newly pushed editor route', (
    tester,
  ) async {
    final repository = _Repository();
    final navigator = GlobalKey<NavigatorState>();
    final opened = <Album>[];
    final container = await _mount(
      tester,
      repository,
      MonthlyMomentPreviewScreen(
        month: _month,
        today: _today,
        records: [_record()],
        onAlbumCreated: (album) async {
          opened.add(album);
          unawaited(
            navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('월간 앨범 편집 중')),
              ),
            ),
          );
        },
      ),
      navigatorKey: navigator,
    );
    try {
      await _tap(tester, 'monthly-moment-create');
      expect(find.text('월간 앨범 편집 중'), findsOneWidget);
      expect(repository.creates.length, 1);
      expect(repository.albumFetches, isEmpty);
      expect(opened.single.coverLayersJson, isEmpty);
      repository.fetchedAlbum = const Album(
        id: 73,
        title: '편집하고 저장한 가을',
        coverLayersJson:
            '{"pages":[{"id":"edited-cover","caption":"저장된 새 문장"}]}',
        updatedAt: '2026-10-26T12:00:00Z',
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await _tap(tester, 'monthly-moment-create');
      expect(find.text('월간 앨범 편집 중'), findsOneWidget);
      expect(repository.creates.length, 1);
      expect(repository.albumFetches, [73]);
      expect(opened, hasLength(2));
      expect(opened.last, repository.fetchedAlbum);
      expect(opened.last.coverLayersJson, contains('저장된 새 문장'));
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets(
    'reopening fails safely instead of editing a stale cached album',
    (tester) async {
      final repository = _Repository();
      final opened = <Album>[];
      final container = await _mount(
        tester,
        repository,
        MonthlyMomentPreviewScreen(
          month: _month,
          today: _today,
          records: [_record()],
          onAlbumCreated: (album) async {
            opened.add(album);
          },
        ),
      );
      try {
        await _tap(tester, 'monthly-moment-create');
        expect(opened, hasLength(1));
        repository.fetchHandler = (_) =>
            Future.error(const MomentException('최신 앨범을 불러오지 못했어요.'));
        await _tap(tester, 'monthly-moment-create');
        expect(repository.albumFetches, [73]);
        expect(repository.creates, hasLength(1));
        expect(opened, hasLength(1));
        expect(find.text('앨범은 저장됐어요. 편집 화면을 다시 열어 주세요.'), findsOneWidget);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  for (final dark in [false, true]) {
    for (final screen in ['journal', 'compose', 'month']) {
      testWidgets(
        '$screen fits narrow screen at 200 percent text in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = _Repository();
          final widget = switch (screen) {
            'journal' => const MomentsScreen(),
            'compose' => MomentComposeScreen(record: _record(), today: _today),
            _ => MonthlyMomentPreviewScreen(
              month: _month,
              today: _today,
              records: [_record()],
            ),
          };
          final container = await _mount(
            tester,
            repository,
            widget,
            dark: dark,
            scale: 2,
          );
          try {
            expect(tester.takeException(), isNull);
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -1600),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          } finally {
            await _close(tester, container, repository);
          }
        },
      );
    }
  }
}
