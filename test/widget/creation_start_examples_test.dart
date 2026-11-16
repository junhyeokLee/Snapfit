import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

Finder _action(String method) => find.byKey(
  ValueKey(
    method == 'manual' ? 'creation-manual-start' : 'creation-open-catalog',
  ),
);

void main() {
  setUpAll(() async {
    if (!kIsWeb) await loadCreationFonts();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('two creation routes explain and activate their own next step', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    var manual = 0;
    await tester.pumpWidget(
      wrapCreation(AiAlbumStartStep(onManualStart: () => manual++)),
    );
    await tester.pumpAndSettle();
    expect(find.text('직접 만들기'), findsOneWidget);
    expect(find.text('디자인으로 시작'), findsOneWidget);
    expect(
      tester.getSize(_action('manual')).height,
      tester.getSize(_action('template')).height,
    );
    await tester.tap(_action('manual'));
    expect(manual, 1);
    await tester.tap(_action('template'));
    await tester.pumpAndSettle();
    expect(find.text('사용할 수 있는 디자인이 아직 없어요.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('creation-category-rail')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('creation routes retain keyboard activation', (tester) async {
    viewport(tester, const Size(1024, 768));
    var manual = 0;
    await tester.pumpWidget(
      wrapCreation(AiAlbumStartStep(onManualStart: () => manual++)),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(manual, 1);
    expect(tester.takeException(), isNull);
  });

  for (final config in [
    (size: const Size(320, 568), scale: 1.8, dark: false),
    (size: const Size(390, 844), scale: 2.4, dark: true),
    (size: const Size(648, 320), scale: 1.8, dark: false),
    (size: const Size(844, 390), scale: 1.8, dark: true),
    (size: const Size(1440, 900), scale: 1.8, dark: false),
  ]) {
    testWidgets(
      'entry and catalogue fit ${config.size} at ${config.scale} dark=${config.dark}',
      (tester) async {
        viewport(tester, config.size);
        await tester.pumpWidget(
          wrapCreation(
            AiAlbumStartStep(onManualStart: () {}),
            textScale: config.scale,
            dark: config.dark,
          ),
        );
        await tester.pumpAndSettle();
        for (final method in ['manual', 'template']) {
          await tester.ensureVisible(_action(method));
          await tester.pumpAndSettle();
          final bounds = tester.getRect(_action(method));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(config.size.width));
          expect(tester.takeException(), isNull, reason: method);
        }
        await tester.tap(_action('template'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('creation-price-무료')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('returning to methods preserves catalogue filter choices', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    var manual = 0;
    await tester.pumpWidget(
      wrapCreation(AiAlbumStartStep(onManualStart: () => manual++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(_action('template'));
    await tester.pumpAndSettle();
    final free = find.byKey(const ValueKey('creation-price-무료'));
    await tester.ensureVisible(free);
    await tester.tap(free);
    await tester.pumpAndSettle();
    final back = find.byKey(const ValueKey('creation-catalog-back'));
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();
    await tester.tap(_action('manual'));
    expect(manual, 1);
    await tester.tap(_action('template'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Semantics>(
            find.descendant(of: free, matching: find.byType(Semantics)),
          )
          .any((w) => w.properties.selected == true),
      isTrue,
    );
  });
}
