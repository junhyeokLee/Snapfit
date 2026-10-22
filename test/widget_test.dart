import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/auth/presentation/views/auth_gate.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:snap_fit/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/mock_repositories.dart';
import 'helpers/pump_app.dart';

void main() {
  testWidgets('앱 부팅 스모크 테스트', (WidgetTester tester) async {
    final mockRepo = MockAlbumRepository();
    stubFetchMyAlbums(mockRepo, []);
    final session = await pumpSnapFitApp(
      tester,
      overrides: [albumRepositoryProvider.overrideWithValue(mockRepo)],
    );
    expect(find.byType(MoaEditorApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AuthGate), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(Supabase.instance.client.auth.currentUser, isNull);
    expect(session.requests, isEmpty);
    expect(session.store.accountId, isNull);
    expect(session.store.finished, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
