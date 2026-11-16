// 실제 HomeScreen의 현재 계층을 로컬 사진과 고정 계정으로 확인하는 임시 캡처다.
// 이 파일은 제품 테스트/소스에 추가하지 않는다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_slider.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_providers.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

import 'file:///Users/devsheep/SnapFit/SnapFit/test/helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import 'file:///Users/devsheep/SnapFit/SnapFit/test/helpers/first_visit_fixtures.dart';
import 'file:///Users/devsheep/SnapFit/SnapFit/test/helpers/memory_moment_draft_store.dart';
import 'capture_support.dart';

class _Home extends HomeViewModel {
  _Home(this.items);
  final List<Album> items;
  @override
  FutureOr<List<Album>> build() => items;
}

class _Auth extends AuthViewModel {
  @override
  Future<UserInfo?> build() async =>
      const UserInfo(id: 'audit-owner', name: '준혁', provider: 'email');
}

const _momentAsset =
    'assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg';
// MomentPhotoView는 storageUri를 먼저 읽으므로 fallback 대신 원천 URI를 로컬로 고정한다.
class _AssetPhoto extends MomentPhoto {
  const _AssetPhoto(String id)
      : super(id: id, path: '', url: 'asset:$_momentAsset', width: 1200, height: 800);

  @override
  String get storageUri => 'asset:$_momentAsset';
}

// 로컬 자산 외 소스를 실수로 추가하면 네트워크/플러그인 접근 대신 즉시 실패한다.
class _AssetOnlyCache extends Fake implements BaseCacheManager, ImageCacheManager {
  @override
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) => throw StateError('Home capture requested a non-asset image: $url');

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => throw StateError('Home capture requested a non-asset image: $url');
}

final _today = DateTime.utc(2026, 11, 16);
final _journal = MomentJournal(
  today: _today,
  weekStart: momentWeekStart(_today),
  month: momentMonth(_today),
  weekPhotoCount: 1,
  records: [
    for (final day in [14, 15, 16])
      MomentRecord(
        id: 'audit-record-$day',
        recordDate: DateTime.utc(2026, 11, day),
        caption: day == 16
            ? '잠깐 멈춰 바라본, 오늘의 바다.'
            : '천천히 걸으며 남긴 하루',
        revision: 1,
        photos: [
          _AssetPhoto('audit-photo-$day'),
        ],
      ),
  ],
);

// 실제 홈 표지 렌더러에 저장 문서를 전달한다. 사진은 기존 로컬 fixture와 동일하다.
Album _album(int id, double ratio, String title, String asset) {
  final canvas = Size(500, 500 / ratio);
  final layer = LayerExportMapper.toJson(
    LayerModel(
      id: 'audit-cover-$id',
      type: LayerType.image,
      position: Offset.zero,
      width: canvas.width,
      height: canvas.height,
      imageUrl: 'asset:$asset',
    ),
    canvasSize: canvas,
  );
  return Album(
    id: id,
    userId: 'audit-owner',
    title: title,
    ratio: '$ratio',
    totalPages: 2,
    targetPages: 4,
    createdAt: '2026-11-16T09:00:00Z',
    updatedAt: '2026-11-16T09:00:00Z',
    coverLayersJson: jsonEncode({
      'pages': [
        {'index': 0, 'isCover': true, 'layers': [layer]},
        {'index': 1, 'isCover': false, 'layers': []},
      ],
    }),
  );
}

