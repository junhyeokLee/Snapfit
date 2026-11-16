import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/store/data/api/material_provider.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

class _Auth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() =>
      const UserInfo(id: 'local-filter-user', name: '로컬 검수', provider: 'EMAIL');
}

Widget _library() => wrapCreation(
  ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith(_Auth.new),
      mockTemplateList(() => []),
      mockMaterialList(() => []),
    ],
    child: const MaterialCatalogScreen(library: true),
  ),
  showShell: false,
);

void main() {
  late CatalogFavorites previous;
  setUpAll(loadCreationFonts);
  setUp(() async {
    previous = CatalogFavorites.instance;
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() {
    CatalogFavorites.instance.dispose();
    CatalogFavorites.instance = previous;
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_library());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '즐겨찾기'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'favorite-only condition uses its existing switch without a repeated summary',
    (tester) async {
      await mount(tester);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '즐겨찾기'))
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('catalog-active-filter-favorites')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('catalog-reset-filters')), findsNothing);
      // 빈 결과 복구와 선택 버튼 자체의 해제 동작은 남긴다.
      expect(find.byKey(const ValueKey('catalog-empty-reset')), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, '즐겨찾기'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '즐겨찾기'))
            .selected,
        isFalse,
      );
    },
  );

  testWidgets(
    'combined search keeps removable conditions and resets both values',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('검색'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '없는 디자인');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('catalog-active-filter-query')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('catalog-active-filter-favorites')),
        findsOneWidget,
      );
      final reset = find.byKey(const ValueKey('catalog-reset-filters'));
      expect(reset, findsOneWidget);
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '즐겨찾기'))
            .selected,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('catalog-active-filter-query')),
        findsNothing,
      );
    },
  );
}
