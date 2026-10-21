import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/shared/widgets/snapfit_motion.dart';

void main() {
  testWidgets('pressable cards support Tab, Enter, Space and visible focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var first = 0;
      var second = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: SnapFitTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                const SnapFitPressable(child: Text('사용할 수 없는 카드')),
                SnapFitPressable(
                  key: const ValueKey('first-card'),
                  onTap: () => first++,
                  child: const SizedBox(
                    width: 120,
                    height: 70,
                    child: Text('첫 번째 카드'),
                  ),
                ),
                SnapFitPressable(
                  onTap: () => second++,
                  child: const SizedBox(
                    width: 120,
                    height: 70,
                    child: Text('두 번째 카드'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final card = find.byKey(const ValueKey('first-card'));
      final node = tester.getSemantics(card);
      expect(node.hasFlag(ui.SemanticsFlag.isButton), true);
      expect(node.hasFlag(ui.SemanticsFlag.isFocused), true);
      final ring = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: card, matching: find.byType(DecoratedBox)),
          )
          .where((box) => box.position == DecorationPosition.foreground)
          .single;
      expect((ring.decoration as BoxDecoration).border, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(first, 2);
      expect(second, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(second, 1);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(first, 3);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('disabled pressable does not expose an activation action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SnapFitPressable(child: Text('판매 준비 중'))),
        ),
      );
      final node = tester.getSemantics(find.byType(SnapFitPressable));
      expect(node.hasFlag(ui.SemanticsFlag.isEnabled), false);
      expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), false);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final accessibleNavigation in [false, true]) {
    testWidgets(
      'album route reduces motion for ${accessibleNavigation ? 'accessible navigation' : 'disabled animations'}',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: !accessibleNavigation,
                accessibleNavigation: accessibleNavigation,
              ),
              child: child!,
            ),
            home: const Scaffold(body: Text('앨범 목록')),
          ),
        );
        final route = snapFitAlbumOpenRoute<String>(
          page: const Scaffold(body: Text('앨범 내용')),
        );
        final result = navigator.currentState!.push(route);
        await tester.pump();
        await tester.pump();
        expect(route.transitionDuration, Duration.zero);
        expect(route.reverseTransitionDuration, Duration.zero);
        expect(find.text('앨범 내용').hitTestable(), findsOneWidget);
        navigator.currentState!.pop('완료');
        await tester.pumpAndSettle();
        expect(await result, '완료');
        expect(find.text('앨범 목록').hitTestable(), findsOneWidget);
      },
    );
  }

  testWidgets('normal album opening keeps its existing duration', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('목록')),
      ),
    );
    final route = snapFitAlbumOpenRoute<void>(
      page: const Scaffold(body: Text('내용')),
    );
    navigator.currentState!.push(route);
    await tester.pumpAndSettle();
    expect(route.transitionDuration, SnapFitMotion.slow);
    expect(route.reverseTransitionDuration, SnapFitMotion.fast);
    expect(find.text('내용'), findsOneWidget);
  });
}
