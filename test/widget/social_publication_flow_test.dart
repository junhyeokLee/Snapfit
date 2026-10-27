import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/data/social_album_snapshot.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_publish_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_work_detail_screen.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _profile = SocialProfile(
  userId: _owner,
  displayName: '나의 공개 기록',
  handle: 'my.public',
);

Map<String, dynamic> _page(int index, String text) => {
  'index': index,
  'isCover': index == 0,
  'backgroundColor': 0xffffffff,
  'layers': [
    {
      'id': 'text-$index',
      'type': 'TEXT',
      'x': .15,
      'y': .2,
      'width': .7,
      'height': .3,
      'scale': 1,
      'zIndex': 1,
      'payload': {
        'text': text,
        'textStyle': {
          'fontFamily': 'NotoSans',
          'fontSizeRatio': .04,
          'color': '#FF273C30',
        },
      },
    },
  ],
};

Album _album(String title, List<Map<String, dynamic>> pages) => Album(
  id: 42,
  title: title,
  userId: _owner,
  ratio: '1:1',
  totalPages: pages.length,
  updatedAt: '2026-10-25T09:00:00.000Z',
  coverLayersJson: jsonEncode({'pages': pages}),
);

class _Albums extends Fake implements AlbumRepository {
  _Albums(this.saved);
  final Album saved;
  Completer<Album>? pending;
  final fetchedIds = <String>[];
  int updates = 0, locks = 0;

  @override
  Future<Album> fetchAlbum(String id) {
    fetchedIds.add(id);
    return pending?.future ?? Future.value(saved);
  }

  @override
  Future<List<Album>> fetchMyAlbums() async => [];

  @override
  Future<Album> updateAlbum(
    int id,
    CreateAlbumRequest request, {
    String? expectedUpdatedAt,
    String? requestId,
    String? expectedUserId,
  }) async {
    updates++;
    throw StateError('Publication must never update the source album.');
  }

  @override
  Future<void> lockAlbum(int id) async {
    locks++;
    throw StateError('Publication must never lock the editor.');
  }
}

