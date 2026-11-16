import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_photo_fill_draft.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_photo_fill_screen.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

const _ownerId = 'workspace-owner';
const _productKey = 'template:-9531';
const _canvas = Size(500, 375);
const _backgrounds = [0xFFFFF5E8, 0xFFE9F5EE, 0xFFEDF1FA];

class _Owner {
  String? value = _ownerId;
}

class _Photo extends Mock implements AssetEntity {}

AssetEntity _photo(String id) {
  final photo = _Photo();
  when(() => photo.id).thenReturn(id);
  when(() => photo.width).thenReturn(800);
  when(() => photo.height).thenReturn(600);
  when(() => photo.orientation).thenReturn(0);
  when(() => photo.file).thenAnswer((_) async => null);
  when(
    () => photo.thumbnailDataWithSize(const ThumbnailSize.square(150)),
  ).thenAnswer((_) async => null);
  return photo;
}

String _document() => jsonEncode({
  'printProduct': {
    'id': 'REDP_200X150_HARD',
    'trimWidthMm': 200,
    'trimHeightMm': 150,
  },
  'sourceTemplate': {'productKey': _productKey},
  'pages': [
    for (var page = 0; page < 3; page++)
      {
        'index': page,
        'isCover': page == 0,
        'backgroundColor': _backgrounds[page],
        'layers': [
          for (final layer in [
            LayerModel(
              id: 'photo-$page',
              type: LayerType.image,
              position: const Offset(24, 24),
              width: 210,
              height: 240,
              imageBackground: 'polaroid',
            ),
            LayerModel(
              id: 'caption-$page',
              type: LayerType.text,
              position: const Offset(250, 48),
              width: 210,
              height: 60,
              text: '원래 기록 $page',
              textStyle: const TextStyle(fontSize: 14),
            ),
          ])
            LayerExportMapper.toJson(
              layer,
              canvasSize: _canvas,
              isCover: page == 0,
            ),
        ],
      },
  ],
});

