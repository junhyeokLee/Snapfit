import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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

import '../helpers/memory_moment_draft_store.dart';
import '../helpers/memory_moment_publication_repository.dart';

final _date = DateTime.utc(2026, 10, 26);

// A small decoded image keeps browser tests independent from real asset fetch
// timing while exercising the same AssetImage/fallback rendering path.
class _FixtureAssetBundle extends CachingAssetBundle {
  static const asset = 'assets/cover/cover1.png';
  final _photoBytes = img.encodePng(img.Image(width: 6, height: 8));
  final _manifest = const StandardMessageCodec().encodeMessage({
    asset: [
      {'asset': asset},
    ],
  })!;

  @override
  Future<ByteData> load(String key) async {
    if (key == asset) return ByteData.sublistView(_photoBytes);
    if (key == 'AssetManifest.bin') return _manifest;
    if (key == 'AssetManifest.bin.json') {
      return ByteData.sublistView(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode(
              base64Encode(
                _manifest.buffer.asUint8List(
                  _manifest.offsetInBytes,
                  _manifest.lengthInBytes,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return rootBundle.load(key);
  }
}

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
        bundle: _FixtureAssetBundle(),
        child: MaterialApp(
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

void main() {
  setUp(() => SnapfitImage.storageOwnerForTesting = () => 'owner');
  tearDown(() => SnapfitImage.storageOwnerForTesting = null);
  testWidgets(
    'direct writing opens the composer without waiting for an offline journal',
    (tester) async {
      final repo = _Repository()..offline = true;
      final store = MemoryMomentDraftStore();
      final container = await _mount(tester, repo, store, direct: true);
      await tester.tap(find.byKey(const ValueKey('direct-moment-compose')));
      await _settleDirect(tester);
      expect(find.byType(MomentComposeScreen), findsOneWidget);
      expect(find.byType(MomentsScreen), findsNothing);
      expect(repo.reads, 0);
      expect(repo.saves, 0);
      // Release the mounted midnight scheduler before binding invariants.
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'direct recovered new record saves once then opens the monthly appreciation preview',
    (tester) async {
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
      expect(find.byKey(const ValueKey('moment-new-photo-0')), findsOneWidget);
      expect(repo.reads, 0);
      // Saving still confirms the server date after the immediate offline entry.
      repo.offline = false;
      await _saveDirect(tester);
      expect(repo.saves, 1);
      expect(repo.reads, 1);
      expect(store.drafts, isEmpty);
      expect(find.byType(MomentSavedPreviewScreen), findsOneWidget);
      expect(find.byType(MomentsScreen), findsNothing);
    },
  );

  testWidgets(
    'direct saved preview only describes the saved photos without a complete journal',
    (tester) async {
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
      // The date confirmation must not turn its payload into month history.
      repo.offline = false;
      await _saveDirect(tester);

      expect(repo.saves, 1);
      expect(repo.reads, 1);
      expect(find.byType(MomentSavedPreviewScreen), findsOneWidget);
      // Direct entry has no month history, so it cannot claim a first or total.
      expect(find.text('내 한 달의\n첫 장이 생겼어요.'), findsNothing);
      expect(find.text('나의 한 달에\n한 장이 더 쌓였어요.'), findsNothing);
      expect(find.textContaining('10월에 모은 사진'), findsNothing);
      expect(find.text('이 순간을,\n잘 간직했어요.'), findsOneWidget);
      expect(
        find.text('사진 1장을 저장했어요.\n모아둔 사진으로 내 한 달의 책을 만들어보세요.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'direct recovered edit keeps its revision and skips the new-record preview',
    (tester) async {
      final draft = _draft(editing: true);
      final repo = _Repository();
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
      await _saveDirect(tester);
      expect(repo.saves, 1);
      expect(repo.expectedRevision, 7);
      expect(find.byType(MomentSavedPreviewScreen), findsNothing);
      expect(
        find.byKey(const ValueKey('direct-moment-compose')),
        findsOneWidget,
      );
      expect(store.drafts, isEmpty);
    },
  );

  testWidgets(
    'direct draft lookup rejects an owner A-B-A change before pushing a route',
    (tester) async {
      final pending = Completer<void>();
      final repo = _Repository();
      final store = MemoryMomentDraftStore()
        ..seed(_draft())
        ..beforeLoad = () => pending.future;
      await _mount(tester, repo, store, direct: true, initialId: 'new');
      await tester.tap(find.byKey(const ValueKey('direct-moment-compose')));
      await tester.pump();
      repo.change('other');
      repo.change('owner');
      await tester.pump();
      pending.complete();
      await _settleDirect(tester);
      expect(find.byType(MomentComposeScreen), findsNothing);
      expect(find.byType(MomentSavedPreviewScreen), findsNothing);
      expect(repo.saves, 0);
      expect(store.drafts, isNotEmpty);
    },
  );

  testWidgets(
    'direct late compose result cannot show an appreciation preview after owner A-B-A',
    (tester) async {
      final repo = _Repository();
      final store = MemoryMomentDraftStore();
      await _mount(tester, repo, store, direct: true);
      await tester.tap(find.byKey(const ValueKey('direct-moment-compose')));
      await _settleDirect(tester);
      repo.change('other');
      repo.change('owner');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop(_original);
      await _settleDirect(tester);
      expect(find.byType(MomentSavedPreviewScreen), findsNothing);
      expect(
        find.byKey(const ValueKey('direct-moment-compose')),
        findsOneWidget,
      );
      expect(repo.saves, 0);
    },
  );
  testWidgets('restored raw photo remains decodable for display and upload', (
    tester,
  ) async {
    final draft = _draft();
    final store = MemoryMomentDraftStore()..seed(draft);
    final repo = _Repository()..offline = true;
    final container = await _mount(
      tester,
      repo,
      store,
      initialId: draft.recordId,
    );
    final photo = find.byKey(const ValueKey('moment-new-photo-0'));
    expect(photo, findsOneWidget);
    final restoredBytes = tester.widget<MomentPhotoView>(photo).bytes!;
    expect(restoredBytes, orderedEquals(draft.uploads.single.bytes));
    final raw = tester.widget<RawImage>(
      find.descendant(of: photo, matching: find.byType(RawImage)).first,
    );
    expect(
      raw.image,
      isNotNull,
      reason: 'The restored photograph must display decoded pixels.',
    );
    expect(raw.image!.width, 2);
    expect(raw.image!.height, 2);
    await tester.runAsync(() async {
      final prepared = await prepareMomentPhoto(
        restoredBytes,
      ).timeout(const Duration(seconds: 5));
      expect(prepared.width, 2);
      expect(prepared.height, 2);
    });
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });
  testWidgets(
    'explicit draft recovery remains reachable while journal is offline',
    (tester) async {
      final repo = _Repository()..offline = true;
      final store = MemoryMomentDraftStore()..seed(_draft());
      final container = await _mount(tester, repo, store, initialId: 'new');
      expect(find.byType(MomentComposeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('moment-new-photo-0')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('moment-caption')),
        250,
        scrollable: find
            .descendant(
              of: find.byType(MomentComposeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('보관한 순간'), findsOneWidget);
      expect(repo.saves, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
  for (final deepEntry in [false, true]) {
    testWidgets(
      'recovered new record with unavailable journal shows only saved photos deepEntry=$deepEntry',
      (tester) async {
        final draft = _draft();
        final repo = _Repository()..offline = true;
        final store = MemoryMomentDraftStore()..seed(draft);
        await _mount(
          tester,
          repo,
          store,
          initialId: draft.recordId,
          direct: !deepEntry,
        );
        if (!deepEntry) {
          await tester.tap(find.byKey(const ValueKey('direct-moment-compose')));
          await _settleDirect(tester);
        }
        expect(find.byType(MomentComposeScreen), findsOneWidget);
        final readsBeforeSave = repo.reads;
        // The original journal is unavailable; saving still confirms its date.
        repo.offline = false;
        await _saveDirect(tester);

        expect(repo.saves, 1);
        expect(repo.reads, greaterThan(readsBeforeSave));
        expect(store.drafts, isEmpty);
        expect(find.byType(MomentSavedPreviewScreen), findsOneWidget);
        expect(find.text('내 한 달의\n첫 장이 생겼어요.'), findsNothing);
        expect(find.textContaining('10월에 모은 사진'), findsNothing);
        expect(find.text('이 순간을,\n잘 간직했어요.'), findsOneWidget);
        expect(
          find.text('사진 1장을 저장했어요.\n모아둔 사진으로 내 한 달의 책을 만들어보세요.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final deepEntry in [false, true]) {
    testWidgets('restored edit skips new-record reward deepEntry=$deepEntry', (
      tester,
    ) async {
      final repo = _Repository();
      final store = MemoryMomentDraftStore()..seed(_draft(editing: true));
      await _mount(
        tester,
        repo,
        store,
        initialId: 'record',
        direct: !deepEntry,
      );
      if (!deepEntry) {
        await tester.tap(find.byKey(const ValueKey('direct-moment-compose')));
        await _settle(tester);
      }
      expect(find.byType(MomentComposeScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('moment-save')),
        300,
        scrollable: find
            .descendant(
              of: find.byType(MomentComposeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('moment-save')));
      await _settle(tester);
      expect(repo.saves, 1);
      expect(repo.expectedRevision, 7);
      expect(find.byType(MomentSavedPreviewScreen), findsNothing);
      expect(
        find.byType(MomentsScreen),
        deepEntry ? findsOneWidget : findsNothing,
      );
      expect(find.byKey(const ValueKey('moments-resume-draft')), findsNothing);
      expect(store.drafts, isEmpty);
    });
  }
}
