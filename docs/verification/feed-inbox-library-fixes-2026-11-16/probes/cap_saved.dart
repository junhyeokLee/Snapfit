// 실제 내 디자인 위젯을 로컬 보유권·즐겨찾기 데이터로 캡처한다.
// 네트워크 요청과 제품 코드는 변경하지 않는다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/data/api/material_provider.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_discovery_provider.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';

import 'capture_support.dart';

class _Auth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() => const UserInfo(
    id: 'audit-library-user',
    name: '준혁',
    email: 'audit@example.invalid',
    provider: 'EMAIL',
  );
}

final _template = publishedCreationTemplates.firstWhere((t) => t.id == -9501);
final _sticker = studioDecorations.firstWhere((s) => s.id == 'studioPressedCosmos');
final _paper = studioDecorations.firstWhere((s) => s.id == 'studioCottonRag');
final _frame = imageFrameStyles.firstWhere((f) => f.key == 'studioPostcard');
final _owned = <String>{
  pointShopTemplateKey(_template),
  'sticker:${_paper.id}',
  'frame:${_frame.key}',
};

Widget _app({bool empty = false, bool dark = false, double scale = 1}) =>
    ProviderScope(
      key: UniqueKey(),
      retry: (_, __) => null,
      overrides: [
        authViewModelProvider.overrideWith(_Auth.new),
        ownedPointShopKeysProvider.overrideWith((_) async => empty ? <String>{} : _owned),
        pointShopCatalogProvider.overrideWith((_) async => []),
        mockTemplateList(() => [_template]),
        mockMaterialList(() => bundledMaterials),
        storeDiscoveryProvider.overrideWith((_) async => <String, StoreProductDiscovery>{}),
        storeDiscoveryClockProvider.overrideWith((_) => DateTime.utc(2026, 11, 16)),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const MaterialCatalogScreen(library: true),
        ),
      ),
    );

Future<void> _artwork(WidgetTester tester) async {
  // 이미지·문서 글꼴의 실제 IO와 테스트 프레임을 번갈아 유한하게 진행한다.
  for (var frame = 0; frame < 60; frame++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 32));
  }
}

Future<void> _favorites(WidgetTester tester) async {
  final chip = find.widgetWithText(FilterChip, '즐겨찾기');
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(auditFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets('내 디자인 보유 목록에서 즐겨찾기와 검색 복구', (tester) async {
    auditViewport(tester);
    await CatalogFavorites.instance.toggle(CatalogFavoriteKeys.decoration(_sticker.insertionValue));
    await tester.pumpWidget(auditFrame(_app()));
    await _artwork(tester);
    expect(find.text('4개 항목'), findsOneWidget);
    await auditCapture(tester, 'saved-01-library');

    await _favorites(tester);
    expect(find.text('1개 항목'), findsOneWidget);
    await auditCapture(tester, 'saved-02-favorites');

    // 미구매 항목은 즐겨찾기를 해제하면 보관함 노출 조건에서도 빠진다.
    final favoriteKey = CatalogFavoriteKeys.decoration(_sticker.insertionValue);
    await tester.tap(find.byKey(ValueKey('favorite-$favoriteKey')));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾는 항목이 없어요.'), findsOneWidget);
    expect(find.byType(SnackBarAction), findsOneWidget);
    expect(CatalogFavorites.instance.contains(favoriteKey), isFalse);
    await auditCapture(tester, 'saved-02b-removed-favorite');
    await _favorites(tester);
    expect(find.text('3개 항목'), findsOneWidget);
    expect(find.byKey(ValueKey('material-item-sticker:${_sticker.id}')), findsNothing);
    await auditCapture(tester, 'saved-02c-all-after-removal');

    // 사라진 미구매 디자인은 보관함 안내의 되돌리기로 실제 복원한다.
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(CatalogFavorites.instance.contains(favoriteKey), isTrue);
    expect(find.text('4개 항목'), findsOneWidget);
    await auditCapture(tester, 'saved-02d-undo-restored');
    await _favorites(tester);

    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '여행');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 항목이 없어요.'), findsOneWidget);
    await auditCapture(tester, 'saved-03-filter-no-results');

    final reset = find.byKey(const ValueKey('catalog-empty-reset'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await _artwork(tester);
    expect(find.text('4개 항목'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await auditCapture(tester, 'saved-04-reset');
  });

  testWidgets('내 디자인의 빈 보관함과 즐겨찾기 빈 상태', (tester) async {
    auditViewport(tester);
    await tester.pumpWidget(auditFrame(_app(empty: true)));
    await tester.pumpAndSettle();
    expect(find.text('아직 보관한 항목이 없어요.'), findsOneWidget);
    await auditCapture(tester, 'saved-05-empty');
    await _favorites(tester);
    expect(find.text('즐겨찾는 항목이 없어요.'), findsOneWidget);
    await auditCapture(tester, 'saved-06-favorites-empty');
  });

  testWidgets('내 디자인의 좁은 다크 큰 글자 상태', (tester) async {
    auditViewport(tester, size: const Size(320, 844));
    await CatalogFavorites.instance.toggle(CatalogFavoriteKeys.decoration(_sticker.insertionValue));
    await tester.pumpWidget(auditFrame(_app(dark: true, scale: 1.6)));
    await _artwork(tester);
    expect(find.text('4개 항목'), findsOneWidget);
    await auditCapture(tester, 'saved-07-dark-large-text');
    final favoriteKey = CatalogFavoriteKeys.decoration(_sticker.insertionValue);
    await tester.tap(find.byKey(ValueKey('favorite-$favoriteKey')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBarAction), findsOneWidget);
    await auditCapture(tester, 'saved-08-dark-large-undo');
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(CatalogFavorites.instance.contains(favoriteKey), isTrue);
    expect(find.text('4개 항목'), findsOneWidget);
  });
}
