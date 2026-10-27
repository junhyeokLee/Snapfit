import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/onboarding/data/first_visit_store.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';

import '../helpers/first_visit_fixtures.dart';

ProviderContainer _container(FirstVisitStore store) {
  final container = ProviderContainer(
    overrides: [firstVisitStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _SlowWriteStore extends MemoryFirstVisitStore {
  final firstWrite = Completer<void>();
  @override
  Future<void> write(int flags) async {
    if (writes.isEmpty) {
      writes.add(flags);
      await firstWrite.future;
      this.flags = flags;
    } else {
      await super.write(flags);
    }
  }
}

class _FailingStore implements FirstVisitStore {
  @override
  Future<int> read() async => throw StateError('unavailable');
  @override
  Future<void> write(int _) async => throw StateError('unavailable');
}

void main() {
  test('one preferences read is shared by intro and guide consumers', () async {
    final store = MemoryFirstVisitStore();
    final container = _container(store);
    await Future.wait([
      container.read(firstVisitProvider.future),
      container.read(firstVisitProvider.future),
    ]);
    expect(store.reads, 1);
    expect(container.read(firstVisitProvider).requireValue.flags, 0);
    expect(store.writes, isEmpty);
  });

  test('finishing introduction leaves one main guide pending', () async {
    final store = MemoryFirstVisitStore();
    final container = _container(store);
    await container.read(firstVisitProvider.future);
    final controller = container.read(firstVisitProvider.notifier);
    await controller.completeIntroduction(skipped: false);
    expect(
      container.read(firstVisitProvider).requireValue.shouldShowHomeGuide,
      isTrue,
    );
    expect(controller.takeHomeGuide(), isTrue);
    expect(controller.takeHomeGuide(), isFalse);
    await _flush();
    expect(store.flags, 3);
    expect(store.writes, [1, 3]);
  });

  test('skip persists both opt-outs across a new session', () async {
    final store = MemoryFirstVisitStore();
    final first = _container(store);
    await first
        .read(firstVisitProvider.notifier)
        .completeIntroduction(skipped: true);
    await _flush();
    final restored = await _container(store).read(firstVisitProvider.future);
    expect(restored.introductionSeen, isTrue);
    expect(restored.shouldShowHomeGuide, isFalse);
    expect(store.flags, 3);
  });

  test(
    'guide replay is consumed once and never resets first-visit flags',
    () async {
      final store = MemoryFirstVisitStore(3);
      final container = _container(store);
      await container.read(firstVisitProvider.future);
      final controller = container.read(firstVisitProvider.notifier);
      controller.requestHomeGuide();
      expect(
        container.read(firstVisitProvider).requireValue.homeGuideRequested,
        isTrue,
      );
      expect(controller.takeHomeGuide(), isTrue);
      expect(controller.takeHomeGuide(), isFalse);
      await _flush();
      final restored = await _container(store).read(firstVisitProvider.future);
      expect(restored.flags, 3);
      expect(restored.homeGuideRequested, isFalse);
      expect(restored.shouldShowHomeGuide, isFalse);
      expect(store.writes, isEmpty);
    },
  );

  test('a slow older write cannot erase the newer guide decision', () async {
    final store = _SlowWriteStore();
    final container = _container(store);
    final controller = container.read(firstVisitProvider.notifier);
    await controller.completeIntroduction(skipped: false);
    expect(controller.takeHomeGuide(), isTrue);
    await _flush();
    expect(store.writes, [1]);
    store.firstWrite.complete();
    await _flush();
    expect(store.writes, [1, 3]);
    expect(store.flags, 3);
  });

  test(
    'unavailable storage still remembers dismissal within the session',
    () async {
      final container = _container(_FailingStore());
      final controller = container.read(firstVisitProvider.notifier);
      await controller.completeIntroduction(skipped: false);
      expect(controller.takeHomeGuide(), isTrue);
      await _flush();
      expect(controller.takeHomeGuide(), isFalse);
      expect(container.read(firstVisitProvider).requireValue.flags, 3);
    },
  );

  test(
    'preferences adapter restores flags without an account identifier',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = PreferencesFirstVisitStore();
      expect(await store.read(), 0);
      await store.write(3);
      expect(await PreferencesFirstVisitStore().read(), 3);
    },
  );
}
