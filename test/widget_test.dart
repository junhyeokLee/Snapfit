import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';

import 'helpers/mock_repositories.dart';
import 'helpers/pump_app.dart';

void main() {
  testWidgets('앱 부팅 스모크 테스트', (WidgetTester tester) async {
    final mockRepo = MockAlbumRepository();
    stubFetchMyAlbums(mockRepo, []);
    await pumpSnapFitApp(tester, overrides: [
      albumRepositoryProvider.overrideWithValue(mockRepo),
    ]);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
