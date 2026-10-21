import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/template_design_profile.dart';
import 'package:snap_fit/features/store/presentation/widgets/catalog_edition_artwork.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_design_comparison.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

Widget _host(
  Widget child, {
  List<PointShopProduct> Function()? products,
  Set<String> Function()? owned,
  TextScaler textScaler = TextScaler.noScaling,
  Brightness brightness = Brightness.light,
}) => ProviderScope(
  overrides: [
    publicPointShopCatalogProvider.overrideWith(
      (ref) async => products?.call() ?? [],
    ),
    ownedPointShopKeysProvider.overrideWith((ref) async => owned?.call() ?? {}),
  ],
  child: MaterialApp(
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: child,
  ),
);

void main() {
  final designs = [
    bundledCreationTemplates.first,
    publishedPremiumTemplates.first,
    publishedPremiumTemplates[1],
  ];

  test(
    'selection preserves order and identity without duplicates or a fourth item',
    () {
      const empty = TemplateDesignComparisonSelection.empty();
      final first = empty.add(-9501);
      final full = first.add(-9502).add(-9503);
      expect(empty.ids, isEmpty);
      expect(first.ids, [-9501]);
      expect(full.ids, [-9501, -9502, -9503]);
      expect(
        full.addResult(-9501),
        TemplateDesignComparisonAddResult.alreadySelected,
      );
      expect(
        full.addResult(-9504),
        TemplateDesignComparisonAddResult.limitReached,
      );
      expect(identical(full.add(-9501), full), isTrue);
      expect(identical(full.add(-9504), full), isTrue);
      expect(full.remove(-9502).add(-9504).ids, [-9501, -9503, -9504]);
      expect(full.clear().ids, isEmpty);
      expect(full.ids, [-9501, -9502, -9503]);
      expect(() => full.ids.add(-9504), throwsUnsupportedError);
      expect(TemplateDesignComparisonSelection.fromIds([-1, -1, -2]).ids, [
        -1,
        -2,
      ]);
      expect(
        () => TemplateDesignComparisonSelection.fromIds([1, 2, 3, 4]),
        throwsArgumentError,
      );
    },
  );

  testWidgets(
    'tray waits for two designs and delegates removal and comparison',
    (tester) async {
      PremiumTemplate? removed;
      var compared = 0;
      var cleared = 0;
      await tester.pumpWidget(
        _host(
          Scaffold(
            bottomNavigationBar: TemplateDesignComparisonTray(
              designs: [designs.first],
              onRemove: (design) => removed = design,
              onClear: () => cleared++,
              onCompare: () => compared++,
            ),
          ),
        ),
      );
      var compare = tester.widget<FilledButton>(
        find.byKey(const ValueKey('template-comparison-open')),
      );
      expect(compare.onPressed, isNull);
      expect(find.text('비교할 디자인 1/3'), findsOneWidget);
      await tester.tap(find.byTooltip('${designs.first.title} 비교에서 빼기'));
      expect(removed?.id, designs.first.id);

      await tester.pumpWidget(
        _host(
          Scaffold(
            bottomNavigationBar: TemplateDesignComparisonTray(
              designs: designs.take(2).toList(),
              onRemove: (design) => removed = design,
              onClear: () => cleared++,
              onCompare: () => compared++,
            ),
          ),
        ),
      );
      compare = tester.widget<FilledButton>(
        find.byKey(const ValueKey('template-comparison-open')),
      );
      expect(compare.onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('template-comparison-open')));
      expect(compared, 1);
      await tester.tap(find.byKey(const ValueKey('template-comparison-clear')));
      expect(cleared, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'comparison renders current editable artwork and live prices without purchase',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paid = designs[1];
      var price = 600;
      var ownershipReads = 0;
      late ProviderContainer container;
      PremiumTemplate? opened;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context, listen: false);
              return TemplateDesignComparisonView(
                designs: designs,
                onRemove: (_) {},
                onClear: () {},
                onOpen: (design) => opened = design,
              );
            },
          ),
          products: () => [
            PointShopProduct(
              productKey: pointShopTemplateKey(paid),
              kind: 'template',
              assetId: 'paid',
              title: paid.title,
              pointPrice: price,
              isActive: true,
            ),
          ],
          owned: () {
            ownershipReads++;
            return {};
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CreationCatalogCover), findsNWidgets(3));
      expect(find.byType(CatalogSpreadPreview), findsNWidgets(3));
      expect(find.byType(TemplatePageRenderer), findsNWidgets(9));
      for (final renderer in tester.widgetList<TemplatePageRenderer>(
        find.byType(TemplatePageRenderer),
      )) {
        expect(renderer.imageDecodeWidth, inInclusiveRange(128, 1024));
        expect(renderer.preserveTypography, isTrue);
      }
      for (final design in designs) {
        expect(
          find.byKey(ValueKey('catalog-live-spread-${design.id}')),
          findsOneWidget,
        );
        expect(
          find.text(TemplateDesignProfile.of(design).photoLabel),
          findsWidgets,
        );
      }
      expect(find.text('600P'), findsOneWidget);
      price = 950;
      container.invalidate(publicPointShopCatalogProvider);
      await tester.pumpAndSettle();
      expect(find.text('950P'), findsOneWidget);
      expect(find.text('600P'), findsNothing);
      expect(opened, isNull);
      final open = find.byKey(ValueKey('comparison-open-${paid.id}'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      expect(opened?.id, paid.id);
      expect(ownershipReads, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final configuration in [
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(320, 320), scale: 2.0),
  ]) {
    testWidgets(
      'tray removal exposes an enabled action without a disabled checkbox '
      '${configuration.size} scale=${configuration.scale}',
      (tester) async {
        tester.view.physicalSize = configuration.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          final removed = <int>[];
          await tester.pumpWidget(
            _host(
              Scaffold(
                bottomNavigationBar: TemplateDesignComparisonTray(
                  designs: [designs.first],
                  onRemove: (design) => removed.add(design.id),
                  onClear: () {},
                  onCompare: () {},
                ),
              ),
              textScaler: TextScaler.linear(configuration.scale),
            ),
          );
          await tester.pumpAndSettle();
          final remove = find.byKey(
            ValueKey('comparison-selected-remove-${designs.first.id}'),
          );
          await tester.ensureVisible(remove);
          await tester.pumpAndSettle();
          final target = tester.getSize(remove);
          expect(target.width, greaterThanOrEqualTo(48));
          expect(target.height, greaterThanOrEqualTo(48));

          final node = tester.getSemantics(remove);
          final data = node.getSemanticsData();
          // IconButton exposes its name through the tooltip field. Flutter web
          // combines tooltip and label into the accessible DOM name.
          expect(
            [
              data.tooltip,
              data.label,
            ].where((part) => part.isNotEmpty).join('\n'),
            '${designs.first.title} 비교에서 빼기',
          );
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
          expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
          // A usable child must not inherit aria-disabled from a chip ancestor.
          for (var ancestor = node; ; ancestor = ancestor.parent!) {
            final flags = ancestor.getSemanticsData().flagsCollection;
            expect(flags.isEnabled, isNot(ui.Tristate.isFalse));
            expect(flags.isChecked, ui.CheckedState.none);
            if (ancestor.parent == null) break;
          }
          await tester.tap(find.text(designs.first.title));
          expect(removed, isEmpty);
          node.owner!.performAction(node.id, ui.SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(removed, [designs.first.id]);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'short viewport keeps the enlarged-text tray bounded and all actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var cleared = 0;
      var compared = 0;
      await tester.pumpWidget(
        _host(
          Scaffold(
            body: const Center(child: Text('디자인 목록')),
            bottomNavigationBar: TemplateDesignComparisonTray(
              designs: designs,
              onRemove: (_) {},
              onClear: () => cleared++,
              onCompare: () => compared++,
            ),
          ),
          textScaler: TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('template-comparison-tray')))
            .height,
        lessThanOrEqualTo(135),
      );
      final clear = find.byKey(const ValueKey('template-comparison-clear'));
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      final compare = find.byKey(const ValueKey('template-comparison-open'));
      await tester.ensureVisible(compare);
      await tester.tap(compare);
      expect(cleared, 1);
      expect(compared, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      '320px-high comparison remains scrollable at 200% text in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(360, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        PremiumTemplate? opened;
        await tester.pumpWidget(
          _host(
            TemplateDesignComparisonView(
              designs: designs,
              onRemove: (_) {},
              onClear: () {},
              onOpen: (design) => opened = design,
            ),
            textScaler: TextScaler.linear(2),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final horizontal = tester.widget<SingleChildScrollView>(
          find.byKey(const ValueKey('template-comparison-horizontal-scroll')),
        );
        expect(horizontal.controller!.position.maxScrollExtent, greaterThan(0));
        horizontal.controller!.jumpTo(
          horizontal.controller!.position.maxScrollExtent,
        );
        await tester.pump();
        final target = find.byKey(
          ValueKey('comparison-open-${designs.last.id}'),
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        expect(opened?.id, designs.last.id);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'route reflects remove and clear immediately and Escape returns to catalog',
    (tester) async {
      final removed = <int>[];
      var cleared = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showTemplateDesignComparison(
                  context,
                  designs: designs,
                  onRemove: (design) => removed.add(design.id),
                  onClear: () => cleared++,
                  onOpen: (_) {},
                ),
                child: const Text('비교 열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('비교 열기'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('comparison-remove-${designs.first.id}')),
      );
      await tester.pumpAndSettle();
      expect(removed, [designs.first.id]);
      expect(
        find.byKey(ValueKey('comparison-remove-${designs.first.id}')),
        findsNothing,
      );
      expect(find.byType(CreationCatalogCover), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('comparison-view-clear')));
      await tester.pumpAndSettle();
      expect(cleared, 1);
      expect(find.text('비교할 디자인을 다시 골라 주세요.'), findsOneWidget);
      expect(find.byType(CreationCatalogCover), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateDesignComparisonView), findsNothing);
      expect(find.text('비교 열기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
