import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/service/pending_album_invite.dart';
import 'package:snap_fit/features/referral/data/pending_referral.dart';
import 'package:snap_fit/features/referral/domain/referral_link.dart';

const _one = 'ABCD2345XY';
const _two = 'JKMP2345XY';
const _three = 'PQRS2345XY';

class _Store extends PendingReferralStore {
  Future<PendingReferral?> Function()? onRead;
  Future<void> Function(PendingReferral?)? onWrite;
  final writes = <PendingReferral?>[];

  @override
  Future<PendingReferral?> read() async =>
      onRead == null ? null : await onRead!();

  @override
  Future<void> write(PendingReferral? referral) async {
    writes.add(referral);
    await onWrite?.call(referral);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'secure persistence survives an OAuth restart without touching album invites',
    () async {
      final now = DateTime.utc(2026, 10, 26, 3);
      FlutterSecureStorage.setMockInitialValues({});
      final store = PendingReferralStore(now: () => now);
      await const FlutterSecureStorage().write(
        key: PendingAlbumInviteStore.key,
        value: 'existing-collaboration-invitation',
      );
      await store.write(PendingReferral(_one, now));
      final restored = await PendingReferralStore(now: () => now).read();
      expect(restored?.code, _one);
      expect(restored?.receivedAt, now);
      await store.write(null);
      expect(await store.read(), isNull);
      expect(
        await const FlutterSecureStorage().read(
          key: PendingAlbumInviteStore.key,
        ),
        'existing-collaboration-invitation',
      );
    },
  );

  test(
    'saved codes expire exactly at seven days and future receipt times are ignored',
    () async {
      final now = DateTime.utc(2026, 10, 26, 3);
      FlutterSecureStorage.setMockInitialValues({});
      final store = PendingReferralStore(now: () => now);
      await store.write(
        PendingReferral(
          _one,
          now
              .subtract(PendingReferralStore.lifetime)
              .add(const Duration(seconds: 1)),
        ),
      );
      expect((await store.read())?.code, _one);
      for (final timestamp in [
        now.subtract(PendingReferralStore.lifetime),
        now.subtract(const Duration(days: 8)),
        now.add(const Duration(seconds: 1)),
      ]) {
        await store.write(PendingReferral(_one, timestamp));
        expect(await store.read(), isNull, reason: timestamp.toIso8601String());
      }
    },
  );

  test('malformed stored data is ignored instead of blocking login', () async {
    final now = DateTime.utc(2026, 10, 26, 3);
    FlutterSecureStorage.setMockInitialValues({});
    final store = PendingReferralStore(now: () => now);
    for (final raw in [
      'not-json',
      '[]',
      jsonEncode({
        'code': [_one],
        'receivedAt': now.toIso8601String(),
      }),
      jsonEncode({'code': 'ABCD2345X0', 'receivedAt': now.toIso8601String()}),
      jsonEncode({'code': _one, 'receivedAt': 'yesterday'}),
      jsonEncode({'code': _one}),
    ]) {
      await const FlutterSecureStorage().write(
        key: PendingReferralStore.key,
        value: raw,
      );
      expect(await store.read(), isNull, reason: raw);
    }
  });

