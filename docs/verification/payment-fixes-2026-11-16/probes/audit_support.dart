// 현재 UI의 후보 상태만 캡처한다. 실제 계정·초대·주문 요청은 실행하지 않는다.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final auditBoundary = GlobalKey();
Widget auditFrame(Widget child) =>
    RepaintBoundary(key: auditBoundary, child: child);
void auditViewport(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> auditFonts() async {
  for (final (family, paths) in [
    ('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']),
    (
      'NotoSans',
      [
        'assets/fonts/NotoSansKR-Regular.ttf',
        'assets/fonts/NotoSansKR-SemiBold.ttf',
        'assets/fonts/NotoSansKR-Bold.ttf',
      ],
    ),
    (
      'Pretendard',
      [
        'assets/fonts/NotoSansKR-Regular.ttf',
        'assets/fonts/NotoSansKR-Bold.ttf',
      ],
    ),
    (
      'Poppins',
      ['assets/fonts/Poppins-Regular.otf', 'assets/fonts/Poppins-SemiBold.otf'],
    ),
  ]) {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

void _repaint(RenderObject object) {
  object.visitChildren(_repaint);
  if (object.attached) object.markNeedsPaint();
}

Future<void> auditCapture(WidgetTester tester, String name, {bool settle=true}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  if(settle) await tester.pumpAndSettle();
  for (final view in tester.binding.renderViews) {
    _repaint(view);
  }
  await tester.pump(const Duration(milliseconds: 32));
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final boundary =
        auditBoundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final directory = Platform.environment['NEXT_AUDIT_DIR']!;
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      picture.dispose();
    }
  });
}
