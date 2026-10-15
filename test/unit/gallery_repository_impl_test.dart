import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/repositories/gallery_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.fluttercandies/photo_manager');
  final calls = <MethodCall>[];
  final albums = [
    {'id': 'family', 'name': '가족', 'isAll': false},
    {'id': 'all', 'name': 'Recent', 'isAll': true},
    {'id': 'travel', 'name': '여행', 'isAll': false},
  ];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getAssetPathList')
            return {
              'data': (call.arguments as Map)['onlyAll'] == true
                  ? albums.where((album) => album['isAll'] == true).toList()
                  : albums,
            };
          if (call.method == 'getAssetListPaged') return {'data': <Map>[]};
          throw StateError('Unexpected gallery call ${call.method}');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  void expectLatestFirst(MethodCall call) {
    final option = (call.arguments as Map)['option'] as Map;
    expect(option['type'], 0);
    expect((option['child'] as Map)['orders'], [
      {'type': OrderOptionType.createDate.index, 'asc': false},
      {'type': OrderOptionType.updateDate.index, 'asc': false},
    ]);
  }

  test('requestPermission treats limited photo access as usable', () async {
    final repository = GalleryRepositoryImpl(
      requestPermissionExtend: () async => PermissionState.limited,
    );

    final permitted = await repository.requestPermission();

    expect(permitted, isTrue);
  });

  test(
    'album query requests native newest first and puts all photos first',
    () async {
      final result = await GalleryRepositoryImpl().loadAlbums();
      expect(result.map((a) => a.id), ['all', 'family', 'travel']);
      expectLatestFirst(calls.single);
      expect((calls.single.arguments as Map)['hasAll'], true);
      expect((calls.single.arguments as Map)['type'], RequestType.image.value);
      for (final album in result) {
        expect(
          (album.filterOption as FilterOptionGroup).orders.first.asc,
          false,
        );
      }
    },
  );

  test('all photo collector uses the same native order', () async {
    final result = await GalleryRepositoryImpl().loadAllPhotosAlbum();
    expectLatestFirst(calls.single);
    expect((calls.single.arguments as Map)['onlyAll'], true);
    expect(result?.id, 'all');
  });

  for (final cached in [false, true]) {
    test(
      'pagination overrides ${cached ? 'cached oldest-first' : 'unsorted'} paths before fetching',
      () async {
        final originalFilter = cached
            ? FilterOptionGroup(
                orders: const [OrderOption(asc: true)],
                includeHiddenAssets: false,
              )
            : null;
        final album = AssetPathEntity(
          id: 'family',
          name: '가족',
          type: RequestType.image,
          filterOption: originalFilter,
        );
        final repository = GalleryRepositoryImpl();
        await repository.loadImagesPaged(album, 0, 40);
        await repository.loadImagesPaged(album, 1, 40);
        expect(calls.length, 2);
        for (final (index, call) in calls.indexed) {
          expectLatestFirst(call);
          expect((call.arguments as Map)['page'], index);
          expect((call.arguments as Map)['size'], 40);
          expect((call.arguments as Map)['id'], 'family');
        }
        if (cached) expect(originalFilter!.orders.first.asc, true);
      },
    );
  }
}
