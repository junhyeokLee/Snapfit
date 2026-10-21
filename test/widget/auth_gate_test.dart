import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/auth_gate.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/auth/presentation/providers/public_template_return_intent.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel(this.user);

  final UserInfo? user;

  @override
  FutureOr<UserInfo?> build() => user;

  void setUser(UserInfo? next) => state = AsyncData(next);
}

class LoadingAuthViewModel extends AuthViewModel {
  LoadingAuthViewModel(this._completer);

  final Completer<UserInfo?> _completer;

  @override
  FutureOr<UserInfo?> build() => _completer.future;
}

class FakeHomeViewModel extends HomeViewModel {
  FakeHomeViewModel(this.albums);

  final List<Album> albums;

  @override
  FutureOr<List<Album>> build() => albums;
}

Future<ProviderContainer> _mountReturnFlow(
  WidgetTester tester,
  FakeAuthViewModel auth,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(() => auth),
        homeViewModelProvider.overrideWith(() => FakeHomeViewModel(const [])),
        templateListProvider.overrideWith((_) async => []),
        pointShopCatalogProvider.overrideWith((_) async => []),
        publicPointShopCatalogProvider.overrideWith((_) async => []),
        ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => const MaterialApp(home: AuthGate()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(AuthGate)));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());
  testWidgets('AuthGate shows LoginScreen when user is null', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => FakeAuthViewModel(null)),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(home: AuthGate()),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('카카오로 계속하기'), findsOneWidget);
  });

  testWidgets('AuthGate shows HomeScreen when user exists', (tester) async {
    final user = UserInfo(id: '7', name: 'Tester', provider: 'kakao');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => FakeAuthViewModel(user)),
          homeViewModelProvider.overrideWith(() => FakeHomeViewModel(const [])),
          templateListProvider.overrideWith((_) async => []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(home: AuthGate()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('AuthGate shows loading indicator while auth is loading', (
    tester,
  ) async {
    final completer = Completer<UserInfo?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(
            () => LoadingAuthViewModel(completer),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(home: AuthGate()),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'native guest selection returns to the canonical detail once after login',
    (tester) async {
      final auth = FakeAuthViewModel(null);
      final container = await _mountReturnFlow(tester, auth);
      final canonical = publishedCreationTemplates.first;
      Navigator.of(tester.element(find.byType(LoginScreen))).push(
        MaterialPageRoute<void>(
          builder: (_) => TemplateDetailScreen(
            template: canonical.copyWith(title: '게스트 화면에서 변경된 제목'),
            guestPreview: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('로그인하고 이 디자인으로 시작'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(container.read(publicTemplateReturnIntentProvider), canonical.id);
      final user = UserInfo(
        id: 'return-owner',
        name: 'Tester',
        provider: 'kakao',
      );
      auth.setUser(user);
      await tester.pumpAndSettle();
      final detail = tester.widget<TemplateDetailScreen>(
        find.byType(TemplateDetailScreen),
      );
      expect(identical(detail.template, canonical), isTrue);
      expect(detail.guestPreview, isFalse);
      expect(container.read(publicTemplateReturnIntentProvider), isNull);
      Navigator.of(tester.element(find.byType(TemplateDetailScreen))).pop();
      await tester.pumpAndSettle();
      auth.setUser(user);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateDetailScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('logout before the scheduled return cancels the choice', (
    tester,
  ) async {
    final auth = FakeAuthViewModel(null);
    final container = await _mountReturnFlow(tester, auth);
    container
        .read(publicTemplateReturnIntentProvider.notifier)
        .remember(publishedCreationTemplates.first.id);
    auth.setUser(
      UserInfo(id: 'previous-owner', name: 'Tester', provider: 'kakao'),
    );
    auth.setUser(null);
    await tester.pumpAndSettle();
    expect(container.read(publicTemplateReturnIntentProvider), isNull);
    expect(find.byType(TemplateDetailScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('changing accounts invalidates an already scheduled return', (
    tester,
  ) async {
    final auth = FakeAuthViewModel(null);
    final container = await _mountReturnFlow(tester, auth);
    container
        .read(publicTemplateReturnIntentProvider.notifier)
        .remember(publishedCreationTemplates.first.id);
    auth.setUser(UserInfo(id: 'first-owner', name: 'First', provider: 'kakao'));
    auth.setUser(
      UserInfo(id: 'second-owner', name: 'Second', provider: 'kakao'),
    );
    await tester.pumpAndSettle();
    expect(container.read(publicTemplateReturnIntentProvider), isNull);
    expect(find.byType(TemplateDetailScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
