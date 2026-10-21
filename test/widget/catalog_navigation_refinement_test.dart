import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'experience_detail_redesign_test.dart' show reviewApp;
import '../support/store_catalog_navigation.dart';

void main() {
  setUpAll(loadCreationFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets(
    'large store header fits and library command preserves the catalog',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var destination = -1;
      await tester.pumpWidget(
        reviewApp(
          ExperienceNavigationScope(
            onNavigate: (index) => destination = index,
            onBack: () {},
            child: const MediaQuery(
              data: MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: StoreHubScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text('스토어'), matching: find.byType(RichText)),
      );
      expect(title.didExceedMaxLines, isFalse);
      await selectStoreCatalog(tester, 2);
      expect(destination, 6);
      expect(
        find.byType(MaterialCatalogScreen, skipOffstage: false),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final page in [
    const MyPageScreen(),
    const MaterialCatalogScreen(library: true),
  ]) {
    testWidgets(
      '${page.runtimeType} root destination has no back, pushed destination does',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          reviewApp(
            ExperienceNavigationScope(
              onNavigate: (_) {},
              onBack: () {},
              child: page,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('뒤로가기'), findsNothing);
        expect(
          tester.widget<ExperienceHeader>(find.byType(ExperienceHeader)).back,
          isFalse,
        );
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(find.byTooltip('뒤로가기'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          reviewApp(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => page)),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('뒤로가기'), findsOneWidget);
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        expect(find.text('열기'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
