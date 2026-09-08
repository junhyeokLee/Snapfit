import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/design_templates.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_phrase_catalog.dart';
import 'package:snap_fit/features/album/presentation/providers/design_template_catalog_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_sticker_tab.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/design_template_panel.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/studio_phrase_picker.dart';

import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;

class _Editor extends AlbumEditorViewModel {
  _Editor(this.applied);
  final List<String> applied;

  @override
  AlbumEditorState build() => const AlbumEditorState();

  @override
  void applyDesignTemplateToCurrentPage(
    DesignTemplate template,
    Size canvasSize,
  ) {
    applied.add(template.id);
  }
}

void main() {
  late CatalogFavorites previous;
  setUpAll(loadCreationFonts);
  setUp(() async {
    previous = CatalogFavorites.instance;
    CatalogFavorites.instance = CatalogFavorites(
      storage: MemoryFavoritesStorage(),
    );
    await CatalogFavorites.instance.load();
  });
  tearDown(() {
    CatalogFavorites.instance.dispose();
    CatalogFavorites.instance = previous;
  });

  for (final kind in ['sticker', 'phrase', 'frame', 'template']) {
    testWidgets(
      '$kind previews stay free; cancel, duplicate taps and disposal never apply',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final decoration = studioDecorations.first;
        final phrase = studioPhrases.first;
        final applied = <String>[];
        final requests = <String>[];
        final template = DesignTemplate(
          id: 'lightbound',
          name: '테스트 디자인',
          category: '웨딩',
          buildLayers: (_) => [],
        );
        var approval = Completer<bool>();
        final String id, label, value;
        final Widget picker;
        switch (kind) {
          case 'sticker':
            id = decoration.id;
            label = decoration.label;
            value = decoration.insertionValue;
            picker = DecorateStickerTab(
              surfaceColor: Colors.white,
              onStickerTap: applied.add,
            );
          case 'phrase':
            id = phrase.id;
            label = phrase.text;
            value = phrase.id;
            picker = StudioPhrasePicker(onSelect: (p) => applied.add(p.id));
          case 'frame':
            id = 'zineContact';
            label = '필름 콘택트';
            value = id;
            picker = ImageFrameStylePicker(
              selectedKey: null,
              onSelect: applied.add,
              photoBuilder: (_) => const ColoredBox(color: Colors.blue),
            );
          default:
            id = template.id;
            label = template.name;
            value = id;
            picker = ProviderScope(
              overrides: [
                albumEditorViewModelProvider.overrideWith(
                  () => _Editor(applied),
                ),
                designTemplateCatalogProvider.overrideWith(
                  (ref) async => [template],
                ),
              ],
              child: const DesignTemplatePanel(closeOnApply: false),
            );
        }
        final productKey = '$kind:$id';
        await tester.pumpWidget(
          wrapCreation(
            picker,
            shopProducts: [
              PointShopProduct(
                productKey: productKey,
                kind: kind,
                assetId: id,
                title: label,
                pointPrice: 120,
                isActive: true,
              ),
            ],
            pointShopGate:
                (context, ref, {required productKey, required title}) {
                  requests.add(productKey);
                  return approval.future;
                },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        expect(find.text('120P'), findsOneWidget);
        expect(requests, isEmpty);
        expect(applied, isEmpty);
        await tester.tap(find.byType(CatalogFavoriteButton).first);
        await tester.pumpAndSettle();
        expect(requests, isEmpty);
        expect(applied, isEmpty);

        await tester.tap(find.text(label));
        await tester.tap(find.text(label));
        await tester.pump();
        expect(requests, [productKey]);
        expect(applied, isEmpty);
        approval.complete(false);
        await tester.pumpAndSettle();
        expect(applied, isEmpty);

        approval = Completer<bool>();
        await tester.tap(find.text(label));
        expect(requests, [productKey, productKey]);
        approval.complete(true);
        await tester.pumpAndSettle();
        expect(applied, [value]);

        approval = Completer<bool>();
        await tester.tap(find.text(label));
        await tester.pumpWidget(const SizedBox());
        approval.complete(true);
        await tester.pumpAndSettle();
        expect(applied, [value]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('removing a frame stays free and never calls the purchase gate', (
    tester,
  ) async {
    var gateCalls = 0;
    final selected = <String>[];
    await tester.pumpWidget(
      wrapCreation(
        ImageFrameStylePicker(
          selectedKey: 'studyArchWindow',
          onSelect: selected.add,
          photoBuilder: (_) => const ColoredBox(color: Colors.blue),
        ),
        pointShopGate:
            (context, ref, {required productKey, required title}) async {
              gateCalls++;
              return false;
            },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('기본'));
    await tester.pumpAndSettle();
    expect(selected, ['']);
    expect(gateCalls, 0);
  });
}
