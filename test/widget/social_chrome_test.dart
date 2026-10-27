import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_web_frame.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('social toolbar keeps the page color on scroll ($dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            home: SocialWebFrame(
              child: Scaffold(
                appBar: AppBar(title: const Text('피드')),
                body: ListView.builder(
                  itemCount: 40,
                  itemBuilder: (_, index) =>
                      SizedBox(height: 100, child: Text('작품 $index')),
                ),
              ),
            ),
          ),
        ),
      );
      Color? toolbarColor() => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(AppBar),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;
      final pageColor = Theme.of(
        tester.element(find.byType(AppBar)),
      ).scaffoldBackgroundColor;
      expect(toolbarColor(), pageColor);
      await tester.drag(find.byType(ListView), const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(toolbarColor(), pageColor);
      expect(tester.takeException(), isNull);
    });
  }
}
