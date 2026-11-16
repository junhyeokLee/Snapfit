import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, SynchronousFuture;
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
import 'package:snap_fit/features/moments/data/moment_publication_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_publication_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_compose_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/moments_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/monthly_moment_preview_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_month_calendar.dart';

import '../helpers/memory_moment_draft_store.dart';
import '../helpers/memory_moment_publication_repository.dart';
import '../helpers/load_moment_capture_fonts.dart';

final _today = DateTime.utc(2026, 10, 26);
final _month = DateTime.utc(2026, 10);

// Browser UI fixtures use real bundled pixels without depending on an
// initialized Supabase signing client. Private path/ID serialization remains
// intact; storage authorization is exercised by the repository test suites.
class _BrowserFixturePhoto extends MomentPhoto {
  const _BrowserFixturePhoto({
    required super.id,
    required super.path,
    required super.url,
    required super.width,
    required super.height,
  });

  @override
  String get storageUri => url;
}

// Exercise the browser's real Image/PNG decoder without fetching the multi-MB
// production image or asset manifest through a fake-async network transport.
// Native captures continue to use rootBundle and the actual photograph.
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
    if (_isImage(key)) return SynchronousFuture(ByteData.sublistView(_png));
    return rootBundle.load(key);
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) => _isImage(key)
      ? ui.ImmutableBuffer.fromUint8List(_png)
      : super.loadBuffer(key);

  bool _isImage(String key) =>
      RegExp(r'[.](png|jpg|jpeg|webp)$', caseSensitive: false).hasMatch(key);
}

MomentPhoto _fixturePhoto({required String id, required String path}) => kIsWeb
    ? _BrowserFixturePhoto(
        id: id,
        path: path,
        url: 'asset:assets/cover/cover1.png',
        width: 600,
        height: 800,
      )
    : MomentPhoto(
        id: id,
        path: path,
        url: 'asset:assets/cover/cover1.png',
        width: 600,
        height: 800,
      );

