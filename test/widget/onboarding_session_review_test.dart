import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'package:snap_fit/features/onboarding/presentation/app_introduction_screen.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/splash/presentation/views/splash_screen.dart';

import '../helpers/first_visit_fixtures.dart';
import 'auth_gate_test.dart' show FakeAuthViewModel, FakeHomeViewModel;

const _ownerA = UserInfo(id: 'owner-a', name: 'A', provider: 'kakao');
const _ownerB = UserInfo(id: 'owner-b', name: 'B', provider: 'kakao');
final _guide = find.byKey(const ValueKey('first-home-guide'));

Future<void> _launch(
  WidgetTester tester,
  MemoryFirstVisitStore store,
  FakeAuthViewModel auth,
) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        firstVisitStoreProvider.overrideWithValue(store),
        authViewModelProvider.overrideWith(() => auth),
        homeViewModelProvider.overrideWith(() => FakeHomeViewModel(const [])),
        // The first-use guide belongs to a loaded private journal.
        momentEntryJournalProvider.overrideWith((ref) async {
          if (ref.watch(authViewModelProvider).asData?.value == null)
            return null;
          return MomentJournal(
            today: DateTime.utc(2026, 11, 4),
            weekStart: DateTime.utc(2026, 11, 2),
            month: DateTime.utc(2026, 11),
            records: const [],
            weekPhotoCount: 0,
          );
        }),
        homeUiStateProvider.overrideWith(
          () => HomeUiStateNotifier(initialIndex: 0),
        ),
        pointShopCatalogProvider.overrideWith((_) async => []),
        ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
      ],
      child: const MaterialApp(home: SplashScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 950));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'seen intro and guide stay dismissed across logout, direct switch, and restart',
    (tester) async {
      final store = MemoryFirstVisitStore(3);
      final auth = FakeAuthViewModel(_ownerA);
      await _launch(tester, store, auth);
      expect(find.byType(AppIntroductionScreen), findsNothing);
      expect(_guide, findsNothing);
      auth.setUser(_ownerB);
      await tester.pumpAndSettle();
      expect(_guide, findsNothing);
      auth.setUser(null);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      auth.setUser(_ownerA);
      await tester.pumpAndSettle();
      expect(_guide, findsNothing);
      expect(store.reads, 1);
      await tester.pumpWidget(const SizedBox());
      await _launch(tester, store, FakeAuthViewModel(_ownerB));
      expect(find.byType(AppIntroductionScreen), findsNothing);
      expect(_guide, findsNothing);
      expect(store.reads, 2);
      expect(store.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completed intro waits for the first main visit across guest restart, then remains seen',
    (tester) async {
      final store = MemoryFirstVisitStore(1);
      final auth = FakeAuthViewModel(null);
      await _launch(tester, store, auth);
      expect(find.byType(AppIntroductionScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(store.flags, 1);
      auth.setUser(_ownerA);
      await tester.pumpAndSettle();
      expect(_guide, findsOneWidget);
      await tester.tap(find.byTooltip('안내 닫기'));
      await tester.pumpAndSettle();
      expect(store.flags, 3);
      auth.setUser(null);
      await tester.pumpAndSettle();
      auth.setUser(_ownerB);
      await tester.pumpAndSettle();
      expect(_guide, findsNothing);
      await tester.pumpWidget(const SizedBox());
      await _launch(tester, store, FakeAuthViewModel(_ownerB));
      expect(find.byType(AppIntroductionScreen), findsNothing);
      expect(_guide, findsNothing);
      expect(store.writes, [3]);
      expect(tester.takeException(), isNull);
    },
  );
}
