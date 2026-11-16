import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/views/add_cover_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';

import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import '../helpers/mock_repositories.dart' show MockAlbumRepository;
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;
import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;
import 'album_settings_redesign_test.dart' show openAlbumSettingsSection;

const _owner = '11111111-1111-4111-8111-111111111111';
const _revision = '2026-11-11T00:00:00.123456Z';
final _cover = coverSizeForProduct('REDP_250X200_HARD')!;
final _physicalCanvas = coverCanvasBaseSize(_cover);
final _productKey = pointShopTemplateKey(
  publishedCreationTemplates.firstWhere((template) => template.id == -9501),
);

class _Auth extends AuthViewModel {
  String? owner = _owner;
  final changes = StreamController<String?>.broadcast(sync: true);

  @override
  FutureOr<UserInfo?> build() =>
      UserInfo(id: _owner, name: '생성 경로 검증', provider: 'email');

  void loseOwner() {
    owner = null;
    state = const AsyncData(null);
    changes.add(null);
  }
}

class _Albums extends MockAlbumRepository {
  int creates = 0;
  Completer<void>? creating;
  Album? created;
  final requests = <CreateAlbumRequest>[];
  final requestIds = <String?>[];
  final requestedOwners = <String?>[];

  @override
  Future<Album> createAlbum(
    CreateAlbumRequest request, {
    String? requestId,
    String? expectedUserId,
  }) async {
    creates++;
    requests.add(request);
    requestIds.add(requestId);
    requestedOwners.add(expectedUserId);
    if (creating != null) await creating!.future;
    return created = Album(
      id: 71,
      userId: _owner,
      memberRole: 'OWNER',
      title: request.title,
      ratio: request.ratio,
      targetPages: request.targetPages,
      updatedAt: _revision,
      coverLayersJson: request.coverLayersJson,
    );
  }

  @override
  Future<Album> fetchAlbum(String id) async =>
      created ??
      Album(
        id: 71,
        userId: _owner,
        memberRole: 'OWNER',
        title: '이어 만드는 앨범',
        ratio: _cover.ratio.toString(),
        targetPages: 24,
        updatedAt: _revision,
      );
}

class _Store extends MemoryCreationDraftStore {
  bool failLinked = false;
  Completer<void>? linking;
  int linkedAttempts = 0;
  final savedOwners = <String>[];

  @override
  Future<void> save(String owner, AlbumCreationDraft value) async {
    if (value.createdAlbumId != null) {
      linkedAttempts++;
      if (linking != null) await linking!.future;
      if (failLinked) throw StateError('Linked checkpoint write failed');
    }
    await super.save(owner, value);
    savedOwners.add(owner);
  }
}

class _Persistence extends FakeAlbumPersistenceService {
  _Persistence(this.albums);
  final _Albums albums;
  int calls = 0;

  @override
  Future<Album> performBackgroundUpload({
    required int albumId,
    required String expectedUpdatedAt,
    required String expectedUserId,
    required String requestId,
    bool Function()? canContinue,
    void Function(CreateAlbumRequest)? onPrepared,
    void Function(LayerModel before, LayerModel after)? onLayerUploaded,
    void Function(UploadedUrls)? onUploaded,
    required Size canvasSize,
    required List<LayerModel> currentLayers,
    required Uint8List? coverImageBytes,
    required String themeLabel,
    required String title,
    required double coverRatio,
    required int targetPages,
    Map<String, dynamic>? printProduct,
    String? sourceTemplateProductKey,
    bool swallowErrors = true,
    void Function(int completed, int total)? onProgress,
  }) async {
    calls++;
    // Keep the real create response's owner/revision; only external uploads are fake.
    return albums.created!.copyWith(updatedAt: expectedUpdatedAt);
  }
}

LayerModel _text(String id) => LayerModel(
  id: id,
  type: LayerType.text,
  text: '유지할 문구 $id',
  position: const Offset(24, 250),
  width: 260,
  height: 40,
  textStyle: const TextStyle(fontFamily: 'Pretendard', fontSize: 18),
);

