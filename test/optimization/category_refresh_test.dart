import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/catalog_favorites.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import '../widget/ai_album_start_step_test.dart' show wrapCreation;

void main() {
  testWidgets('removed category stays all when catalog later restores it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
    addTearDown(CatalogFavorites.instance.dispose);
    final travel = bundledCreationTemplates.first.copyWith(category: '여행');
    final daily = bundledCreationTemplates[1].copyWith(category: '일상');
    var templates = [travel, daily];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateListProvider.overrideWith((ref) async => templates),
        ],
        child: wrapCreation(const StoreScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(StoreScreen)),
    );
    Finder topic(String label) => find.descendant(
      of: find.byKey(const ValueKey('store-topic-filters')),
      matching: find.text(label),
    );
    final search = find.byType(TextField);
    final scroll = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(search, 280, scrollable: scroll);
    await tester.ensureVisible(topic('여행'));
    await tester.pumpAndSettle();
    await tester.tap(topic('여행'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(of: topic('여행'), matching: find.byType(Semantics))
                .first,
          )
          .properties
          .selected,
      true,
    );
    templates = [daily];
    scope.invalidate(templateListProvider);
    await tester.pumpAndSettle();
    templates = [travel, daily];
    scope.invalidate(templateListProvider);
    await tester.pumpAndSettle();
    expect(find.text('여행 분위기에 어울리는 1개'), findsNothing);
    final semantics = tester.widget<Semantics>(
      find.ancestor(of: topic('전체'), matching: find.byType(Semantics)).first,
    );
    expect(semantics.properties.selected, true);
    expect(tester.takeException(), isNull);
  });
}