class _PublicationRepository extends SocialRepository {
  _PublicationRepository()
    : super(
        SupabaseClient(
          'https://fixture.invalid',
          'public-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  bool loseFirstBeginResponse = false;
  bool finalized = false;
  int ensureCalls = 0;
  final requests = <Map<String, Object?>>[];
  final uploads = <int, Uint8List>{};
  final finalizedSignal = Completer<void>();

  SocialWork get result => SocialWork(
    id: '22222222-2222-4222-8222-222222222222',
    author: _profile,
    title: requests.last['title']! as String,
    createdAt: DateTime(2026, 10, 25),
  );

  @override
  Future<SocialProfile> ensureOwnProfile() async {
    ensureCalls++;
    return _profile;
  }

  @override
  Future<SocialPublicationDraft> beginPublication({
    required int albumId,
    required List<int> pageIndexes,
    required String title,
    String caption = '',
    String topic = '일상',
    String? requestId,
    String? expectedUpdatedAt,
    bool includeSourceTemplate = false,
  }) async {
    requests.add({
      'albumId': albumId,
      'pageIndexes': List<int>.of(pageIndexes),
      'title': title,
      'caption': caption,
      'topic': topic,
      'requestId': requestId,
      'expectedUpdatedAt': expectedUpdatedAt,
      'includeSourceTemplate': includeSourceTemplate,
    });
    if (loseFirstBeginResponse && requests.length == 1) {
      throw StateError('Synthetic lost response after begin.');
    }
    return SocialPublicationDraft(
      id: '22222222-2222-4222-8222-222222222222',
      pageIndexes: List.of(pageIndexes),
    );
  }

  @override
  Future<void> uploadPublicationPage(
    String draftId,
    int position,
    Uint8List png,
  ) async {
    expect(isSocialPng(png), isTrue);
    uploads[position] = Uint8List.fromList(png);
  }

  @override
  Future<SocialWork> finalizePublication(String draftId) async {
    finalized = true;
    if (!finalizedSignal.isCompleted) finalizedSignal.complete();
    return result;
  }

  @override
  Future<SocialWork?> fetchWork(String id) async => finalized ? result : null;

  @override
  Future<List<SocialComment>> fetchComments(String id) async => [];
  @override
  Future<SocialCommentPage> fetchCommentsPage(
    String id, {
    int offset = 0,
    int limit = 12,
  }) async => const SocialCommentPage(items: [], hasMore: false, nextOffset: 0);
}

Widget _host({
  required Album entry,
  required _Albums albums,
  required _PublicationRepository repository,
  required String? Function() actor,
}) => ProviderScope(
  overrides: [
    socialCurrentUserIdProvider.overrideWith((_) => actor()),
    socialAuthStateProvider.overrideWith((_) => const Stream<String?>.empty()),
    socialRepositoryProvider.overrideWithValue(repository),
    albumRepositoryProvider.overrideWithValue(albums),
  ],
  child: MaterialApp(
    theme: SnapFitTheme.light().copyWith(splashFactory: NoSplash.splashFactory),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => SocialPublishScreen(album: entry),
              ),
            ),
            child: const Text('공개 시작'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 30,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _finish(
  WidgetTester tester,
  _PublicationRepository repository,
) async {
  final publish = find.widgetWithText(FilledButton, '피드에 무료로 공개');
  await _reveal(tester, publish);
  await tester.tap(publish);
  for (var attempt = 0; attempt < 200 && !repository.finalized; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    repository.finalized,
    isTrue,
    reason:
        'Requests: ${repository.requests}; uploads: ${repository.uploads.keys}; '
        'screen: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).whereType<String>().join(" | ")}',
  );
  await tester.pumpAndSettle();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Keep --no-test-assets deterministic without copying the full catalog.
    // The renderer still validates and loads the real bundled NotoSans font.
    const font = 'assets/fonts/NotoSansKR-Regular.ttf';
    final fontBytes = await File(font).readAsBytes();
    final manifest = Uint8List.fromList(
      utf8.encode(
        jsonEncode([
          {
            'family': 'NotoSans',
            'fonts': [
              {'asset': font},
            ],
          },
        ]),
      ),
    );
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      if (message == null) return null;
      final key = utf8.decode(
        message.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (key == 'FontManifest.json') return ByteData.sublistView(manifest);
      if (key == font) return ByteData.sublistView(fontBytes);
      return null;
    });
    // Resolve the renderer's shared font future outside individual FakeAsync
    // zones, so later tests do not depend on an earlier test's microtask queue.
    await SocialSnapshotRenderer().prepareFonts(
      SocialAlbumSnapshot.fromAlbum(
        _album('Font preparation', [_page(0, 'Saved text')]),
      ).pages,
    );
  });

