import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/controllers/photo_crop_editor.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/photo_crop_sheet.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/shared/widgets/photo_crop_viewport.dart';

import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;
import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'photo_crop_sheet_test.dart' show waitForCropPhoto;

const _canvas = Size(500, 500);
const _targetId = 'editor-target-photo';
const _otherId = 'editor-other-photo';
const _titleId = 'editor-title';

BrowserPhotoAsset _photo(String id, Uint8List bytes, Size size) =>
    BrowserPhotoAsset.fromStored(
      ownerId: 'editor-owner',
      id: 'browser_$id',
      name: '$id.png',
      width: size.width.toInt(),
      height: size.height.toInt(),
      createdAtSecond: 0,
      originalBytes: bytes,
      previewBytes: bytes,
      contentSha256: sha256.convert(bytes).toString(),
    );

Map<String, Object?> _facts(LayerModel layer) => {
  'assetId': layer.asset?.id,
  'document': LayerExportMapper.toJson(layer, canvasSize: _canvas),
};

List<Map<String, Object?>> _document(AlbumEditorViewModel vm) => [
  for (final layer in vm.layers) _facts(layer),
];

class _Host extends ConsumerStatefulWidget {
  const _Host();

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  late final LayerInteractionManager _interaction;
  late final LayerBuilder _builder;

  @override
  void initState() {
    super.initState();
    _interaction = LayerInteractionManager.preview(ref, () => _canvas);
    _builder = LayerBuilder(_interaction, () => _canvas);
  }

  @override
  void dispose() {
    _interaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const ValueKey('open-editor-photo-crop'),
        onPressed: () => editPhotoCrop(
          context,
          ref,
          ref
              .read(albumEditorViewModelProvider.notifier)
              .findLayerById(_targetId)!,
          layerBuilder: _builder,
        ),
        child: const Text('사진 구도 조정'),
      ),
    ),
  );
}

LayerModel _precisionDraft(WidgetTester tester) => tester
    .widget<PhotoCropViewport>(
      find.descendant(
        of: find.byType(PhotoCropSheet),
        matching: find.byType(PhotoCropViewport),
      ),
    )
    .layer;

Future<LayerModel> _editAndInspectPage(
  WidgetTester tester, {
  required AlbumEditorViewModel vm,
  required List<Map<String, Object?>> before,
  required LayerModel original,
  required LayerModel other,
  required LayerModel title,
}) async {
  await tester.tap(find.byKey(const ValueKey('open-editor-photo-crop')));
  await waitForCropPhoto(tester);
  final sheet = tester.widget<PhotoCropSheet>(find.byType(PhotoCropSheet));
  expect(sheet.layer, same(original));
  expect(sheet.frameBuilder, isNotNull);
  expect(sheet.pageContext, isNotNull);
  expect(sheet.pageContext!.canvasSize, _canvas);
  await tester.tap(find.byTooltip('사진 확대'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('photo-crop-anchor-0')));
  await tester.pumpAndSettle();
  final draft = _precisionDraft(tester);
  expect(draft.imageZoom, closeTo(original.imageZoom + .1, .001));
  expect(draft.imageOffset, isNot(original.imageOffset));

  await tester.tap(find.byKey(const ValueKey('photo-crop-context-toggle')));
  await tester.pumpAndSettle();
  final page = find.byKey(const ValueKey('photo-crop-page-context'));
  expect(page, findsOneWidget);
  final previews = {
    for (final viewport in tester.widgetList<PhotoCropViewport>(
      find.descendant(of: page, matching: find.byType(PhotoCropViewport)),
    ))
      viewport.layer.id: viewport.layer,
  };
  expect(previews.keys, unorderedEquals([_targetId, _otherId]));
  expect(_facts(previews[_targetId]!), _facts(draft));
  expect(previews[_targetId]!.asset, same(original.asset));
  expect(_facts(previews[_otherId]!), _facts(other));
  expect(previews[_otherId]!.asset, same(other.asset));
  expect(
    find.descendant(of: page, matching: find.text(title.text!)),
    findsOneWidget,
  );
  final stack = tester.widget<Stack>(
    find.descendant(
      of: page,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Stack &&
            widget.children.length == 4 &&
            widget.children.every((child) => child is Positioned),
      ),
    ),
  );
  // Actual editor painting puts a full-page background below content even
  // with a higher zIndex, then preserves source order for equal-z layers.
  expect(
    find.descendant(
      of: find.byWidget(stack.children[0]),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                const Color(0xFFEFECE4),
      ),
    ),
    findsOneWidget,
  );
  for (final entry in [(1, _targetId), (2, _otherId)]) {
    expect(
      tester
          .widget<PhotoCropViewport>(
            find.descendant(
              of: find.byWidget(stack.children[entry.$1]),
              matching: find.byType(PhotoCropViewport),
            ),
          )
          .layer
          .id,
      entry.$2,
    );
  }
  expect(
    find.descendant(
      of: find.byWidget(stack.children[3]),
      matching: find.text(title.text!),
    ),
    findsOneWidget,
  );
  expect(_document(vm), before);
  expect(vm.findLayerById(_titleId), same(title));
  expect(vm.findLayerById(_otherId), same(other));

  await tester.tap(find.byKey(const ValueKey('photo-crop-context-toggle')));
  await tester.pumpAndSettle();
  expect(page, findsNothing);
  expect(_facts(_precisionDraft(tester)), _facts(draft));
  return draft;
}

