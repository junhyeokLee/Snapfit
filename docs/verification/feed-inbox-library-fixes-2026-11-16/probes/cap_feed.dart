// 실제 피드 화면을 로컬 데이터로 캡처한다. 외부 요청이나 운영 쓰기는 없다.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_work_detail_screen.dart';
import 'capture_support.dart';

const _author = SocialProfile(
  userId: 'haerin',
  displayName: '해린의 여행 기록',
  handle: 'haerin.archive',
  bio: '걸으며 만난 장면을 모읍니다.',
);
const _secondAuthor = SocialProfile(
  userId: 'jisu',
  displayName: '지수',
  handle: 'slow.days',
);

const _imageAssets = {
  'https://fixture.invalid/feed/ocean.jpg': 'assets/frame_preview/ocean_shore.jpg',
  'https://fixture.invalid/feed/forest.jpg': 'assets/frame_preview/forest_trail.jpg',
  'https://fixture.invalid/feed/flowers.jpg': 'assets/frame_preview/spring_flowers.jpg',
};
final _imageBytes = <String, Uint8List>{};

final _works = [
  SocialWork(
    id: 'weekend-walk',
    kind: 'moment',
    author: _author,
    title: '바다를 따라 걸었던 주말',
    caption: '서두르지 않고 걷다가 마음에 드는 풍경 앞에서 멈췄어요. 오래 기억하고 싶은 가을의 하루.',
    imageUrls: _imageAssets.keys.take(2).toList(),
    aspectRatio: 1.5,
    likeCount: 42,
    commentCount: 2,
    createdAt: DateTime(2026, 11, 15),
    recordDate: DateTime(2026, 11, 15),
  ),
  SocialWork(
    id: 'morning-flowers',
    kind: 'moment',
    author: _secondAuthor,
    title: '매일 지나던 길에서',
    caption: '오늘은 꽃이 먼저 보였어요.',
    imageUrls: [_imageAssets.keys.last],
    aspectRatio: 1.5,
    likeCount: 7,
    createdAt: DateTime(2026, 11, 14),
  ),
];

class _FeedRepository extends SocialRepository {
  _FeedRepository() : super(SupabaseClient(
    'https://fixture.invalid', 'public-test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ));

  final queries = <bool>[];
  @override
  Future<SocialWorkPage> fetchFeed({
    bool following = false, String? topic, int offset = 0, int limit = 12,
  }) async {
    queries.add(following);
    final items = (following ? [_works.first] : _works).skip(offset).take(limit).toList();
    return SocialWorkPage(items: items, hasMore: false, nextOffset: offset + items.length);
  }

  @override
  Future<SocialWork?> fetchWork(String id) async => _works.where((work) => work.id == id).firstOrNull;

  @override
  Future<SocialCommentPage> fetchCommentsPage(String id, {int offset = 0, int limit = 12}) async {
    final comments = [
      SocialComment(id: 'comment-1', author: _secondAuthor, body: '사진만 봐도 바람이 느껴져요.', createdAt: DateTime(2026, 11, 15, 15)),
      SocialComment(id: 'comment-2', author: _author, body: '다음에는 숲길도 함께 걸어요.', createdAt: DateTime(2026, 11, 15, 16)),
    ];
    return SocialCommentPage(items: comments.skip(offset).take(limit).toList(), hasMore: false, nextOffset: comments.length);
  }
}

class _ImageClient extends Mock implements HttpClient {}
class _ImageRequest extends Mock implements HttpClientRequest {}
class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.bytes);
  final Uint8List bytes;
  @override int get statusCode => 200;
  @override int get contentLength => bytes.length;
  @override HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData, {
    Function? onError, void Function()? onDone, bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _withAssetImages(WidgetTester tester, Future<void> Function() body) async {
  final previous = painting.debugNetworkImageHttpClientProvider;
  final client = _ImageClient();
  when(() => client.getUrl(any())).thenAnswer((invocation) async {
    final url = (invocation.positionalArguments.single as Uri).toString();
    final bytes = _imageBytes[url];
    if (bytes == null) throw StateError('Unreviewed image URL: $url');
    final request = _ImageRequest();
    when(() => request.close()).thenAnswer((_) async => _ImageResponse(bytes));
    return request;
  });
  painting.debugNetworkImageHttpClientProvider = () => client;
  try {
    await body();
  } finally {
    await tester.pumpWidget(const SizedBox());
    painting.debugNetworkImageHttpClientProvider = previous;
    painting.PaintingBinding.instance.imageCache.clear();
    painting.PaintingBinding.instance.imageCache.clearLiveImages();
  }
}

Widget _app(_FeedRepository repository, {bool dark = false, double textScale = 1}) => ProviderScope(
  overrides: [
    socialCurrentUserIdProvider.overrideWith((_) => 'me'),
    socialAuthStateProvider.overrideWith((_) => const Stream<String?>.empty()),
    socialRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(splashFactory: NoSplash.splashFactory),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: auditFrame(child!),
    ),
    home: const SocialFeedScreen(),
  ),
);

Future<void> _decodeVisible(WidgetTester tester) async {
  // 새 route와 PageView가 사진 위젯을 먼저 만들도록 유한 프레임만 진행한다.
  await tester.pump(const Duration(milliseconds: 400));
  // 디코드 완료를 기다리는 동안 fake frame을 막지 않는다.
  for (final image in tester.widgetList<Image>(find.byType(Image))) {
    unawaited(precacheImage(image.image, tester.element(find.byWidget(image)), onError: (_, _) {}));
  }
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 40));
    if (painting.PaintingBinding.instance.imageCache.pendingImageCount == 0) break;
  }
  await tester.pumpAndSettle();
  expect(tester.widgetList<RawImage>(find.byType(RawImage)).any((image) => image.image != null), isTrue);
}

