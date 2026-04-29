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

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel(this.user);

  final UserInfo? user;

  @override
  FutureOr<UserInfo?> build() => user;
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

void main() {
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
    final user = UserInfo(id: 7, name: 'Tester', provider: 'kakao');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => FakeAuthViewModel(user)),
          homeViewModelProvider.overrideWith(() => FakeHomeViewModel(const [])),
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
}
