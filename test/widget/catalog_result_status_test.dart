import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/widgets/catalog_result_status.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_catalog_empty_state.dart';

void main() {
  testWidgets(
    'result announcements wait for stable input without moving focus',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      late StateSetter update;
      var label = '30개의 디자인';
      var query = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  children: [
                    TextField(focusNode: focus),
                    CatalogResultStatus(label: label, debounceToken: query),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      Semantics result() => tester.widget<Semantics>(
        find.byKey(const ValueKey('catalog-result-announcement')),
      );
      expect(result().properties.liveRegion, isTrue);
      expect(result().properties.label, '30개의 디자인');
      update(() => label = '12개의 디자인');
      await tester.pump();
      expect(find.text('12개의 디자인'), findsOneWidget);
      expect(result().properties.label, '30개의 디자인');
      await tester.pump(const Duration(milliseconds: 300));
      update(() => label = '1개의 디자인');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(result().properties.label, '30개의 디자인');
      // More typing with the same count also postpones the announcement.
      update(() => query = '여행');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(result().properties.label, '30개의 디자인');
      await tester.pump(const Duration(milliseconds: 300));
      expect(result().properties.label, '1개의 디자인');
      expect(focus.hasFocus, isTrue);
      final excluded = find.descendant(
        of: find.byType(CatalogResultStatus),
        matching: find.byType(ExcludeSemantics),
      );
      expect(excluded, findsOneWidget);

      // Returning to the already announced state cancels a pending stale result.
      update(() => label = '0개의 디자인');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      update(() => label = '1개의 디자인');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(result().properties.label, '1개의 디자인');

      update(() => label = '5개의 디자인');
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an empty public catalog does not invent recovery subjects', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublicCatalogEmptyState(
            catalogEmpty: true,
            suggestedCategories: const [],
            onReset: () => fail('No search can recover an empty catalog'),
            onCategorySelected: (_) => fail('No subjects exist'),
          ),
        ),
      ),
    );
    expect(find.text('둘러볼 디자인을 준비하고 있어요.'), findsOneWidget);
    expect(find.text('검색 결과가 없어요. 다른 이름이나 주제로 찾아보세요.'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    expect(find.byKey(const ValueKey('discovery-reset-filters')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
