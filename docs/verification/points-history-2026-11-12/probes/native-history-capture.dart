import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file:///Users/devsheep/SnapFit/SnapFit/test/widget/point_ledger_history_test.dart'
    show PointHistoryFixture, mountPointHistory, pointHistoryRows;

class _CaptureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> _loadFonts() async {
  for (final (family, assets) in [
    (
      'NotoSans',
      [
        'assets/fonts/NotoSansKR-Regular.ttf',
        'assets/fonts/NotoSansKR-SemiBold.ttf',
        'assets/fonts/NotoSansKR-Bold.ttf',
      ],
    ),
    ('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']),
  ]) {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

String get _output {
  const defined = String.fromEnvironment('POINTS_HISTORY_QA_DIR');
  return defined.isNotEmpty
      ? defined
      : Platform.environment['POINTS_HISTORY_QA_DIR'] ??
          '/Users/devsheep/SnapFit/SnapFit/docs/verification/points-history-2026-11-12/after';
}

void _markPaint(RenderObject object) {
  object.visitChildren(_markPaint);
  if (object.attached) object.markNeedsPaint();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  PointHistoryFixture fixture,
  String scene,
  Size size, {
  required bool dark,
  required double scale,
}) async {
  expect(fixture.pageRequests, isNotEmpty);
  expect(find.byType(LinearProgressIndicator), findsNothing);
  await tester.pumpAndSettle();
  // native 경계 캡처에서도 정적인 상단 자식 레이어를 다시 칠한다.
  for (final view in tester.binding.renderViews) {
    _markPaint(view);
  }
  await tester.pump(const Duration(milliseconds: 32));
  await tester.pump(const Duration(milliseconds: 32));
  final metrics = {
    'scene': scene,
    'logicalSize': {'width': size.width, 'height': size.height},
    'pixelRatio': 2,
    'dark': dark,
    'textScale': scale,
    'availableLedgerRows': fixture.rows.length,
    'requests': fixture.requests,
    'olderDebitInSource': fixture.rows.any((row) => row['id'] == 1),
    'olderDebitInWidgetTree':
        find.byKey(const ValueKey('points-ledger-1')).evaluate().isNotEmpty,
    'emptyFilteredMessage':
        find.text('해당 포인트 내역이 없어요.').evaluate().isNotEmpty,
    'purchaseCalls': fixture.store.buyCalls,
    'moreButtonVisible': find.byKey(const ValueKey('points-history-more')).hitTestable().evaluate().isNotEmpty,
  };
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_output/$scene.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await File('$_output/$scene-metrics.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(metrics),
      );
      stdout.writeln('POINTS_HISTORY ${jsonEncode(metrics)}');
    } finally {
      image.dispose();
    }
  });
}

void main() {
  _CaptureBinding();
  setUpAll(_loadFonts);

  for (final (scene, size, spent, dark, scale) in [
    ('01-history-all-390x844', const Size(390, 844), false, false, 1.0),
    ('02-history-spent-390x844', const Size(390, 844), true, false, 1.0),
    ('03-history-spent-320x844-dark-large-text', const Size(320, 844), true, true, 1.6),
    ('04-history-more-390x844', const Size(390, 844), false, false, 1.0),
  ]) {
    testWidgets('capture current native points history $scene', (
      tester,
    ) async {
      // 각 장면은 새 provider scope와 화면에서 시작해 상태 유입을 막는다.
      final key = GlobalKey();
      final fixture = PointHistoryFixture(
        rows: scene.startsWith('04-') ? pointHistoryRows(25) : null,
      );
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(fixture.store.controller.close);
      await mountPointHistory(tester, fixture, captureKey: key, dark: dark, textScale: scale);
      if (spent) {
        await tester.tap(find.text('차감'));
        await tester.pumpAndSettle();
      }
      if (scene.startsWith('04-')) {
        final more = find.byKey(const ValueKey('points-history-more'));
        final scroll = find.descendant(
          of: find.byType(CustomScrollView), matching: find.byType(Scrollable),
        ).first;
        await tester.scrollUntilVisible(more, 350, scrollable: scroll);
        await tester.ensureVisible(more);
        await tester.pumpAndSettle();
        expect(more.hitTestable(), findsOneWidget);
      }
      // A scrolled history legitimately moves its balance card off screen.
      if (!scene.startsWith('04-')) {
        expect(find.text('11,800 P'), findsOneWidget);
        expect(find.byKey(const ValueKey('points-ledger-filter')), findsOneWidget);
      }
      expect(fixture.store.buyCalls, 0);
      expect(tester.takeException(), isNull);
      if (spent) {
        expect(find.byKey(const ValueKey('points-ledger-1')), findsOneWidget);
        expect(find.text('해당 포인트 내역이 없어요.'), findsNothing);
      }
      await _capture(tester, key, fixture, scene, size, dark: dark, scale: scale);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
