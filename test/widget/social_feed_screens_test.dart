import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_saved_works_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_search_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_work_detail_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_works_manage_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_widgets.dart';

const _me = SocialProfile(
  userId: 'me',
  displayName: '나의 공개 기록',
  handle: 'my.public',
);
const _author = SocialProfile(
  userId: 'author',
  displayName: '함께 걷는 날들을 기록하는 해린',
  handle: 'haerin.travel.archive',
  bio: '오래 간직할 여행의 순간들',
);

class _WorkImageClient extends Mock implements HttpClient {}

class _WorkImageRequest extends Mock implements HttpClientRequest {}

class _WorkImageResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _WorkImageResponse(this.statusCode);

  @override
  final int statusCode;
  final Uint8List bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

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
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _withWorkImageResponses(
  WidgetTester tester,
  int Function(Uri) status,
  Future<void> Function(List<String>) body, {
  Future<void> Function(Uri)? beforeResponse,
}) async {
  final previous = painting.debugNetworkImageHttpClientProvider;
  final client = _WorkImageClient();
  final requests = <String>[];
  when(() => client.getUrl(any())).thenAnswer((invocation) async {
    final uri = invocation.positionalArguments.single as Uri;
    requests.add(uri.toString());
    final request = _WorkImageRequest();
    when(() => request.close()).thenAnswer((_) async {
      await beforeResponse?.call(uri);
      return _WorkImageResponse(status(uri));
    });
    return request;
  });
  painting.debugNetworkImageHttpClientProvider = () => client;
  try {
    await body(requests);
  } finally {
    await tester.pumpWidget(const SizedBox());
    painting.debugNetworkImageHttpClientProvider = previous;
    painting.PaintingBinding.instance.imageCache.clear();
    painting.PaintingBinding.instance.imageCache.clearLiveImages();
  }
}

Future<void> _settleWorkImage(WidgetTester tester) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    final image = find.byType(Image);
    if (image.evaluate().isNotEmpty) {
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(image.first).image,
          tester.element(image.first),
          onError: (_, _) {},
        ),
      );
    }
    // A fresh URL can start its decode during this frame; service that decode
    // in the next real-async cycle instead of settling an indefinite spinner.
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

SocialWork _work({
  String id = 'travel-work',
  SocialProfile author = _author,
  String title = '바다를 따라 남긴 우리의 아주 긴 여행 기록',
  String caption = '함께 걸었던 순간을 한 권으로 모았어요.',
  String topic = '여행',
  String status = 'published',
  bool image = false,
  int likes = 42,
  int comments = 3,
  double aspectRatio = 1,
  List<String>? imageUrls,
}) => SocialWork(
  id: id,
  kind: 'moment',
  author: author,
  title: title,
  caption: caption,
  topic: topic,
  status: status,
  imageUrls:
      imageUrls ??
      (image
          ? [
              'https://fixture.invalid/$id/0.png',
              'https://fixture.invalid/$id/1.png',
            ]
          : []),
  likeCount: likes,
  commentCount: comments,
  aspectRatio: aspectRatio,
  createdAt: DateTime(2026, 10, 25),
);

