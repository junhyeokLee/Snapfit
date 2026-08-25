import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_bottom_menu.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets(
    'cover editing bottom menu keeps template and layer controls visible',
    (tester) async {
      final selected = <EditorMode>[];

      await tester.pumpWidget(
        _wrap(
          EditorBottomMenu(
            currentMode: EditorMode.none,
            isCover: true,
            onModeChanged: selected.add,
            onAddPhoto: () {},
          ),
        ),
      );

      expect(find.text('템플릿'), findsOneWidget);
      expect(find.text('레이어'), findsOneWidget);

      await tester.tap(find.text('템플릿'));
      await tester.pump();
      await tester.tap(find.text('레이어'));
      await tester.pump();

      expect(selected, contains(EditorMode.template));
      expect(selected, contains(EditorMode.layer));
    },
  );
}
