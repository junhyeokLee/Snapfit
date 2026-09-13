import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/templates/studio_phrase_catalog.dart';
import 'package:snap_fit/core/templates/template_catalog_categories.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';
import 'package:snap_fit/shared/widgets/studio_phrase_picker.dart';
import 'package:snap_fit/shared/widgets/edit_text_overlay.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/tool_button.dart';
import '../../tool/template_studio/atelier_preview.dart';
import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;
import 'studio_decorations_test.dart' show capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCreationFonts();
    await (FontLoader(
      'Eulyoo',
    )..addFont(rootBundle.load('assets/fonts/Eulyoo1945-Regular.ttf'))).load();
  });

  test(
    'six additive frames, eight original assets, four phrases per topic',
    () {
      expect(atelierPhotoFrames.length, 6);
      expect(studioPhotoFrames, containsAll(newStudioPhotoFrames));
      expect(atelierDecorations.length, 8);
      expect(
        studioDecorations.map((s) => s.id).toSet().length,
        studioDecorations.length,
      );
      expect(studioPhrases.length, 28);
      expect(studioPhrases.map((p) => p.id).toSet().length, 28);
      expect(studioPhrases.map((p) => p.text).toSet().length, 28);
      for (final topic in templateTopicOrder) {
        expect(studioPhrases.where((p) => p.category == topic).length, 4);
      }
    },
  );

  for (final aspect in CollectionAspect.values) {
    test(
      '${aspect.name}: new frame paths and insets scale with saved geometry',
      () {
        for (final key in atelierPhotoFrames) {
          final size = aspect.canvas;
          final path = StudioMaterialClipper(key).getClip(size);
          final large = StudioMaterialClipper(key).getClip(size * 2);
          final bounds = path.getBounds();
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(size.width));
          expect(bounds.bottom, lessThanOrEqualTo(size.height));
          expect(path.contains(size.center(Offset.zero)), isTrue);
          for (var x = 0; x < 32; x++) {
            for (var y = 0; y < 32; y++) {
              final p = Offset(size.width * x / 32, size.height * y / 32);
              expect(path.contains(p), large.contains(p * 2));
            }
          }
          final inset = StudioMaterial.photoInsets(
            key,
            size,
          ).deflateRect(Offset.zero & size);
          expect(inset.width, greaterThan(size.width * .75));
          expect(inset.height, greaterThan(size.height * .75));
        }
      },
    );

    test(
      '${aspect.name}: editable phrase insertion, undo, redo and save retain typography',
      () async {
        final container = ProviderContainer(
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
        );
        addTearDown(container.dispose);
        await container.read(albumEditorViewModelProvider.future);
        final vm = container.read(albumEditorViewModelProvider.notifier);
        for (final phrase in studioPhrases) {
          vm.resetForCreate(initialCover: aspect.cover, targetPages: 2);
          vm.updatePageLayers([], recordHistory: false);
          vm.addTextLayer(
            phrase.text,
            style: phrase.lettering.style,
            mode: TextStyleType.none,
            canvasSize: aspect.canvas,
            textAlign: phrase.alignment,
          );
          final layer = vm.pages.first.layers.single;
          expect(layer.width, lessThan(aspect.canvas.width));
          expect(layer.height, lessThan(aspect.canvas.height));
          vm.undo();
          expect(vm.pages.first.layers, isEmpty);
          vm.redo();
          final saved = LayerExportMapper.fromJson(
            LayerExportMapper.toJson(
              vm.pages.first.layers.single,
              canvasSize: aspect.canvas,
            ),
            canvasSize: aspect.canvas,
          );
          expect(saved.type, LayerType.text);
          expect(saved.text, phrase.text);
          expect(saved.textStyle!.fontFamily, phrase.lettering.font);
          expect(saved.textStyle!.height, phrase.lettering.leading);
          expect(saved.textAlign, phrase.alignment);
          vm.updateLayer(saved.copyWith(text: '직접 고친 문구'));
          expect(vm.pages.first.layers.single.text, '직접 고친 문구');
        }
      },
    );

    for (var set = 0; set < atelierSets.length; set++) {
      testWidgets(
        '${atelierSets[set].name} ${aspect.name}: native composition renders and fits',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1100, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final style = atelierSets[set];
          final layers = atelierPreviewLayers(
            set: set,
            aspect: aspect,
            frame: style.frame,
            phrase: studioPhrases.singleWhere((p) => p.id == style.phrase),
            photo: style.photo,
          );
          for (final layer in layers) {
            expect(layer.position.dx, greaterThanOrEqualTo(0));
            expect(layer.position.dy, greaterThanOrEqualTo(0));
            expect(
              layer.position.dx + layer.width,
              lessThanOrEqualTo(aspect.canvas.width),
            );
            expect(
              layer.position.dy + layer.height,
              lessThanOrEqualTo(aspect.canvas.height),
            );
            if (layer.type == LayerType.text) {
              final painter = TextPainter(
                text: TextSpan(text: layer.text, style: layer.textStyle),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: layer.width);
              expect(painter.height, lessThanOrEqualTo(layer.height));
              painter.dispose();
            }
          }
          final image = await capture(
            tester,
            ColoredBox(
              color: const Color(0xFFFCFCFA),
              child: TemplatePageRenderer(
                layers: layers,
                width: aspect.canvas.width,
                height: aspect.canvas.height,
                designCanvasSize: aspect.canvas,
              ),
            ),
          );
          final bytes = await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.png),
          );
          if (const bool.fromEnvironment('EXPORT_ATELIER')) {
            await tester.runAsync(() async {
              final file = File(
                'output/template-preview/atelier/set-$set-${aspect.name}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
            });
          }
          image.dispose();
        },
      );
    }
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('$size: phrase picker is scrollable and applies every topic', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      StudioPhrase? selected;
      await tester.pumpWidget(
        wrapCreation(
          StudioPhrasePicker(onSelect: (value) => selected = value),
          textScale: 1.4,
        ),
      );
      for (final topic in templateTopicOrder) {
        final chip = find.widgetWithText(ChoiceChip, topic);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        final first = studioPhrases.firstWhere((p) => p.category == topic);
        await tester.tap(find.text(first.text));
        expect(selected, same(first));
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final viewport in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets(
      '$viewport: text tool applies phrase and remains editable after returning from picker',
      (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        String? submitted;
        TextStyle? submittedStyle;
        await tester.pumpWidget(
          wrapCreation(
            EditTextOverlay(
              initialText: '',
              initialStyle: const TextStyle(fontSize: 20),
              onCancel: () {},
              onSubmit: (text, style, mode, color, align) {
                submitted = text;
                submittedStyle = style;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final element in find.byType(ToolButton).evaluate()) {
          final size = tester.getSize(find.byWidget(element.widget));
          expect(size.height, greaterThanOrEqualTo(44));
          expect(size.width, greaterThanOrEqualTo(48));
        }
        if (viewport.height > 600) {
          tester.view.viewInsets = FakeViewPadding(
            bottom: 220 * tester.view.devicePixelRatio,
          );
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const ValueKey('studio-phrase-tool')));
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        await tester.tap(find.text(studioPhrases.first.text));
        await tester.pumpAndSettle();
        expect(find.byType(EditTextOverlay), findsOneWidget);
        await tester.enterText(find.byType(EditableText), '우리가 직접 쓴 문장');
        await tester.tap(find.text('완료'));
        expect(submitted, '우리가 직접 쓴 문장');
        expect(submittedStyle!.fontFamily, 'Eulyoo');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