void main() {
  setUpAll(() async {
    registerFallbackValue(Uri.parse('https://fixture.invalid/unused'));
    await auditFonts();
    // asset IO를 위젯 test의 fake clock 밖에서 완료한다.
    for (final entry in _imageAssets.entries) {
      _imageBytes[entry.key] = (await rootBundle.load(entry.value)).buffer.asUint8List();
    }
  });

  testWidgets('feed latest following detail comments and back 390', (tester) async {
    auditViewport(tester);
    final repository = _FeedRepository();
    await _withAssetImages(tester, () async {
      await tester.pumpWidget(_app(repository));
      await tester.pump();
      await _decodeVisible(tester);
      await auditCapture(tester, 'feed_01_latest_390');

      await tester.tap(find.text('팔로잉'));
      await _decodeVisible(tester);
      expect(repository.queries.last, isTrue);
      await auditCapture(tester, 'feed_02_following_390');

      await tester.drag(find.byKey(const ValueKey('social-feed-pages-weekend-walk')), const Offset(-330, 0));
      await _decodeVisible(tester);
      expect(find.text('2 / 2'), findsOneWidget);
      await auditCapture(tester, 'feed_03_second_photo_390');

      await tester.tap(find.byKey(const ValueKey('social-feed-image-weekend-walk-1')));
      await _decodeVisible(tester);
      expect(tester.widget<SocialWorkDetailScreen>(find.byType(SocialWorkDetailScreen)).initialPage, 1);
      await auditCapture(tester, 'feed_04_detail_390');

      await tester.tap(find.byTooltip('뒤로가기'));
      await _decodeVisible(tester);
      expect(find.text('2 / 2'), findsOneWidget);
      await auditCapture(tester, 'feed_05_back_390');

      await tester.tap(find.byTooltip('댓글 보기').first);
      await _decodeVisible(tester);
      expect(find.text('이 기록에 남긴 이야기').hitTestable(), findsOneWidget);
      expect(tester.testTextInput.isVisible, false);
      await auditCapture(tester, 'feed_06_comments_390');
    });
  });

  testWidgets('feed 320 large text dark', (tester) async {
    auditViewport(tester, size: const Size(320, 844));
    await _withAssetImages(tester, () async {
      await tester.pumpWidget(_app(_FeedRepository(), dark: true, textScale: 1.8));
      await tester.pump();
      await _decodeVisible(tester);
      await auditCapture(tester, 'feed_07_320_large_dark');
      await tester.tap(find.byTooltip('댓글 보기').first);
      await _decodeVisible(tester);
      await auditCapture(tester, 'feed_08_comments_320_large_dark');
    });
  });
}
