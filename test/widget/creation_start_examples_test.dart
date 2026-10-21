import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_workspace.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

const _methods = ['manual', 'ai', 'template'];
Finder _action(String method) =>
    find.byKey(ValueKey('creation-method-$method'));
Finder _example(String method) =>
    find.byKey(ValueKey('creation-example-$method'));

void main() {
  setUpAll(() async {
    // Real bundled font metrics cover enlarged native layouts. These tests do
    // not compare pixels; the Chrome harness can leave explicit FontLoader
    // futures pending, so its structural and interaction checks use its fonts.
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

  testWidgets('method examples explain three starts without generated photos', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    final semantics = tester.ensureSemantics();
    try {
      var manual = 0, ai = 0;
      await tester.pumpWidget(
        wrapCreation(
          AiAlbumStartStep(
            aiPointCost: 780,
            isFirstAiDraftFree: true,
            onManualStart: () => manual++,
            onAiStart: () => ai++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('직접 배치 예시'), findsOneWidget);
      expect(find.text('AI 디자인 예시'), findsOneWidget);
      expect(find.text('기존 디자인 시작 예시'), findsOneWidget);
      expect(find.text('실제 결과는 달라요'), findsOneWidget);
      expect(find.text('첫 AI 템플릿 1회 무료 · 이후 현재 구성 기준 780P'), findsOneWidget);
      if (!kIsWeb) {
        final titleTop = tester.getTopLeft(find.text('직접 만들기')).dy;
        final bottom = tester.getBottomLeft(_action('manual')).dy;
        for (final title in ['AI 템플릿', '템플릿 고르기']) {
          expect(
            tester.getTopLeft(find.text(title)).dy,
            closeTo(titleTop, 0.1),
          );
        }
        for (final method in ['ai', 'template']) {
          expect(
            tester.getBottomLeft(_action(method)).dy,
            closeTo(bottom, 0.1),
          );
        }
      }
      for (final method in _methods) {
        expect(
          find.descendant(of: _action(method), matching: _example(method)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _example(method),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _example(method), matching: find.byType(Image)),
          findsNothing,
        );
      }
      expect(
        tester.getSemantics(_example('ai')).label,
        contains('사진은 이후 직접 추가해요. 실제 결과는 달라요.'),
      );
      expect(
        tester.getSemantics(_example('manual')).flagsCollection.isImage,
        isTrue,
      );
      await tester.ensureVisible(_action('manual'));
      await tester.pumpAndSettle();
      expect(_action('manual').hitTestable(), findsOneWidget);
      await tester.tap(_action('manual'));
      await tester.ensureVisible(_action('ai'));
      await tester.pumpAndSettle();
      expect(_action('ai').hitTestable(), findsOneWidget);
      await tester.tap(_action('ai'));
      await tester.ensureVisible(_action('template'));
      await tester.pumpAndSettle();
      expect(_action('template').hitTestable(), findsOneWidget);
      await tester.tap(_action('template'));
      await tester.pumpAndSettle();
      expect(manual, 1);
      expect(ai, 1);
      expect(find.text('등록된 템플릿이 없어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('example actions retain keyboard activation', (tester) async {
    viewport(tester, const Size(1024, 768));
    var manual = 0, ai = 0;
    await tester.pumpWidget(
      wrapCreation(
        AiAlbumStartStep(onManualStart: () => manual++, onAiStart: () => ai++),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(manual, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(ai, 1);
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
      'method examples fit ${config.size} at ${config.scale} dark=${config.dark}',
      (tester) async {
        viewport(tester, config.size);
        await tester.pumpWidget(
          wrapCreation(
            AiAlbumStartStep(onManualStart: () {}, onAiStart: () {}),
            textScale: config.scale,
            dark: config.dark,
          ),
        );
        await tester.pumpAndSettle();
        for (final method in _methods) {
          await tester.ensureVisible(_example(method));
          await tester.pumpAndSettle();
          final bounds = tester.getRect(_example(method));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(config.size.width));
          expect(tester.takeException(), isNull, reason: method);
        }
      },
    );
  }

  testWidgets('filtered compact choices keep all examples and callbacks', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    var manual = 0, ai = 0;
    await tester.pumpWidget(
      wrapCreation(
        AiAlbumStartStep(onManualStart: () => manual++, onAiStart: () => ai++),
        textScale: 1.8,
      ),
    );
    await tester.pumpAndSettle();
    final freeFilter = find.text('무료').first;
    await tester.ensureVisible(freeFilter);
    await tester.pumpAndSettle();
    expect(freeFilter.hitTestable(), findsOneWidget);
    await tester.tap(freeFilter);
    await tester.pumpAndSettle();
    expect(find.byType(CreationBlankBook), findsNothing);
    for (final method in _methods) {
      await tester.ensureVisible(_example(method));
      await tester.pumpAndSettle();
      expect(_example(method), findsOneWidget);
      expect(tester.takeException(), isNull, reason: method);
    }
    await tester.ensureVisible(_action('manual'));
    await tester.pumpAndSettle();
    expect(_action('manual').hitTestable(), findsOneWidget);
    await tester.tap(_action('manual'));
    await tester.ensureVisible(_action('ai'));
    await tester.pumpAndSettle();
    expect(_action('ai').hitTestable(), findsOneWidget);
    await tester.tap(_action('ai'));
    expect(manual, 1);
    expect(ai, 1);
    expect(tester.takeException(), isNull);
  });
}
