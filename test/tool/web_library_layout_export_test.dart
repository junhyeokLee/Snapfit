import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../widget/web_album_library_test.dart' show mountWebLibraryFixture;

void main() {
  testWidgets('export production web library layouts with local sample data', (
    tester,
  ) async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest.where(
      (font) => ['NotoSans', 'MaterialIcons'].contains(font['family']),
    )) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List) {
        loader.addFont(rootBundle.load(file['asset'] as String));
      }
      await loader.load();
    }
    for (final fixture in [
      (
        name: 'library-desktop-light',
        size: const Size(1440, 1040),
        brightness: Brightness.light,
        list: false,
      ),
      (
        name: 'library-desktop-dark-list',
        size: const Size(1440, 1040),
        brightness: Brightness.dark,
        list: true,
      ),
      (
        name: 'library-narrow-light',
        size: const Size(390, 1000),
        brightness: Brightness.light,
        list: false,
      ),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await mountWebLibraryFixture(
        tester,
        size: fixture.size,
        brightness: fixture.brightness,
      );
      if (fixture.list) {
        await tester.tap(find.byTooltip('앨범 목록 보기'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('web-library-layout-proof')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/web-design-2026-10-18/${fixture.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  }, skip: !const bool.fromEnvironment('EXPORT_WEB_LIBRARY_LAYOUT'));
}
