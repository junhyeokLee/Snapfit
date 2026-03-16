import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';

import '../helpers/fake_album.dart';
import '../helpers/mock_repositories.dart';

void main() {
  late MockAlbumRepository mockRepo;

  setUp(() {
    mockRepo = MockAlbumRepository();
  });

  test('reorder updates order locally and calls repository', () async {
    final albums = [
      fakeAlbum(id: 1).copyWith(orders: 0),
      fakeAlbum(id: 2).copyWith(orders: 1),
    ];

    stubFetchMyAlbums(mockRepo, albums);
    when(() => mockRepo.reorderAlbums(any())).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [albumRepositoryProvider.overrideWithValue(mockRepo)],
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
        overrides: [albumRepositoryProvider.overrideWithValue(mockRepo)],
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
        overrides: [albumRepositoryProvider.overrideWithValue(mockRepo)],
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
}
