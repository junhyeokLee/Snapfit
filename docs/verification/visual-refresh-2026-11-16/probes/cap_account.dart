// 실제 설정 화면을 로컬 가짜 계정으로만 캡처한다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/core/theme/theme_mode_controller.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/home_news/data/admin_home_news_repository.dart';
import 'package:snap_fit/features/profile/presentation/views/account_settings_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/admin_point_shop_management_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';

import 'capture_support.dart';

class _AccountAuth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() => const UserInfo(
    id: 'local-account-audit',
    name: '준혁',
    provider: 'kakao',
    email: 'junhyeok@example.com',
  );
}

class _AccountTheme extends ThemeModeController {
  _AccountTheme(this.mode);

  final ThemeMode mode;

  @override
  ThemeMode build() => mode;
}

Widget _accountApp({required bool dark, required double textScale}) =>
    ProviderScope(
      key: UniqueKey(),
      retry: (_, __) => null,
      overrides: [
        authViewModelProvider.overrideWith(_AccountAuth.new),
        themeModeControllerProvider.overrideWith(
          () => _AccountTheme(dark ? ThemeMode.dark : ThemeMode.light),
        ),
        // 권한 조회가 원격 클라이언트에 닿지 않도록 일반 사용자로 고정한다.
        pointShopAdminAccessProvider.overrideWithValue(false),
        adminHomeNewsAccessProvider.overrideWithValue(false),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => auditFrame(
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
          ),
          home: const MyPageScreen(),
        ),
      ),
    );

void main() {
  setUpAll(auditFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final state in [
    (name: 'light', size: const Size(390, 844), dark: false, scale: 1.0),
    (name: 'narrow-large', size: const Size(320, 720), dark: false, scale: 1.6),
    (name: 'dark', size: const Size(390, 844), dark: true, scale: 1.0),
  ]) {
    testWidgets('capture settings and account ${state.name}', (tester) async {
      auditViewport(tester, size: state.size);
      await tester.pumpWidget(
        _accountApp(dark: state.dark, textScale: state.scale),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MyPageScreen), findsOneWidget);
      await auditCapture(tester, 'account-settings-${state.name}');

      // 같은 설정 목록의 실제 탐색 경로로 계정 설정을 연다.
      await tester.tap(find.byTooltip('계정 설정'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSettingsScreen), findsOneWidget);
      expect(find.text('준혁'), findsOneWidget);
      await auditCapture(tester, 'account-profile-${state.name}');
      expect(tester.takeException(), isNull);
    });
  }
}
