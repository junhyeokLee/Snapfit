import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/repositories/gallery_repository.dart';
import 'package:snap_fit/features/album/domain/models/gallery_date_range.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/gallery_notifier.dart';

class _Repository extends Mock implements GalleryRepository {}

class _Album extends Mock implements AssetPathEntity {}

class _Photo extends Mock implements AssetEntity {}

void main() {
  late _Repository repository;
  late AssetPathEntity first, second;
  late ProviderContainer container;
  late GalleryNotifier notifier;
  setUpAll(
    () => registerFallbackValue(
      AssetPathEntity(id: 'fallback', name: 'fallback'),
    ),
  );
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
  test(
    'date range queries bounded native pages without changing album paths',
    () async {
      first = AssetPathEntity(id: 'first', name: '가족');
      second = AssetPathEntity(id: 'second', name: '여행');
      final original = FilterOptionGroup(includeHiddenAssets: false);
      first = AssetPathEntity(id: 'first', name: '가족', filterOption: original);
      when(
        () => repository.loadAlbums(),
      ).thenAnswer((_) async => [first, second]);
      final requests = <({AssetPathEntity album, int page, int size})>[];
      when(() => repository.loadImagesPaged(any(), any(), any())).thenAnswer((
        call,
      ) async {
        requests.add((
          album: call.positionalArguments[0] as AssetPathEntity,
          page: call.positionalArguments[1] as int,
          size: call.positionalArguments[2] as int,
        ));
        return List.generate(40, (_) => _Photo());
      });
      await notifier.fetchInitialData();
      final range = GalleryDateRange(
        DateTime(2022, 11, 3, 18),
        DateTime(2022, 11, 5, 2),
      );
      await notifier.setDateRange(range);
      await notifier.loadMore();
      expect(requests.map((r) => r.page), [0, 0, 1]);
      expect(requests.map((r) => r.size), everyElement(40));
      for (final request in requests.skip(1)) {
        final filter = request.album.filterOption as FilterOptionGroup;
        expect(filter.createTimeCond.min, DateTime(2022, 11, 3));
        expect(
          filter.createTimeCond.max,
          DateTime(2022, 11, 6).subtract(const Duration(milliseconds: 1)),
        );
        expect(filter.createTimeCond.ignore, isFalse);
        expect(filter.includeHiddenAssets, isFalse);
      }
      expect(
        original.createTimeCond,
        isNot(
          (requests[1].album.filterOption as FilterOptionGroup).createTimeCond,
        ),
      );
      expect(container.read(galleryProvider).selectedAlbum, same(first));
      await notifier.selectAlbum(second);
      expect(container.read(galleryProvider).dateRange, range);
      expect(requests.last.album.id, 'second');
      expect(requests.last.page, 0);
      await notifier.fetchInitialData(albumId: 'second');
      expect(container.read(galleryProvider).dateRange, range);
      expect(
        (requests.last.album.filterOption as FilterOptionGroup)
            .createTimeCond
            .min,
        range.start,
      );
      await notifier.setDateRange(null);
      expect(container.read(galleryProvider).dateRange, isNull);
      expect(requests.last.album, same(second));
      expect(requests.last.page, 0);
      verify(() => repository.requestPermission()).called(2);
    },
  );

  for (final lateFailure in [false, true]) {
    test(
      'date changes ignore a late ${lateFailure ? 'failure' : 'page'} from an earlier range',
      () async {
        first = AssetPathEntity(id: 'first', name: '가족');
        second = AssetPathEntity(id: 'second', name: '여행');
        when(
          () => repository.loadImagesPaged(first, 0, 40),
        ).thenAnswer((_) async => [_Photo()]);
        await notifier.fetchInitialData();
        final old = Completer<List<AssetEntity>>();
        final next = Completer<List<AssetEntity>>();
        var request = 0;
        when(
          () => repository.loadImagesPaged(any(), 0, 40),
        ).thenAnswer((_) => request++ == 0 ? old.future : next.future);
        final a = notifier.setDateRange(
          GalleryDateRange(DateTime(2020), DateTime(2020, 2)),
        );
        final newest = GalleryDateRange(DateTime(2024), DateTime(2024, 2));
        final b = notifier.setDateRange(newest);
        if (lateFailure) {
          old.completeError(StateError('old date query'));
        } else {
          old.complete([_Photo()]);
        }
        await a;
        expect(container.read(galleryProvider).dateRange, newest);
        expect(container.read(galleryProvider).isLoading, isTrue);
        expect(container.read(galleryProvider).images, isEmpty);
        expect(container.read(galleryProvider).error, isNull);
        final photo = _Photo();
        next.complete([photo]);
        await b;
        expect(container.read(galleryProvider).images, [photo]);
      },
    );
  }

  test(
    'date query errors retry the same first page and range without new permission',
    () async {
      first = AssetPathEntity(id: 'first', name: '가족');
      second = AssetPathEntity(id: 'second', name: '여행');
      when(
        () => repository.loadImagesPaged(first, 0, 40),
      ).thenAnswer((_) async => [_Photo()]);
      await notifier.fetchInitialData();
      final range = GalleryDateRange(
        DateTime(2019, 6, 1),
        DateTime(2019, 6, 3),
      );
      final queried = <AssetPathEntity>[];
      var fail = true;
      when(() => repository.loadImagesPaged(any(), 0, 40)).thenAnswer((
        call,
      ) async {
        queried.add(call.positionalArguments.first as AssetPathEntity);
        if (fail) throw StateError('offline');
        return [];
      });
      await notifier.setDateRange(range);
      expect(container.read(galleryProvider).error, isNotNull);
      expect(container.read(galleryProvider).currentPage, 0);
      expect(container.read(galleryProvider).hasMore, isTrue);
      fail = false;
      await notifier.loadMore();
      expect(container.read(galleryProvider).dateRange, range);
      expect(container.read(galleryProvider).error, isNull);
      expect(container.read(galleryProvider).images, isEmpty);
      expect(container.read(galleryProvider).hasMore, isFalse);
      expect(queried.length, 2);
      for (final album in queried) {
        expect(
          (album.filterOption as FilterOptionGroup).createTimeCond.min,
          range.start,
        );
        expect(
          (album.filterOption as FilterOptionGroup).createTimeCond.max,
          range.lastInstant,
        );
      }
      verify(() => repository.requestPermission()).called(1);
    },
  );
  for (final waitingForAlbums in [false, true]) {
    test(
      'date changes during ${waitingForAlbums ? 'album' : 'permission'} loading preserve initialization and apply to first page',
      () async {
        first = AssetPathEntity(id: 'first', name: '가족');
        second = AssetPathEntity(id: 'second', name: '여행');
        final permission = Completer<bool>();
        final albums = Completer<List<AssetPathEntity>>();
        when(() => repository.requestPermission()).thenAnswer(
          (_) => waitingForAlbums ? Future.value(true) : permission.future,
        );
        when(() => repository.loadAlbums()).thenAnswer(
          (_) =>
              waitingForAlbums ? albums.future : Future.value([first, second]),
        );
        final queried = <AssetPathEntity>[];
        when(() => repository.loadImagesPaged(any(), 0, 40)).thenAnswer((
          call,
        ) async {
          queried.add(call.positionalArguments.first as AssetPathEntity);
          return [_Photo()];
        });
        final initial = notifier.fetchInitialData();
        await Future<void>.delayed(Duration.zero);
        final obsolete = GalleryDateRange(DateTime(2018), DateTime(2018, 3));
        final current = GalleryDateRange(DateTime(2020), DateTime(2020, 3));
        await notifier.setDateRange(obsolete);
        await notifier.setDateRange(null);
        await notifier.setDateRange(current);
        expect(container.read(galleryProvider).isLoading, isTrue);
        if (waitingForAlbums) {
          albums.complete([first, second]);
        } else {
          permission.complete(true);
        }
        await initial;
        expect(container.read(galleryProvider).dateRange, current);
        expect(container.read(galleryProvider).selectedAlbum?.id, 'first');
        expect(container.read(galleryProvider).images.length, 1);
        expect(container.read(galleryProvider).isLoading, isFalse);
        expect(queried.length, 1);
        expect(
          (queried.single.filterOption as FilterOptionGroup).createTimeCond.min,
          current.start,
        );
      },
    );
  }
}
