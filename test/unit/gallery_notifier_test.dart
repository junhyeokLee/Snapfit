import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/repositories/gallery_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/gallery_notifier.dart';

class _Repository extends Mock implements GalleryRepository {}

class _Album extends Mock implements AssetPathEntity {}

class _Photo extends Mock implements AssetEntity {}

void main() {
  late _Repository repository;
  late AssetPathEntity first, second;
  late ProviderContainer container;
  late GalleryNotifier notifier;
  setUp(() {
    repository = _Repository();
    first = _Album();
    second = _Album();
    when(() => first.id).thenReturn('first');
    when(() => second.id).thenReturn('second');
    when(() => first.isAll).thenReturn(false);
    when(() => second.isAll).thenReturn(false);
    when(() => repository.requestPermission()).thenAnswer((_) async => true);
    when(
      () => repository.loadAlbums(),
    ).thenAnswer((_) async => [first, second]);
    container = ProviderContainer(
      overrides: [galleryRepositoryProvider.overrideWithValue(repository)],
    );
    notifier = container.read(galleryProvider.notifier);
  });
  tearDown(() => container.dispose());

  test(
    'initial selection prefers all photos rather than the first folder',
    () async {
      when(() => second.isAll).thenReturn(true);
      when(
        () => repository.loadImagesPaged(second, 0, 40),
      ).thenAnswer((_) async => [_Photo()]);
      await notifier.fetchInitialData();
      expect(container.read(galleryProvider).selectedAlbum?.id, 'second');
      verify(() => repository.loadImagesPaged(second, 0, 40)).called(1);
      verifyNever(() => repository.loadImagesPaged(first, 0, 40));
    },
  );

  test(
    'refresh preserves the chosen album while loading a new first page',
    () async {
      when(() => first.isAll).thenReturn(true);
      when(
        () => repository.loadImagesPaged(second, 0, 40),
      ).thenAnswer((_) async => [_Photo()]);
      await notifier.fetchInitialData(albumId: 'second');
      expect(container.read(galleryProvider).selectedAlbum?.id, 'second');
      expect(container.read(galleryProvider).currentPage, 1);
      verifyNever(() => repository.loadImagesPaged(first, 0, 40));
    },
  );

  test(
    'a deleted chosen folder falls back to all photos during refresh',
    () async {
      when(() => first.isAll).thenReturn(true);
      when(() => repository.loadAlbums()).thenAnswer((_) async => [first]);
      when(
        () => repository.loadImagesPaged(first, 0, 40),
      ).thenAnswer((_) async => [_Photo()]);
      await notifier.fetchInitialData(albumId: 'deleted');
      expect(container.read(galleryProvider).selectedAlbum?.id, 'first');
      expect(container.read(galleryProvider).error, isNull);
    },
  );

  for (final failure in [false, true]) {
    test(
      'album switching ignores a late ${failure ? 'failure' : 'success'} without unlocking the new request',
      () async {
        final old = Completer<List<AssetEntity>>(),
            next = Completer<List<AssetEntity>>();
        final oldPhoto = _Photo(), newPhoto = _Photo();
        when(
          () => repository.loadImagesPaged(first, 0, 40),
        ).thenAnswer((_) => old.future);
        when(
          () => repository.loadImagesPaged(second, 0, 40),
        ).thenAnswer((_) => next.future);
        final initial = notifier.fetchInitialData();
        await Future<void>.delayed(Duration.zero);
        final selection = notifier.selectAlbum(second);
        if (failure) {
          old.completeError(StateError('old album failed'));
        } else {
          old.complete([oldPhoto]);
        }
        await initial;
        expect(container.read(galleryProvider).selectedAlbum?.id, 'second');
        expect(container.read(galleryProvider).isLoading, isTrue);
        expect(container.read(galleryProvider).images, isEmpty);
        expect(container.read(galleryProvider).error, isNull);
        next.complete([newPhoto]);
        await selection;
        expect(container.read(galleryProvider).images, [newPhoto]);
        expect(container.read(galleryProvider).isLoading, isFalse);
        expect(container.read(galleryProvider).currentPage, 1);
      },
    );
  }

  test(
    'concurrent pagination loads each page once and retries the failed page',
    () async {
      final photos = List<AssetEntity>.generate(40, (_) => _Photo());
      when(
        () => repository.loadImagesPaged(first, 0, 40),
      ).thenAnswer((_) async => photos);
      await notifier.fetchInitialData();
      final pending = Completer<List<AssetEntity>>();
      when(
        () => repository.loadImagesPaged(first, 1, 40),
      ).thenAnswer((_) => pending.future);
      final loading = notifier.loadMore();
      await notifier.loadMore();
      pending.completeError(StateError('try again'));
      await loading;
      expect(container.read(galleryProvider).images.length, 40);
      expect(container.read(galleryProvider).currentPage, 1);
      expect(container.read(galleryProvider).error, isNotNull);
      when(
        () => repository.loadImagesPaged(first, 1, 40),
      ).thenAnswer((_) async => [_Photo()]);
      await notifier.loadMore();
      expect(container.read(galleryProvider).images.length, 41);
      expect(container.read(galleryProvider).currentPage, 2);
      expect(container.read(galleryProvider).hasMore, isFalse);
      expect(container.read(galleryProvider).error, isNull);
      verify(() => repository.loadImagesPaged(first, 1, 40)).called(2);
    },
  );

  test(
    'refresh ignores permission results from an older initialization',
    () async {
      final permission = Completer<bool>();
      when(
        () => repository.requestPermission(),
      ).thenAnswer((_) => permission.future);
      final old = notifier.fetchInitialData();
      when(() => repository.requestPermission()).thenAnswer((_) async => true);
      when(
        () => repository.loadImagesPaged(first, 0, 40),
      ).thenAnswer((_) async => [_Photo()]);
      await notifier.fetchInitialData();
      permission.complete(false);
      await old;
      expect(container.read(galleryProvider).selectedAlbum?.id, 'first');
      expect(container.read(galleryProvider).images.length, 1);
      expect(container.read(galleryProvider).error, isNull);
    },
  );

  test('disposal before a request fails does not write state', () async {
    final pending = Completer<List<AssetEntity>>();
    when(
      () => repository.loadImagesPaged(first, 0, 40),
    ).thenAnswer((_) => pending.future);
    final initial = notifier.fetchInitialData();
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    pending.completeError(StateError('late failure'));
    await expectLater(initial, completes);
  });
}
