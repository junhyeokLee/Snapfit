import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/album/presentation/controllers/editor_canvas_coordinates.dart';
import 'package:snap_fit/features/album/presentation/controllers/toolbar_action_handler.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'page_editor_screen_golden_test.dart'
    show MockAlbumRepository, FakeStorageService, FakeAlbumPersistenceService;

class _Photo extends Mock implements AssetEntity {}

class _Boot extends ConsumerStatefulWidget {
  const _Boot({required this.displaySize, required this.photo});
  final Size displaySize;
  final AssetEntity photo;
  @override
  ConsumerState<_Boot> createState() => _BootState();
}

class _BootState extends ConsumerState<_Boot> {
  var ready = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(albumEditorViewModelProvider.future);
      if (!mounted) return;
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      vm.startLocalTemplateAlbum(
        albumTitle: 'reference canvas',
        initialCover: defaultCoverSize,
        pages: [const [], const []],
      );
      vm.goToPage(1);
      setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ready
        ? TextButton(
            onPressed: () => ToolbarActionHandler(
              context,
              ref,
              selectPhoto: (_, _) async => widget.photo,
              selectTemplate: (_) async => 'free',
            ).addPhoto(widget.displaySize),
            child: const Text('insert original ratio photo'),
          )
        : const SizedBox(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final display in [const Size(770, 770), const Size(330, 330)]) {
    testWidgets(
      'photo inserted from $display stays in saved and print 500 canvas',
      (tester) async {
        final photo = _Photo();
        when(() => photo.id).thenReturn('reference-photo');
        when(() => photo.width).thenReturn(1800);
        when(() => photo.height).thenReturn(1400);
        when(() => photo.orientation).thenReturn(0);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
              albumEditorServiceProvider.overrideWithValue(
                const AlbumEditorService(),
              ),
              albumPersistenceServiceProvider.overrideWithValue(
                FakeAlbumPersistenceService(),
              ),
              storageServiceProvider.overrideWithValue(FakeStorageService()),
            ],
            child: MaterialApp(
              home: _Boot(displaySize: display, photo: photo),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('insert original ratio photo'));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(_Boot)),
        );
        final vm = container.read(albumEditorViewModelProvider.notifier);
        final layer = vm.currentPage!.layers.single;
        expect(layer.width, closeTo(400, .001));
        expect(layer.width / layer.height, closeTo(1800 / 1400, .00001));
        expect(layer.position.dx, greaterThanOrEqualTo(0));
        expect(layer.position.dy, greaterThanOrEqualTo(0));
        expect(layer.position.dx + layer.width, lessThanOrEqualTo(500));
        expect(layer.position.dy + layer.height, lessThanOrEqualTo(500));

        final exported = jsonDecode(vm.exportFullAlbumLayersJson(null)) as Map;
        final raw =
            ((exported['pages'] as List)[1]['layers'] as List).single as Map;
        expect((raw['x'] as num) + (raw['width'] as num), lessThanOrEqualTo(1));
        expect(
          (raw['y'] as num) + (raw['height'] as num),
          lessThanOrEqualTo(1),
        );
        final document = PrintAlbumDocument.fromSnapshot({
          'album': {
            'id': 69,
            'title': 'reference canvas',
            'ratio': '1',
            'cover_theme': 'classic',
            'cover_layers_json': exported,
          },
          'pages': const [],
        });
        final printed = document.interiors.first.layers.single;
        expect(document.interiors.first.canvasSize, const Size(500, 500));
        expect(printed.position.dx, closeTo(layer.position.dx, .00001));
        expect(printed.position.dy, closeTo(layer.position.dy, .00001));
        expect(printed.width, closeTo(layer.width, .00001));
        expect(printed.height, closeTo(layer.height, .00001));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test(
    'photo and text insertion use each album ratio with the same 500 reference',
    () async {
      final photo = _Photo();
      when(() => photo.id).thenReturn('reference-photo');
      when(() => photo.width).thenReturn(1800);
      when(() => photo.height).thenReturn(1400);
      when(() => photo.orientation).thenReturn(0);
      const service = AlbumEditorService();
      for (final cover in coverSizes) {
        final canvas = editorReferenceCanvasSize(cover);
        expect(canvas.width, 500);
        expect(canvas.width / canvas.height, closeTo(cover.ratio, .00001));
        final image = await service.createImageLayer(
          asset: photo,
          canvasSize: canvas,
          templateKey: 'free',
        );
        final text = service.createTextLayer(
          text: '앨범 제목',
          style: const TextStyle(fontSize: 16),
          mode: TextStyleType.none,
          canvasSize: canvas,
        );
        for (final layer in [image, text]) {
          expect(layer.position.dx, greaterThanOrEqualTo(0));
          expect(layer.position.dy, greaterThanOrEqualTo(0));
          expect(
            layer.position.dx + layer.width,
            lessThanOrEqualTo(canvas.width),
          );
          expect(
            layer.position.dy + layer.height,
            lessThanOrEqualTo(canvas.height),
          );
        }
      }
    },
  );
}
