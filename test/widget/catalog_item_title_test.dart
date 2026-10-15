import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/store/presentation/widgets/catalog_item_title.dart';

void main() {
  Future<void> mount(WidgetTester tester, String text, double width) =>
      tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              child: CatalogItemTitle(
                text,
                style: const TextStyle(fontSize: 14, fontFamily: 'Ahem'),
              ),
            ),
          ),
        ),
      );

  testWidgets('short names remain on a single line', (tester) async {
    await mount(tester, 'Soft paper', 300);
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, 'Soft paper');
    expect(text.semanticsLabel, 'Soft paper');
  });

  testWidgets('two-line titles break between words and retain semantics', (
    tester,
  ) async {
    await mount(tester, 'Soft paper frame', 160);
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, 'Soft paper\nframe');
    expect(text.semanticsLabel, 'Soft paper frame');
    expect(text.maxLines, 2);
    expect(tester.takeException(), isNull);
  });
}
