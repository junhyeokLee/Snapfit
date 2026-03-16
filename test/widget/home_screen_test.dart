import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';

import '../helpers/fake_album.dart';
import '../helpers/mock_repositories.dart';

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel(this.user);

  final UserInfo? user;

  @override
  Future<UserInfo?> build() => Future.value(user);
}

Future<void> _setLargeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  late MockAlbumRepository mockRepo;

  setUp(() {
    mockRepo = MockAlbumRepository();
  });

  testWidgets('앨범 목록 로딩 후 비어있으면 빈 상태 문구 표시', (WidgetTester tester) async {
    await _setLargeSurface(tester);
    stubFetchMyAlbums(mockRepo, []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(const UserInfo(id: 1, name: 'User', provider: 'kakao')),
          ),
          templateListProvider.overrideWith((ref) async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(home: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('아직 참여 중인 앨범이 없습니다.'), findsOneWidget);
  });

  testWidgets('앨범이 있으면 앨범 슬라이더 표시', (WidgetTester tester) async {
    await _setLargeSurface(tester);
    final album = fakeAlbum(id: 42, ratio: '0.75');
    stubFetchMyAlbums(mockRepo, [album]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(const UserInfo(id: 1, name: 'User', provider: 'kakao')),
          ),
          templateListProvider.overrideWith((ref) async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(home: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('앨범 만들기 버튼 탭 시 생성 플로우로 이동', (WidgetTester tester) async {
    await _setLargeSurface(tester);
    stubFetchMyAlbums(mockRepo, []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(const UserInfo(id: 1, name: 'User', provider: 'kakao')),
          ),
          templateListProvider.overrideWith((ref) async => const []),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(home: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumCreateFlowScreen), findsOneWidget);
  });
}
