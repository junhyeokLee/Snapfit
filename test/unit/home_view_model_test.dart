import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';

import '../helpers/fake_album.dart';
import '../helpers/mock_repositories.dart';

final _testOwner = NotifierProvider<_TestOwner, String?>(_TestOwner.new);

class _TestOwner extends Notifier<String?> {
  @override
  String? build() => 'owner';
  void change(String? value) => state = value;
}

void main() {
  late MockAlbumRepository mockRepo;

  setUp(() {
    mockRepo = MockAlbumRepository();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        albumEditorOwnerReaderProvider.overrideWithValue(() => 'owner'),
        albumCurrentSessionOwnerProvider.overrideWithValue('owner'),
        albumRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    container.listen(homeViewModelProvider, (_, _) {});
    addTearDown(container.dispose);
    return container;
  }

  test(
    'pending refresh retains data and coalesces overlapping requests',
    () async {
      final albums = [fakeAlbum(id: 1), fakeAlbum(id: 2)];
      stubFetchMyAlbums(mockRepo, albums);
      final container = createContainer();
      await container.read(homeViewModelProvider.future);
      final pending = Completer<List<Album>>();
      when(() => mockRepo.fetchMyAlbums()).thenAnswer((_) => pending.future);

      final notifier = container.read(homeViewModelProvider.notifier);
      final first = notifier.refresh();
      final second = notifier.refresh();
      expect(second, same(first));
      final duringRefresh = container.read(homeViewModelProvider);
      expect(duringRefresh.requireValue, same(albums));
      expect(
        duringRefresh.when(
          data: (_) => 'data',
          error: (_, _) => 'error',
          loading: () => 'loading',
        ),
        'data',
      );
      verify(() => mockRepo.fetchMyAlbums()).called(2);

      final updated = [fakeAlbum(id: 3)];
      pending.complete(updated);
      await Future.wait([first, second]);
      expect(container.read(homeViewModelProvider).requireValue, same(updated));
    },
  );

  test('failed refresh retains albums and permits a later retry', () async {
    final albums = [fakeAlbum()];
    stubFetchMyAlbums(mockRepo, albums);
    final container = createContainer();
    await container.read(homeViewModelProvider.future);
    final pending = Completer<List<Album>>();
    when(() => mockRepo.fetchMyAlbums()).thenAnswer((_) => pending.future);
    final notifier = container.read(homeViewModelProvider.notifier);
    final refresh = notifier.refresh();
    pending.completeError(StateError('offline'));
    await refresh;
    expect(container.read(homeViewModelProvider).requireValue, same(albums));
    expect(container.read(homeViewModelProvider).hasError, isFalse);

    final updated = [fakeAlbum(id: 2)];
    when(() => mockRepo.fetchMyAlbums()).thenAnswer((_) async => updated);
    await notifier.refresh();
    expect(container.read(homeViewModelProvider).requireValue, same(updated));
  });

  test(
    'refresh without data exposes loading and errors, then recovers',
    () async {
      when(() => mockRepo.fetchMyAlbums()).thenThrow(StateError('offline'));
      final container = createContainer();
      await expectLater(
        container.read(homeViewModelProvider.future),
        throwsStateError,
      );
      final pending = Completer<List<Album>>();
      when(() => mockRepo.fetchMyAlbums()).thenAnswer((_) => pending.future);
      final notifier = container.read(homeViewModelProvider.notifier);
      final refresh = notifier.refresh();
      expect(container.read(homeViewModelProvider).isLoading, isTrue);
      expect(container.read(homeViewModelProvider).hasValue, isFalse);
      pending.completeError(StateError('still offline'));
      await refresh;
      expect(container.read(homeViewModelProvider).hasError, isTrue);
      when(() => mockRepo.fetchMyAlbums()).thenAnswer((_) async => []);
      await notifier.refresh();
      expect(container.read(homeViewModelProvider).requireValue, isEmpty);
    },
  );

  test(
    'refresh completion after disposal does not write provider state',
    () async {
      stubFetchMyAlbums(mockRepo, [fakeAlbum()]);
      final container = ProviderContainer(
        overrides: [
          albumEditorOwnerReaderProvider.overrideWithValue(() => 'owner'),
          albumCurrentSessionOwnerProvider.overrideWithValue('owner'),
          albumRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      container.listen(homeViewModelProvider, (_, _) {});
      await container.read(homeViewModelProvider.future);
      final pending = Completer<List<Album>>();
      when(() => mockRepo.fetchMyAlbums()).thenAnswer((_) => pending.future);
      final refresh = container.read(homeViewModelProvider.notifier).refresh();
      container.dispose();
      pending.complete([fakeAlbum(id: 2)]);
      await expectLater(refresh, completes);
    },
  );

  test('reorder updates order locally and calls repository', () async {
    final albums = [
      fakeAlbum(id: 1).copyWith(orders: 0),
      fakeAlbum(id: 2).copyWith(orders: 1),
    ];

    stubFetchMyAlbums(mockRepo, albums);
    when(() => mockRepo.reorderAlbums(any())).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        albumEditorOwnerReaderProvider.overrideWithValue(() => 'owner'),
        albumCurrentSessionOwnerProvider.overrideWithValue('owner'),
        albumRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeViewModelProvider.future);

    final notifier = container.read(homeViewModelProvider.notifier);
    await notifier.reorder(0, 2);

    final state = container.read(homeViewModelProvider).value;
    expect(state, isNotNull);
    expect(state!.map((album) => album.id), [2, 1]);
    expect(state[0].orders, 0);
    expect(state[1].orders, 1);

    verify(() => mockRepo.reorderAlbums([2, 1])).called(1);
  });

  test(
    'deleteAlbum removes item optimistically and calls repository',
    () async {
      final albums = [fakeAlbum(id: 1), fakeAlbum(id: 2)];

      stubFetchMyAlbums(mockRepo, albums);
      when(() => mockRepo.deleteAlbum(any())).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          albumEditorOwnerReaderProvider.overrideWithValue(() => 'owner'),
          albumCurrentSessionOwnerProvider.overrideWithValue('owner'),
          albumRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeViewModelProvider.future);

      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.deleteAlbum(albums.first);

      final state = container.read(homeViewModelProvider).value;
      expect(state, isNotNull);
      expect(state!.map((album) => album.id), [2]);

      verify(() => mockRepo.deleteAlbum(1)).called(1);
    },
  );

  test(
    'reorderByCategory prioritizes category albums and calls repository',
    () async {
      final albums = [
        fakeAlbum(id: 1).copyWith(orders: 0),
        fakeAlbum(id: 2).copyWith(orders: 1),
        fakeAlbum(id: 3).copyWith(orders: 2),
      ];

      stubFetchMyAlbums(mockRepo, albums);
      when(() => mockRepo.reorderAlbums(any())).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          albumEditorOwnerReaderProvider.overrideWithValue(() => 'owner'),
          albumCurrentSessionOwnerProvider.overrideWithValue('owner'),
          albumRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(homeViewModelProvider.future);

      final notifier = container.read(homeViewModelProvider.notifier);
      await notifier.reorderByCategory([albums[1], albums[0]]);

      final state = container.read(homeViewModelProvider).value;
      expect(state, isNotNull);
      expect(state!.map((album) => album.id), [2, 1, 3]);
      expect(state[0].orders, 0);
      expect(state[1].orders, 1);
      expect(state[2].orders, 2);

      verify(() => mockRepo.reorderAlbums([2, 1, 3])).called(1);
    },
  );
  test(
    'account replacement clears old albums and ignores a late refresh',
    () async {
      var currentOwner = 'owner';
      final old = Completer<List<Album>>();
      var initial = true;
      when(() => mockRepo.fetchMyAlbums()).thenAnswer((_) async {
        if (currentOwner == 'new-owner') return [fakeAlbum(id: 9)];
        if (initial) {
          initial = false;
          return [fakeAlbum(id: 1)];
        }
        return old.future;
      });
      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          albumEditorOwnerReaderProvider.overrideWithValue(() => currentOwner),
          albumCurrentSessionOwnerProvider.overrideWith(
            (ref) => ref.watch(_testOwner),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(homeViewModelProvider, (_, _) {});
      await container.read(homeViewModelProvider.future);
      final refresh = container.read(homeViewModelProvider.notifier).refresh();
      currentOwner = 'new-owner';
      container.read(_testOwner.notifier).change(currentOwner);
      expect(container.read(homeViewModelProvider).value, isEmpty);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(homeViewModelProvider).requireValue.single.id, 9);
      old.complete([fakeAlbum(id: 2)]);
      await refresh;
      expect(container.read(homeViewModelProvider).requireValue.single.id, 9);
    },
  );
  test(
    'failed old-account delete cannot roll private albums into the new account',
    () async {
      var currentOwner = 'owner';
      when(() => mockRepo.fetchMyAlbums()).thenAnswer(
        (_) async => [fakeAlbum(id: currentOwner == 'owner' ? 1 : 9)],
      );
      final deletion = Completer<void>();
      when(() => mockRepo.deleteAlbum(1)).thenAnswer((_) => deletion.future);
      final container = ProviderContainer(
        overrides: [
          albumRepositoryProvider.overrideWithValue(mockRepo),
          albumEditorOwnerReaderProvider.overrideWithValue(() => currentOwner),
          albumCurrentSessionOwnerProvider.overrideWith(
            (ref) => ref.watch(_testOwner),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(homeViewModelProvider, (_, _) {});
      await container.read(homeViewModelProvider.future);
      final result = container
          .read(homeViewModelProvider.notifier)
          .deleteAlbum(fakeAlbum(id: 1));
      final error = expectLater(result, throwsStateError);
      currentOwner = 'new-owner';
      container.read(_testOwner.notifier).change(currentOwner);
      await container.read(homeViewModelProvider.future);
      deletion.completeError(StateError('old failure'));
      await error;
      expect(container.read(homeViewModelProvider).requireValue.single.id, 9);
    },
  );
  test('signed-out home never queries private albums', () async {
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(mockRepo),
        albumEditorOwnerReaderProvider.overrideWithValue(() => null),
        albumCurrentSessionOwnerProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(homeViewModelProvider.future), isEmpty);
    verifyNever(() => mockRepo.fetchMyAlbums());
  });
}
