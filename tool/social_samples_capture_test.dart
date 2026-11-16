// Tool-only visual review of the actual social screens, using local sample
// photographs. Run explicitly; this is not a production seed or a regression
// suite. Comment/reply fixtures exist only in this capture process and are
// never sent to Supabase, Auth, notifications, or the published app.
//
// flutter test tool/social_samples_capture_test.dart --no-pub --concurrency=1
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_work_detail_screen.dart';

const _directory = 'output/social-samples-20261103';
const _viewer = 'offline-capture-viewer';

class _GuestAuth extends AuthViewModel {
  @override
  Future<UserInfo?> build() async => null;
}

class _OfflineRepository extends Fake implements SocialRepository {
  _OfflineRepository(this.profiles);
  final List<SocialProfile> profiles;
  @override
  Future<List<SocialProfile>> searchProfiles(String query) async => profiles
      .where((profile) => profile.handle.startsWith(query.toLowerCase()))
      .toList();
}

class _ImageClient extends Mock implements HttpClient {}

class _ImageRequest extends Mock implements HttpClientRequest {}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => HttpStatus.ok;
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
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unexpected image response method: ${invocation.memberName}',
  );
}

class _CaptureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _CaptureBinding();
  registerFallbackValue(Uri.parse('https://offline-social.invalid/image.png'));
  final source =
      jsonDecode(File('$_directory/posts.json').readAsStringSync())
          as Map<String, dynamic>;
  final rows = (source['posts'] as List).cast<Map<String, dynamic>>();
  final profiles = [
    for (final row in rows)
      SocialProfile(
        userId: row['userId'] as String,
        displayName: row['displayName'] as String,
        handle: row['handle'] as String,
        bio: row['bio'] as String,
      ),
  ];
  final localImages = <String, File>{
    for (final row in rows)
      'https://offline-social.invalid/${row['slug']}.png': File(
        '$_directory/${row['image']}',
      ),
  };
  final works = [
    for (var i = 0; i < rows.length; i++)
      SocialWork(
        id: rows[i]['id'] as String,
        kind: 'moment',
        author: profiles[i],
        title: rows[i]['title'] as String,
        caption: rows[i]['caption'] as String,
        topic: rows[i]['topic'] as String,
        createdAt: DateTime.parse(rows[i]['createdAt'] as String),
        recordDate: DateTime(2026, 11, 3),
        aspectRatio: (rows[i]['aspectRatio'] as num).toDouble(),
        imageUrls: ['https://offline-social.invalid/${rows[i]['slug']}.png'],
      ),
  ];
  // These three comments are UI fixtures only. No invented activity is added
  // to the 10 content samples, and no write-capable repository is constructed.
  final comments = [
    SocialComment(
      id: 'fixture-root',
      author: profiles[4],
      body: '창가 빛이 너무 좋다. 저도 아침에 이런 시간 좀 만들어봐야겠어요 ☕',
      createdAt: DateTime(2026, 11, 3, 9),
    ),
    SocialComment(
      id: 'fixture-reply',
      author: profiles.first,
      body: '@${profiles[4].handle} 일찍 나오길 잘했더라고요. 커피 식는 줄도 모르고 앉아 있었어요 ㅎㅎ',
      createdAt: DateTime(2026, 11, 3, 9, 10),
      parentCommentId: 'fixture-root',
      rootCommentId: 'fixture-root',
      parentAuthor: profiles[4],
      mentions: [profiles[4]],
    ),
    SocialComment(
      id: 'fixture-other',
      author: profiles[6],
      body: '토스트까지 완벽한 아침이네요 🥪',
      createdAt: DateTime(2026, 11, 3, 9, 20),
    ),
  ];
  final repository = _OfflineRepository(profiles);
  final boundary = GlobalKey();
  final imageClient = _ImageClient();
  final previousClient = painting.debugNetworkImageHttpClientProvider;

  setUpAll(() async {
    // Load just the app's interface family and material symbols, rather than
    // loading the full catalog's collection of document fonts into this Mac.
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest.cast<Map<String, dynamic>>()) {
      if (!['NotoSans', 'MaterialIcons'].contains(font['family'])) continue;
      final loader = FontLoader(font['family'] as String);
      for (final asset in (font['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    // Native widget tests intentionally omit platform emoji fallback. Reuse
    // this Mac's installed emoji face for the unchanged sample captions.
    final emoji = File('/System/Library/Fonts/Apple Color Emoji.ttc');
    if (emoji.existsSync()) {
      final loader = FontLoader('SocialCaptureEmoji');
      loader.addFont(
        Future.value(ByteData.sublistView(emoji.readAsBytesSync())),
      );
      await loader.load();
    }
    when(() => imageClient.getUrl(any())).thenAnswer((invocation) async {
      final uri = invocation.positionalArguments.single as Uri;
      final original = localImages[uri.toString()];
      if (original == null) throw StateError('External request blocked: $uri');
      final request = _ImageRequest();
      when(
        () => request.close(),
      ).thenAnswer((_) async => _ImageResponse(original.readAsBytesSync()));
      return request;
    });
    painting.debugNetworkImageHttpClientProvider = () => imageClient;
  });
  tearDownAll(() {
    painting.debugNetworkImageHttpClientProvider = previousClient;
    painting.PaintingBinding.instance.imageCache.clear();
    painting.PaintingBinding.instance.imageCache.clearLiveImages();
  });

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    bool dark = false,
    bool withCommentFixtures = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final detailWork = withCommentFixtures
        ? SocialWork(
            id: works.first.id,
            kind: works.first.kind,
            author: works.first.author,
            title: works.first.title,
            caption: works.first.caption,
            topic: works.first.topic,
            imageUrls: works.first.imageUrls,
            createdAt: works.first.createdAt,
            recordDate: works.first.recordDate,
            aspectRatio: works.first.aspectRatio,
            commentCount: comments.length,
          )
        : works.first;
    final theme = dark ? SnapFitTheme.dark() : SnapFitTheme.light();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(_GuestAuth.new),
          socialCurrentUserIdProvider.overrideWith((_) => _viewer),
          socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
          socialRepositoryProvider.overrideWithValue(repository),
          ownSocialProfileProvider.overrideWith((_) async => null),
          socialProfileProvider.overrideWith(
            (_, id) async => profiles.where((p) => p.userId == id).firstOrNull,
          ),
          socialFeedProvider.overrideWith(
            (_, __) async => SocialWorkPage(
              items: works,
              hasMore: false,
              nextOffset: works.length,
            ),
          ),
          socialWorkProvider.overrideWith((_, __) async => detailWork),
          socialCommentsPageProvider.overrideWith(
            (_, __) async => SocialCommentPage(
              items: withCommentFixtures ? comments.reversed.toList() : [],
              hasMore: false,
              nextOffset: withCommentFixtures ? comments.length : 0,
            ),
          ),
          socialCommentsProvider.overrideWith(
            (_, __) async => withCommentFixtures ? comments : [],
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(
              fontFamilyFallback: const ['SocialCaptureEmoji'],
            ),
          ),
          builder: (_, child) => RepaintBoundary(key: boundary, child: child!),
          home: screen,
        ),
      ),
    );
    // Serve original PNG bytes locally to the actual NetworkImage widget.
    await tester.pump();
    await tester.runAsync(() async {
      final context = boundary.currentContext!;
      // The feed builds nearby cards as well as the first card. Service every
      // original's decode in real time so a lower card's loading indicator
      // cannot keep the fake widget-test clock animating indefinitely.
      for (final work in works) {
        await precacheImage(
          ResizeImage(NetworkImage(work.imageUrls.first), width: 1440),
          context,
        );
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump();
    expect(tester.takeException(), isNull, reason: name);
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final pixels = await render.toImage(pixelRatio: 1);
      try {
        final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
        final output = File('$_directory/ui/$name.png');
        output.parent.createSync(recursive: true);
        output.writeAsBytesSync(
          bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        // ignore: avoid_print
        print('Saved ${output.path} (${pixels.width}×${pixels.height})');
      } finally {
        pixels.dispose();
      }
    });
  }

  testWidgets('capture local social sample screens for visual review', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    try {
      await mount(tester, const SocialFeedScreen());
      await capture(tester, 'feed-light');
      await mount(tester, SocialWorkDetailScreen(workId: works.first.id));
      await capture(tester, 'detail-light');
      for (final dark in [false, true]) {
        await mount(
          tester,
          SocialWorkDetailScreen(workId: works.first.id, showComments: true),
          dark: dark,
          withCommentFixtures: true,
        );
        final reply = find.byKey(
          const ValueKey('social-comment-reply-fixture-root'),
        );
        await tester.ensureVisible(reply);
        await tester.tap(reply);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('social-comment-input')),
          '@${profiles[4].handle} 저도 아침 산책하고 들른 곳이에요 :)',
        );
        await tester.pumpAndSettle();
        await capture(
          tester,
          'comments-reply-fixture-${dark ? 'dark' : 'light'}',
        );
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      // Restore before the widget binding verifies its per-test invariants.
      painting.debugNetworkImageHttpClientProvider = previousClient;
    }
  });
}