Future<({ProviderContainer container, AlbumEditorViewModel vm, _Owner owner})>
_boot() async {
  final owner = _Owner();
  final container = ProviderContainer(
    overrides: [
      albumEditorOwnerReaderProvider.overrideWithValue(() => owner.value),
      albumEditorOwnerChangesProvider.overrideWith((_) => const Stream.empty()),
      albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(albumEditorViewModelProvider.future);
  final vm = container.read(albumEditorViewModelProvider.notifier);
  await vm.prepareAlbumForEdit(
    Album(
      id: 17,
      userId: _ownerId,
      memberRole: 'OWNER',
      title: '사진 작업본 원본',
      ratio: '${4 / 3}',
      targetPages: 2,
      coverLayersJson: _document(),
      updatedAt: '2026-11-11T00:00:00Z',
    ),
  );
  vm.loadPendingEditAlbumIfNeeded(_canvas);
  return (container: container, vm: vm, owner: owner);
}

Future<void> _mount(
  WidgetTester tester,
  ProviderContainer container,
  AlbumPhotoFillDraft draft, {
  TemplatePhotoFillSession? initialSession,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('원본 편집기')),
      ),
    ),
  );
  unawaited(
    navigator.currentState!.push<EditorPhotoFillResult>(
      MaterialPageRoute(
        builder: (_) =>
            EditorPhotoFillScreen(draft: draft, initialSession: initialSession),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectMetadata(AlbumEditorViewModel vm) {
  final document = jsonDecode(vm.exportFullAlbumLayersJson(null)) as Map;
  expect(vm.pages, hasLength(3));
  expect(vm.pages.map((page) => page.backgroundColor), _backgrounds);
  expect(document['sourceTemplate'], {'productKey': _productKey});
  expect(document['printProduct'], {
    'id': 'REDP_200X150_HARD',
    'trimWidthMm': 200,
    'trimHeightMm': 150,
  });
}

void main() {
  testWidgets('workspace passes the editor photo and canvas contracts', (
    tester,
  ) async {
    final fixture = await _boot();
    final before = fixture.vm.exportFullAlbumLayersJson(null);
    final draft = fixture.vm.beginPhotoFill()!;
    await _mount(tester, fixture.container, draft);

    final step = tester.widget<TemplatePhotoFillStep>(
      find.byType(TemplatePhotoFillStep),
    );
    expect(
      find.byKey(const ValueKey('editor-photo-fill-owned-navigation')),
      findsOneWidget,
    );
    expect(step.continueLabel, '편집기에 적용');
    expect(step.currentOwner!(), _ownerId);
    expect(step.canvasSize, _canvas);
    expect(step.enableAutoFill, isTrue);
    expect(step.preserveTypography, isTrue);
    expect(step.pages, hasLength(3));
    expect(step.cover.productId, 'REDP_200X150_HARD');
    for (var page = 0; page < _backgrounds.length; page++) {
      final renderer = find.descendant(
        of: find.byKey(const ValueKey('photo-fill-page-rail')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is TemplatePageRenderer &&
              widget.showCanvasChrome &&
              widget.layers.any((layer) => layer.id == 'photo-$page'),
        ),
      );
      expect(renderer, findsOneWidget);
      final children = <Element>[];
      tester.element(renderer).visitChildElements(children.add);
      expect(children, hasLength(1));
      final paper = children.single.widget;
      expect(paper, isA<Container>());
      // Check the rendered paper itself, rather than a new optional API value.
      final decoration = (paper as Container).decoration! as BoxDecoration;
      expect(decoration.color, Color(_backgrounds[page]));
    }
    expect(fixture.vm.exportFullAlbumLayersJson(null), before);
    _expectMetadata(fixture.vm);
    expect(tester.takeException(), isNull);
  });

  for (final invalidation in ['owner', 'document']) {
    testWidgets('a stale $invalidation removes every owned photo route', (
      tester,
    ) async {
      final fixture = await _boot();
      final draft = fixture.vm.beginPhotoFill()!;
      await _mount(tester, fixture.container, draft);
      final stepFinder = find.byType(TemplatePhotoFillStep);
      final originalStep = tester.widget<TemplatePhotoFillStep>(stepFinder);
      final toolsNavigator = Navigator.of(tester.element(stepFinder));
      final outerNavigator = Navigator.of(
        tester.element(find.byType(EditorPhotoFillScreen)),
      );
      expect(identical(toolsNavigator, outerNavigator), isFalse);

      // A gallery can open a crop sheet on top; both belong to the workspace.
      unawaited(
        toolsNavigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('이전 계정 사진')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(find.text('이전 계정 사진')),
          builder: (_) => const SizedBox(
            height: 180,
            child: Center(child: Text('이전 계정 사진 구도')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('이전 계정 사진 구도'), findsOneWidget);

      if (invalidation == 'owner') {
        fixture.owner.value = 'different-owner';
        fixture.vm.resetForCreate();
      } else {
        fixture.vm.updatePageLayers([
          fixture.vm.layers.first,
          fixture.vm.layers.last.copyWith(text: '선택 도중 외부에서 변경한 기록'),
        ]);
      }
      final afterInvalidation = fixture.vm.exportFullAlbumLayersJson(null);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('editor-photo-fill-owned-navigation')),
        findsNothing,
      );
      expect(find.byType(TemplatePhotoFillStep), findsNothing);
      expect(find.text('이전 계정 사진', skipOffstage: false), findsNothing);
      expect(find.text('이전 계정 사진 구도', skipOffstage: false), findsNothing);
      expect(find.text('앨범이나 계정이 변경됐어요. 사진 도구를 닫고 다시 열어주세요.'), findsOneWidget);
      expect(fixture.vm.isPhotoFillCurrent(draft), isFalse);

      // A picker that finishes after its route disappears cannot publish or apply.
      originalStep.onChanged([
        for (final page in draft.pages) List<LayerModel>.of(page),
      ]);
      originalStep.onContinue();
      await tester.pump();
      expect(fixture.vm.exportFullAlbumLayersJson(null), afterInvalidation);
      expect(find.byType(EditorPhotoFillScreen), findsOneWidget);
      if (invalidation == 'document') _expectMetadata(fixture.vm);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancel keeps the original document and inherited queue intact', (
    tester,
  ) async {
    final fixture = await _boot();
    final before = fixture.vm.exportFullAlbumLayersJson(null);
    final first = _photo('pending-first');
    final second = _photo('pending-second');
    final replacement = _photo('workspace-only');
    final initial = TemplatePhotoFillSession()
      ..pendingPhotos.addAll([first, second])
      ..selectedPhoto = first
      ..page = 2;
    final draft = fixture.vm.beginPhotoFill()!;
    await _mount(tester, fixture.container, draft, initialSession: initial);
    final step = tester.widget<TemplatePhotoFillStep>(
      find.byType(TemplatePhotoFillStep),
    );
    final session = step.session!;
    expect(session, isNot(same(initial)));
    session.pendingPhotos
      ..remove(first)
      ..add(replacement);
    session.selectedPhoto = replacement;
    session.page = 1;
    final staged = [for (final page in step.pages) List<LayerModel>.of(page)];
    staged[0][0] = staged[0][0].copyWith(
      imageZoom: 1.7,
      imageOffset: const Offset(12, -8),
    );
    step.onChanged(staged);
    await tester.pumpAndSettle();
    expect(fixture.vm.exportFullAlbumLayersJson(null), before);

    await tester.tap(find.byKey(const ValueKey('editor-photo-fill-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('원본 편집기'), findsOneWidget);
    expect(find.byType(EditorPhotoFillScreen), findsNothing);
    expect(initial.pendingPhotos, [first, second]);
    expect(initial.selectedPhoto, same(first));
    expect(initial.page, 2);
    expect(fixture.vm.exportFullAlbumLayersJson(null), before);
    expect(
      fixture.container.read(albumEditorViewModelProvider).requireValue.canUndo,
      isFalse,
    );
    expect(fixture.vm.isPhotoFillCurrent(draft), isTrue);
    _expectMetadata(fixture.vm);
    expect(tester.takeException(), isNull);
  });
}