List<List<LayerModel>> _templatePages() => [
  for (var page = 0; page < 25; page++)
    [
      LayerModel(
        id: 'photo-$page',
        type: LayerType.image,
        position: Offset(
          _physicalCanvas.width * .1,
          _physicalCanvas.height * .1,
        ),
        width: _physicalCanvas.width * .7,
        height: _physicalCanvas.height * .5,
        imageUrl: 'asset:assets/frame_preview/alpine_lake.jpg',
        imageZoom: page == 0 ? 1.7 : 1,
        imageOffset: page == 0 ? const Offset(12, -8) : null,
        imageBackground: 'archSoft',
      ),
      _text('text-$page'),
    ],
];

AlbumCreationDraft _templateDraft() {
  final pages = _templatePages();
  return AlbumCreationDraft(
    id: 'unified-template-draft',
    updatedAt: DateTime.utc(2026, 11, 11),
    title: '설정에서 이어갈 템플릿',
    cover: _cover,
    pageCount: 24,
    step: 0,
    showPhotoFill: false,
    hasSelectedMode: true,
    sourceLabel: '선택한 템플릿',
    usesPhysicalCanvas: true,
    preserveTypography: true,
    pages: pages,
    basePages: pages,
    baseCanvasSize: _physicalCanvas,
    templateTitle: '전체 지면 검증',
    sourceTemplateProductKey: _productKey,
    editedCover: pages.first,
    editedCoverCanvasSize: _physicalCanvas,
  );
}

class _Fixture {
  _Fixture(
    this.container,
    this.albums,
    this.store,
    this.auth,
    this.persistence,
  );
  final ProviderContainer container;
  final _Albums albums;
  final _Store store;
  final _Auth auth;
  final _Persistence persistence;
  AlbumEditorViewModel get vm =>
      container.read(albumEditorViewModelProvider.notifier);
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 100; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 32));
    if (ready()) return;
  }
  fail('Unified album entry did not reach its expected state.');
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  AlbumCreationDraft? draft,
  bool manual = false,
  bool seedOldEditor = false,
  bool deferCreate = false,
  bool failLinked = false,
  bool deferLinked = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  final albums = _Albums();
  if (deferCreate) albums.creating = Completer<void>();
  final store = _Store()
    ..draft = draft
    ..failLinked = failLinked;
  if (deferLinked) store.linking = Completer<void>();
  final auth = _Auth();
  final persistence = _Persistence(albums);
  final container = ProviderContainer(
    overrides: [
      authViewModelProvider.overrideWith(() => auth),
      albumEditorOwnerReaderProvider.overrideWithValue(() => auth.owner),
      albumEditorOwnerChangesProvider.overrideWith(
        (ref) => auth.changes.stream,
      ),
      albumCreationDraftStoreProvider.overrideWithValue(store),
      albumRepositoryProvider.overrideWithValue(albums),
      albumPersistenceServiceProvider.overrideWithValue(persistence),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumCreationCatalogProvider.overrideWith((ref) => Stream.value([])),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    container.dispose();
    await auth.changes.close();
    tester.view.reset();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  await container.read(authViewModelProvider.future);
  await container.read(albumEditorViewModelProvider.future);
  final fixture = _Fixture(container, albums, store, auth, persistence);
  if (seedOldEditor) {
    fixture.vm.startLocalTemplateAlbum(
      albumTitle: '이전 작업',
      initialCover: defaultCoverSize,
      pages: [
        for (var page = 0; page < 25; page++) [_text('old-$page')],
      ],
      templateCanvasSize: const Size(500, 500),
    );
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: wrapCreation(AlbumCreateFlowScreen(initialDraft: draft)),
    ),
  );
  await _until(
    tester,
    () => manual
        ? find
              .byKey(const ValueKey('creation-manual-start'))
              .evaluate()
              .isNotEmpty
        : draft?.createdAlbumId != null
        ? find.byType(PageEditorScreen).evaluate().isNotEmpty
        : find.byType(AlbumCreateStep1).evaluate().isNotEmpty,
  );
  if (manual) {
    await tester.tap(find.byKey(const ValueKey('creation-manual-start')));
    await tester.pump();
    await openAlbumSettingsSection(tester, 'name');
    await tester.enterText(
      find.byKey(const ValueKey('creation-album-title')),
      '직접 만든 새 책',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    tester
        .widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1))
        .onCoverSelected(_cover);
    await tester.pump();
  }
  return fixture;
}

