import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/album_invite_link.dart';
import 'package:snap_fit/features/album/service/album_invite_failure.dart';
import 'package:snap_fit/features/album/service/pending_album_invite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Store extends PendingAlbumInviteStore {
  Future<PendingAlbumInvite?> Function()? onRead;
  Future<void> Function(PendingAlbumInvite?)? onWrite;
  final writes = <PendingAlbumInvite?>[];
  @override
  Future<PendingAlbumInvite?> read() async =>
      onRead == null ? null : await onRead!();
  @override
  Future<void> write(PendingAlbumInvite? invite) async {
    writes.add(invite);
    await onWrite?.call(invite);
  }
}

Uri _link(String token) => Uri.parse('snapfit://invite?token=$token');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('invitation parser rejects ambiguous and unrelated links', () {
    expect(albumInviteTokenFromUri(_link('a-01_')), 'a-01_');
    for (final link in [
      'https://invite?token=a',
      'snapfit://auth?token=a',
      'snapfit://invite/path?token=a',
      'snapfit://invite?token=',
      'snapfit://invite?token=a&token=b',
      'snapfit://invite?token=a%20b',
      'snapfit://invite?token=a#b',
      'snapfit://user@invite?token=a',
      'snapfit://invite:12?token=a',
    ]) {
      expect(albumInviteTokenFromUri(Uri.parse(link)), isNull, reason: link);
    }
    expect(albumInviteTokenFromUri(_link('a' * 257)), isNull);
  });

  test(
    'secure store keeps token across restart and drops expired or malformed data',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = PendingAlbumInviteStore();
      final invite = PendingAlbumInvite('one', DateTime.now());
      await store.write(invite);
      expect((await PendingAlbumInviteStore().read())?.token, 'one');
      await store.write(
        PendingAlbumInvite(
          'old',
          DateTime.now().subtract(const Duration(days: 15)),
        ),
      );
      expect(await store.read(), isNull);
      await const FlutterSecureStorage().write(
        key: PendingAlbumInviteStore.key,
        value: jsonEncode({
          'token': ['bad'],
        }),
      );
      expect(await store.read(), isNull);
      await store.write(null);
      expect(
        await const FlutterSecureStorage().read(
          key: PendingAlbumInviteStore.key,
        ),
        isNull,
      );
    },
  );

  test('cold link wins over previously saved invitation', () async {
    final store = _Store()
      ..onRead = () async => PendingAlbumInvite('old', DateTime.now());
    final container = ProviderContainer(
      overrides: [pendingAlbumInviteStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final controller = container.read(pendingAlbumInviteProvider.notifier);
    controller.receive(_link('new'));
    await controller.restore();
    expect(container.read(pendingAlbumInviteProvider)?.token, 'new');
  });

  test(
    'link received while restoring wins; old completion cannot clear new request',
    () async {
      final restored = Completer<PendingAlbumInvite?>();
      final store = _Store()..onRead = () => restored.future;
      final container = ProviderContainer(
        overrides: [pendingAlbumInviteStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final controller = container.read(pendingAlbumInviteProvider.notifier);
      final restoring = controller.restore();
      controller.receive(_link('new'));
      final current = container.read(pendingAlbumInviteProvider)!;
      restored.complete(PendingAlbumInvite('old', DateTime.now()));
      await restoring;
      controller.clearIfCurrent(PendingAlbumInvite('new', DateTime.now()));
      expect(container.read(pendingAlbumInviteProvider), same(current));
      controller.receive(_link('new'));
      expect(container.read(pendingAlbumInviteProvider), same(current));
      controller.clearIfCurrent(current);
      expect(container.read(pendingAlbumInviteProvider), isNull);
    },
  );

  test(
    'persist writes remain ordered and recover after storage failure',
    () async {
      final blocked = Completer<void>();
      var count = 0;
      final store = _Store()
        ..onWrite = (_) async {
          if (++count == 1) {
            await blocked.future;
            throw StateError('fixture storage failure');
          }
        };
      final container = ProviderContainer(
        overrides: [pendingAlbumInviteStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final controller = container.read(pendingAlbumInviteProvider.notifier);
      controller.receive(_link('one'));
      controller.clearIfCurrent(container.read(pendingAlbumInviteProvider)!);
      controller.receive(_link('two'));
      await Future<void>.delayed(Duration.zero);
      expect(store.writes.map((i) => i?.token), ['one']);
      blocked.complete();
      await Future<void>.delayed(Duration.zero);
      expect(store.writes.map((i) => i?.token), ['one', null, 'two']);
    },
  );

  test(
    'error guidance is structured and never exposes raw backend error or token',
    () {
      for (final row in [
        (410, 'invite_expired'),
        (409, 'invite_used'),
        (404, 'invite_not_found'),
      ]) {
        final failure = AlbumInviteFailure.from(
          FunctionException(status: row.$1, details: {'error': row.$2}),
        );
        expect(failure.retryable, isFalse);
      }
      expect(
        AlbumInviteFailure.from(
          const FunctionException(status: 401),
        ).needsLogin,
        isTrue,
      );
      final failure = AlbumInviteFailure.from(
        Exception('secret-token backend stack'),
      );
      expect(failure.retryable, isTrue);
      expect(failure.message, isNot(contains('secret-token')));
    },
  );
}
