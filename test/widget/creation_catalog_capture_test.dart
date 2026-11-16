import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/shared/widgets/album_stage_style.dart';
import 'package:snap_fit/shared/widgets/catalog_cover_skeleton.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/experience_form_style.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

const _fixtureTitles = ['여행의 결', '빛으로 엮은 우리', '작은 날의 기록', '우리의 서약'];

List<PremiumTemplate> _publishedFixtures() => [
  for (final title in _fixtureTitles) _publishedTemplate(title),
];

PremiumTemplate _publishedTemplate(String title) {
  final matches = publishedCreationTemplates
      .where((template) => template.title == title)
      .toList();
  if (matches.length != 1) {
    throw StateError(
      'Capture fixture needs one published "$title"; found ${matches.length}.',
    );
  }
  return matches.single;
}

List<PointShopProduct> _products(List<PremiumTemplate> templates) => [
  for (final template in templates) _product(template),
];

PointShopProduct _product(PremiumTemplate template) {
  final key = pointShopTemplateKey(template);
  final price = pointShopLaunchPrices[key];
  if (price == null) {
    throw StateError('Capture fixture has no registered launch price: $key.');
  }
  return PointShopProduct(
    productKey: key,
    kind: 'template',
    assetId: key.substring('template:'.length),
    title: template.title,
    pointPrice: price.points,
    isActive: true,
  );
}

/// 실제 비동기 에셋·이미지 디코딩을 기다리되 끝나지 않는 대기는 만들지 않는다.
Future<void> _settleArtwork(WidgetTester tester) async {
  var stableFrames = 0;
  for (var frame = 0; frame < 160; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 32));
    final ready =
        find.byType(CatalogCoverSkeleton).evaluate().isEmpty &&
        PaintingBinding.instance.imageCache.pendingImageCount == 0 &&
        !tester.binding.hasScheduledFrame;
    stableFrames = ready && frame >= 12 ? stableFrames + 1 : 0;
    if (stableFrames == 4) {
      expect(tester.takeException(), isNull);
      return;
    }
  }
  fail('Creation artwork did not settle within 160 bounded frames.');
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  Directory output,
  String filename,
) async {
  await tester.pump();
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    try {
      expect(image.width, 390);
      expect(image.height, 844);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('PNG encoding failed: $filename.');
      await output.create(recursive: true);
      await File('${output.path}/$filename').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    } finally {
      image.dispose();
    }
  });
}

void _expectNoRailScrollbar(Finder rail) {
  expect(
    find.descendant(of: rail, matching: find.byType(Scrollbar)),
    findsNothing,
  );
  expect(
    find.descendant(of: rail, matching: find.byType(RawScrollbar)),
    findsNothing,
  );
}

void main() {
  // 파일 출력은 네이티브 캡처를 명시적으로 요청한 실행에서만 활성화한다.
  final outputPath = Platform.environment['CREATION_CATALOG_CAPTURE_DIR']
      ?.trim();
  if (outputPath == null || outputPath.isEmpty) return;
  final output = Directory(outputPath);
  setUpAll(loadCreationFonts);

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets(
      'capture creation entry catalogue and scrolled rail 390x844 $theme',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final previousFavorites = CatalogFavorites.instance;
        final favorites = CatalogFavorites();
        CatalogFavorites.instance = favorites;
        await favorites.load();
        final boundary = GlobalKey();
        final templates = _publishedFixtures();
        var browsing = false;
        try {
          await tester.pumpWidget(
            wrapCreation(
              StatefulBuilder(
                builder: (context, setState) => RepaintBoundary(
                  key: boundary,
                  child: Scaffold(
                    appBar: AppBar(
                      key: const ValueKey('creation-hub-header'),
                      toolbarHeight: 56,
                      backgroundColor: AlbumStageStyle.top(context),
                      surfaceTintColor: Colors.transparent,
                      scrolledUnderElevation: 0,
                      elevation: 0,
                      leading: IconButton(
                        key: const ValueKey('creation-hub-back'),
                        tooltip: browsing ? '만들기 방법' : '뒤로가기',
                        onPressed: () {
                          if (browsing) setState(() => browsing = false);
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                      ),
                      title: Text(
                        browsing ? '디자인 고르기' : '앨범 만들기',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExperienceFormStyle.text(
                          context,
                          19,
                          weight: FontWeight.w600,
                        ),
                      ),
                      actions: [
                        IconButton(
                          key: const ValueKey('creation-save-draft'),
                          tooltip: '임시 저장',
                          onPressed: () {},
                          icon: const Icon(Icons.save_outlined, size: 21),
                        ),
                        IconButton(
                          key: const ValueKey('creation-exit'),
                          tooltip: '앨범 만들기 나가기',
                          onPressed: () {},
                          icon: const Icon(Icons.close_rounded, size: 21),
                        ),
                      ],
                    ),
                    body: AiAlbumStartStep(
                      templates: AsyncData(templates),
                      browsing: browsing,
                      onBrowsingChanged: (value) =>
                          setState(() => browsing = value),
                      onManualStart: () {},
                      onTemplateSelected: (_) => fail(
                        'Capture must not enter a template or purchase.',
                      ),
                    ),
                  ),
                ),
              ),
              dark: dark,
              shopProducts: _products(templates),
              showShell: false,
            ),
          );
          await _settleArtwork(tester);
          expect(find.text('앨범 만들기'), findsOneWidget);
          expect(find.text('직접 만들기'), findsOneWidget);
          expect(find.text('디자인으로 시작'), findsOneWidget);
          await _capture(tester, boundary, output, 'creation_entry_$theme.png');

          await tester.tap(find.byKey(const ValueKey('creation-open-catalog')));
          await _settleArtwork(tester);
          expect(browsing, isTrue);
          expect(find.text('디자인 고르기'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('creation-catalog-back')),
            findsNothing,
          );
          final rail = find.byKey(const ValueKey('creation-category-rail'));
          _expectNoRailScrollbar(rail);
          for (final template in templates) {
            expect(
              find.byKey(ValueKey('creation-template-${template.id}')),
              findsOneWidget,
            );
          }
          await _capture(
            tester,
            boundary,
            output,
            'creation_catalogue_$theme.png',
          );

          final top = find.byKey(const ValueKey('creation-category-전체'));
          final bottom = find.byKey(const ValueKey('creation-category-일상'));
          final topBefore = tester.getTopLeft(top).dx;
          final bottomBefore = tester.getTopLeft(bottom).dx;
          await tester.drag(rail, const Offset(-245, 0));
          await _settleArtwork(tester);
          final topDelta = tester.getTopLeft(top).dx - topBefore;
          final bottomDelta = tester.getTopLeft(bottom).dx - bottomBefore;
          expect(topDelta, lessThan(0));
          expect(bottomDelta, closeTo(topDelta, .01));
          _expectNoRailScrollbar(rail);
          await _capture(
            tester,
            boundary,
            output,
            'creation_catalogue_scrolled_$theme.png',
          );

          await tester.tap(find.byKey(const ValueKey('creation-hub-back')));
          await _settleArtwork(tester);
          expect(browsing, isFalse);
          expect(find.text('앨범 만들기'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          favorites.dispose();
          CatalogFavorites.instance = previousFavorites;
        }
      },
    );
  }
}
