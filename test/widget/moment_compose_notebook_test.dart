import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_compose_notebook.dart';

Future<void> _mount(
  WidgetTester tester, {
  required TextEditingController controller,
  required ValueChanged<String> onChanged,
  bool dateConfirmed = true,
  bool captionEnabled = true,
  bool captionReadOnly = false,
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
  VoidCallback? onPhoto,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: MomentComposeNotebook(
            date: DateTime.utc(2026, 11, 11),
            dateConfirmed: dateConfirmed,
            captionController: controller,
            captionEnabled: captionEnabled,
            captionReadOnly: captionReadOnly,
            onCaptionChanged: onChanged,
            photoContent: SizedBox(
              key: const ValueKey('notebook-photo-slot'),
              height: 128,
              child: Center(
                child: TextButton(
                  onPressed: onPhoto ?? () {},
                  child: const Text('사진 고르기'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('confirmed date is read only and has no date picker action', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _mount(tester, controller: controller, onChanged: (_) {});

    final date = find.byKey(const ValueKey('moment-date'));
    expect(find.text('11'), findsOneWidget);
    expect(find.text('2026년 11월 · 수요일'), findsOneWidget);
    expect(tester.widget<Semantics>(date).properties.readOnly, isTrue);
    expect(tester.widget<Semantics>(date).properties.onTap, isNull);
    await tester.tap(date, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unconfirmed date does not expose the assumed device date', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _mount(
      tester,
      controller: controller,
      onChanged: (_) {},
      dateConfirmed: false,
    );

    expect(find.text('오늘'), findsOneWidget);
    expect(find.text('한국 시간 기준'), findsOneWidget);
    expect(find.text('11'), findsNothing);
    expect(find.textContaining('2026'), findsNothing);
    final semantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('moment-date')),
    );
    expect(semantics.properties.label, isNot(contains('2026')));
    expect(semantics.properties.label, contains('확인'));
  });

  testWidgets('optional memo retains restored text and reports real edits', (
    tester,
  ) async {
    final controller = TextEditingController(text: '보관해 둔 한 줄');
    addTearDown(controller.dispose);
    final edits = <String>[];
    await _mount(tester, controller: controller, onChanged: edits.add);

    expect(find.text('보관해 둔 한 줄'), findsOneWidget);
    expect(edits, isEmpty);
    final caption = find.byKey(const ValueKey('moment-caption'));
    await tester.ensureVisible(caption);
    await tester.enterText(caption, '오늘도 함께 걸었다');
    expect(controller.text, '오늘도 함께 걸었다');
    expect(edits, ['오늘도 함께 걸었다']);
    expect(find.text('한 줄 기록 (선택)'), findsOneWidget);
  });

  for (final readOnly in [false, true]) {
    testWidgets(
      '${readOnly ? 'read-only' : 'disabled'} memo cannot open an editing keyboard',
      (tester) async {
        final controller = TextEditingController(text: '그대로 보관할 글');
        addTearDown(controller.dispose);
        final edits = <String>[];
        await _mount(
          tester,
          controller: controller,
          onChanged: edits.add,
          captionEnabled: readOnly,
          captionReadOnly: readOnly,
        );

        final caption = find.byKey(const ValueKey('moment-caption'));
        await tester.ensureVisible(caption);
        await tester.tap(caption, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(controller.text, '그대로 보관할 글');
        expect(edits, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 390.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'notebook preserves photo-before-memo order at $width and 200% text in ${dark ? 'dark' : 'light'}',
        (tester) async {
          final controller = TextEditingController();
          addTearDown(controller.dispose);
          var photoTaps = 0;
          await _mount(
            tester,
            controller: controller,
            onChanged: (_) {},
            onPhoto: () => photoTaps++,
            size: Size(width, 844),
            scale: 2,
            dark: dark,
          );

          final date = find.byKey(const ValueKey('moment-date'));
          final photo = find.byKey(const ValueKey('notebook-photo-slot'));
          final caption = find.byKey(const ValueKey('moment-caption'));
          expect(
            tester.getTopLeft(date).dy,
            lessThan(tester.getTopLeft(photo).dy),
          );
          expect(
            tester.getBottomLeft(photo).dy,
            lessThan(tester.getTopLeft(caption).dy),
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('사진 고르기'));
          await tester.tap(find.text('사진 고르기'));
          expect(photoTaps, 1);
          await tester.ensureVisible(caption);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
