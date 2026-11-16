import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/shared/snapfit_image.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/data/moment_photo_codec.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_publication_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_compose_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_saved_preview_screen.dart';
import 'package:snap_fit/features/moments/presentation/views/moments_screen.dart';
import 'package:snap_fit/features/moments/presentation/moments_navigation.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';

import '/Users/devsheep/SnapFit/SnapFit/test/helpers/memory_moment_draft_store.dart';
import '/Users/devsheep/SnapFit/SnapFit/test/helpers/memory_moment_publication_repository.dart';

final _date = DateTime.utc(2026, 10, 26);

const _photo = MomentPhoto(
  id: 'existing',
  path: 'owner/moments/record/photo.png',
  url: 'asset:assets/cover/cover1.png',
  width: 600,
  height: 800,
);
final _original = MomentRecord(
  id: 'record',
  recordDate: _date,
  caption: '원래의 순간',
  photos: [_photo],
  revision: 7,
);

MomentDraft _draft({bool editing = false}) => MomentDraft(
  ownerId: 'owner',
  recordId: editing ? 'record' : 'new',
  recordDate: _date,
  caption: '보관한 순간',
  updatedAt: _date,
  existingPhotos: editing ? [_photo] : [],
  originalRecord: editing ? _original : null,
  uploads: editing
      ? []
      : [
          MomentDraftUpload(
            id: 'upload',
            filename: 'photo.png',
            bytes: img.encodePng(img.Image(width: 2, height: 2)),
          ),
        ],
);

class _Repository implements MomentsRepository {
  String? actor = 'owner';
  final changes = StreamController<String?>.broadcast();
  bool offline = false;
  int saves = 0;
  int reads = 0;
  int? expectedRevision;
  @override
  String? get currentUserId => actor;
  @override
  Stream<String?> get authChanges => changes.stream;
  void change(String? next) {
    actor = next;
    changes.add(next);
  }

  @override
  Future<MomentJournal> listMonth(DateTime? requestedMonth) async {
    final month = requestedMonth ?? momentMonth(_date);
    reads++;
    if (offline) throw const MomentException('연결을 확인해 주세요.');
    return MomentJournal(
      today: _date,
      weekStart: momentWeekStart(_date),
      month: month,
      records: [_original],
      weekPhotoCount: 1,
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
    saves++;
    this.expectedRevision = expectedRevision;
    return MomentRecord(
      id: id,
      recordDate: recordDate,
      caption: caption,
      photos: [_photo],
      revision: (expectedRevision ?? 0) + 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Repository repo,
  MemoryMomentDraftStore store, {
  String? initialId,
  bool direct = false,
}) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      momentsRepositoryProvider.overrideWithValue(repo),
      momentPublicationRepositoryProvider.overrideWithValue(
        MemoryMomentPublicationRepository(),
      ),
      momentDraftStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await repo.changes.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: DefaultAssetBundle(
        bundle: rootBundle,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => RepaintBoundary(
            key: const ValueKey('saved-accuracy-capture-root'),
            child: child!,
          ),
          theme: SnapFitTheme.light(),
          home: direct
              ? Consumer(
                  builder: (context, ref, _) => Scaffold(
                    body: TextButton(
                      key: const ValueKey('direct-moment-compose'),
                      onPressed: () => openMomentCompose(
                        context,
                        ref,
                        draftRecordId: initialId,
                      ),
                      child: const Text('바로 기록 남기기'),
                    ),
                  ),
                )
              : MomentsScreen(initialDraftRecordId: initialId),
        ),
      ),
    ),
  );
  if (!kIsWeb) {
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      await precacheImage(
        ResizeImage.resizeIfNeeded(
          1200,
          null,
          const AssetImage('assets/cover/cover1.png'),
        ),
        context,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw StateError('fixture asset precache timeout');
        },
      );
    });
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump();
      final photos = tester.widgetList<Image>(find.byType(Image)).toList();
      await tester.runAsync(() async {
        for (final image in photos) {
          await precacheImage(image.image, context).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw StateError('visible image precache timeout');
            },
          );
        }
      });
    }
  }
  await _settle(tester);
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  if (kIsWeb) {
    // Browser image promises started by a fake-clock frame must be flushed by
    // another fake-clock frame. Awaiting their existing ImageStream inside
    // runAsync deadlocks the stream's original zone instead.
    for (var frame = 0; frame < 24; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Future<void> _settleDirect(WidgetTester tester) async {
  if (!kIsWeb) {
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 400));
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      await tester.runAsync(() async {
        for (final image in images) {
          await precacheImage(
            image.image,
            tester.element(find.byType(Image).first),
          ).timeout(const Duration(seconds: 5));
        }
      });
    }
  }
  await _settle(tester);
}

Future<void> _saveDirect(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('moment-save'));
  await tester.scrollUntilVisible(
    save,
    250,
    scrollable: find
        .descendant(
          of: find.byType(MomentComposeScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(save);
  await tester.tap(save);
  await _settleDirect(tester);
}

// Native-only visual audit. Run in a fresh process with real asset fonts and
// CAPTURE_DIR pointing to the review output directory.
void main() {
  final captureDirectory = Platform.environment['CAPTURE_DIR'];
  if (captureDirectory == null) return;
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
        'assets/fonts/Poppins-Bold.otf',
      ],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final asset in entry.value) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  });
  setUp(() => SnapfitImage.storageOwnerForTesting = () => 'owner');
  tearDown(() => SnapfitImage.storageOwnerForTesting = null);
  testWidgets('capture direct saved preview accuracy', (tester) async {
    final draft = _draft();
    final repo = _Repository()..offline = true;
    final store = MemoryMomentDraftStore()..seed(draft);
    await _mount(
      tester,
      repo,
      store,
      direct: true,
      initialId: draft.recordId,
    );
    await tester.tap(find.byKey(const ValueKey('direct-moment-compose')));
    await _settleDirect(tester);
    expect(repo.reads, 0);
    // The composer opens offline; saving still confirms the server date.
    repo.offline = false;
    await _saveDirect(tester);
    expect(find.byType(MomentSavedPreviewScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('moment-saved-book-cover')), findsOneWidget);
    expect(repo.saves, 1);
    expect(repo.reads, 1);
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('saved-accuracy-capture-root')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final target = File('$captureDirectory/direct-saved-preview.png');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  });
}
