import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/catalog_preview_assets.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });
  testWidgets('export seven actual covers together', (tester) async {
    tester.view.physicalSize = const Size(1400, 1070);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFFF1F5F3),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SNAPFIT / ATELIER EDITIONS',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 16,
                        color: Color(0xFF4B6C5B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '카테고리별 새로운 일곱 권 · 표지 + 내지 32쪽',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 26,
                        color: Color(0xFF203A2F),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 4,
                        mainAxisSpacing: 28,
                        crossAxisSpacing: 28,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: .83,
                        children: [
                          for (final e in AtelierEdition.values)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Image.asset(
                                    catalogPreviewAssets['template:${e.catalogId}']!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  e.title,
                                  style: const TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontSize: 19,
                                    color: Color(0xFF203A2F),
                                  ),
                                ),
                                Text(
                                  '${e.category} / 32쪽',
                                  style: const TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontSize: 14,
                                    color: Color(0xFF61796D),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
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
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final bitmap =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      File(
        'output/premium-atelier-qa/overview.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      bitmap.dispose();
    });
  }, skip: !const bool.fromEnvironment('EXPORT_ATELIER_OVERVIEW'));
}
