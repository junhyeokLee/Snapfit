import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';

import 'helpers/mock_repositories.dart';
import 'helpers/pump_app.dart';

class _MockPointPurchaseService extends Mock implements PointPurchaseService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://smoke-test.invalid',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets('앱 부팅 스모크 테스트', (WidgetTester tester) async {
    final mockRepo = MockAlbumRepository();
    stubFetchMyAlbums(mockRepo, []);
    final purchases = _MockPointPurchaseService();
    when(() => purchases.recover()).thenAnswer((_) async {});
    await pumpSnapFitApp(
      tester,
      overrides: [
        albumRepositoryProvider.overrideWithValue(mockRepo),
        pointPurchaseServiceProvider.overrideWithValue(purchases),
      ],
    );
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
    verify(() => purchases.start()).called(1);
    verify(() => purchases.recover()).called(1);
  });
}