void main() {
  setUpAll(() async {
    if (!kIsWeb) await loadCreationFonts();
  });

  for (final size in [const Size(390, 844), const Size(1000, 800)]) {
    testWidgets(
      'editor crop page context preserves the document until apply and undoes atomically $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = MockAlbumRepository();
        final container = ProviderContainer(
          overrides: [
            albumRepositoryProvider.overrideWithValue(repository),
            albumEditorServiceProvider.overrideWithValue(
              const AlbumEditorService(),
            ),
            albumPersistenceServiceProvider.overrideWithValue(
              FakeAlbumPersistenceService(),
            ),
            storageServiceProvider.overrideWithValue(FakeStorageService()),
          ],
        );
        addTearDown(container.dispose);
        await container.read(albumEditorViewModelProvider.future);
        final vm = container.read(albumEditorViewModelProvider.notifier);
        final originals = [
          browserPhotoFixture(width: 60, height: 120),
          browserPhotoFixture(width: 60, height: 40),
        ];
        final photos = [
          _photo('crop_target', originals[0], const Size(60, 120)),
          _photo('crop_other', originals[1], const Size(60, 40)),
        ];
        vm.startLocalTemplateAlbum(
          albumTitle: '로컬 구도 확인',
          initialCover: defaultCoverSize,
          templateCanvasSize: _canvas,
          pages: [
            [],
            [
              LayerModel(
                id: _targetId,
                type: LayerType.image,
                position: const Offset(40, 100),
                width: 320,
                height: 240,
                rotation: 8,
                imageBackground: 'archSoft',
                asset: photos[0],
                imageZoom: 1.2,
                imageOffset: const Offset(12, 20),
                opacity: .9,
                zIndex: 1,
              ),
              LayerModel(
                id: _otherId,
                type: LayerType.image,
                position: const Offset(380, 380),
                width: 80,
                height: 80,
                imageBackground: 'round',
                asset: photos[1],
                imageZoom: 1.8,
                imageOffset: const Offset(-8, 12),
                zIndex: 3,
              ),
              LayerModel(
                id: _titleId,
                type: LayerType.text,
                position: const Offset(24, 24),
                width: 452,
                height: 52,
                text: '같은 장면을 오래 기억해요',
                textStyle: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 22,
                  color: Color(0xFF183D36),
                ),
                zIndex: 3,
              ),
              LayerModel(
                id: 'editor_background',
                type: LayerType.decoration,
                position: Offset.zero,
                width: _canvas.width,
                height: _canvas.height,
                decorationFillColor: '#EFECE4',
                zIndex: 99,
              ),
            ],
          ],
        );
        vm.goToPage(1);
        final original = vm.findLayerById(_targetId)!;
        final other = vm.findLayerById(_otherId)!;
        final title = vm.findLayerById(_titleId)!;
        final originalLayers = vm.layers;
        final before = _document(vm);
        final pageId = vm.currentPage!.id;
        final pageCount = vm.pages.length;
        expect(
          container.read(albumEditorViewModelProvider).requireValue.canUndo,
          isFalse,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (_, __) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: SnapFitTheme.light(),
                home: const _Host(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _editAndInspectPage(
          tester,
          vm: vm,
          before: before,
          original: original,
          other: other,
          title: title,
        );
        await tester.tap(find.byKey(const ValueKey('photo-crop-cancel')));
        await tester.pumpAndSettle();
        expect(find.byType(PhotoCropSheet), findsNothing);
        expect(_document(vm), before);
        expect(vm.findLayerById(_targetId), same(original));
        final cancelled = container
            .read(albumEditorViewModelProvider)
            .requireValue;
        expect(cancelled.canUndo, isFalse);
        expect(cancelled.canRedo, isFalse);
        expect(vm.hasUnsavedChanges, isFalse);

        final draft = await _editAndInspectPage(
          tester,
          vm: vm,
          before: before,
          original: original,
          other: other,
          title: title,
        );
        await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
        await tester.pumpAndSettle();
        final applied = vm.findLayerById(_targetId)!;
        expect(applied.imageZoom, draft.imageZoom);
        expect(applied.imageOffset, draft.imageOffset);
        expect(applied.asset, same(photos[0]));
        expect(
          _facts(
            applied.copyWith(
              imageZoom: original.imageZoom,
              imageOffset: original.imageOffset,
            ),
          ),
          _facts(original),
        );
        expect(vm.findLayerById(_otherId), same(other));
        expect(vm.findLayerById(_titleId), same(title));
        expect(_document(vm), [
          for (final layer in originalLayers)
            _facts(layer.id == _targetId ? applied : layer),
        ]);
        expect(
          container.read(albumEditorViewModelProvider).requireValue.canUndo,
          isTrue,
        );
        expect(vm.currentPage!.id, pageId);
        expect(vm.pages.length, pageCount);

        vm.undo();
        await tester.pumpAndSettle();
        expect(_document(vm), before);
        final undone = container
            .read(albumEditorViewModelProvider)
            .requireValue;
        expect(undone.canUndo, isFalse);
        expect(undone.canRedo, isTrue);
        vm.redo();
        await tester.pumpAndSettle();
        expect(_facts(vm.findLayerById(_targetId)!), _facts(applied));
        expect(_facts(vm.findLayerById(_otherId)!), _facts(other));
        expect(_facts(vm.findLayerById(_titleId)!), _facts(title));
        for (var i = 0; i < photos.length; i++) {
          expect(photos[i].originalBytes, orderedEquals(originals[i]));
          expect(
            photos[i].contentSha256,
            sha256.convert(originals[i]).toString(),
          );
        }
        verifyZeroInteractions(repository);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