MomentRecord _record({String id = 'record-1', int photos = 1}) => MomentRecord(
  id: id,
  recordDate: _today,
  caption: '기억하고 싶은 조용한 산책',
  revision: 3,
  photos: List.generate(
    photos,
    (index) => _fixturePhoto(
      id: '$id-photo-$index',
      path: 'owner/moments/$id/photo-$index.png',
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
  MomentMonthlyReward? reward;
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
  Future<MomentJournal> listMonth(DateTime? requestedMonth) async {
    final month = requestedMonth ?? momentMonth(_today);
    reads.add(month);
    return readHandler?.call(month) ??
        MomentJournal(
          today: _today,
          weekStart: momentWeekStart(_today),
          month: month,
          records: records,
          weekPhotoCount: weekCount,
          monthlyAlbumId: albumId,
          monthlyReward: reward,
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
  int calls = 0;
  List<XFile>? selected;
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    calls++;
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
  MemoryMomentPublicationRepository? publications,
}) async {
  final browserAssets = kIsWeb ? _MemoryBrowserAssets() : null;
  final container = ProviderContainer(
    overrides: [
      momentsRepositoryProvider.overrideWithValue(repository),
      momentPublicationRepositoryProvider.overrideWithValue(
        publications ?? MemoryMomentPublicationRepository(recordRevision: 3),
      ),
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
            child: kIsWeb
                ? DefaultAssetBundle(bundle: browserAssets!, child: child!)
                : child!,
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
  if (!kIsWeb)
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
  if (kIsWeb) {
    await _settlePhotoFrames(tester, 'mount');
    return container;
  }
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
  if (!kIsWeb && key == 'moment-pick-photos') {
    // Await the actual async handler outside FakeAsync; native engine codec
    // futures cannot finish by advancing the simulated widget clock alone.
    final action = tester.widget<InkWell>(target).onTap;
    if (action != null) {
      await tester.runAsync(() async => Function.apply(action, const []));
    }
  } else {
    await tester.tap(target);
  }
  if (kIsWeb) {
    await _settlePhotoFrames(tester, 'tap $key');
  } else {
    if (key == 'moment-pick-photos') {
      // The new artwork widget starts a second native decode on first layout.
      await _settlePhotoFrames(tester, 'native photo preview');
    } else {
      await _settleNativePhotos(tester);
    }
  }
}

Future<void> _selectPublic(WidgetTester tester) async {
  // Opening the disclosure alone must not opt the record into the public feed.
  await _tap(tester, 'moment-share-public');
  await _tap(tester, 'moment-privacy-public');
}

Future<void> _settlePhotoFrames(WidgetTester tester, String stage) async {
  if (find.byKey(const ValueKey('moment-save-overlay')).evaluate().isNotEmpty) {
    await tester.pump(const Duration(milliseconds: 100));
    return;
  }
  final warmed = <ImageProvider>{};
  // Start route/scroll tickers first. Decode exact providers only after their
  // active widgets exist, without awaiting a decoder before browser frames run.
  await tester.pump();
  for (var frame = 0; frame < 60; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() async {
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      for (final image in images) {
        if (!warmed.add(image.image)) continue;
        unawaited(
          precacheImage(
            image.image,
            tester.element(find.byType(Image).first),
            onError: (error, stack) =>
                debugPrint('Browser fixture decode: $error'),
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    if (!tester.binding.hasScheduledFrame) return;
  }
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  } catch (_) {
    debugPrint(
      'Photo fixture did not settle at $stage; images=${find.byType(Image).evaluate().length}, decoded=${tester.widgetList<RawImage>(find.byType(RawImage)).where((image) => image.image != null).length}',
    );
    rethrow;
  }
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
    if (kIsWeb) {
      await _settlePhotoFrames(tester, 'reveal reset');
    } else {
      await _settleNativePhotos(tester);
    }
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: scrollable,
      maxScrolls: 60,
    );
  }
  await tester.ensureVisible(target);
  if (kIsWeb) {
    await _settlePhotoFrames(tester, 'reveal target');
  } else {
    await _settleNativePhotos(tester);
  }
}

Future<void> _settleNativePhotos(WidgetTester tester) async {
  // 경로 전환과 스크롤 뒤 새로 생긴 이미지도 가짜 시계 밖에서 디코딩한다.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  // 진행 중 저장의 로딩 표시는 의도적으로 계속 움직이므로 완료를 기다리지 않는다.
  if (find.byKey(const ValueKey('moment-save-overlay')).evaluate().isNotEmpty)
    return;
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
    await Future<void>.delayed(const Duration(milliseconds: 60));
  });
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Finder target, String text) async {
  await _reveal(tester, target);
  await tester.enterText(target, text);
  if (kIsWeb) {
    await _settlePhotoFrames(tester, 'enter text');
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  final exceptionReporter = reportTestException;
  final captureDirectory = kIsWeb
      ? null
      : Platform.environment['FIRST_BOOK_CAPTURE_DIR'];
  setUpAll(() async {
    reportTestException = (details, description) {
      // Browser reporters can otherwise omit useful assertion details.
      // ignore: avoid_print
      print(details.exceptionAsString());
      exceptionReporter(details, description);
    };
    if (captureDirectory != null) await loadMomentCaptureFonts();
  });
  tearDownAll(() => reportTestException = exceptionReporter);
  if (captureDirectory != null) {
    for (final dark in [false, true]) {
      testWidgets(
        'capture empty notebook compose in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = _Repository();
          final capture = GlobalKey();
          final container = await _mount(
            tester,
            repository,
            MomentComposeScreen(today: _today, imagePicker: _Picker()),
            dark: dark,
            capture: capture,
          );
          try {
            expect(find.text('한 줄 기록 (선택)'), findsOneWidget);
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
                  '$captureDirectory/compose-notebook-${dark ? 'dark' : 'light'}.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(png!.buffer.asUint8List());
              } finally {
                rendered.dispose();
              }
            });
            expect(repository.saves, isEmpty);
          } finally {
            await _close(tester, container, repository);
          }
        },
      );
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
            await _reveal(
              tester,
              find.byKey(const ValueKey('moment-draft-status')),
            );
            expect(find.text('보관한 기록을 이어서 작성하고 있어요'), findsOneWidget);
            expect(repo.saves, isEmpty);
            await _reveal(tester, find.byKey(const ValueKey('moment-date')));
            await screenshot('');
            await _reveal(tester, find.byKey(const ValueKey('moment-caption')));
            await screenshot('-caption');
            await _selectPublic(tester);
            await _tap(tester, 'moment-public-photo-recovered-photo');
            await _reveal(
              tester,
              find.byKey(const ValueKey('moment-share-public')),
            );
            expect(
              tester
                  .widget<PopupMenuButton<bool>>(
                    find.byKey(const ValueKey('moment-share-public')),
                  )
                  .initialValue,
              isTrue,
            );
            expect(
              find.byKey(const ValueKey('moment-public-photo-preview')),
              findsOneWidget,
            );
            expect(repo.saves, isEmpty);
            await screenshot('-public-photo-selection');
            expect(tester.takeException(), isNull);
          } finally {
            await _close(tester, container, repo);
          }
        },
      );
    }
  }
  testWidgets(
    'journal always shows the selected month calendar without an expand action',
    (tester) async {
      final repository = _Repository();
      final container = await _mount(
        tester,
        repository,
        MomentsScreen(initialMonth: _month),
      );
      try {
        expect(find.byType(MomentMonthCalendar), findsOneWidget);
        expect(
          find.byKey(const ValueKey('moments-calendar-toggle')),
          findsNothing,
        );
        expect(
          tester
              .widget<MomentMonthCalendar>(find.byType(MomentMonthCalendar))
              .month,
          _month,
        );
        await _tap(tester, 'moments-previous-month');
        expect(find.byType(MomentMonthCalendar), findsOneWidget);
        expect(
          tester
              .widget<MomentMonthCalendar>(find.byType(MomentMonthCalendar))
              .month,
          DateTime.utc(2026, 9),
        );
        expect(repository.saves, isEmpty);
        expect(repository.creates, isEmpty);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'empty server today opens writing while past and future empty days stay closed',
    (tester) async {
      final repository = _Repository()..records = [];
      final container = await _mount(
        tester,
        repository,
        MomentsScreen(initialMonth: _month),
      );
      try {
        expect(
          tester
              .widget<MomentMonthCalendar>(find.byType(MomentMonthCalendar))
              .today,
          _today,
        );
        for (final day in [25, 27]) {
          expect(
            tester
                .widget<InkWell>(
                  find.byKey(ValueKey('moments-calendar-2026-10-$day')),
                )
                .onTap,
            isNull,
          );
        }
        await _tap(tester, 'moments-calendar-2026-10-26');
        expect(find.byType(MomentComposeScreen), findsOneWidget);
        expect(repository.saves, isEmpty);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets('journal hides resume prompts while preserving saved drafts', (
    tester,
  ) async {
    final repository = _Repository();
    final draft = _draft(upload: true);
    final drafts = MemoryMomentDraftStore()..seed(draft);
    final container = await _mount(
      tester,
      repository,
      MomentsScreen(initialMonth: _month),
      draftStore: drafts,
    );
    try {
      expect(find.text('남기던 순간 이어 쓰기'), findsNothing);
      expect(find.byKey(const ValueKey('moments-resume-draft')), findsNothing);
      expect(find.byType(MomentComposeScreen), findsNothing);
      expect(
        (await drafts.load('owner', draft.recordId))?.caption,
        draft.caption,
      );
      expect(drafts.removals, 0);
      expect(repository.saves, isEmpty);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets(
    'journal shows the monthly reward and one album entry for its selected month',
    (tester) async {
      final repository = _Repository()
        ..reward = const MomentMonthlyReward(
          points: 1000,
          recordedDays: 26,
          daysInMonth: 31,
          awarded: false,
          canComplete: true,
        );
      final container = await _mount(
        tester,
        repository,
        MomentsScreen(initialMonth: _month),
      );
      try {
        await _reveal(tester, find.text('모은 순간을 한 권의 앨범으로'));
        expect(find.text('모은 순간을 한 권의 앨범으로'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('moments-monthly-album')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('home-monthly-reward')),
          findsOneWidget,
        );
        await _tap(tester, 'home-monthly-album-entry');
        expect(find.byType(MonthlyMomentPreviewScreen), findsOneWidget);
        expect(
          tester
              .widget<MonthlyMomentPreviewScreen>(
                find.byType(MonthlyMomentPreviewScreen),
              )
              .month,
          _month,
        );
        expect(repository.creates, isEmpty);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'journal uses server week count and opens no automatic mutations',
    (tester) async {
      final repository = _Repository();
      final container = await _mount(tester, repository, const MomentsScreen());
      try {
        expect(find.textContaining('이번 주 사진 4장'), findsOneWidget);
        expect(find.text('기억하고 싶은 조용한 산책'), findsNothing);
        await _tap(tester, 'moment-record-toggle-record-1');
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
      await _reveal(tester, find.byKey(const ValueKey('moment-save')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('moment-save')))
            .onPressed,
        isNull,
      );
      expect(repository.saves, isEmpty);
      expect(find.text('사진을 고르면 저장할 수 있어요.'), findsOneWidget);
      await _tap(tester, 'moment-pick-photos');
      await _reveal(tester, find.textContaining('사진 접근 권한'));
      expect(find.textContaining('사진 접근 권한'), findsOneWidget);
      await _reveal(tester, find.byKey(const ValueKey('moment-caption')));
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
      await _reveal(tester, find.byKey(const ValueKey('moment-caption')));
      expect(find.text('수정한 기록'), findsOneWidget);
      await _reveal(tester, find.text('일시적으로 저장할 수 없어요.'));
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
    'one explicit photo is published and failed publish retries without saving twice',
    (tester) async {
      final record = _record(photos: 3);
      final repository = _Repository()..saveHandler = () async => record;
      final publications = MemoryMomentPublicationRepository(recordRevision: 3)
        ..publishError = const MomentException('공개 연결을 확인해 주세요.');
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(record: record, today: _today),
        publications: publications,
      );
      try {
        await _reveal(
          tester,
          find.byKey(const ValueKey('moment-share-public')),
        );
        expect(
          tester
              .widget<PopupMenuButton<bool>>(
                find.byKey(const ValueKey('moment-share-public')),
              )
              .initialValue,
          isFalse,
        );
        await _selectPublic(tester);
        expect(publications.publications, isEmpty);
        await _tap(tester, 'moment-save');
        expect(repository.saves, isEmpty);
        expect(find.text('피드에 보여줄 사진 한 장을 골라 주세요.'), findsOneWidget);
        await _tap(tester, 'moment-public-photo-${record.photos[1].id}');
        if (kIsWeb) {
          final preview = find.byKey(
            const ValueKey('moment-public-photo-preview'),
          );
          await _reveal(tester, preview);
          expect(
            tester
                .widgetList<RawImage>(
                  find.descendant(of: preview, matching: find.byType(RawImage)),
                )
                .any((image) => image.image != null),
            isTrue,
            reason:
                'The chosen real bundled photograph must be decoded and painted in the browser preview.',
          );
        }
        await _tap(tester, 'moment-save');
        expect(repository.saves, hasLength(1));
        expect(publications.publications.single.photoId, record.photos[1].id);
        expect(find.byType(MomentComposeScreen), findsOneWidget);
        await _reveal(tester, find.byKey(const ValueKey('moment-save')));
        expect(find.text('피드 공개 다시 시도'), findsOneWidget);
        final requestId = publications.publications.single.requestId;
        publications.publishError = null;
        await _tap(tester, 'moment-save');
        expect(repository.saves, hasLength(1));
        expect(publications.publications, hasLength(2));
        expect(publications.publications.last.requestId, requestId);
        expect(publications.publications.last.photoId, record.photos[1].id);
        expect(find.byType(MomentComposeScreen), findsNothing);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'private no-op save explicitly withdraws an existing public copy',
    (tester) async {
      final record = _record();
      final repository = _Repository();
      final publications = MemoryMomentPublicationRepository(recordRevision: 3);
      publications.states[record.id] = MomentPublicationState(
        recordId: record.id,
        recordRevision: 3,
        sourceRevision: 3,
        status: 'published',
        publicationRevision: 4,
        workId: 'existing-public-work',
        photoId: record.photos.single.id,
      );
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(record: record, today: _today),
        publications: publications,
      );
      try {
        await _tap(tester, 'moment-save');
        expect(repository.saves, hasLength(1));
        expect(publications.privateCalls, [record.id]);
        expect(publications.states[record.id]!.isPublished, isFalse);
        expect(publications.publications, isEmpty);
        expect(find.byType(MomentComposeScreen), findsNothing);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'public failure can finish privately only after confirmed withdrawal',
    (tester) async {
      final record = _record();
      final repository = _Repository();
      final publications = MemoryMomentPublicationRepository(recordRevision: 3)
        ..publishError = const MomentException('공개 응답 확인 필요')
        ..privateError = const MomentException('비공개 응답 확인 필요');
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(record: record, today: _today),
        publications: publications,
      );
      try {
        await _selectPublic(tester);
        await _tap(tester, 'moment-save');
        expect(repository.saves, hasLength(1));
        await _tap(tester, 'moment-finish-private');
        expect(find.byType(MomentComposeScreen), findsOneWidget);
        expect(repository.saves, hasLength(1));
        publications.privateError = null;
        await _tap(tester, 'moment-finish-private');
        expect(find.byType(MomentComposeScreen), findsNothing);
        expect(repository.saves, hasLength(1));
        expect(publications.privateCalls, [record.id, record.id]);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

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
        await _reveal(tester, find.byTooltip('이 사진 빼기'));
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
    'compose preserves album canvases and contains mixed photo proportions',
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
          final view = tester.widget<MomentPhotoView>(photo);
          // The existing print format is a square canvas. Its photo layer
          // retains the source ratio instead of stretching to fill the canvas.
          expect(size.width / size.height, closeTo(1, .01));
          expect(view.fit, BoxFit.contain);
          if (view.design case final design?) {
            final image = design
                .layersForPhoto('moment-photo://original')
                .single;
            expect(image.width / image.height, closeTo(entry.value, .01));
          }
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
        await _settlePhotoFrames(tester, 'reopen native photo draft');
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

  testWidgets('record date is fixed to the authoritative server day', (
    tester,
  ) async {
    final repository = _Repository();
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(today: _today),
    );
    try {
      final dateHeader = tester.widget<Semantics>(
        find.byKey(const ValueKey('moment-date')),
      );
      expect(dateHeader.properties.readOnly, isTrue);
      expect(dateHeader.properties.onTap, isNull);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.textContaining('날짜는 바꿀 수 없어요'), findsOneWidget);
      expect(repository.saves, isEmpty);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets('past record locks photographs but allows caption-only save', (
    tester,
  ) async {
    final nextDay = _today.add(const Duration(days: 1));
    final repository = _Repository()
      ..readHandler = (month) async => MomentJournal(
        today: nextDay,
        weekStart: momentWeekStart(nextDay),
        month: month,
        records: [_record()],
        weekPhotoCount: 1,
      );
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(record: _record(), today: nextDay),
    );
    try {
      expect(
        tester
            .widget<InkWell>(find.byKey(const ValueKey('moment-pick-photos')))
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('moment-decorate-record-1-photo-0')),
            )
            .onPressed,
        isNull,
      );
      await _enter(
        tester,
        find.byKey(const ValueKey('moment-caption')),
        '지난 기록의 글만 다듬기',
      );
      await _tap(tester, 'moment-save');
      expect(repository.saves.single.caption, '지난 기록의 글만 다듬기');
      expect(repository.saves.single.uploads, isEmpty);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets('expired new draft retains its photos without backdated save', (
    tester,
  ) async {
    final nextDay = _today.add(const Duration(days: 1));
    final repository = _Repository();
    final drafts = MemoryMomentDraftStore()..seed(_draft(upload: true));
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(today: nextDay, draftRecordId: 'local-record'),
      draftStore: drafts,
    );
    try {
      await _reveal(
        tester,
        find.byKey(const ValueKey('moment-photo-date-policy')),
      );
      expect(find.textContaining('이전 날짜에 새로 저장할 수 없어요'), findsOneWidget);
      await _reveal(tester, find.byKey(const ValueKey('moment-save')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('moment-save')))
            .onPressed,
        isNull,
      );
      expect(repository.saves, isEmpty);
      expect((await drafts.list('owner')).single.uploads, hasLength(1));
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets(
    'midnight before first save keeps the draft without backfilling',
    (tester) async {
      final nextDay = _today.add(const Duration(days: 1));
      final repository = _Repository()
        ..readHandler = (month) async => MomentJournal(
          today: nextDay,
          weekStart: momentWeekStart(nextDay),
          month: month,
          records: const [],
          weekPhotoCount: 0,
        );
      final drafts = MemoryMomentDraftStore()..seed(_draft(upload: true));
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(today: _today, draftRecordId: 'local-record'),
        draftStore: drafts,
      );
      try {
        await _tap(tester, 'moment-save');
        expect(repository.saves, isEmpty);
        expect((await drafts.list('owner')).single.uploads, hasLength(1));
        expect(find.textContaining('날짜가 지나 사진을 저장할 수 없어요'), findsOneWidget);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets('uncertain save can reconcile the same request after midnight', (
    tester,
  ) async {
    var serverDay = _today;
    final repository = _Repository();
    repository.readHandler = (month) async => MomentJournal(
      today: serverDay,
      weekStart: momentWeekStart(serverDay),
      month: month,
      records: const [],
      weekPhotoCount: 0,
    );
    repository.saveHandler = () =>
        Future.error(const MomentException('응답을 확인하지 못했어요.'));
    final drafts = MemoryMomentDraftStore()..seed(_draft(upload: true));
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(today: _today, draftRecordId: 'local-record'),
      draftStore: drafts,
    );
    try {
      await _tap(tester, 'moment-save');
      expect(repository.saves, hasLength(1));
      serverDay = _today.add(const Duration(days: 1));
      repository.saveHandler = () async => _record(id: 'local-record');
      await _tap(tester, 'moment-save');
      expect(repository.saves, hasLength(2));
      expect(repository.saves[0].id, repository.saves[1].id);
      expect(repository.saves[0].caption, repository.saves[1].caption);
    } finally {
      await _close(tester, container, repository);
    }
  });

  testWidgets('existing photo edit reconciles a lost save after midnight', (
    tester,
  ) async {
    var serverDay = _today;
    final original = _record(photos: 2);
    final repository = _Repository()..records = [original];
    repository.readHandler = (month) async => MomentJournal(
      today: serverDay,
      weekStart: momentWeekStart(serverDay),
      month: month,
      records: [original],
      weekPhotoCount: 2,
    );
    repository.saveHandler = () =>
        Future.error(const MomentException('응답을 확인하지 못했어요.'));
    final drafts = MemoryMomentDraftStore();
    final container = await _mount(
      tester,
      repository,
      MomentComposeScreen(record: original, today: _today),
      draftStore: drafts,
    );
    try {
      await _reveal(tester, find.byTooltip('이 사진 빼기').first);
      await tester.tap(find.byTooltip('이 사진 빼기').first);
      await tester.pumpAndSettle();
      await _tap(tester, 'moment-save');
      expect(repository.saves, hasLength(1));
      expect((await drafts.list('owner')).single.hasPendingSave, isTrue);
      serverDay = _today.add(const Duration(days: 1));
      repository.saveHandler = () async => _record();
      await _tap(tester, 'moment-save');
      expect(repository.saves, hasLength(2));
      expect(repository.saves[1].id, original.id);
      expect(repository.saves[1].revision, original.revision);
    } finally {
      await _close(tester, container, repository);
    }
  });

  for (final editing in [false, true]) {
    testWidgets(
      'restored pending ${editing ? 'edit' : 'new record'} reconciles after restart and midnight',
      (tester) async {
        final nextDay = _today.add(const Duration(days: 1));
        final original = editing ? _record() : null;
        final initial = _draft(original: original, upload: true);
        final pending = initial.copyWith(
          pendingSaveFingerprint: initial.saveFingerprint,
        );
        final restored = MomentDraft.fromMetadata(
          pending.toMetadata(),
          photoBytes: pending.uploads.map((upload) => upload.bytes).toList(),
        );
        final fresh = _record(id: initial.recordId);
        final serverRecord = MomentRecord(
          id: fresh.id,
          recordDate: fresh.recordDate,
          caption: fresh.caption,
          photos: fresh.photos,
          revision: 4,
        );
        final repository = _Repository();
        repository.readHandler = (month) async => MomentJournal(
          today: nextDay,
          weekStart: momentWeekStart(nextDay),
          month: month,
          records: [serverRecord],
          weekPhotoCount: 1,
        );
        repository.saveHandler = () async => serverRecord;
        final drafts = MemoryMomentDraftStore()..seed(restored);
        final container = await _mount(
          tester,
          repository,
          MomentComposeScreen(today: nextDay, draftRecordId: initial.recordId),
          draftStore: drafts,
        );
        try {
          await _reveal(tester, find.byKey(const ValueKey('moment-save')));
          expect(
            tester
                .widget<FilledButton>(find.byKey(const ValueKey('moment-save')))
                .onPressed,
            isNotNull,
          );
          await _tap(tester, 'moment-save');
          expect(repository.saves, hasLength(1));
          expect(repository.saves.single.id, initial.recordId);
          expect(repository.saves.single.revision, original?.revision);
        } finally {
          await _close(tester, container, repository);
        }
      },
    );
  }

  testWidgets(
    'unknown date resolves before opening the picker and can retry safely',
    (tester) async {
      final repository = _Repository()
        ..readHandler = (_) => Future.error(const MomentException('연결 실패'));
      final picker = _Picker();
      final drafts = MemoryMomentDraftStore();
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(imagePicker: picker),
        draftStore: drafts,
      );
      try {
        expect(find.text('오늘'), findsOneWidget);
        expect(
          tester
              .widget<InkWell>(find.byKey(const ValueKey('moment-pick-photos')))
              .onTap,
          isNotNull,
        );
        await _tap(tester, 'moment-pick-photos');
        expect(picker.calls, 0);
        expect(repository.saves, isEmpty);
        await _reveal(tester, find.textContaining('오늘 날짜를 확인하지 못했어요'));
        expect(find.textContaining('오늘 날짜를 확인하지 못했어요'), findsOneWidget);

        repository.readHandler = null;
        await _tap(tester, 'moment-pick-photos');
        expect(picker.calls, 1);
        final draft = (await drafts.list('owner')).single;
        expect(draft.recordDate, _today);
        expect(draft.uploads, hasLength(1));
        expect(repository.saves, isEmpty);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

  testWidgets(
    'future device date uses server current journal before picking a photo',
    (tester) async {
      final repository = _Repository();
      final drafts = MemoryMomentDraftStore();
      final container = await _mount(
        tester,
        repository,
        MomentComposeScreen(
          today: DateTime.utc(2099, 12, 31),
          imagePicker: _Picker(),
        ),
        draftStore: drafts,
      );
      try {
        await _tap(tester, 'moment-pick-photos');
        final draft = (await drafts.list('owner')).single;
        expect(draft.recordDate, _today);
        expect(draft.uploads, hasLength(1));
        expect(find.textContaining('오늘 날짜를 확인하지 못했어요'), findsNothing);
      } finally {
        await _close(tester, container, repository);
      }
    },
  );

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
