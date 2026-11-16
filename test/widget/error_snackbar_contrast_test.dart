import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/core/utils/context_extensions.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'error message stays readable in ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => context.showErrorSnack('다시 시도해 주세요.'),
                  child: const Text('실패 재현'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('실패 재현'));
        await tester.pumpAndSettle();
        final message = find.text('다시 시도해 주세요.');
        final text = tester.widget<Text>(message);
        final foreground =
            text.style?.color ??
            DefaultTextStyle.of(tester.element(message)).style.color!;
        final background = tester
            .widget<SnackBar>(find.byType(SnackBar))
            .backgroundColor!;
        final lighter = foreground.computeLuminance();
        final darker = background.computeLuminance();
        final contrast = lighter > darker
            ? (lighter + .05) / (darker + .05)
            : (darker + .05) / (lighter + .05);
        expect(
          contrast,
          greaterThanOrEqualTo(4.5),
          reason: '실패 원인과 재시도 안내가 실제 배경에서 읽혀야 한다.',
        );
      },
    );
  }
}