  tearDownAll(() {
    binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      null,
    );
  });

  testWidgets(
    'publication resolves the full saved album instead of entry data',
    (tester) async {
      final compact = _album('편집 중 미저장 제목', [_page(0, 'UNSAVED EDITOR TEXT')]);
      final fresh = _album('서버에 저장된 앨범', [
        _page(0, 'Saved cover'),
        _page(1, 'Saved first page'),
        _page(2, 'Saved second page'),
      ]);
      final originalEntry = compact.coverLayersJson;
      final originalSaved = fresh.coverLayersJson;
      final albums = _Albums(fresh);
      final repository = _PublicationRepository();

      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(
          entry: compact,
          albums: albums,
          repository: repository,
          actor: () => _owner,
        ),
      );
      await tester.tap(find.text('공개 시작'));
      await tester.pumpAndSettle();
      expect(albums.fetchedIds, ['42']);
      expect(find.text('표지'), findsOneWidget);
      expect(find.text('1쪽'), findsOneWidget);
      await _tap(tester, find.text('다음 · 3쪽'));
      final title = tester.widget<TextField>(find.byType(TextField).first);
      expect(title.controller!.text, fresh.title);
      expect(find.text('UNSAVED EDITOR TEXT'), findsNothing);
      expect(compact.coverLayersJson, originalEntry);
      expect(fresh.coverLayersJson, originalSaved);
      expect(albums.updates, 0);
      expect(albums.locks, 0);
      expect(repository.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'partial order consent and a lost begin response keep one request',
    (tester) async {
      final fresh = _album('저장된 원본', [
        _page(0, 'Saved cover'),
        _page(1, 'This page stays private'),
        _page(2, 'Selected last page'),
      ]);
      final albums = _Albums(fresh);
      final repository = _PublicationRepository()
        ..loseFirstBeginResponse = true;

      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(
          entry: fresh,
          albums: albums,
          repository: repository,
          actor: () => _owner,
        ),
      );
      await tester.tap(find.text('공개 시작'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('선택 지우기'));
      await _tap(tester, find.text('표지'));
      await _tap(tester, find.text('2쪽'));
      await _tap(tester, find.text('다음 · 2쪽'));
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      await _reveal(tester, find.text('다음 · 2쪽'));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '다음 · 2쪽'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField).first, '나의 공개 하이라이트');
      await _tap(tester, find.text('다음 · 2쪽'));
      await _reveal(tester, find.byType(CheckboxListTile));
      final up = find.byTooltip('공개 순서 앞으로');
      await tester.tap(up.last);
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('피드에 무료로 공개'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '피드에 무료로 공개'),
            )
            .onPressed,
        isNull,
      );
      await _tap(tester, find.byType(CheckboxListTile));
      await _tap(tester, find.text('피드에 무료로 공개'));
      expect(repository.requests, hasLength(1));
      expect(repository.requests.single['pageIndexes'], [2, 0]);
      expect(repository.requests.single['title'], '나의 공개 하이라이트');
      expect(repository.uploads, isEmpty);
      await _finish(tester, repository);
      expect(repository.requests, hasLength(2));
      expect(repository.requests[0]['requestId'], isNotEmpty);
      expect(
        repository.requests[1]['requestId'],
        repository.requests[0]['requestId'],
      );
      expect(repository.requests[1]['expectedUpdatedAt'], fresh.updatedAt);
      expect(repository.requests[1]['pageIndexes'], [2, 0]);
      expect(repository.uploads.keys.toList(), [0, 1]);
      expect(repository.uploads.values.every(isSocialPng), isTrue);
      expect(find.byType(SocialWorkDetailScreen), findsOneWidget);
      expect(albums.updates, 0);
      expect(albums.locks, 0);
      expect(jsonDecode(fresh.coverLayersJson)['pages'], hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing after a lost begin response starts a new publication key',
    (tester) async {
      final fresh = _album('수정 전 공개 제목', [_page(0, 'Saved cover')]);
      final albums = _Albums(fresh);
      final repository = _PublicationRepository()
        ..loseFirstBeginResponse = true;
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(
          entry: fresh,
          albums: albums,
          repository: repository,
          actor: () => _owner,
        ),
      );
      await tester.tap(find.text('공개 시작'));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('다음 · 1쪽'));
      await _tap(tester, find.text('다음 · 1쪽'));
      await _tap(tester, find.byType(CheckboxListTile));
      await _tap(tester, find.text('피드에 무료로 공개'));
      expect(repository.requests, hasLength(1));
      await _tap(tester, find.text('이전 단계에서 다시 확인'));
      await tester.enterText(find.byType(TextField).first, '다시 확인한 새 공개 제목');
      await _tap(tester, find.text('다음 · 1쪽'));
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      await _tap(tester, find.byType(CheckboxListTile));
      await _finish(tester, repository);
      expect(repository.requests, hasLength(2));
      expect(repository.requests[0]['title'], fresh.title);
      expect(repository.requests[1]['title'], '다시 확인한 새 공개 제목');
      expect(
        repository.requests[1]['requestId'],
        isNot(repository.requests[0]['requestId']),
      );
      expect(repository.uploads, hasLength(1));
      expect(find.byType(SocialWorkDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logout while loading a saved album discards the private response',
    (tester) async {
      String? actor = _owner;
      final fresh = _album('이전 계정의 비공개 제목', [_page(0, 'Private record')]);
      final albums = _Albums(fresh)..pending = Completer<Album>();
      final repository = _PublicationRepository();

      await tester.pumpWidget(
        _host(
          entry: fresh,
          albums: albums,
          repository: repository,
          actor: () => actor,
        ),
      );
      await tester.tap(find.text('공개 시작'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialPublishScreen)),
      );
      actor = null;
      container.invalidate(socialCurrentUserIdProvider);
      await tester.pump();
      albums.pending!.complete(fresh);
      await tester.pumpAndSettle();
      expect(find.text('계정이 변경됐어요.'), findsOneWidget);
      expect(find.text(fresh.title), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(repository.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