  test(
    'a received public link wins over stale storage and only restores once',
    () async {
      var reads = 0;
      final store = _Store()
        ..onRead = () async {
          reads++;
          return PendingReferral(_one, DateTime.now());
        };
      final container = ProviderContainer(
        overrides: [pendingReferralStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final controller = container.read(pendingReferralProvider.notifier);
      expect(controller.receive(referralShareUri(_two)), isTrue);
      await controller.restore();
      await controller.persisted;
      expect(container.read(pendingReferralProvider)?.code, _two);
      expect(reads, 0);
      await controller.restore();
      expect(reads, 0);
    },
  );

  test(
    'a persisted code survives login redirection into a fresh provider scope',
    () async {
      final store = _Store();
      final before = ProviderContainer(
        overrides: [pendingReferralStoreProvider.overrideWithValue(store)],
      );
      final controller = before.read(pendingReferralProvider.notifier);
      controller.receive(referralShareUri(_one));
      await controller.persisted;
      final saved = store.writes.single;
      before.dispose();
      store.onRead = () async => saved;
      final after = ProviderContainer(
        overrides: [pendingReferralStoreProvider.overrideWithValue(store)],
      );
      addTearDown(after.dispose);
      await after.read(pendingReferralProvider.notifier).restore();
      expect(after.read(pendingReferralProvider)?.code, _one);
      expect(
        after
            .read(pendingReferralProvider.notifier)
            .receive(Uri.parse('https://external.example/friends/$_two')),
        isFalse,
      );
      expect(after.read(pendingReferralProvider)?.code, _one);
    },
  );

  test(
    'a slow restore or obsolete registration cannot overwrite a newer friend code',
    () async {
      final restoring = Completer<PendingReferral?>();
      final store = _Store()..onRead = () => restoring.future;
      final container = ProviderContainer(
        overrides: [pendingReferralStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final controller = container.read(pendingReferralProvider.notifier);
      final restored = controller.restore();
      controller.receive(referralShareUri(_two));
      final second = container.read(pendingReferralProvider)!;
      restoring.complete(PendingReferral(_one, DateTime.now()));
      await restored;
      expect(container.read(pendingReferralProvider), same(second));
      controller.clearIfCurrent(PendingReferral(_two, second.receivedAt));
      expect(container.read(pendingReferralProvider), same(second));
      controller.receive(referralShareUri(_three));
      controller.clearIfCurrent(second);
      expect(container.read(pendingReferralProvider)?.code, _three);
      controller.clearIfCurrent(container.read(pendingReferralProvider)!);
      await controller.persisted;
      expect(container.read(pendingReferralProvider), isNull);
      expect(store.writes.map((value) => value?.code), [_two, _three, null]);
    },
  );

  test(
    'tapping the same invitation again signals a fresh explicit intake',
    () async {
      final store = _Store();
      final container = ProviderContainer(
        overrides: [pendingReferralStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final controller = container.read(pendingReferralProvider.notifier);
      controller.receive(referralShareUri(_one));
      final original = container.read(pendingReferralProvider);
      controller.receive(Uri.parse('snapfit://friends?code=$_one'));
      await controller.persisted;
      expect(container.read(pendingReferralProvider), isNot(same(original)));
      expect(container.read(pendingReferralProvider)?.code, _one);
      expect(store.writes, hasLength(2));
    },
  );

  test(
    'storage failures preserve receive-clear ordering and never block a new code',
    () async {
      final blocked = Completer<void>();
      var calls = 0;
      final store = _Store()
        ..onWrite = (_) async {
          if (++calls == 1) {
            await blocked.future;
            throw StateError('Storage temporarily locked');
          }
        };
      final container = ProviderContainer(
        overrides: [pendingReferralStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final controller = container.read(pendingReferralProvider.notifier);
      controller.receive(referralShareUri(_one));
      controller.clearIfCurrent(container.read(pendingReferralProvider)!);
      controller.receive(referralShareUri(_two));
      await Future<void>.delayed(Duration.zero);
      expect(store.writes.map((value) => value?.code), [_one]);
      blocked.complete();
      await controller.persisted;
      expect(store.writes.map((value) => value?.code), [_one, null, _two]);
      expect(container.read(pendingReferralProvider)?.code, _two);
    },
  );

  test(
    'disposing a login scope while storage reads does not resurrect its draft',
    () async {
      final loading = Completer<PendingReferral?>();
      final store = _Store()..onRead = () => loading.future;
      final container = ProviderContainer(
        overrides: [pendingReferralStoreProvider.overrideWithValue(store)],
      );
      final restore = container
          .read(pendingReferralProvider.notifier)
          .restore();
      container.dispose();
      loading.complete(PendingReferral(_one, DateTime.now()));
      await restore;
      expect(store.writes, isEmpty);
    },
  );
}