Future<void> _ready(WidgetTester tester) async {
  // 완료 콜백에도 pump가 필요하므로 decode를 시작한 뒤 IO와 프레임을 번갈아 진행한다.
  // 표지 큐가 다음 프레임에 새 이미지를 마운트할 수 있어 매번 아직 준비하지 않은 것만 찾는다.
  final warmed = <ImageProvider<Object>>{};
  var stableFrames = 0;
  for (var frame = 0; frame < 120; frame++) {
    void warm(ImageProvider<Object> provider, BuildContext context) {
      if (warmed.add(provider)) {
        unawaited(precacheImage(provider, context));
      }
    }

    for (final element in find.byType(Image).evaluate()) {
      warm((element.widget as Image).image, element);
    }
    for (final element in find.byType(SnapfitImage).evaluate()) {
      final image = element.widget as SnapfitImage;
      for (final source in [image.urlOrGs, ...image.fallbackSources]) {
        if (source.trim().isEmpty) continue;
        expect(source.startsWith('asset:'), isTrue,
            reason: 'The home capture must use local artwork only: $source');
      }
      if (!image.urlOrGs.startsWith('asset:')) continue;
      warm(
        ResizeImage.resizeIfNeeded(
          image.memCacheWidth,
          image.memCacheHeight,
          AssetImage(image.urlOrGs.substring(6)),
        ),
        element,
      );
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 32));
    final ready = PaintingBinding.instance.imageCache.pendingImageCount == 0 &&
        !tester.binding.hasScheduledFrame;
    stableFrames = ready && frame >= 12 ? stableFrames + 1 : 0;
    if (stableFrames >= 3) return;
  }
  fail('Home artwork did not settle within the bounded frame budget.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // 기존 home_profile_ux_export_test와 같은 경로 대체로 호스트 플러그인을 호출하지 않는다.
    final cache = Directory('/tmp/snapfit-visual-refresh-20261116/home-cache');
    await cache.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.path,
        );
    CachedNetworkImageProvider.defaultCacheManager = _AssetOnlyCache();
    SnapfitImage.storageOwnerForTesting = () => 'audit-owner';
    await auditFonts();
  });
  tearDownAll(() {
    SnapfitImage.storageOwnerForTesting = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });
  for (final scene in [
    (size: const Size(390, 844), dark: false, scale: 1.0, name: 'home-390-light'),
    (size: const Size(390, 844), dark: true, scale: 1.0, name: 'home-390-dark'),
    (size: const Size(320, 568), dark: false, scale: 2.0, name: 'home-320-large'),
  ]) {
    testWidgets('현재 홈 캡처 ${scene.name}', (tester) async {
      auditViewport(tester, size: scene.size);
      SharedPreferences.setMockInitialValues({});
      final albums = [
        _album(701, .75, '둘만의 순간', 'assets/snapfit_home_portrait.jpg'),
        _album(702, 1, '우리의 느린 오후', 'assets/snapfit_home_square.jpg'),
        _album(703, 4 / 3, '여름의 결', 'assets/snapfit_home_landscape.jpg'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeViewModelProvider.overrideWith(() => _Home(albums)),
            authViewModelProvider.overrideWith(_Auth.new),
            homeUiStateProvider.overrideWith(HomeUiStateNotifier.new),
            albumEditorOwnerReaderProvider.overrideWith(
              (_) => () => 'audit-owner',
            ),
            momentEntryJournalProvider.overrideWith((_) async => _journal),
            momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
            albumCreationDraftStoreProvider.overrideWithValue(
              MemoryCreationDraftStore(),
            ),
            firstVisitStoreProvider.overrideWithValue(MemoryFirstVisitStore(3)),
            homeNewsCurrentOwnerProvider.overrideWithValue(null),
            notificationUnreadCountProvider.overrideWith((_) async => 0),
            pointShopCatalogProvider.overrideWith((_) async => []),
            mockTemplateList(() async => const []),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, __) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: scene.dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
              builder: (context, child) => auditFrame(
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(scene.scale),
                  ),
                  child: child!,
                ),
              ),
              home: const HomeScreen(),
            ),
          ),
        ),
      );
      await _ready(tester);
      await auditCapture(tester, '${scene.name}-top');
      if (scene.scale > 1.5) {
        await tester.ensureVisible(find.byKey(const ValueKey('home-monthly-feed-date')));
        await _ready(tester);
        await auditCapture(tester, '${scene.name}-record');
      }
      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(HomeAlbumSlider),
          matching: find.byType(SingleChildScrollView),
        ),
      ).controller!;
      final albumHeading = find.byKey(const ValueKey('home-album-section'));
      final top = tester.getRect(find.byType(HomeAlbumSlider)).top;
      final headingTop = tester.getRect(albumHeading).top;
      scroll.jumpTo(
        (scroll.offset + headingTop - top).clamp(0.0, scroll.position.maxScrollExtent).toDouble(),
      );
      await _ready(tester);
      await auditCapture(tester, '${scene.name}-album');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