bool _editorShown() => find.byType(PageEditorScreen).evaluate().isNotEmpty;

void _expectNoOldStep() {
  expect(find.byType(TemplatePhotoFillStep), findsNothing);
  expect(find.byType(AddCoverScreen), findsNothing);
}

void _expectLinkedEditor(_Fixture fixture, {int pages = 25}) {
  expect(find.byType(PageEditorScreen), findsOneWidget);
  _expectNoOldStep();
  expect(fixture.albums.creates, 1);
  expect(fixture.vm.editingAlbumId, 71);
  expect(fixture.vm.currentPageIndex, 0);
  expect(fixture.vm.pages, hasLength(pages));
  expect(fixture.store.draft!.createdAlbumId, 71);
  expect(fixture.store.draft!.editorCheckpoint, isNotNull);
  expect(fixture.store.draft!.editorCheckpoint!.pageIndex, 0);
  expect(fixture.store.draft!.editorCheckpoint!.pages, hasLength(pages));
  expect(fixture.albums.requestedOwners, [_owner]);
  expect(fixture.albums.requestIds.single, isNotEmpty);
}

void main() {
  setUpAll(loadCreationFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'template enters the editor only after ID and linked checkpoint',
    (tester) async {
      final fixture = await _mount(
        tester,
        draft: _templateDraft(),
        deferLinked: true,
      );
      tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1)).onNext();
      await tester.pump();
      _expectNoOldStep();
      await _until(tester, () => fixture.store.linkedAttempts > 0);
      expect(fixture.albums.creates, 1);
      expect(_editorShown(), isFalse);
      expect(fixture.store.draft!.createdAlbumId, isNull);
      fixture.store.linking!.complete();
      await _until(tester, _editorShown);
      _expectLinkedEditor(fixture);
      expect(fixture.vm.selectedCover.productId, 'REDP_250X200_HARD');
      expect(fixture.vm.innerPageCount, 24);
      for (var page = 0; page < 25; page++) {
        expect(fixture.vm.pages[page].layers.map((layer) => layer.id), [
          'photo-$page',
          'text-$page',
        ]);
      }
      final crop = fixture.vm.pages.first.layers.first;
      expect(crop.imageZoom, 1.7);
      expect(crop.imageOffset, const Offset(12, -8));
      final checkpoint = fixture.store.draft!.editorCheckpoint!;
      expect(checkpoint.sourceTemplateProductKey, _productKey);
      expect(checkpoint.coverCanvas, const Size(500, 400));
      expect(checkpoint.innerCanvas, const Size(500, 400));
      expect(checkpoint.pages.first.layers.first.imageZoom, 1.7);
      expect(
        checkpoint.pages.first.layers.first.imageOffset,
        const Offset(12, -8),
      );
    },
  );

  testWidgets(
    'manual entry clears an old editor and keeps twenty blank inner pages',
    (tester) async {
      final fixture = await _mount(tester, manual: true, seedOldEditor: true);
      tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1)).onNext();
      await tester.pump();
      _expectNoOldStep();
      await _until(tester, _editorShown);
      _expectLinkedEditor(fixture, pages: 21);
      expect(fixture.vm.selectedCover.productId, 'REDP_250X200_HARD');
      expect(fixture.vm.innerPageCount, 20);
      expect(
        fixture.vm.pages.skip(1).every((page) => page.layers.isEmpty),
        isTrue,
      );
      expect(
        fixture.vm.pages
            .expand((page) => page.layers)
            .any((layer) => layer.id.startsWith('old-')),
        isFalse,
      );
      expect(
        fixture.store.draft!.editorCheckpoint!.sourceTemplateProductKey,
        isNull,
      );
    },
  );

  testWidgets(
    'repeated continue while create is pending makes one server request',
    (tester) async {
      final fixture = await _mount(
        tester,
        draft: _templateDraft(),
        deferCreate: true,
      );
      final next = tester
          .widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1))
          .onNext;
      next();
      next();
      await _until(tester, () => fixture.albums.creates > 0);
      expect(fixture.albums.creates, 1);
      expect(_editorShown(), isFalse);
      _expectNoOldStep();
      expect(fixture.store.draft!.createdAlbumId, isNull);
      fixture.albums.creating!.complete();
      await _until(tester, _editorShown);
      _expectLinkedEditor(fixture);
    },
  );

  testWidgets(
    'failed linked checkpoint blocks entry and retries only the local write',
    (tester) async {
      final fixture = await _mount(
        tester,
        draft: _templateDraft(),
        failLinked: true,
      );
      tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1)).onNext();
      await _until(
        tester,
        () => find
            .byKey(const ValueKey('creation-checkpoint-retry'))
            .evaluate()
            .isNotEmpty,
      );
      expect(_editorShown(), isFalse);
      _expectNoOldStep();
      expect(fixture.albums.creates, 1);
      expect(fixture.vm.editingAlbumId, 71);
      expect(fixture.store.draft!.createdAlbumId, isNull);
      expect(fixture.store.draft!.creationAttempt, isNotNull);
      final uploads = fixture.persistence.calls;
      final requestId = fixture.albums.requestIds.single;
      fixture.store.failLinked = false;
      final retry = find.byKey(const ValueKey('creation-checkpoint-retry'));
      final retryAgain = tester.widget<ButtonStyleButton>(retry).onPressed!;
      retryAgain();
      retryAgain();
      await _until(tester, _editorShown);
      _expectLinkedEditor(fixture);
      expect(fixture.persistence.calls, uploads);
      expect(fixture.albums.requestIds, [requestId]);
      expect(fixture.vm.pages[24].layers.last.id, 'text-24');
    },
  );

  testWidgets('owner loss while create is pending blocks the old response', (
    tester,
  ) async {
    final fixture = await _mount(
      tester,
      draft: _templateDraft(),
      deferCreate: true,
    );
    tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1)).onNext();
    await _until(tester, () => fixture.albums.creates == 1);
    fixture.auth.loseOwner();
    await tester.pump();
    final writes = fixture.store.writes;
    fixture.albums.creating!.complete();
    for (var frame = 0; frame < 12; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 32));
    }
    expect(_editorShown(), isFalse);
    expect(fixture.store.writes, writes);
    expect(fixture.store.draft?.createdAlbumId, isNull);
    expect(fixture.albums.creates, 1);
    expect(fixture.store.savedOwners.every((owner) => owner == _owner), isTrue);
  });

  testWidgets(
    'created legacy draft restores edited page and layers without recreating',
    (tester) async {
      final old = _templateDraft();
      final checkpoint = AlbumCreationEditorCheckpoint(
        pages: [
          for (var page = 0; page < 25; page++)
            AlbumPage(
              id: 'restored-page-$page',
              pageIndex: page,
              isCover: page == 0,
              backgroundColor: page == 3 ? 0xFFDAE8E3 : null,
              layers: old.pages![page],
            ),
        ],
        pageIndex: 3,
        coverCanvas: const Size(500, 400),
        innerCanvas: const Size(500, 400),
        theme: CoverTheme.nature1,
        sourceOwnerId: _owner,
        sourceMemberRole: 'OWNER',
        sourceUpdatedAt: _revision,
        sourceTemplateProductKey: _productKey,
      );
      final json = old.toJson()
        ..['createdAlbumId'] = 71
        ..['showPhotoFill'] = true
        ..['currentPage'] = 1
        ..['editorCheckpoint'] = checkpoint.toJson();
      final draft = AlbumCreationDraft.fromJson(json);
      final fixture = await _mount(tester, draft: draft);
      expect(_editorShown(), isTrue);
      _expectNoOldStep();
      expect(fixture.albums.creates, 0);
      expect(fixture.vm.editingAlbumId, 71);
      expect(fixture.vm.currentPageIndex, 3);
      expect(fixture.vm.pages[3].id, 'restored-page-3');
      expect(fixture.vm.pages[3].backgroundColor, 0xFFDAE8E3);
      expect(fixture.vm.pages[3].layers.map((layer) => layer.id), [
        'photo-3',
        'text-3',
      ]);
      expect(fixture.vm.selectedTheme, CoverTheme.nature1);
      expect(fixture.store.writes, 0);
    },
  );
}
