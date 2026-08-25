import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_bottom_menu.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(
      theme: ThemeData(fontFamily: 'Noto Sans KR'),
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _dragDockUntilVisible(WidgetTester tester, String label) async {
  for (var i = 0; i < 5 && find.text(label).evaluate().isEmpty; i++) {
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _loadKoreanFonts() async {
  final regular = FontLoader('Noto Sans KR')
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'));
  await regular.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadKoreanFonts();
  });

  testWidgets(
    'cover editing command dock keeps every required control available',
    (tester) async {
      final selected = <EditorMode>[];
      var photoTapped = 0;
      var coverTapped = 0;

      await tester.pumpWidget(
        _wrap(
          EditorBottomMenu(
            currentMode: EditorMode.none,
            isCover: true,
            showCoverMenuItem: true,
            onModeChanged: selected.add,
            onAddPhoto: () => photoTapped++,
            onCover: () => coverTapped++,
          ),
        ),
      );

      for (final label in [
        '글',
        '사진',
        '커버',
        '레이아웃',
        '템플릿',
        '레이어',
        '스티커',
        '배경',
      ]) {
        await _dragDockUntilVisible(tester, label);
        expect(find.text(label), findsOneWidget, reason: label);
      }

      await tester.tap(find.text('사진'));
      await tester.pump();
      expect(photoTapped, 1);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(360, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('글'));
      await tester.pump();
      expect(selected, contains(EditorMode.text));
    },
  );

  testWidgets(
    'page editing command dock keeps template layer layout and toggles selected mode',
    (tester) async {
      final selected = <EditorMode>[];

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              final current = selected.isEmpty
                  ? EditorMode.none
                  : selected.last;
              return EditorBottomMenu(
                currentMode: current,
                isCover: false,
                onModeChanged: (mode) => setState(() => selected.add(mode)),
                onAddPhoto: () {},
              );
            },
          ),
        ),
      );

      for (final label in ['글', '사진', '레이아웃', '템플릿', '레이어', '스티커', '배경']) {
        await _dragDockUntilVisible(tester, label);
        expect(find.text(label), findsOneWidget, reason: label);
      }

      await tester.tap(find.text('템플릿'));
      await tester.pumpAndSettle();
      expect(selected, contains(EditorMode.template));

      await tester.tap(find.text('템플릿'));
      await tester.pumpAndSettle();
      expect(selected.last, EditorMode.none);

      await tester.tap(find.text('레이어'));
      await tester.pumpAndSettle();
      expect(selected, contains(EditorMode.layer));
    },
  );

  testWidgets('command dock golden keeps restored tools visually prominent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        Align(
          alignment: Alignment.bottomCenter,
          child: EditorBottomMenu(
            currentMode: EditorMode.template,
            isCover: true,
            showCoverMenuItem: false,
            onModeChanged: (_) {},
            onAddPhoto: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(EditorBottomMenu),
      matchesGoldenFile('goldens/editor_command_dock_390x160.png'),
    );
  });
}
