import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/shared/widgets/studio_word_art_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../widget/ai_album_start_step_test.dart' show wrapCreation;

void main() {
  testWidgets(
    'list material decode follows display width DPR, editor remains original',
    (tester) async {
      final spec = studioDecorations.firstWhere((s) => s.assetPath != null);
      await tester.pumpWidget(
        wrapCreation(
          Center(
            child: SizedBox(
              width: 80,
              height: 100,
              child: StudioDecoration(spec: spec, preview: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image).first);
      expect(image.image, isA<ResizeImage>());
      final png = await rootBundle.load(spec.assetPath!);
      debugPrint(
        'BUDGET material_source_width=${png.getUint32(16)} requested_decode_width=${(image.image as ResizeImage).width}',
      );
      expect(
        (image.image as ResizeImage).width,
        (80 * tester.view.devicePixelRatio).ceil(),
      );
      await tester.pumpWidget(
        wrapCreation(
          Center(
            child: SizedBox(
              width: 80,
              height: 100,
              child: StudioDecoration(spec: spec),
            ),
          ),
        ),
      );
      expect(
        tester.widget<Image>(find.byType(Image).first).image,
        isA<AssetImage>(),
      );
    },
  );
  testWidgets('word art remount shares immutable preview model', (
    tester,
  ) async {
    Future<void> mount(String key) async {
      await tester.pumpWidget(
        wrapCreation(
          Center(
            child: SizedBox(
              width: 120,
              height: 100,
              child: StudioWordArtPreview(
                key: ValueKey(key),
                art: studioWordArts.first,
              ),
            ),
          ),
        ),
      );
    }

    await mount('one');
    final layers = tester
        .widget<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
        .layers;
    await mount('two');
    expect(
      identical(
        layers,
        tester
            .widget<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
            .layers,
      ),
      isTrue,
    );
  });
}
