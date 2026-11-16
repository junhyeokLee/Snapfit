import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/web/web_album_library_screen.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_moment_month_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_moment_month_cover_picker.dart';
import 'package:snap_fit/features/social/presentation/views/social_work_detail_screen.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

import '../helpers/first_visit_fixtures.dart';
import '../helpers/memory_moment_draft_store.dart';
import '../widget/social_profile_personal_area_test.dart' as personal;

class _Home extends HomeViewModel {
  _Home(this.items);
  final List<Album> items;
  @override
  FutureOr<List<Album>> build() => items;
}

final _album = Album(
  id: 42,
  userId: 'owner-a',
  title: '골목의 오후',
  ratio: '1',
  coverThumbnailUrl: 'asset:assets/catalog_thumbnails/template_-9471.png',
  coverPreviewUrl: 'asset:assets/catalog_thumbnails/template_-9471.png',
  targetPages: 1,
  totalPages: 2,
  coverLayersJson: jsonEncode({
    'pages': [
      {'index': 0, 'isCover': true, 'layers': []},
      {
        'index': 1,
        'isCover': false,
        'layers': [
          {
            'type': 'IMAGE',
            'templateContent': false,
            'payload': {'previewUrl': 'asset:assets/snapfit_home_square.jpg'},
          },
        ],
      },
    ],
  }),
);
const _profile = SocialProfile(
  userId: 'owner-a',
  displayName: '오늘의 수집가',
  handle: 'snapfit.days',
  bio: '작은 날들을 한 장씩 모아요.',
  worksCount: 1,
  momentsCount: 2,
);

final _works = [
  SocialWork(
    id: 'fixture-alley',
    kind: 'moment',
    caption: '우연히 만난 골목. 잠깐 멈춰 오래 바라봤다.',
    recordDate: DateTime.utc(2026, 10, 28),
    author: _profile,
    title: '골목의 오후',
    createdAt: DateTime.utc(2026, 10, 28),
    imageUrls: const ['https://review.snapfit.test/alley.png'],
  ),
  SocialWork(
    id: 'fixture-family',
    kind: 'moment',
    caption: '같이 있어 더 좋았던 오늘.',
    recordDate: DateTime.utc(2026, 10, 27),
    author: _profile,
    title: '오래 바라본 오늘',
    createdAt: DateTime.utc(2026, 10, 27),
    imageUrls: const ['https://review.snapfit.test/family.png'],
  ),
];

class _Client extends Mock implements HttpClient {}

