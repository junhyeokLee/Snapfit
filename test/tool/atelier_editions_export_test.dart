import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_catalog_release.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

void main() {
  test('export registration metadata without repainting approved pages', () {
    final output = Directory('output/premium-atelier-qa')
      ..createSync(recursive: true);
    File('${output.path}/studio-data.js').writeAsStringSync(
      'const studioEditionData = ${jsonEncode([for (final e in StudioEdition.values) _studioManifest(e)])};\n',
    );
  }, skip: !const bool.fromEnvironment('EXPORT_ATELIER_METADATA'));

  testWidgets(
    'export actual editable atelier pages in three ratios',
    (tester) async {
      final fonts =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final font in fonts) {
        final loader = FontLoader(font['family'] as String);
        for (final asset in font['fonts'] as List) {
          loader.addFont(rootBundle.load(asset['asset'] as String));
        }
        await loader.load();
      }
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final output = Directory('output/premium-atelier-qa')
        ..createSync(recursive: true);
      final selected = const String.fromEnvironment(
        'EXPORT_ATELIER_IDS',
      ).split(',').where((s) => s.isNotEmpty).toSet();
      final editions = [
        for (final e in AtelierEdition.values) (id: e.id, document: e.document),
        for (final e in StudioEdition.values) (id: e.id, document: e.document),
      ];
      expect(selected.difference(editions.map((e) => e.id).toSet()), isEmpty);
      for (final edition in editions.where(
        (e) => selected.isEmpty || selected.contains(e.id),
      )) {
        for (final aspect in CollectionAspect.values) {
          final pages = templateDocumentPages(edition.document(aspect));
          final lastSpread =
              const bool.fromEnvironment('EXPORT_ATELIER_COVERS_ONLY')
              ? 0
              : (pages.length - 1) ~/ 2;
          for (var spread = 0; spread <= lastSpread; spread++) {
            final selected = spread == 0
                ? pages.take(1).toList()
                : pages.skip(spread * 2 - 1).take(2).toList();
            final width = spread == 0 ? 600.0 : 1000.0;
            final height = width / selected.length / aspect.canvas.aspectRatio;
            final key = GlobalKey();
            await tester.pumpWidget(
              ScreenUtilInit(
                designSize: const Size(390, 844),
                builder: (_, _) => MaterialApp(
                  home: Scaffold(
                    body: Center(
                      child: RepaintBoundary(
                        key: key,
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: Row(
                            children: [
                              for (final page in selected)
                                Expanded(
                                  child: FittedBox(
                                    child: TemplatePageRenderer(
                                      layers:
                                          DataTemplateEngine.buildLayersFromJson(
                                            page,
                                            aspect.canvas,
                                          ),
                                      width: aspect.canvas.width,
                                      height: aspect.canvas.height,
                                      designCanvasSize: aspect.canvas,
                                      preserveTypography: true,
                                      imageDecodeWidth: 1000,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              for (final element in find.byType(Image).evaluate()) {
                Object? error;
                await precacheImage(
                  (element.widget as Image).image,
                  element,
                  onError: (e, _) => error = e,
                );
                if (error != null) throw StateError('${edition.id}: $error');
              }
            });
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${edition.id} / ${aspect.name} / $spread',
            );
            await tester.runAsync(() async {
              final bitmap =
                  await (key.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await bitmap.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                '${output.path}/${edition.id}-${aspect.name}-$spread.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              bitmap.dispose();
            });
            await tester.pumpWidget(const SizedBox());
          }
          debugPrint(
            'Exported ${edition.id} / ${aspect.name}: cover + ${pages.length - 1} pages',
          );
        }
      }
      if (!const bool.fromEnvironment('EXPORT_ATELIER_COVERS_ONLY')) {
        await tester.runAsync(() async {
          for (final edition in StudioEdition.values.where(
            (e) => selected.isEmpty || selected.contains(e.id),
          )) {
            for (final aspect in CollectionAspect.values) {
              const tileWidth = 460.0, gap = 24.0, margin = 30.0;
              final tileHeight = tileWidth / (2 * aspect.canvas.aspectRatio);
              final count = edition.innerPageCount ~/ 2;
              const width = margin * 2 + tileWidth * 3 + gap * 2;
              final rowHeight = tileHeight + 50;
              final recorder = ui.PictureRecorder();
              final canvas = Canvas(recorder)
                ..drawColor(const Color(0xFFF1F5F3), BlendMode.src);
              final sources = <ui.Image>[];
              for (var spread = 1; spread <= count; spread++) {
                final codec = await ui.instantiateImageCodec(
                  File(
                    '${output.path}/${edition.id}-${aspect.name}-$spread.png',
                  ).readAsBytesSync(),
                );
                final image = (await codec.getNextFrame()).image;
                sources.add(image);
                codec.dispose();
                final at = Offset(
                  margin + (spread - 1) % 3 * (tileWidth + gap),
                  margin + (spread - 1) ~/ 3 * rowHeight,
                );
                canvas.drawImageRect(
                  image,
                  Rect.fromLTWH(
                    0,
                    0,
                    image.width.toDouble(),
                    image.height.toDouble(),
                  ),
                  at & Size(tileWidth, tileHeight),
                  Paint(),
                );
                final label = TextPainter(
                  textDirection: TextDirection.ltr,
                  text: TextSpan(
                    text:
                        '${spread * 2 - 1}–${spread * 2}쪽 / ${edition.chapters[spread - 1]}',
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 17,
                      color: Color(0xFF233A3E),
                    ),
                  ),
                )..layout(maxWidth: tileWidth);
                label.paint(canvas, at + Offset(0, tileHeight + 8));
                label.dispose();
              }
              final picture = recorder.endRecording();
              final sheet = await picture.toImage(
                width.ceil(),
                (margin * 2 + (count / 3).ceil() * rowHeight).ceil(),
              );
              final bytes = await sheet.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                '${output.path}/${edition.id}-${aspect.name}-overview.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              sheet.dispose();
              picture.dispose();
              for (final image in sources) {
                image.dispose();
              }
            }
          }
          File('${output.path}/studio-data.js').writeAsStringSync(
            'const studioEditionData = ${jsonEncode([for (final e in StudioEdition.values) _studioManifest(e)])};\n',
          );
        });
      }
    },
    skip: !const bool.fromEnvironment('EXPORT_ATELIER'),
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Map<String, dynamic> _studioManifest(StudioEdition edition) {
  final materials = templateVisualMaterialKeys(
    edition.document(CollectionAspect.square),
  );
  final paid = materials.where(
    (key) => (pointShopLaunchPrices[key]?.points ?? 0) > 0,
  );
  return {
    'id': edition.id,
    'title': edition.title,
    'category': edition.category,
    'concept': edition.subtitle,
    'tier': edition.premium ? 'premium' : 'free',
    'innerPages': edition.innerPageCount,
    'price': pointShopLaunchPrices[edition.productKey]!.points,
    'salesActivated': false,
    'registrationApproved':
        !edition.premium ||
        ownerApprovedCatalogProductKeys.contains(edition.productKey),
    'approvalRevision': pointShopCatalogApprovalRevision,
    'materialCount': materials.length,
    'paidMaterialCount': paid.length,
    'chapters': edition.chapters,
  };
}
