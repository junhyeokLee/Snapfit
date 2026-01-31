import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';

import '../helpers/fake_album.dart';
import '../helpers/mock_repositories.dart';
import '../helpers/pump_app.dart';

void main() {
  late MockAlbumRepository mockRepo;

  setUp(() {
    mockRepo = MockAlbumRepository();
  });

  testWidgets('앨범 목록 로딩 후 비어있으면 빈 상태 문구 표시', (WidgetTester tester) async {
    stubFetchMyAlbums(mockRepo, []);
    await pumpSnapFitApp(tester, overrides: [
      albumRepositoryProvider.overrideWithValue(mockRepo),
    ]);

    expect(find.text('앨범이 비어있습니다.'), findsOneWidget);
  });

  testWidgets('앨범이 있으면 앨범 슬라이더 표시', (WidgetTester tester) async {
    final album = fakeAlbum(id: 42, ratio: '0.75');
    stubFetchMyAlbums(mockRepo, [album]);
    await pumpSnapFitApp(tester, overrides: [
      albumRepositoryProvider.overrideWithValue(mockRepo),
    ]);

    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('FAB 탭 시 /add_cover 라우트로 이동', (WidgetTester tester) async {
    stubFetchMyAlbums(mockRepo, []);
    await pumpSnapFitApp(tester, overrides: [
      albumRepositoryProvider.overrideWithValue(mockRepo),
    ]);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('완료'), findsOneWidget);
  });
}
