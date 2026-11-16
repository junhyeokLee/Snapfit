import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/repositories/gallery_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/gallery_notifier.dart';
import 'package:snap_fit/shared/widgets/album_bottom_sheet.dart';

class _PanelGallery extends Fake implements GalleryRepository {
  _PanelGallery({this.permitted = true, this.albumError});
  final bool permitted;
  final Object? albumError;

  @override
  Future<bool> requestPermission() async => permitted;

  @override
  Future<List<AssetPathEntity>> loadAlbums() async {
    if (albumError != null) throw albumError!;
    return const [];
  }
}

/// 실제 초기 조회 경로에서 만든 원인을 화면에 전달한다.
Future<Object?> _initialGalleryError({
  bool permitted = true,
  Object? albumError,
}) async {
  final container = ProviderContainer(
    overrides: [
      galleryRepositoryProvider.overrideWithValue(
        _PanelGallery(permitted: permitted, albumError: albumError),
      ),
    ],
  );
  try {
    await container.read(galleryProvider.notifier).fetchInitialData();
    return container.read(galleryProvider).error;
  } finally {
    container.dispose();
  }
}

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('permission error offers settings and retry recovery', (
    tester,
  ) async {
    var retried = false;
    var openedSettings = false;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final error = await _initialGalleryError(permitted: false);

    await tester.pumpWidget(
      _wrap(
        GalleryEmptyOrErrorPanel(
          message: error,
          onRetry: () => retried = true,
          onOpenPhotoSettings: () => openedSettings = true,
        ),
      ),
    );

    expect(find.text('사진 접근 권한이 필요해요'), findsOneWidget);
    expect(find.textContaining('설정에서 사진을 몇 장 더 허용'), findsOneWidget);
    expect(find.text('사진 권한 열기'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    await tester.tap(find.text('사진 권한 열기'));
    await tester.pump();
    expect(openedSettings, isTrue);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('empty album offers adding photos or checking access', (
    tester,
  ) async {
    var retried = false;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        GalleryEmptyOrErrorPanel(
          message: null,
          onRetry: () => retried = true,
          onOpenPhotoSettings: () {},
        ),
      ),
    );

    expect(find.text('이미지 앨범이 비어 있어요'), findsOneWidget);
    expect(find.textContaining('사진을 추가하거나 접근 범위를 확인'), findsOneWidget);
    expect(find.text('다시 불러오기'), findsOneWidget);
    expect(find.text('사진 권한 열기'), findsNothing);

    await tester.tap(find.text('다시 불러오기'));
    await tester.pump();
    expect(retried, isTrue);
  });

  for (final message in [
    'temporary photo database failure',
    'permission was granted but the album query failed',
  ]) {
    testWidgets(
      'recovery regression: initial lookup failure is recoverable without claiming an empty library: $message',
      (tester) async {
        var retried = 0;
        final failure = StateError(message);
        final error = await _initialGalleryError(albumError: failure);
        expect(error, same(failure));
        await tester.pumpWidget(
          _wrap(
            GalleryEmptyOrErrorPanel(
              message: error,
              onRetry: () => retried++,
              onOpenPhotoSettings: () => fail('일반 조회 오류는 권한 설정으로 보내지 않는다.'),
            ),
          ),
        );

        expect(find.text('사진을 불러오지 못했어요'), findsOneWidget);
        expect(find.text('이미지 앨범이 비어 있어요'), findsNothing);
        expect(find.text('사진 접근 권한이 필요해요'), findsNothing);
        expect(find.textContaining('접근 범위를 넓힌'), findsNothing);
        expect(find.text('사진 권한 열기'), findsNothing);
        await tester.tap(find.text('다시 시도'));
        await tester.pump();
        expect(retried, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'recovery regression: a confirmed empty library keeps the empty guidance and reload action',
    (tester) async {
      var retried = 0;
      final error = await _initialGalleryError();
      await tester.pumpWidget(
        _wrap(
          GalleryEmptyOrErrorPanel(
            message: error,
            onRetry: () => retried++,
            onOpenPhotoSettings: () {},
          ),
        ),
      );
      expect(find.text('이미지 앨범이 비어 있어요'), findsOneWidget);
      expect(find.text('사진을 불러오지 못했어요'), findsNothing);
      expect(find.text('사진 권한 열기'), findsNothing);
      await tester.tap(find.text('다시 불러오기'));
      await tester.pump();
      expect(retried, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
