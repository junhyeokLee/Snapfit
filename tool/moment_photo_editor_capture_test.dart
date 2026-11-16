// Local visual review only. This opens the real editor with existing generated
// sample pixels and editable layers; it never creates an account or album.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_context_dock.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_editor_canvas.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_album_workspace.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_photo_editor_screen.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';

import '../test/helpers/load_moment_capture_fonts.dart';
import '../test/widget/moment_photo_editor_test.dart'
    show MomentPhotoEditorFixture;

void main() {
  setUpAll(() async {
    await loadMomentCaptureFonts();
    // Native widget tests omit platform font fallback. Reuse this Mac's
    // installed emoji face; no production theme or bundled assets change.
    final emoji = File('/System/Library/Fonts/Apple Color Emoji.ttc');
    if (emoji.existsSync()) {
      final loader = FontLoader('MomentCaptureEmoji')
        ..addFont(Future.value(ByteData.sublistView(emoji.readAsBytesSync())));
      await loader.load();
    }
  });
  for (final web in [false, true]) {
    testWidgets('capture actual shared photo editor web=$web', (tester) async {
      const canvas = Size(500, 625);
      final design = MomentPhotoDesign.fromLayers(
        canvasSize: canvas,
        backgroundColor: Colors.white,
        photoSource: momentPhotoOriginalSource,
        layers: [
          LayerModel(
            id: 'capture-original',
            type: LayerType.image,
            position: Offset.zero,
            width: 500,
            height: 625,
            imageUrl: momentPhotoOriginalSource,
            originalUrl: momentPhotoOriginalSource,
            previewUrl: momentPhotoOriginalSource,
          ),
          LayerModel(
            id: 'capture-sticker',
            type: LayerType.decoration,
            position: const Offset(415, 28),
            width: 46,
            height: 44,
            imageBackground: 'stickerHeartRed',
            zIndex: 1,
          ),
          LayerModel(
            id: 'capture-lettering',
            type: LayerType.text,
            position: const Offset(30, 462),
            width: 440,
            height: 120,
            text: '조금 느리게,\n오늘의 아침',
            zIndex: 2,
            textStyle: const TextStyle(
              fontFamily: 'NotoSans',
              fontSize: 30,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      );
      final boundary = GlobalKey();
      final fixture = MomentPhotoEditorFixture(
        upload: MomentUpload(
          id: 'capture-cafe',
          filename: 'cafe.png',
          design: design,
          bytes: File(
            'output/social-samples-20261103/images/01-cafe-morning.png',
          ).readAsBytesSync(),
        ),
      );
      final base = SnapFitTheme.light();
      await fixture.mount(
        tester,
        captureKey: boundary,
        size: web ? const Size(1280, 900) : const Size(390, 844),
        useWebWorkspace: web,
        theme: base.copyWith(
          textTheme: base.textTheme.apply(
            fontFamilyFallback: const ['MomentCaptureEmoji'],
          ),
        ),
      );
      await fixture.open(tester);
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Future<void> capture(String suffix) => tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'output/moment-photo-editor-20261103/editor-shared-${web ? 'web' : 'native'}$suffix-v2.png',
          );
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(
            png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          );
        } finally {
          image.dispose();
        }
      });
      await capture('');
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(MomentPhotoEditorScreen)),
      );
      final original = scope
          .read(albumEditorViewModelProvider.notifier)
          .layers
          .first;
      if (web) {
        final workspace = tester.widget<WebAlbumEditorWorkspace>(
          find.byType(WebAlbumEditorWorkspace),
        );
        final canvas = find.descendant(
          of: find.byWidget(workspace.canvas),
          matching: find.byType(PageEditorCanvas),
        );
        tester
            .widget<PageEditorCanvas>(canvas)
            .interaction
            .setSelectedLayer(original.id);
      } else {
        tester
            .widget<EditorContextDock>(find.byType(EditorContextDock))
            .interaction
            .setSelectedLayer(original.id);
      }
      await tester.pumpAndSettle();
      await capture('-photo-tools');
      if (web) {
        tester
            .widget<WebAlbumEditorWorkspace>(
              find.byType(WebAlbumEditorWorkspace),
            )
            .onSave();
      } else {
        await tester.tap(
          find.byKey(const ValueKey('moment-photo-design-apply')),
        );
      }
      await tester.pumpAndSettle();
      expect(await fixture.result!, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
