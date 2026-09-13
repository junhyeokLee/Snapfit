import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../widget/ai_album_start_step_test.dart' show wrapCreation;

void main() {
  testWidgets('cover remount reuses parsed layers, display DPR bounds decode', (
    tester,
  ) async {
    final template = bundledCreationTemplates.first;
    Future<void> mount(String key) async {
      await tester.pumpWidget(
        wrapCreation(
          Center(
            child: SizedBox(
              width: 120,
              height: 160,
              child: CreationCatalogCover(
                previewDecode: true,
                key: ValueKey(key),
                template: template,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mount('first');
    final first = tester.widget<TemplatePageRenderer>(
      find.byType(TemplatePageRenderer),
    );
    await mount('second');
    final second = tester.widget<TemplatePageRenderer>(
      find.byType(TemplatePageRenderer),
    );
    expect(identical(first.layers, second.layers), isTrue);
    expect(second.imageDecodeWidth, isNotNull);
    expect(
      second.imageDecodeWidth!,
      lessThanOrEqualTo((160 * tester.view.devicePixelRatio).ceil()),
    );
    expect(tester.takeException(), isNull);
  });
}