class _FeedRepository extends SocialRepository {
  _FeedRepository(this.works)
    : super(
        SupabaseClient(
          'https://fixture.invalid',
          'public-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  List<SocialWork> works;
  String? currentActor = 'me';
  final _savedByActor = <String, Set<String>>{};
  final _likedByActor = <String, Set<String>>{};
  final _followedByActor = <String, Set<String>>{};
  Set<String> get saved =>
      _savedByActor.putIfAbsent(currentActor ?? 'guest', () => {});
  Set<String> get liked =>
      _likedByActor.putIfAbsent(currentActor ?? 'guest', () => {});
  Set<String> get followed =>
      _followedByActor.putIfAbsent(currentActor ?? 'guest', () => {});
  final likeWrites = <(String?, String, bool)>[];
  final saveWrites = <(String?, String, bool)>[];
  final followWrites = <(String?, String, bool)>[];
  final pendingLikes = <Completer<void>>[];
  final pendingSaves = <Completer<void>>[];
  Completer<void>? feedBarrier, workBarrier;
  List<List<SocialWork>>? feedPages;
  final feedQueries = <SocialFeedQuery>[];
  final searches = <String>[];
  final profileSearches = <String>[];
  final visibilityCalls = <(String, bool)>[];
  int feedFailures = 0, saveCalls = 0, commentCalls = 0;
  int lostLikeResponses = 0, lostSaveResponses = 0;
  int lostCommentResponses = 0;
  final commentRequestIds = <String?>[];
  final commentsByWork = <String, List<SocialComment>>{};
  final commentsByRequest = <String, SocialComment>{};
  bool failComment = false, failWork = false;

  SocialProfile _profile(SocialProfile person) => SocialProfile(
    userId: person.userId,
    displayName: person.displayName,
    handle: person.handle,
    bio: person.bio,
    avatarUrl: person.avatarUrl,
    followersCount: _followedByActor.values
        .where((ids) => ids.contains(person.userId))
        .length,
    followingCount: _followedByActor[person.userId]?.length ?? 0,
    worksCount: works
        .where(
          (work) => work.author.userId == person.userId && work.isPublished,
        )
        .length,
    isFollowing: followed.contains(person.userId),
  );

  SocialWork _view(SocialWork work, {String? status}) => SocialWork(
    id: work.id,
    kind: work.kind,
    author: _profile(work.author),
    title: work.title,
    caption: work.caption,
    topic: work.topic,
    status: status ?? work.status,
    imageUrls: work.imageUrls,
    likeCount:
        work.likeCount +
        _likedByActor.values.where((ids) => ids.contains(work.id)).length,
    commentCount: work.commentCount + (commentsByWork[work.id]?.length ?? 0),
    isLiked: liked.contains(work.id),
    isSaved: saved.contains(work.id),
    createdAt: work.createdAt,
    aspectRatio: work.aspectRatio,
  );

  SocialWorkPage _workPage(List<SocialWork> list, int offset, int limit) {
    final items = list.skip(offset).take(limit).toList();
    return SocialWorkPage(
      items: items,
      hasMore: offset + items.length < list.length,
      nextOffset: offset + items.length,
    );
  }

  SocialProfilePage _profilePage(
    List<SocialProfile> list,
    int offset,
    int limit,
  ) {
    final items = list.skip(offset).take(limit).toList();
    return SocialProfilePage(
      items: items,
      hasMore: offset + items.length < list.length,
      nextOffset: offset + items.length,
    );
  }

  @override
  Future<SocialWorkPage> fetchOwnWorksPage({
    String status = 'all',
    int offset = 0,
    int limit = 12,
  }) async => _workPage(
    (await fetchOwnWorks())
        .where(
          (w) =>
              status == 'all' ||
              (status == 'public' ? w.isPublished : !w.isPublished),
        )
        .toList(),
    offset,
    limit,
  );
  @override
  Future<SocialWorkPage> fetchSavedWorksPage({
    int offset = 0,
    int limit = 12,
  }) async => _workPage(await fetchSavedWorks(), offset, limit);
  @override
  Future<SocialWorkPage> fetchProfileWorksPage(
    String id, {
    int offset = 0,
    int limit = 12,
  }) async => _workPage(await fetchProfileWorks(id), offset, limit);
  @override
  Future<SocialWorkPage> searchPage(
    String query, {
    int offset = 0,
    int limit = 12,
  }) async => _workPage(await search(query), offset, limit);
  @override
  Future<SocialProfilePage> searchProfilesPage(
    String query, {
    int offset = 0,
    int limit = 12,
  }) async => _profilePage(await searchProfiles(query), offset, limit);
  final commentOffsets = <int>[];
  final failedCommentOffsets = <int>{};
  @override
  Future<SocialCommentPage> fetchCommentsPage(
    String id, {
    int offset = 0,
    int limit = 12,
  }) async {
    commentOffsets.add(offset);
    if (failedCommentOffsets.remove(offset))
      throw StateError('Synthetic older comments failure');
    final comments = (await fetchComments(id)).reversed.toList();
    final items = comments.skip(offset).take(limit).toList();
    return SocialCommentPage(
      items: items,
      hasMore: offset + items.length < comments.length,
      nextOffset: offset + items.length,
    );
  }

  @override
  Future<void> deleteComment(String id) async {
    for (final comments in commentsByWork.values) {
      comments.removeWhere((comment) => comment.id == id);
    }
  }

  @override
  Future<SocialWorkPage> fetchFeed({
    bool following = false,
    String? topic,
    int offset = 0,
    int limit = 12,
  }) async {
    feedQueries.add(
      SocialFeedQuery(
        following: following,
        topic: topic,
        offset: offset,
        limit: limit,
      ),
    );
    final barrier = feedBarrier;
    if (barrier != null) await barrier.future;
    if (feedFailures > 0) {
      feedFailures--;
      throw StateError('Synthetic temporary feed error');
    }
    var pageIndex = 0, pageStart = 0;
    if (feedPages != null) {
      while (pageIndex + 1 < feedPages!.length &&
          offset >= pageStart + feedPages![pageIndex].length) {
        pageStart += feedPages![pageIndex].length;
        pageIndex++;
      }
    }
    final items = (feedPages == null ? works : feedPages![pageIndex])
        .where((work) {
          return work.isPublished &&
              (!following || followed.contains(work.author.userId)) &&
              (topic == null || work.topic == topic);
        })
        .map(_view)
        .toList();
    return SocialWorkPage(
      items: items,
      hasMore: feedPages != null && pageIndex < feedPages!.length - 1,
      nextOffset: offset + items.length,
    );
  }

  @override
  Future<SocialProfile?> fetchProfile(String userId) async =>
      _profile(userId == 'me' ? _me : _author);
  @override
  Future<SocialProfile> ensureOwnProfile() async => _profile(_me);
  @override
  Future<bool> setFollowing(String userId, bool desired) async {
    followWrites.add((currentActor, userId, desired));
    desired ? followed.add(userId) : followed.remove(userId);
    return desired;
  }

  @override
  Future<List<SocialProfile>> fetchBlockedProfiles() async => [];
  @override
  Future<List<SocialWork>> fetchProfileWorks(String userId) async => works
      .where((work) => work.author.userId == userId && work.isPublished)
      .map(_view)
      .toList();
  @override
  Future<SocialWork?> fetchWork(String id) async {
    final barrier = workBarrier;
    if (barrier != null) await barrier.future;
    if (failWork) throw StateError('Synthetic work loading failure');
    final work = works.where((work) => work.id == id).firstOrNull;
    return work == null ? null : _view(work);
  }

  @override
  Future<List<SocialWork>> fetchOwnWorks() async => works
      .where((work) => work.author.userId == 'me' && work.status != 'deleted')
      .map(_view)
      .toList();
  @override
  Future<List<SocialWork>> fetchSavedWorks() async => works
      .where((work) => saved.contains(work.id) && work.isPublished)
      .map(_view)
      .toList();
  @override
  Future<bool> setSaved(String id, bool desired) async {
    saveCalls++;
    saveWrites.add((currentActor, id, desired));
    final target = saved;
    final lost = lostSaveResponses > 0;
    if (lost) lostSaveResponses--;
    if (pendingSaves.isNotEmpty) await pendingSaves.removeAt(0).future;
    desired ? target.add(id) : target.remove(id);
    if (lost) throw StateError('Saved committed; response lost');
    return desired;
  }

  @override
  Future<bool> setLiked(String id, bool desired) async {
    likeWrites.add((currentActor, id, desired));
    final target = liked;
    final lost = lostLikeResponses > 0;
    if (lost) lostLikeResponses--;
    if (pendingLikes.isNotEmpty) await pendingLikes.removeAt(0).future;
    desired ? target.add(id) : target.remove(id);
    if (lost) throw StateError('Like committed; response lost');
    return desired;
  }

  @override
  Future<List<SocialComment>> fetchComments(String id) async =>
      commentsByWork[id] ?? [];
  @override
  Future<SocialComment> addComment(
    String id,
    String body, {
    String? requestId,
    String? parentCommentId,
  }) async {
    commentCalls++;
    commentRequestIds.add(requestId);
    if (failComment) throw StateError('Synthetic comment failure');
    if (requestId != null && commentsByRequest.containsKey(requestId)) {
      return commentsByRequest[requestId]!;
    }
    final comment = SocialComment(
      id: 'comment-$commentCalls',
      author: _me,
      body: body,
      createdAt: DateTime(2026),
    );
    commentsByWork.putIfAbsent(id, () => []).add(comment);
    if (requestId != null) commentsByRequest[requestId] = comment;
    if (lostCommentResponses > 0) {
      lostCommentResponses--;
      throw StateError('Comment committed; response lost');
    }
    return comment;
  }

  @override
  Future<List<SocialWork>> search(String query) async {
    searches.add(query);
    return works
        .where(
          (work) =>
              work.isPublished && '${work.title} ${work.topic}'.contains(query),
        )
        .map(_view)
        .toList();
  }

  @override
  Future<List<SocialProfile>> searchProfiles(String query) async {
    profileSearches.add(query);
    return query == '여행' ? [_author] : [];
  }

  @override
  Future<void> setWorkVisibility(String id, bool published) async {
    visibilityCalls.add((id, published));
    works = works
        .map(
          (work) => work.id == id
              ? _view(work, status: published ? 'published' : 'withdrawn')
              : work,
        )
        .toList();
  }

  @override
  Future<SocialWorkPage> fetchProfileMomentsPage(
    String userId, {
    int offset = 0,
    int limit = 12,
  }) async => SocialWorkPage(
    items: works
        .where(
          (work) =>
              work.author.userId == userId && work.isMoment && work.isPublished,
        )
        .toList(),
    hasMore: false,
    nextOffset: works.length,
  );

  @override
  Future<void> deleteWork(String id) async {
    works = works
        .map((work) => work.id == id ? _view(work, status: 'deleted') : work)
        .toList();
  }
}

Widget _app(
  Widget screen,
  _FeedRepository repository, {
  String? Function()? actor,
  bool dark = false,
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    socialCurrentUserIdProvider.overrideWith(
      (_) => repository.currentActor = actor == null ? 'me' : actor(),
    ),
    socialAuthStateProvider.overrideWith((_) => const Stream<String?>.empty()),
    socialRepositoryProvider.overrideWithValue(repository),
    socialProfileMomentMonthsPageProvider.overrideWith(
      (_, _) async => const SocialMomentMonthsPage(
        items: [],
        hasMore: false,
        nextOffset: 0,
      ),
    ),
  ],
  child: MaterialApp(
    theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
      splashFactory: NoSplash.splashFactory,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: screen,
  ),
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 35,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _withDecodedNetworkImages(Future<void> Function() body) async {
  await mockNetworkImagesFor(() async {
    // Use the mock client explicitly: an earlier failure test may have already
    // initialized NetworkImage's process-wide default client.
    final previous = painting.debugNetworkImageHttpClientProvider;
    final client = HttpClient();
    painting.debugNetworkImageHttpClientProvider = () => client;
    try {
      await body();
    } finally {
      painting.debugNetworkImageHttpClientProvider = previous;
    }
  });
}

Future<void> _decodeDetailImages(
  WidgetTester tester,
  Iterable<SocialWork> works, {
  Finder? screen,
}) async {
  final context = tester.element(screen ?? find.byType(SocialWorkDetailScreen));
  await tester.runAsync(() async {
    for (final work in works) {
      for (final url in work.imageUrls) {
        await precacheImage(
          ResizeImage(NetworkImage(url), width: 1440),
          context,
        );
      }
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://fixture.invalid/mock.png'));
  });

  testWidgets(
    'older comments remain reachable past the legacy hundred-comment cap',
    (tester) async {
      final repository = _FeedRepository([_work()]);
      repository.commentsByWork['travel-work'] = List.generate(
        101,
        (index) => SocialComment(
          id: 'history-$index',
          author: _author,
          body: '이야기 번호 $index',
          createdAt: DateTime(2026).add(Duration(minutes: index)),
        ),
      );
      await tester.pumpWidget(
        _app(const SocialWorkDetailScreen(workId: 'travel-work'), repository),
      );
      await tester.pumpAndSettle();
      for (var page = 0; page < 8; page++) {
        await _scrollTo(tester, find.text('이전 댓글 더 보기'));
        await tester.tap(find.text('이전 댓글 더 보기'));
        await tester.pumpAndSettle();
      }
      expect(
        repository.commentOffsets.toSet(),
        containsAll([0, 12, 24, 36, 48, 60, 72, 84, 96]),
      );
      expect(find.text('이야기 번호 0'), findsOneWidget);
      expect(find.text('이야기 번호 100'), findsOneWidget);
      expect(find.text('이전 댓글 더 보기'), findsNothing);
      expect(
        tester.getTopLeft(find.text('이야기 번호 0')).dy,
        lessThan(tester.getTopLeft(find.text('이야기 번호 100')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed older comment page retains current discussion and can retry',
    (tester) async {
      final repository = _FeedRepository([_work()])
        ..failedCommentOffsets.add(12);
      repository.commentsByWork['travel-work'] = List.generate(
        13,
        (index) => SocialComment(
          id: 'history-$index',
          author: _author,
          body: '이야기 번호 $index',
          createdAt: DateTime(2026),
        ),
      );
      await tester.pumpWidget(
        _app(const SocialWorkDetailScreen(workId: 'travel-work'), repository),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('이전 댓글 더 보기'));
      await tester.tap(find.text('이전 댓글 더 보기'));
      await tester.pumpAndSettle();
      expect(find.text('이야기 번호 12'), findsOneWidget);
      expect(find.text('이야기 번호 0'), findsNothing);
      await tester.tap(find.text('이전 댓글 다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('이야기 번호 0'), findsOneWidget);
      expect(find.text('이야기 번호 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a failed middle comment page stays visible as a retry after revalidation',
    (tester) async {
      final repository = _FeedRepository([_work()]);
      repository.commentsByWork['travel-work'] = List.generate(
        25,
        (index) => SocialComment(
          id: 'history-$index',
          author: _author,
          body: '이야기 번호 $index',
          createdAt: DateTime(2026),
        ),
      );
      await tester.pumpWidget(
        _app(const SocialWorkDetailScreen(workId: 'travel-work'), repository),
      );
      await tester.pumpAndSettle();
      for (var page = 0; page < 2; page++) {
        await _scrollTo(tester, find.text('이전 댓글 더 보기'));
        await tester.tap(find.text('이전 댓글 더 보기'));
        await tester.pumpAndSettle();
      }
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialWorkDetailScreen)),
      );
      repository.failedCommentOffsets.add(12);
      container.invalidate(socialCommentsPageProvider);
      await tester.pumpAndSettle();
      expect(find.text('이야기 번호 24'), findsOneWidget);
      expect(find.text('이야기 번호 0'), findsOneWidget);
      expect(find.text('이야기 번호 12'), findsNothing);
      await _scrollTo(tester, find.text('이전 댓글 다시 불러오기'));
      await tester.tap(find.text('이전 댓글 다시 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('이야기 번호 12'), findsOneWidget);
      expect(
        repository.commentOffsets.where((offset) => offset == 12).length,
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final detail in [false, true]) {
    for (final save in [false, true]) {
      testWidgets(
        'desired ${save ? 'save' : 'like'} recovers a lost response detail=$detail',
        (tester) async {
          final repository = _FeedRepository([_work()]);
          if (save) {
            repository.lostSaveResponses = 1;
          } else {
            repository.lostLikeResponses = 1;
          }
          await tester.pumpWidget(
            _app(
              detail
                  ? const SocialWorkDetailScreen(workId: 'travel-work')
                  : const SocialFeedScreen(),
              repository,
            ),
          );
          await tester.pumpAndSettle();
          final action = find.byTooltip(save ? '기록 저장' : '좋아요');
          await _scrollTo(tester, action);
          await tester.tap(action);
          await tester.pumpAndSettle();
          final cancel = find.byTooltip(save ? '기록 저장 해제' : '좋아요 취소');
          await _scrollTo(tester, cancel);
          expect(
            save ? repository.saved : repository.liked,
            contains('travel-work'),
          );
          expect(
            (save ? repository.saveWrites : repository.likeWrites).map(
              (write) => write.$3,
            ),
            [true],
          );
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(save ? repository.saved : repository.liked, isEmpty);
          expect(
            (save ? repository.saveWrites : repository.likeWrites).map(
              (write) => write.$3,
            ),
            [true, false],
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'account change discards late reaction error without clearing the new busy state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        String? actor = 'me';
        final first = Completer<void>(), second = Completer<void>();
        final repository = _FeedRepository([_work()])
          ..lostLikeResponses = 1
          ..pendingLikes.addAll([first, second]);
        await tester.pumpWidget(
          _app(
            const SocialWorkDetailScreen(workId: 'travel-work'),
            repository,
            actor: () => actor,
          ),
        );
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.byTooltip('좋아요'));
        await tester.tap(find.byTooltip('좋아요'));
        await tester.pump();
        final reaction = find.byKey(const ValueKey('social-like-travel-work'));
        expect(
          tester.getSemantics(reaction).hasFlag(ui.SemanticsFlag.isEnabled),
          false,
        );
        expect(
          tester
              .getSemantics(reaction)
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          false,
        );
        await tester.tap(find.byTooltip('좋아요'));
        await tester.pump();
        expect(repository.likeWrites, hasLength(1));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SocialWorkDetailScreen)),
        );
        actor = 'other';
        container.invalidate(socialCurrentUserIdProvider);
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.byTooltip('좋아요'));
        await tester.tap(find.byTooltip('좋아요'));
        await tester.pump();
        expect(repository.likeWrites, [
          ('me', 'travel-work', true),
          ('other', 'travel-work', true),
        ]);
        first.complete();
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(reaction).hasFlag(ui.SemanticsFlag.isEnabled),
          false,
        );
        expect(find.text('요청 결과를 확인하지 못했어요. 최신 상태를 다시 확인할게요.'), findsNothing);
        second.complete();
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.byTooltip('좋아요 취소'));
        final data = tester.getSemantics(reaction).getSemanticsData();
        expect(
          tester.getSemantics(reaction).hasFlag(ui.SemanticsFlag.isToggled),
          true,
        );
        expect(data.label, '좋아요 취소');
        expect(data.value, '44개');
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'feed comment opens the loaded conversation once without keyboard or sending',
    (tester) async {
      final gate = Completer<void>();
      final caption = List.filled(
        25,
        '함께 걸었던 오래 간직할 순간들을 기록해요. ',
      ).join().substring(0, 500);
      final work = _work(caption: caption);
      final repository = _FeedRepository([work])..workBarrier = gate;
      await tester.pumpWidget(_app(const SocialFeedScreen(), repository));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byTooltip('댓글 보기'));
      await tester.tap(find.byTooltip('댓글 보기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester
            .widget<SocialWorkDetailScreen>(find.byType(SocialWorkDetailScreen))
            .showComments,
        true,
      );
      expect(find.text('공개 기록과 앨범을 불러오고 있어요.'), findsOneWidget);
      gate.complete();
      repository.workBarrier = null;
      await tester.pumpAndSettle();
      expect(find.text('이 기록에 남긴 이야기').hitTestable(), findsOneWidget);
      expect(tester.testTextInput.isVisible, false);
      expect(repository.commentCalls, 0);
      await tester.ensureVisible(find.text(work.title));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialWorkDetailScreen)),
      );
      container.invalidate(socialWorkProvider(work.id));
      await tester.pumpAndSettle();
      expect(find.text(work.title).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('monthly feed loading remains honest until records arrive', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = _FeedRepository([_work()])..feedBarrier = gate;
    await tester.pumpWidget(_app(const SocialFeedScreen(), repository));
    await tester.pump();
    expect(find.text('공개한 기록을 불러오고 있어요.'), findsOneWidget);
    expect(find.byType(SocialFeedCard), findsNothing);
    gate.complete();
    repository.feedBarrier = null;
    await tester.pumpAndSettle();
    expect(find.byType(SocialFeedCard), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(repository.feedQueries.last.topic, isNull);
  });

  testWidgets('offset pages never render the same work twice', (tester) async {
    final first = _work(id: 'first'),
        overlap = _work(id: 'overlap'),
        last = _work(id: 'last');
    final repository = _FeedRepository([first, overlap, last])
      ..feedPages = [
        [first, overlap],
        [overlap, last],
      ];
    await tester.pumpWidget(_app(const SocialFeedScreen(), repository));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('기록 더 보기'));
    await tester.tap(find.text('기록 더 보기'));
    await tester.pumpAndSettle();
    expect(repository.feedQueries.last.offset, 2);
    expect(find.byKey(const ValueKey('first')), findsOneWidget);
    expect(find.byKey(const ValueKey('overlap')), findsOneWidget);
    expect(find.byKey(const ValueKey('last')), findsOneWidget);
  });

  testWidgets(
    'lost comment response retries the same request and creates one comment',
    (tester) async {
      final repository = _FeedRepository([_work()])..lostCommentResponses = 1;
      await tester.pumpWidget(
        _app(const SocialWorkDetailScreen(workId: 'travel-work'), repository),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), '오래 간직하고 싶은 기록이에요.');
      await _scrollTo(tester, find.text('댓글 남기기'));
      await tester.tap(find.text('댓글 남기기'));
      await tester.pumpAndSettle();
      expect(repository.commentsByWork['travel-work'], hasLength(1));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '오래 간직하고 싶은 기록이에요.',
      );
      await _scrollTo(tester, find.text('댓글 남기기'));
      await tester.tap(find.text('댓글 남기기'));
      await tester.pumpAndSettle();
      expect(repository.commentRequestIds, hasLength(2));
      expect(repository.commentRequestIds.first, isNotNull);
      expect(repository.commentRequestIds.toSet(), hasLength(1));
      expect(repository.commentsByWork['travel-work'], hasLength(1));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('editing a failed comment replaces its request key', (
    tester,
  ) async {
    final repository = _FeedRepository([_work()])..failComment = true;
    await tester.pumpWidget(
      _app(const SocialWorkDetailScreen(workId: 'travel-work'), repository),
    );
    await tester.pumpAndSettle();
    for (final body in ['첫 번째 이야기', '새로 고친 이야기']) {
      await _scrollTo(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), body);
      await _scrollTo(tester, find.text('댓글 남기기'));
      await tester.tap(find.text('댓글 남기기'));
      await tester.pumpAndSettle();
    }
    expect(repository.commentRequestIds.toSet(), hasLength(2));
    expect(repository.commentsByWork, isEmpty);
  });

  testWidgets(
    'expired artwork renews automatically and a decoded frame allows future recovery',
    (tester) async {
      final url = ValueNotifier('https://fixture.invalid/expired-first.png');
      addTearDown(url.dispose);
      var renewals = 0;
      await _withWorkImageResponses(
        tester,
        (uri) => uri.path.contains('fresh') ? 200 : 403,
        (requests) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Material(
                child: ValueListenableBuilder<String>(
                  valueListenable: url,
                  builder: (_, value, _) => SizedBox.square(
                    dimension: 320,
                    child: SocialWorkImage(
                      url: value,
                      onRetry: () {
                        renewals++;
                        url.value =
                            'https://fixture.invalid/fresh-$renewals.png';
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await _settleWorkImage(tester);
          expect(renewals, 1);
          expect(requests, contains('https://fixture.invalid/fresh-1.png'));
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image,
            isNotNull,
          );
          url.value = 'https://fixture.invalid/expired-second.png';
          await _settleWorkImage(tester);
          expect(renewals, 2);
          expect(requests, contains('https://fixture.invalid/fresh-2.png'));
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image,
            isNotNull,
          );
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  testWidgets(
    'permanent artwork failure renews once and keeps a semantic manual retry',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final url = ValueNotifier('https://fixture.invalid/forbidden.png');
      addTearDown(url.dispose);
      var renewals = 0;
      try {
        await _withWorkImageResponses(tester, (_) => 403, (requests) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: SnapFitTheme.light().copyWith(
                splashFactory: NoSplash.splashFactory,
              ),
              home: Material(
                child: ValueListenableBuilder<String>(
                  valueListenable: url,
                  builder: (_, value, _) => SizedBox.square(
                    dimension: 320,
                    child: SocialWorkImage(
                      url: value,
                      onRetry: () {
                        renewals++;
                        url.value =
                            'https://fixture.invalid/forbidden-$renewals.png';
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await _settleWorkImage(tester);
          expect(renewals, 1);
          url.value = 'https://fixture.invalid/another-signed-failure.png';
          await _settleWorkImage(tester);
          expect(renewals, 1, reason: 'A new URL is not a decoded success.');
          final retry = find.widgetWithText(TextButton, '이미지 다시 불러오기');
          expect(find.bySemanticsLabel('이미지 다시 불러오기'), findsOneWidget);
          final node = tester.getSemantics(retry);
          expect(
            node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            true,
          );
          tester.binding.pipelineOwner.semanticsOwner!.performAction(
            node.id,
            ui.SemanticsAction.tap,
          );
          await _settleWorkImage(tester);
          expect(renewals, 2);
          expect(retry, findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('disposed artwork ignores a late failed image response', (
    tester,
  ) async {
    final response = Completer<void>();
    var renewals = 0;
    await _withWorkImageResponses(tester, (_) => 403, (requests) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: SocialWorkImage(
              url: 'https://fixture.invalid/late-image.png',
              onRetry: () => renewals++,
            ),
          ),
        ),
      );
      await tester.pump();
      final image = find.byType(Image);
      late Future<void> loading;
      await tester.runAsync(() async {
        loading = precacheImage(
          tester.widget<Image>(image).image,
          tester.element(image),
          onError: (_, _) {},
        );
      });
      await tester.pumpWidget(const SizedBox());
      response.complete();
      await tester.runAsync(() => loading);
      await tester.pumpAndSettle();
      expect(requests, contains('https://fixture.invalid/late-image.png'));
      expect(renewals, 0);
      expect(tester.takeException(), isNull);
    }, beforeResponse: (_) => response.future);
  });

  testWidgets('a failed feed image keeps its accessible retry action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final repository = _FeedRepository([
        _work(id: 'failed-photo', image: true),
      ]);
      await tester.pumpWidget(_app(const SocialFeedScreen(), repository));
      await tester.pump();
      await tester.runAsync(() async {
        await precacheImage(
          ResizeImage(
            const NetworkImage('https://fixture.invalid/failed-photo/0.png'),
            width: 1440,
          ),
          tester.element(find.byType(SocialFeedScreen)),
          onError: (_, _) {},
        );
      });
      await tester.pumpAndSettle();
      final retry = find.widgetWithText(TextButton, '이미지 다시 불러오기');
      await _scrollTo(tester, retry);
      expect(find.bySemanticsLabel('이미지 다시 불러오기'), findsOneWidget);
      final retryNode = tester.getSemantics(retry);
      expect(
        retryNode.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        true,
      );
      final requests = repository.feedQueries.length;
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        retryNode.id,
        ui.SemanticsAction.tap,
      );
      await tester.pumpAndSettle();
      expect(repository.feedQueries.length, greaterThan(requests));
      expect(find.byType(SocialWorkDetailScreen), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final viewportWidth in [320.0, 390.0, 820.0, 1280.0]) {
    testWidgets(
      'feed and detail keep large original-ratio photographs at ${viewportWidth.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(viewportWidth, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _withDecodedNetworkImages(() async {
          for (final ratio in [1.5, .75, 1.0]) {
            final repository = _FeedRepository([
              _work(image: true, aspectRatio: ratio),
            ]);
            for (final detail in [false, true]) {
              await tester.pumpWidget(const SizedBox());
              await tester.pumpWidget(
                _app(
                  detail
                      ? const SocialWorkDetailScreen(workId: 'travel-work')
                      : const SocialFeedScreen(),
                  repository,
                  dark: viewportWidth == 320,
                  textScale: viewportWidth == 320 ? 1.8 : 1,
                ),
              );
              await tester.pump();
              await tester.runAsync(() async {
                final context = tester.element(
                  detail
                      ? find.byType(SocialWorkDetailScreen)
                      : find.byType(SocialFeedScreen),
                );
                for (final url in repository.works.first.imageUrls) {
                  await precacheImage(
                    ResizeImage(NetworkImage(url), width: 1440),
                    context,
                  );
                }
              });
              await tester.pumpAndSettle();
              final artwork = find.byKey(
                ValueKey(
                  'social-${detail ? 'detail' : 'feed'}-artwork-travel-work',
                ),
              );
              final contentWidth = viewportWidth.clamp(
                0.0,
                detail ? 820.0 : 1120.0,
              );
              final inset = detail && contentWidth >= 760 ? 24.0 : 16.0;
              final expectedWidth = contentWidth - inset * 2;
              final size = tester.getSize(artwork);
              expect(size.width, closeTo(expectedWidth, .01));
              expect(size.height, closeTo(expectedWidth / ratio, .01));
              final pictures = find.descendant(
                of: artwork,
                matching: find.byType(SocialWorkImage),
              );
              expect(pictures, findsWidgets);
              for (final picture in tester.widgetList<SocialWorkImage>(
                pictures,
              )) {
                expect(picture.fit, BoxFit.contain);
              }
              final decoded = find.descendant(
                of: artwork,
                matching: find.byType(RawImage),
              );
              expect(decoded, findsWidgets);
              expect(tester.widget<RawImage>(decoded.first).image, isNotNull);
              if (viewportWidth == 390) {
                expect(tester.getTopLeft(artwork).dy, lessThan(500));
              }
              expect(tester.takeException(), isNull);
            }
          }
        });
      },
    );
  }

  testWidgets('monthly feed hides album publications and opens with records', (
    tester,
  ) async {
    final repository = _FeedRepository([
      _work(id: 'record'),
      SocialWork(
        id: 'album-only',
        author: _author,
        title: '공개 앨범',
        createdAt: DateTime.utc(2026, 10, 28),
      ),
    ]);
    await tester.pumpWidget(_app(const SocialFeedScreen(), repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('record')), findsOneWidget);
    expect(find.byKey(const ValueKey('album-only')), findsNothing);
    expect(find.byTooltip('한 장의 기록 남기기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feed reactions persist and expose the updated actual state', (
    tester,
  ) async {
    final repository = _FeedRepository([_work()]);
    await tester.pumpWidget(_app(const SocialFeedScreen(), repository));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byTooltip('좋아요'));
    await tester.tap(find.byTooltip('좋아요'));
    await tester.pumpAndSettle();
    expect(repository.liked, contains('travel-work'));
    await _scrollTo(tester, find.byTooltip('좋아요 취소'));
    expect(find.text('43'), findsOneWidget);
    await _scrollTo(tester, find.byTooltip('기록 저장'));
    await tester.tap(find.byTooltip('기록 저장'));
    await tester.pumpAndSettle();
    expect(repository.saved, contains('travel-work'));
    await _scrollTo(tester, find.byTooltip('기록 저장 해제'));
    await tester.tap(find.byTooltip('기록 저장 해제'));
    await tester.pumpAndSettle();
    expect(repository.saved, isEmpty);
    expect(repository.saveCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest can cancel a reaction without creating a like or save', (
    tester,
  ) async {
    final repository = _FeedRepository([_work()]);
    await tester.pumpWidget(
      _app(const SocialFeedScreen(), repository, actor: () => null),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byTooltip('좋아요'));
    await tester.tap(find.byTooltip('좋아요'));
    await tester.pumpAndSettle();
    expect(find.text('로그인하고 기록을 이어가세요.'), findsOneWidget);
    await tester.tap(find.text('계속 둘러보기'));
    await tester.pumpAndSettle();
    expect(repository.liked, isEmpty);
    expect(repository.saved, isEmpty);
    expect(repository.saveCalls, 0);
    expect(find.byType(SocialFeedScreen), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'published detail preserves controls at 320px large text dark=$dark',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _FeedRepository([_work(likes: 1234, comments: 123)]);
        await tester.pumpWidget(
          _app(
            const SocialWorkDetailScreen(workId: 'travel-work'),
            repository,
            dark: dark,
            textScale: 2.2,
          ),
        );
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.byTooltip('기록 저장'));
        expect(find.text('1234'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SocialReactions),
            matching: find.text('123'),
          ),
          findsOneWidget,
        );
        await _scrollTo(tester, find.text('댓글 남기기'));
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'comment action reaches its section beyond a long large-text caption',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final caption = List.filled(
        25,
        '기억하고 싶은 여행의 순간을 차곡차곡 기록했어요. ',
      ).join().substring(0, 500);
      final repository = _FeedRepository([_work(caption: caption)]);
      await tester.pumpWidget(
        _app(
          const SocialWorkDetailScreen(workId: 'travel-work'),
          repository,
          textScale: 2.2,
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byTooltip('댓글 보기'));
      await tester.tap(find.byTooltip('댓글 보기'));
      await tester.pumpAndSettle();
      expect(find.text('이 기록에 남긴 이야기').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('feed retries then preserves the following query', (
    tester,
  ) async {
    final repository = _FeedRepository([
      _work(),
      _work(id: 'daily', topic: '일상', title: '느린 하루'),
    ])..feedFailures = 1;

    await tester.pumpWidget(_app(const SocialFeedScreen(), repository));
    await tester.pumpAndSettle();
    expect(find.text('기록을 불러오지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byType(SocialFeedCard), findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, '팔로잉'));
    await tester.pumpAndSettle();
    expect(repository.feedQueries.last.following, isTrue);
    expect(find.text('새로운 기록을 기다리고 있어요.'), findsOneWidget);
    await tester.tap(find.text('최신 피드 보기'));
    await tester.pumpAndSettle();
    expect(repository.feedQueries.last.topic, isNull);
    expect(repository.feedQueries.last.following, isFalse);
    expect(find.byKey(const ValueKey('daily')), findsOneWidget);
    expect(find.byKey(const ValueKey('travel-work')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'feed pages swipe without navigating and reactions retain the selected page',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _withDecodedNetworkImages(() async {
        final urls = [
          'https://fixture.invalid/storage/v1/object/sign/works/first.png?token=old',
          'https://fixture.invalid/storage/v1/object/sign/works/second.png?token=old',
        ];
        final repository = _FeedRepository([_work(imageUrls: urls)]);
        await tester.pumpWidget(_app(const SocialFeedScreen(), repository));
        await tester.pump();
        await _decodeDetailImages(
          tester,
          repository.works,
          screen: find.byType(SocialFeedScreen),
        );
        final pages = find.byKey(
          const ValueKey('social-feed-pages-travel-work'),
        );
        final counter = find.byKey(
          const ValueKey('social-feed-page-count-travel-work'),
        );
        await tester.drag(pages, const Offset(-330, 0));
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(counter).data, '2 / 2');
        expect(find.byType(SocialWorkDetailScreen), findsNothing);
        await _scrollTo(tester, find.byTooltip('좋아요'));
        await tester.tap(find.byTooltip('좋아요'));
        await tester.pumpAndSettle();
        expect(repository.liked, contains('travel-work'));
        expect(tester.widget<Text>(counter).data, '2 / 2');
        repository.works = [
          _work(
            imageUrls: urls
                .map((url) => url.replaceAll('token=old', 'token=new'))
                .toList(),
          ),
        ];
        ProviderScope.containerOf(
          tester.element(find.byType(SocialFeedScreen)),
        ).invalidate(socialFeedProvider);
        await tester.pump();
        await _decodeDetailImages(
          tester,
          repository.works,
          screen: find.byType(SocialFeedScreen),
        );
        expect(
          tester.widget<Text>(counter).data,
          '2 / 2',
          reason: 'A renewed signature is still the same published page.',
        );
        await _scrollTo(tester, pages);
        await tester.tap(
          find.byKey(const ValueKey('social-feed-image-travel-work-1')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SocialWorkDetailScreen>(
                find.byType(SocialWorkDetailScreen),
              )
              .initialPage,
          1,
        );
        expect(find.text('2 / 2'), findsOneWidget);
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        repository.works = [_work(imageUrls: urls.reversed.toList())];
        ProviderScope.containerOf(
          tester.element(find.byType(SocialFeedScreen)),
        ).invalidate(socialFeedProvider);
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(counter).data,
          '1 / 2',
          reason: 'Actual page order changes reset the preview.',
        );

        await _scrollTo(
          tester,
          find.byKey(const ValueKey('social-feed-open-travel-work')),
        );
        await tester.tap(
          find.byKey(const ValueKey('social-feed-open-travel-work')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SocialWorkDetailScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('feed routes the selected author and work to matching detail', (
    tester,
  ) async {
    await _withDecodedNetworkImages(() async {
      final repository = _FeedRepository([_work(image: true)]);

      await tester.pumpWidget(_app(const SocialFeedScreen(), repository));
      await tester.pump();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(SocialFeedScreen));
        for (final url in repository.works.first.imageUrls) {
          await precacheImage(
            ResizeImage(NetworkImage(url), width: 1440),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text(_author.displayName).first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SocialProfileScreen>(find.byType(SocialProfileScreen))
            .userId,
        'author',
      );
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      final detail = find.byKey(const ValueKey('social-feed-open-travel-work'));
      await _scrollTo(tester, detail);
      await tester.tap(detail);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SocialWorkDetailScreen>(find.byType(SocialWorkDetailScreen))
            .workId,
        'travel-work',
      );
      expect(find.text('1 / 2'), findsOneWidget);
      await _scrollTo(tester, find.byTooltip('다음 공개 페이지'));
      await tester.tap(find.byTooltip('다음 공개 페이지'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('이 스타일로 만들기'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'detail retains its page on reaction refresh and syncs fullscreen page changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _withDecodedNetworkImages(() async {
        final repository = _FeedRepository([
          _work(
            image: true,
            aspectRatio: .75,
            imageUrls: [
              'https://fixture.invalid/functions/v1/social-media?work=travel-work&position=0&token=initial',
              'https://fixture.invalid/functions/v1/social-media?work=travel-work&position=1&token=initial',
            ],
          ),
        ]);
        await tester.pumpWidget(
          _app(
            const SocialWorkDetailScreen(workId: 'travel-work'),
            repository,
            dark: true,
            textScale: 2.2,
          ),
        );
        await tester.pump();
        await _decodeDetailImages(tester, repository.works);
        await _scrollTo(tester, find.byTooltip('다음 공개 페이지'));
        await tester.tap(find.byTooltip('다음 공개 페이지'));
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);
        await _scrollTo(tester, find.byTooltip('좋아요'));
        await tester.tap(find.byTooltip('좋아요'));
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);

        await _scrollTo(tester, find.byTooltip('기록 크게 보기'));
        await tester.tap(find.byTooltip('기록 크게 보기'));
        await tester.pumpAndSettle();
        final viewer = find.byKey(
          const ValueKey('social-artwork-viewer-travel-work'),
        );
        final count = find.byKey(
          const ValueKey('social-fullscreen-page-count'),
        );
        expect(viewer, findsOneWidget);
        expect(tester.widget<Text>(count).data, '2 / 2');
        await tester.tap(find.byTooltip('사진 확대'));
        await tester.pumpAndSettle();
        expect(find.text('150%'), findsOneWidget);

        final original = repository.works.single;
        final renewed = SocialWork(
          id: original.id,
          author: original.author,
          title: original.title,
          caption: original.caption,
          topic: original.topic,
          imageUrls: original.imageUrls
              .map((url) => url.replaceFirst('token=initial', 'token=renewed'))
              .toList(),
          status: original.status,
          createdAt: original.createdAt,
          likeCount: original.likeCount,
          commentCount: original.commentCount,
          aspectRatio: original.aspectRatio,
        );
        repository.works = [renewed];
        await _decodeDetailImages(tester, repository.works);
        ProviderScope.containerOf(
          tester.element(find.byType(SocialWorkDetailScreen)),
        ).invalidate(socialWorkProvider(original.id));
        await tester.pumpAndSettle();
        expect(viewer, findsOneWidget);
        expect(tester.widget<Text>(count).data, '2 / 2');
        expect(find.text('150%'), findsOneWidget);

        await tester.tap(find.byTooltip('이전 확대 페이지'));
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(count).data, '1 / 2');
        expect(find.text('100%'), findsOneWidget);
        await tester.tap(find.byTooltip('확대 감상 닫기'));
        await tester.pumpAndSettle();
        expect(viewer, findsNothing);
        expect(find.text('1 / 2'), findsOneWidget);
        expect(repository.liked, contains('travel-work'));
        expect(tester.takeException(), isNull);
      });
    },
  );

  for (final change in ['account', 'work', 'visibility', 'asset']) {
    testWidgets('$change changes dismiss only their own artwork viewer route', (
      tester,
    ) async {
      await _withDecodedNetworkImages(() async {
        String? actor = 'me';
        var workId = 'travel-work';
        late VoidCallback changeWork;
        final repository = _FeedRepository([
          _work(author: _me, image: true),
          _work(id: 'other-work', author: _me, image: true, title: '다른 공개 작품'),
        ]);
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) {
                changeWork = () => setState(() => workId = 'other-work');
                return SocialWorkDetailScreen(workId: workId);
              },
            ),
            repository,
            actor: () => actor,
          ),
        );
        await tester.pump();
        await _decodeDetailImages(tester, repository.works);
        final context = tester.element(find.byType(SocialWorkDetailScreen));
        final container = ProviderScope.containerOf(context);
        await _scrollTo(tester, find.byTooltip('기록 크게 보기'));
        await tester.tap(find.byTooltip('기록 크게 보기'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('social-artwork-viewer-travel-work')),
          findsOneWidget,
        );
        unawaited(
          showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('다른 대화상자 유지'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('이 대화상자 닫기'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        switch (change) {
          case 'account':
            actor = 'other';
            container.invalidate(socialCurrentUserIdProvider);
          case 'work':
            changeWork();
          case 'visibility':
            repository.works = [
              repository._view(repository.works.first, status: 'withdrawn'),
              repository.works.last,
            ];
            container.invalidate(socialWorkProvider('travel-work'));
          case 'asset':
            repository.works = [
              _work(
                author: _me,
                imageUrls: repository.works.first.imageUrls
                    .map(
                      (url) =>
                          url.replaceFirst('/travel-work/', '/replaced-work/'),
                    )
                    .toList(),
              ),
              repository.works.last,
            ];
            await _decodeDetailImages(tester, repository.works);
            container.invalidate(socialWorkProvider('travel-work'));
        }
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('social-artwork-viewer-travel-work')),
          findsNothing,
        );
        expect(find.text('다른 대화상자 유지'), findsOneWidget);
        await tester.tap(find.text('이 대화상자 닫기'));
        await tester.pumpAndSettle();
        if (change == 'work') {
          expect(
            tester
                .widget<SocialWorkDetailScreen>(
                  find.byType(SocialWorkDetailScreen),
                )
                .workId,
            'other-work',
          );
        }
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets(
    'feed and detail keep like and save state synchronized when returning',
    (tester) async {
      final repository = _FeedRepository([_work()]);
      await tester.pumpWidget(_app(const SocialFeedScreen(), repository));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byTooltip('좋아요'));
      await tester.tap(find.byTooltip('좋아요'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byTooltip('기록 저장'));
      await tester.tap(find.byTooltip('기록 저장'));
      await tester.pumpAndSettle();

      final artwork = find.byKey(
        const ValueKey('social-feed-artwork-travel-work'),
      );
      await _scrollTo(tester, artwork);
      await tester.tap(artwork);
      await tester.pumpAndSettle();
      expect(find.byType(SocialWorkDetailScreen), findsOneWidget);
      await _scrollTo(tester, find.byTooltip('좋아요 취소'));
      expect(find.text('43'), findsOneWidget);
      expect(find.byTooltip('기록 저장 해제'), findsOneWidget);
      await tester.tap(find.byTooltip('좋아요 취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byTooltip('좋아요'));
      expect(find.text('42'), findsOneWidget);
      expect(find.byTooltip('기록 저장 해제'), findsOneWidget);
      expect(repository.liked, isEmpty);
      expect(repository.saved, contains('travel-work'));
      expect(repository.likeWrites, [
        ('me', 'travel-work', true),
        ('me', 'travel-work', false),
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile follow and unfollow immediately refresh the returning following feed',
    (tester) async {
      final repository = _FeedRepository([_work()]);
      await tester.pumpWidget(_app(const SocialFeedScreen(), repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_author.displayName).first);
      await tester.pumpAndSettle();
      final follow = find.widgetWithText(FilledButton, '팔로우');
      await _scrollTo(tester, follow);
      await tester.tap(follow);
      await tester.pumpAndSettle();
      expect(repository.followWrites, [('me', 'author', true)]);
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '팔로잉'));
      await tester.pumpAndSettle();
      expect(repository.feedQueries.last.following, isTrue);
      expect(find.byKey(const ValueKey('travel-work')), findsOneWidget);

      await tester.tap(find.text(_author.displayName).first);
      await tester.pumpAndSettle();
      final unfollow = find.widgetWithText(OutlinedButton, '팔로잉');
      await _scrollTo(tester, unfollow);
      await tester.tap(unfollow);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '팔로우 해제'));
      await tester.pumpAndSettle();
      expect(repository.followWrites, [
        ('me', 'author', true),
        ('me', 'author', false),
      ]);
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      expect(repository.feedQueries.last.following, isTrue);
      expect(find.byType(SocialFeedCard), findsNothing);
      expect(find.text('새로운 기록을 기다리고 있어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search switches between public works and users with recent removal',
    (tester) async {
      final repository = _FeedRepository([_work()]);

      await tester.pumpWidget(_app(const SocialSearchScreen(), repository));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, '여행'));
      await tester.pumpAndSettle();
      expect(repository.searches, ['여행']);
      expect(repository.profileSearches, ['여행']);
      expect(find.text(_work().title), findsOneWidget);
      await tester.tap(find.text('사용자'));
      await tester.pumpAndSettle();
      expect(find.text(_author.displayName), findsOneWidget);
      await tester.tap(find.byTooltip('검색어 지우기'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('여행 검색 기록 삭제'), findsOneWidget);
      await tester.tap(find.byTooltip('여행 검색 기록 삭제'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('여행 검색 기록 삭제'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved works can be removed and session logout hides old collection',
    (tester) async {
      String? actor = 'me';
      final repository = _FeedRepository([_work()])..saved.add('travel-work');

      await tester.pumpWidget(
        _app(const SocialSavedWorksScreen(), repository, actor: () => actor),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('저장 해제'));
      await tester.tap(find.text('저장 해제'));
      await tester.pumpAndSettle();
      expect(repository.saveCalls, 1);
      expect(find.text('아직 저장한 기록이나 앨범이 없어요.'), findsOneWidget);
      repository.saved.add('travel-work');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialSavedWorksScreen)),
      );
      container.invalidate(socialSavedWorksProvider);
      container.invalidate(socialSavedWorksPageProvider);
      await tester.pumpAndSettle();
      expect(find.text(_work().title), findsOneWidget);
      actor = null;
      container.invalidate(socialCurrentUserIdProvider);
      await tester.pumpAndSettle();
      expect(find.text('나만 보는 기록·앨범 보관함'), findsOneWidget);
      expect(find.text(_work().title), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manage applies visibility only to the chosen work and hides on logout',
    (tester) async {
      String? actor = 'me';
      final first = _work(id: 'mine-a', author: _me, title: '공개 작품 A');
      final second = _work(
        id: 'mine-b',
        author: _me,
        title: '보관 작품 B',
        status: 'withdrawn',
      );
      final repository = _FeedRepository([first, second]);

      await tester.pumpWidget(
        _app(const SocialWorksManageScreen(), repository, actor: () => actor),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('비공개로 전환'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '비공개 전환'));
      await tester.pumpAndSettle();
      expect(repository.visibilityCalls, [('mine-a', false)]);
      expect(repository.works.first.status, 'withdrawn');
      expect(repository.works.last.title, second.title);
      await tester.tap(find.widgetWithText(ChoiceChip, '비공개 보관'));
      await tester.pumpAndSettle();
      expect(find.text(first.title), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialWorksManageScreen)),
      );
      actor = null;
      container.invalidate(socialCurrentUserIdProvider);
      await tester.pumpAndSettle();
      expect(find.text('내 공개 기록과 앨범을 관리해요.'), findsOneWidget);
      expect(find.text(first.title), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed comment preserves text and an account change clears it', (
    tester,
  ) async {
    String? actor = 'me';
    final repository = _FeedRepository([_work()])..failComment = true;

    await tester.pumpWidget(
      _app(
        const SocialWorkDetailScreen(workId: 'travel-work'),
        repository,
        actor: () => actor,
      ),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), '보내지 못한 나의 이야기');
    await _scrollTo(tester, find.text('댓글 남기기'));
    await tester.tap(find.text('댓글 남기기'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '보내지 못한 나의 이야기',
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SocialWorkDetailScreen)),
    );
    actor = null;
    container.invalidate(socialCurrentUserIdProvider);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 900), const Size(1180, 920)]) {
    testWidgets(
      'feed fits dark ${size.width.toInt()}px with large text and counts',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _FeedRepository([_work(likes: 1234, comments: 123)]);

        await tester.pumpWidget(
          _app(
            const SocialFeedScreen(),
            repository,
            dark: true,
            textScale: 1.6,
          ),
        );
        await tester.pumpAndSettle();
        await _scrollTo(tester, find.byTooltip('기록 저장'));
        expect(find.text('1234'), findsOneWidget);
        expect(find.text('123'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('search and saved cards fit 320px dark large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FeedRepository([_work()])..saved.add('travel-work');

    await tester.pumpWidget(
      _app(const SocialSearchScreen(), repository, dark: true, textScale: 1.6),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '여행'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text(_work().title));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      _app(
        const SocialSavedWorksScreen(),
        repository,
        dark: true,
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('저장 해제'));
    expect(tester.takeException(), isNull);
  });

  for (final destination in ['detail-error', 'saved-guest', 'manage-guest']) {
    testWidgets('$destination fits 320x568 with 2.2 text scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FeedRepository([])..failWork = true;
      final Widget screen = switch (destination) {
        'detail-error' => const SocialWorkDetailScreen(workId: 'unavailable'),
        'saved-guest' => const SocialSavedWorksScreen(),
        _ => const SocialWorksManageScreen(),
      };
      await tester.pumpWidget(
        _app(
          screen,
          repository,
          actor: () => destination == 'detail-error' ? 'me' : null,
          dark: true,
          textScale: 2.2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('populated search fits 720px with 2.2 text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(720, 920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FeedRepository([_work()]);
    await tester.pumpWidget(
      _app(const SocialSearchScreen(), repository, dark: true, textScale: 2.2),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '여행'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text(_work().title));
    expect(tester.takeException(), isNull);
  });
}
