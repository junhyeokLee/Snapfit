import 'dart:async';

// Explicit review reproductions for unresolved findings. Run this file by
// name; it is deliberately outside the default *_test.dart regression suite.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_header.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/auth_gate.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';
import 'package:snap_fit/features/onboarding/presentation/widgets/first_home_guide.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';

import '../helpers/first_visit_fixtures.dart';
import '../widget/auth_gate_test.dart'
    show FakeAuthViewModel, FakeHomeViewModel;

class _DelayedStore extends MemoryFirstVisitStore {
  _DelayedStore([super.flags]);
  final release = Completer<void>();

  @override
  Future<void> write(int flags) async {
    await release.future;
    await super.write(flags);
  }
}

void main() {
  testWidgets(
    'iOS entry cannot show the guide before its target enters the screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firstVisitStoreProvider.overrideWithValue(MemoryFirstVisitStore(1)),
          ],
          child: MaterialApp(
            theme: SnapFitTheme.light().copyWith(platform: TargetPlatform.iOS),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: HomeAlbumHeader(
                            collection: false,
                            onCreateAlbum: () {},
                            createButtonBuilder: (button) =>
                                FirstHomeGuide(onCreate: () {}, child: button),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('메인 열기'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.text('메인 열기')),
      );
      await container.read(firstVisitProvider.future);
      await tester.tap(find.text('메인 열기'));
      await tester.pump();
      final screen = Offset.zero & const Size(390, 844);
      for (final elapsed in [1, 8, 16, 32, 64, 140, 280]) {
        await tester.pump(Duration(milliseconds: elapsed));
        final target = tester.getRect(
          find.byKey(const ValueKey('home-create-album')),
        );
        if (!target.overlaps(screen)) {
          final card = find.byKey(const ValueKey('first-home-guide'));
          final cardRect = card.evaluate().isEmpty
              ? null
              : tester.getRect(card);
          expect(
            cardRect?.overlaps(screen) ?? false,
            isFalse,
            reason: 'Offscreen target: $target; onscreen guide: $cardRect',
          );
        }
      }
      await tester.pumpAndSettle();
    },
  );
  for (final skipped in [false, true]) {
    test(
      'restart immediately after intro skipped=$skipped retains the decision',
      () async {
        final store = _DelayedStore();
        final first = ProviderContainer(
          overrides: [firstVisitStoreProvider.overrideWithValue(store)],
        );
        ProviderContainer? restarted;
        try {
          await first
              .read(firstVisitProvider.notifier)
              .completeIntroduction(skipped: skipped);
          restarted = ProviderContainer(
            overrides: [firstVisitStoreProvider.overrideWithValue(store)],
          );
          final restored = await restarted.read(firstVisitProvider.future);
          expect(
            restored.introductionSeen,
            isTrue,
            reason: 'The completed UI action must survive a new app session.',
          );
        } finally {
          store.release.complete();
          await Future<void>.delayed(Duration.zero);
          first.dispose();
          restarted?.dispose();
        }
      },
    );
  }

  test(
    'restart immediately after the main guide retains its dismissal',
    () async {
      final store = _DelayedStore(1);
      final first = ProviderContainer(
        overrides: [firstVisitStoreProvider.overrideWithValue(store)],
      );
      ProviderContainer? restarted;
      try {
        await first.read(firstVisitProvider.future);
        expect(first.read(firstVisitProvider.notifier).takeHomeGuide(), isTrue);
        restarted = ProviderContainer(
          overrides: [firstVisitStoreProvider.overrideWithValue(store)],
        );
        expect(
          (await restarted.read(firstVisitProvider.future)).shouldShowHomeGuide,
          isFalse,
        );
      } finally {
        store.release.complete();
        await Future<void>.delayed(Duration.zero);
        first.dispose();
        restarted?.dispose();
      }
    },
  );

  testWidgets(
    'a pending replay from the old account cannot open for the next account',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = FakeAuthViewModel(
        const UserInfo(id: 'owner-a', name: 'A', provider: 'kakao'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firstVisitStoreProvider.overrideWithValue(MemoryFirstVisitStore(3)),
            authViewModelProvider.overrideWith(() => auth),
            homeViewModelProvider.overrideWith(
              () => FakeHomeViewModel(const []),
            ),
            homeUiStateProvider.overrideWith(
              () => HomeUiStateNotifier(initialIndex: 0),
            ),
            pointShopCatalogProvider.overrideWith((_) async => []),
            ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AuthGate)),
      );
      container.read(firstVisitProvider.notifier).requestHomeGuide();
      auth.setUser(null);
      await tester.pumpAndSettle();
      auth.setUser(const UserInfo(id: 'owner-b', name: 'B', provider: 'kakao'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first-home-guide')), findsNothing);
    },
  );
}
