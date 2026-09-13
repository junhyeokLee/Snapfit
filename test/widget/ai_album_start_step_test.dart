import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

// Artwork and layout tests use a controlled free catalog, never a live shop.
Widget wrapCreation(
  Widget child, {
  bool dark = false,
  double textScale = 1,
  PointShopAccessGate? pointShopGate,
  List<PointShopProduct> shopProducts = const [],
}) => ProviderScope(
  overrides: [
    pointShopCatalogProvider.overrideWith((ref) async => shopProducts),
    ownedPointShopKeysProvider.overrideWith((ref) async => <String>{}),
    pointShopAccessGateProvider.overrideWithValue(
      pointShopGate ??
          (context, ref, {required productKey, required title}) async => true,
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('앨범 만들기')),
        body: child,
      ),
    ),
  ),
);

Future<void> loadCreationFonts() async {
  await (FontLoader('Pretendard')
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf')))
      .load();
  await (FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  await (FontLoader('NotoSans')
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf')))
      .load();
}

Future<List<PremiumTemplate>> creationFixtures() async {
  final result = <PremiumTemplate>[];
  for (final name in [
    'jeju_travel',
    'film_diary',
    'soft_babybook',
    'minimal_editorial',
  ]) {
    final data =
        jsonDecode(
              await rootBundle.loadString(
                'assets/templates/${name}_handoff.json',
              ),
            )
            as Map<String, dynamic>;
    result.add(
      PremiumTemplate.fromJson(
        Map<String, dynamic>.from(data['template'] as Map),
      ),
    );
  }
  return result;
}

void main() {
  testWidgets(
    'manual, AI, free and point previews use server pricing without buying',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var manual = 0, ai = 0, purchaseChecks = 0;
      PremiumTemplate? selected;
      final templates = [
        PremiumTemplate(
          id: 1,
          title: '여행 일기',
          coverImageUrl: '',
          previewImages: [],
          pageCount: 8,
          userCount: 0,
          isPremium: true,
        ),
        PremiumTemplate(
          id: 2,
          title: '웨딩 화보',
          coverImageUrl: '',
          previewImages: [],
          pageCount: 12,
          userCount: 0,
          isPremium: false,
        ),
      ];
      await tester.pumpWidget(
        wrapCreation(
          AiAlbumStartStep(
            onManualStart: () => manual++,
            onAiStart: () => ai++,
            templates: AsyncData(templates),
            onTemplateSelected: (value) => selected = value,
          ),
          shopProducts: const [
            PointShopProduct(
              productKey: 'template:server-2',
              kind: 'template',
              assetId: 'server-2',
              title: '웨딩 화보',
              pointPrice: 120,
              isActive: true,
            ),
          ],
          pointShopGate:
              (context, ref, {required productKey, required title}) async {
                purchaseChecks++;
                return false;
              },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('직접 만들기'));
      await tester.tap(find.text('AI 템플릿으로 시작'));
      expect(manual, 1);
      expect(ai, 1);
      expect(find.text('첫 템플릿 무료'), findsNothing);
      await tester.tap(find.text('포인트').first);
      await tester.pumpAndSettle();
      expect(find.text('여행 일기'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('creation-template-2')),
      );
      await tester.tap(find.byKey(const ValueKey('creation-template-2')));
      expect(selected?.id, 2);
      expect(purchaseChecks, 0);
      final freeFilter = find.text('무료').first;
      await tester.ensureVisible(freeFilter);
      await tester.tap(freeFilter);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('creation-template-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('creation-template-2')), findsNothing);
      await tester.enterText(find.byType(TextField), '없는검색');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(find.text('검색 결과가 없어요'), findsOneWidget);
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(320, 568),
  ]) {
    testWidgets('catalog layout $size', (tester) async {
      await loadCreationFonts();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final templates = (await tester.runAsync(creationFixtures))!;
      await tester.pumpWidget(
        wrapCreation(
          AiAlbumStartStep(
            onManualStart: () {},
            onAiStart: () {},
            templates: AsyncData(templates),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/creation_hub_${size.width.toInt()}x${size.height.toInt()}.png',
        ),
      );
    });
  }
}