class _Request extends Mock implements HttpClientRequest {}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _fonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final font in manifest.where(
    (font) => [
      'NotoSans',
      'NotoSansKR',
      'Pretendard',
      'Poppins',
      'MaterialIcons',
    ].contains(font['family']),
  )) {
    final loader = FontLoader(font['family'] as String);
    for (final file in font['fonts'] as List) {
      loader.addFont(rootBundle.load(file['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  // Resolve real images before settling. The production loading indicator
  // intentionally keeps scheduling frames until its image is decoded.
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      for (final image in tester.widgetList<SnapfitImage>(
        find.byType(SnapfitImage),
      )) {
        for (final source in [image.urlOrGs, ...image.fallbackSources]) {
          if (!source.startsWith('asset:')) continue;
          await precacheImage(
            ResizeImage.resizeIfNeeded(
              image.memCacheWidth,
              image.memCacheHeight,
              AssetImage(source.substring(6)),
            ),
            context,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
              'Timed out preparing export asset: $source',
            ),
          );
        }
      }
      for (final element in find.byType(Image).evaluate()) {
        final provider = (element.widget as Image).image;
        await precacheImage(provider, element).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
            'Timed out preparing export image: $provider',
          ),
        );
      }
    });
  }
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    const folder = String.fromEnvironment(
      'MEMORY_UX_OUTPUT',
      defaultValue: 'output/memory-ux-20261028',
    );
    final file = File('$folder/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    registerFallbackValue(Uri.parse('https://review.snapfit.test/'));
    final cache = Directory('output/memory-ux-cache-fixture').absolute;
    await cache.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.path,
        );
    await _fonts();
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });
  for (final sample in [
    (
      name: 'home-main',
      home: true,
      empty: false,
      dark: false,
      size: const Size(390, 844),
    ),
    (
      name: 'home-first',
      home: true,
      empty: true,
      dark: false,
      size: const Size(390, 844),
    ),
    (
      name: 'my-profile',
      home: false,
      empty: false,
      dark: false,
      size: const Size(390, 844),
    ),
    (
      name: 'my-profile-dark',
      home: false,
      empty: false,
      dark: true,
      size: const Size(390, 844),
    ),
    (
      name: 'my-profile-web',
      home: false,
      empty: false,
      dark: false,
      size: const Size(1440, 1000),
    ),
    (
      name: 'feed-app',
      home: false,
      empty: false,
      dark: false,
      size: const Size(390, 844),
    ),
    (
      name: 'feed-app-dark',
      home: false,
      empty: false,
      dark: true,
      size: const Size(390, 844),
    ),
    (
      name: 'cover-picker',
      home: false,
      empty: false,
      dark: false,
      size: const Size(390, 844),
    ),
    (
      name: 'monthly-records',
      home: false,
      empty: false,
      dark: false,
      size: const Size(390, 844),
    ),
    (
      name: 'work-detail',
      home: false,
      empty: false,
      dark: false,
      size: const Size(390, 844),
    ),
    (
      name: 'home-web',
      home: true,
      empty: false,
      dark: false,
      size: const Size(1440, 1000),
    ),
  ]) {
    testWidgets('export ${sample.name} production widgets', (tester) async {
      if (!const bool.fromEnvironment('EXPORT_MEMORY_UX')) return;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = sample.size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({});
      final before = painting.debugNetworkImageHttpClientProvider;
      final client = _Client();
      // Asset I/O must finish outside the widget test's fake clock before its
      // bytes are reused by the image client during image decoding.
      final photos = (await tester.runAsync(() async {
        final alley = await rootBundle.load(
          'assets/templates/atelier_editions_2026/alley-afternoon.png',
        );
        final family = await rootBundle.load(
          'assets/frame_preview/spring_flowers.jpg',
        );
        return (
          alley: alley.buffer.asUint8List(),
          family: family.buffer.asUint8List(),
        );
      }))!;
      when(() => client.getUrl(any())).thenAnswer((call) async {
        final request = _Request();
        final uri = call.positionalArguments.first as Uri;
        when(() => request.close()).thenAnswer(
          (_) async => _Response(
            uri.path.contains('family') ? photos.family : photos.alley,
          ),
        );
        return request;
      });
      painting.debugNetworkImageHttpClientProvider = () => client;
      try {
        final key = GlobalKey();
        final page = sample.name == 'cover-picker'
            ? Scaffold(
                body: SafeArea(
                  child: SocialMomentMonthCoverPicker(
                    userId: 'owner-a',
                    month: DateTime.utc(2026, 10),
                    selectedWorkId: null,
                    onSelect: (_) async {},
                  ),
                ),
              )
            : sample.name.startsWith('feed-')
            ? const SocialFeedScreen()
            : sample.name == 'monthly-records'
            ? SocialMomentMonthScreen(
                userId: 'owner-a',
                month: DateTime.utc(2026, 10),
              )
            : sample.name == 'work-detail'
            ? const SocialWorkDetailScreen(workId: 'fixture-alley')
            : sample.home
            ? sample.size.width > 700
                  ? const WebAlbumLibraryScreen()
                  : const HomeScreen()
            : const SocialProfileScreen();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...personal
                  .profilePersonalReviewOverrides(emptyMoments: false)
                  .where(
                    (override) =>
                        override.origin != homeViewModelProvider &&
                        override.origin != ownSocialProfileProvider &&
                        override.origin !=
                            socialProfileWorksPageProvider(
                              const SocialProfileWorksQuery('owner-a'),
                            ) &&
                        override.origin != momentsSessionProvider,
                  ),
              homeViewModelProvider.overrideWith(
                () => _Home(sample.empty ? [] : [_album]),
              ),
              ownSocialProfileProvider.overrideWith((_) async => _profile),
              socialProfileWorksPageProvider(
                const SocialProfileWorksQuery('owner-a'),
              ).overrideWith(
                (_) async => SocialWorkPage(
                  items: _works,
                  hasMore: false,
                  nextOffset: 2,
                ),
              ),
              socialAuthStateProvider.overrideWith(
                (_) => Stream.value('owner-a'),
              ),
              socialProfileMomentsPageProvider.overrideWith(
                (_, __) async => SocialWorkPage(
                  items: _works,
                  hasMore: false,
                  nextOffset: 2,
                ),
              ),
              socialProfileMomentMonthsPageProvider.overrideWith(
                (_, __) async => SocialMomentMonthsPage(
                  items: [
                    SocialMomentMonth(
                      month: DateTime.utc(2026, 10),
                      recordCount: _works.length,
                      cover: _works.first,
                    ),
                  ],
                  hasMore: false,
                  nextOffset: 1,
                ),
              ),
              socialMomentMonthPageProvider.overrideWith(
                (_, __) async => SocialWorkPage(
                  items: _works,
                  hasMore: false,
                  nextOffset: _works.length,
                ),
              ),
              socialProfileProvider(
                'owner-a',
              ).overrideWith((_) async => _profile),
              socialFeedProvider.overrideWith(
                (_, __) async => SocialWorkPage(
                  items: _works,
                  hasMore: false,
                  nextOffset: _works.length,
                ),
              ),
              socialWorkProvider.overrideWith(
                (_, id) async =>
                    _works.where((work) => work.id == id).firstOrNull,
              ),
              homeNewsCurrentOwnerProvider.overrideWithValue(null),
              albumCreationDraftProvider.overrideWith((_) async => null),
              momentDraftStoreProvider.overrideWithValue(
                MemoryMomentDraftStore(),
              ),
              momentsCurrentUserIdProvider.overrideWithValue('owner-a'),
              momentsSessionProvider.overrideWith(
                (_) => Stream.value('owner-a'),
              ),
              momentsMonthProvider.overrideWith(
                (_, month) async => MomentJournal(
                  today: DateTime.utc(2026, 10, 28),
                  weekStart: DateTime.utc(2026, 10, 26),
                  month: month ?? DateTime.utc(2026, 10),
                  records: const [],
                  weekPhotoCount: 0,
                ),
              ),
              firstVisitStoreProvider.overrideWithValue(
                MemoryFirstVisitStore(3),
              ),
              notificationUnreadCountProvider.overrideWith((_) async => 0),
            ],
            child: ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (context, _) => personal.profilePersonalReviewApp(
                Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: RepaintBoundary(
                      key: key,
                      child: WebNavigationScope(
                        onNavigate: (_) {},
                        onNotifications: () {},
                        child: page,
                      ),
                    ),
                  ),
                ),
                dark: sample.dark,
              ),
            ),
          ),
        );
        await _capture(tester, key, sample.name);
        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        painting.debugNetworkImageHttpClientProvider = before;
      }
    });
  }
}
