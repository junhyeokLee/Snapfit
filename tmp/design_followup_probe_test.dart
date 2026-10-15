import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/profile/presentation/views/billing_management_screen.dart';
import 'package:snap_fit/features/splash/presentation/views/splash_screen.dart';
import '../test/support/point_purchase_fakes.dart';
import '../test/widget/ai_album_start_step_test.dart' show loadCreationFonts;

class _LoadingAuth extends AuthViewModel {
  @override
  Future<UserInfo?> build() => Completer<UserInfo?>().future;
}

class _Shop extends PointShopRepository {
  _Shop(this.insufficient);
  final bool insufficient;
  @override
  String? get currentUserId => 'review';
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  Future<List<PointShopProduct>> loadCatalog() async => [];
  @override
  Future<Set<String>> loadOwnedKeys() async => {};
  @override
  Future<void> saveProduct(PointShopProduct product) async {}
  @override
  Future<PointShopAccess> getAccess(String key) async => PointShopAccess(
    productKey: key,
    title: '같이 사는 계절',
    pointPrice: 950,
    available: true,
    isFree: false,
    owned: false,
    remainingBalance: insufficient ? 150 : 2000,
  );
  @override
  Future<PointShopPurchase> purchase(String key, int expectedPrice) =>
      throw StateError('Review never purchases');
}

class _PurchaseProbe extends ConsumerWidget {
  const _PurchaseProbe();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => ensurePointShopAccess(
          context,
          ref,
          productKey: 'template:shared-seasons',
          title: '같이 사는 계절',
        ),
        child: const Text('검토'),
      ),
    ),
  );
}

void main() {
  final observations = <Map<String, Object?>>[];
  setUpAll(loadCreationFonts);
  for (final viewport in [const Size(390, 844), const Size(844, 390)]) {
    for (final dark in [false, true]) {
      for (final state in ['purchase', 'insufficient', 'points', 'splash']) {
        final name =
            '$state-${viewport.width.toInt()}-${dark ? 'dark' : 'light'}';
        testWidgets('review capture $name', (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = FakeViewPadding(
            bottom: 24,
            right: viewport.width > viewport.height ? 32 : 0,
          );
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          final key = GlobalKey();
          final errors = <String>[];
          final oldHandler = FlutterError.onError;
          FlutterError.onError = (details) =>
              errors.add(details.exceptionAsString());
          addTearDown(() => FlutterError.onError = oldHandler);
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: ProviderScope(
                overrides: [
                  authViewModelProvider.overrideWith(_LoadingAuth.new),
                  pointShopRepositoryProvider.overrideWithValue(
                    _Shop(state == 'insufficient'),
                  ),
                  pointPurchaseServiceProvider.overrideWith((ref) {
                    final service = fakePointPurchaseService();
                    ref.onDispose(service.dispose);
                    return service;
                  }),
                  myPointBalanceProvider.overrideWith((_) async => 2000),
                  myPointLedgerProvider.overrideWith((_) async => []),
                ],
                child: ScreenUtilInit(
                  designSize: const Size(390, 844),
                  builder: (_, child) => MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: SnapFitTheme.light(),
                    darkTheme: SnapFitTheme.dark(),
                    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                    home: state == 'points'
                        ? const BillingManagementScreen()
                        : state == 'splash'
                        ? const SplashScreen()
                        : const _PurchaseProbe(),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          if (state == 'purchase' || state == 'insufficient') {
            await tester.tap(find.text('검토'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          }
          await tester.runAsync(() async {
            for (final element in find.byType(Image).evaluate()) {
              await precacheImage((element.widget as Image).image, element);
            }
          });
          await tester.pump();
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('output/design-followup-qa/after/$name.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          observations.add({
            'capture': name,
            'errors': errors,
            'scope': 'mocked UI; no real purchase, points or authentication',
          });
          expect(errors, isEmpty);
          if (find.text('취소').evaluate().isNotEmpty) {
            await tester.tap(find.text('취소'));
            await tester.pump(const Duration(milliseconds: 300));
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  tearDownAll(() async {
    await File(
      'output/design-followup-qa/after/observations.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(observations));
  });
}
