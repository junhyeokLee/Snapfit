import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/moments/data/moment_photo_codec.dart';
import 'package:snap_fit/features/moments/data/moment_publication_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/social/data/social_album_snapshot.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';

class _Social extends Mock implements SocialRepository {}

class _ArtworkRenderer extends SocialSnapshotRenderer {
  _ArtworkRenderer(this.png);
  final Uint8List png;
  List<PrintAlbumPage> prepared = [];
  PrintAlbumPage? rendered;
  @override
  Future<void> prepareFonts(Iterable<PrintAlbumPage> pages) async {
    prepared = pages.toList();
  }

  @override
  Future<Uint8List> renderPage(
    PrintAlbumPage page, {
    required ThemeData theme,
    bool watermark = false,
  }) async {
    rendered = page;
    return png;
  }
}

const _profile = SocialProfile(
  userId: 'owner',
  displayName: '나의 기록',
  handle: 'memory',
);
final _record = MomentRecord(
  id: 'record',
  recordDate: DateTime.utc(2026, 10, 28),
  caption: '오늘 남긴 빛',
  revision: 3,
  photos: List.generate(
    3,
    (index) => MomentPhoto(
      id: 'photo-$index',
      path: 'owner/moments/record/photo-$index.png',
      width: 600,
      height: 800,
    ),
  ),
);
final _work = SocialWork(
  id: 'public-work',
  author: _profile,
  title: '오늘의 기록',
  kind: 'moment',
  createdAt: _record.recordDate,
  likeCount: 7,
  commentCount: 2,
);

Map<String, dynamic> _state({
  String status = 'private',
  int revision = 4,
  String? workId,
  String? photoId,
}) => {
  'recordId': _record.id,
  'recordRevision': 3,
  'sourceRevision': 3,
  'photoId': photoId,
  'workId': workId,
  'status': status,
  'publicationRevision': revision,
};

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (value) {
          context = value;
          return const Scaffold(body: Text('저장한 기록'));
        },
      ),
    ),
  );
  return context;
}

void main() {
  setUpAll(() => registerFallbackValue(Uint8List(0)));
  late _Social social;
  late StreamController<String?> auth;
  late String? owner;
  late MomentPublicationRepository repository;
  late List<String> rasterized;
  late Future<Uint8List> Function() raster;
  final png = Uint8List.fromList(img.encodePng(img.Image(width: 3, height: 4)));

  setUp(() {
    owner = 'owner';
    auth = StreamController<String?>.broadcast(sync: true);
    social = _Social();
    rasterized = [];
    raster = () async => png;
    when(
      () => social.fetchMomentPublication('record'),
    ).thenAnswer((_) async => _state());
    when(() => social.ensureOwnProfile()).thenAnswer((_) async => _profile);
    when(
      () => social.beginMomentPublication(
        recordId: 'record',
        photoId: 'photo-1',
        expectedRevision: 3,
        requestId: 'request',
      ),
    ).thenAnswer(
      (_) async => const SocialPublicationDraft(
        id: 'draft',
        pageIndexes: [0],
        publicationRevision: 4,
      ),
    );
    when(
      () => social.uploadPublicationPage('draft', 0, any()),
    ).thenAnswer((_) async {});
    when(
      () => social.finalizePublication('draft'),
    ).thenAnswer((_) async => _work);
    when(() => social.fetchWork('public-work')).thenAnswer((_) async => _work);
    repository = MomentPublicationRepository(
      social: social,
      currentUserId: () => owner,
      authChanges: auth.stream,
      rasterizer: (photo, _) {
        rasterized.add(photo.id);
        return raster();
      },
    );
  });
  tearDown(() async {
    repository.dispose();
    await auth.close();
  });

  testWidgets('only the explicitly selected photo becomes a public PNG', (
    tester,
  ) async {
    final context = await _context(tester);
    final result = await repository.publish(
      record: _record,
      photoId: 'photo-1',
      requestId: 'request',
      context: context,
      canContinue: () => true,
    );
    expect(result.id, 'public-work');
    expect(rasterized, ['photo-1']);
    final uploaded =
        verify(
              () => social.uploadPublicationPage('draft', 0, captureAny()),
            ).captured.single
            as Uint8List;
    expect(isSocialPng(uploaded), isTrue);
    expect(uploaded, png);
    verify(
      () => social.beginMomentPublication(
        recordId: 'record',
        photoId: 'photo-1',
        expectedRevision: 3,
        requestId: 'request',
      ),
    ).called(1);
  });

  testWidgets(
    'publication renders the selected editable artwork without adding the feed caption',
    (tester) async {
      final design = MomentPhotoDesign.fromJson({
        'version': 1,
        'canvas': {'width': 500, 'height': 400},
        'backgroundColor': '#fff8edda',
        'layers': [
          {
            'id': 'original',
            'type': 'IMAGE',
            'x': 0,
            'y': 0,
            'width': 1,
            'height': 1,
            'rotation': 0,
            'payload': {'originalUrl': momentPhotoOriginalSource},
          },
          {
            'id': 'text',
            'type': 'TEXT',
            'x': .1,
            'y': .7,
            'width': .8,
            'height': .2,
            'rotation': 0,
            'payload': {
              'text': '사진 위에 쓴 글자',
              'textStyle': {'fontFamily': 'NotoSans', 'fontSizeRatio': .06},
            },
          },
          {
            'id': 'sticker',
            'type': 'DECORATION',
            'x': .7,
            'y': .1,
            'width': .1,
            'height': .1,
            'rotation': 0,
            'payload': {'imageBackground': 'stickerBlueStar'},
          },
        ],
      });
      final renderer = _ArtworkRenderer(png);
      repository.dispose();
      repository = MomentPublicationRepository(
        social: social,
        currentUserId: () => owner,
        authChanges: auth.stream,
        snapshotRenderer: renderer,
      );
      final record = MomentRecord(
        id: _record.id,
        recordDate: _record.recordDate,
        caption: _record.caption,
        revision: _record.revision,
        photos: [
          for (final photo in _record.photos)
            photo.id == 'photo-1' ? photo.withDesign(design) : photo,
        ],
      );
      final context = await _context(tester);
      await repository.publish(
        record: record,
        photoId: 'photo-1',
        requestId: 'request',
        context: context,
        canContinue: () => true,
      );
      final page = renderer.rendered!;
      expect(renderer.prepared.single, same(page));
      expect(page.canvasSize, const Size(500, 400));
      expect(page.backgroundColor, const Color(0xfff8edda));
      expect(page.layers.first.originalUrl, record.photos[1].storageUri);
      expect(page.layers.map((l) => l.text).whereType<String>(), [
        '사진 위에 쓴 글자',
      ]);
      expect(page.layers.last.imageBackground, 'stickerBlueStar');
      expect(record.photos[1].width, 600);
      expect(record.photos[1].height, 800);
      verify(() => social.uploadPublicationPage('draft', 0, png)).called(1);
    },
  );

  testWidgets('invalid selection never creates a draft or public profile', (
    tester,
  ) async {
    final context = await _context(tester);
    await expectLater(
      repository.publish(
        record: _record,
        photoId: 'not-selected',
        requestId: 'request',
        context: context,
        canContinue: () => true,
      ),
      throwsA(isA<MomentException>()),
    );
    expect(rasterized, isEmpty);
    verifyNever(() => social.ensureOwnProfile());
  });

  testWidgets(
    'a concurrently withdrawn finalize result is not reported as published',
    (tester) async {
      when(() => social.finalizePublication('draft')).thenAnswer(
        (_) async => SocialWork(
          id: 'draft',
          author: _profile,
          title: '오늘의 기록',
          kind: 'moment',
          status: 'private',
          createdAt: _record.recordDate,
        ),
      );
      final context = await _context(tester);
      await expectLater(
        repository.publish(
          record: _record,
          photoId: 'photo-1',
          requestId: 'request',
          context: context,
          canContinue: () => true,
        ),
        throwsA(isA<MomentException>()),
      );
      verify(() => social.finalizePublication('draft')).called(1);
    },
  );

  testWidgets(
    'an idempotent published lookup cannot claim a now-private work',
    (tester) async {
      when(() => social.fetchMomentPublication('record')).thenAnswer(
        (_) async => _state(
          status: 'published',
          workId: 'public-work',
          photoId: 'photo-1',
        ),
      );
      when(() => social.fetchWork('public-work')).thenAnswer(
        (_) async => SocialWork(
          id: 'public-work',
          author: _profile,
          title: '오늘의 기록',
          kind: 'moment',
          status: 'private',
          createdAt: _record.recordDate,
        ),
      );
      final context = await _context(tester);
      await expectLater(
        repository.publish(
          record: _record,
          photoId: 'photo-1',
          requestId: 'request',
          context: context,
          canContinue: () => true,
        ),
        throwsA(isA<MomentException>()),
      );
      expect(rasterized, isEmpty);
      verifyNever(() => social.ensureOwnProfile());
    },
  );

  for (final status in ['published', 'private']) {
    testWidgets(
      '$status same-photo publication retains its work and reactions',
      (tester) async {
        when(() => social.fetchMomentPublication('record')).thenAnswer(
          (_) async =>
              _state(status: status, workId: 'public-work', photoId: 'photo-1'),
        );
        when(
          () => social.setMomentPublicationVisibility(
            'public-work',
            true,
            expectedPublicationRevision: 4,
          ),
        ).thenAnswer((_) async {});
        final context = await _context(tester);
        final result = await repository.publish(
          record: _record,
          photoId: 'photo-1',
          requestId: 'another-request',
          context: context,
          canContinue: () => true,
        );
        expect(result.id, 'public-work');
        expect(result.likeCount, 7);
        expect(result.commentCount, 2);
        expect(rasterized, isEmpty);
        verifyNever(() => social.ensureOwnProfile());
        if (status == 'private')
          verify(
            () => social.setMomentPublicationVisibility(
              'public-work',
              true,
              expectedPublicationRevision: 4,
            ),
          ).called(1);
      },
    );
  }

  testWidgets(
    'logout and return to the same owner cannot finish an old draft',
    (tester) async {
      final pending = Completer<Uint8List>();
      raster = () => pending.future;
      final context = await _context(tester);
      final future = repository.publish(
        record: _record,
        photoId: 'photo-1',
        requestId: 'request',
        context: context,
        canContinue: () => true,
      );
      final assertion = expectLater(future, throwsA(isA<MomentException>()));
      await tester.pump();
      expect(rasterized, ['photo-1']);
      owner = 'other';
      auth.add(owner);
      owner = 'owner';
      auth.add(owner);
      pending.complete(png);
      await assertion;
      verifyNever(() => social.uploadPublicationPage('draft', 0, any()));
      verifyNever(() => social.finalizePublication('draft'));
    },
  );

  testWidgets(
    'an SDK refresh error stops pending publication without logout or public writes',
    (tester) async {
      final context = await _context(tester);
      final pending = Completer<Map<String, dynamic>?>();
      when(
        () => social.fetchMomentPublication('record'),
      ).thenAnswer((_) => pending.future);
      final publishing = repository.publish(
        record: _record,
        photoId: 'photo-1',
        requestId: 'request',
        context: context,
        canContinue: () => true,
      );
      final rejected = expectLater(publishing, throwsA(isA<MomentException>()));
      await tester.pump();
      auth.addError(
        StateError('fixture offline SDK refresh'),
        StackTrace.current,
      );
      pending.complete(_state());
      await rejected;
      expect(owner, 'owner');
      expect(rasterized, isEmpty);
      verifyNever(() => social.ensureOwnProfile());
      verifyNever(
        () => social.beginMomentPublication(
          recordId: 'record',
          photoId: 'photo-1',
          expectedRevision: 3,
          requestId: 'request',
        ),
      );
      verifyNever(() => social.uploadPublicationPage('draft', 0, any()));
      verifyNever(() => social.finalizePublication('draft'));

      // A fresh read can recover for the same SDK account. Consuming the error
      // never retries a publish or changes the customer's private preference.
      when(
        () => social.fetchMomentPublication('record'),
      ).thenAnswer((_) async => _state());
      final fresh = await repository.state('record');
      expect(fresh?.status, 'private');
      expect(owner, 'owner');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lost finalize response reuses its request without another raster upload',
    (tester) async {
      var began = 0;
      when(
        () => social.beginMomentPublication(
          recordId: 'record',
          photoId: 'photo-1',
          expectedRevision: 3,
          requestId: 'request',
        ),
      ).thenAnswer(
        (_) async => SocialPublicationDraft(
          id: began++ == 0 ? 'draft' : 'public-work',
          pageIndexes: [0],
          status: began == 1 ? 'draft' : 'published',
          publicationRevision: 4,
        ),
      );
      when(
        () => social.finalizePublication('draft'),
      ).thenThrow(const MomentException('응답 유실'));
      final context = await _context(tester);
      await expectLater(
        repository.publish(
          record: _record,
          photoId: 'photo-1',
          requestId: 'request',
          context: context,
          canContinue: () => true,
        ),
        throwsA(isA<MomentException>()),
      );
      final result = await repository.publish(
        record: _record,
        photoId: 'photo-1',
        requestId: 'request',
        context: context,
        canContinue: () => true,
      );
      expect(result.id, 'public-work');
      expect(rasterized, ['photo-1']);
      verify(() => social.uploadPublicationPage('draft', 0, any())).called(1);
    },
  );

  test(
    'withdrawing a pending draft uses the publication fence and confirms private',
    () async {
      var withdrawn = false;
      when(() => social.fetchMomentPublication('record')).thenAnswer(
        (_) async => withdrawn
            ? _state(revision: 5)
            : _state(status: 'draft', workId: 'draft', photoId: 'photo-1'),
      );
      when(
        () => social.setMomentPublicationVisibility(
          'draft',
          false,
          expectedPublicationRevision: 4,
        ),
      ).thenAnswer((_) async {
        withdrawn = true;
      });
      await repository.makePrivate('record');
      verify(
        () => social.setMomentPublicationVisibility(
          'draft',
          false,
          expectedPublicationRevision: 4,
        ),
      ).called(1);
    },
  );

  testWidgets(
    'a timed-out upload cannot continue to finalize after its late reply',
    (tester) async {
      final upload = Completer<void>();
      when(
        () => social.uploadPublicationPage('draft', 0, any()),
      ).thenAnswer((_) => upload.future);
      final context = await _context(tester);
      final publishing = repository.publish(
        record: _record,
        photoId: 'photo-1',
        requestId: 'request',
        context: context,
        canContinue: () => true,
      );
      final failed = expectLater(publishing, throwsA(isA<MomentException>()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 26));
      await failed;
      upload.complete();
      await tester.pump();
      verifyNever(() => social.finalizePublication('draft'));
    },
  );

  testWidgets(
    'public photo normalization preserves original ratio and a bounded PNG',
    (tester) async {
      final prepared = await tester.runAsync(
        () => prepareMomentPhoto(
          Uint8List.fromList(
            img.encodeJpg(img.Image(width: 1600, height: 800)),
          ),
          maxEdge: 1440,
          maxOutputBytes: 8 * 1024 * 1024,
        ),
      );
      expect(prepared!.width, 1440);
      expect(prepared.height, 720);
      expect(isSocialPng(prepared.bytes), isTrue);
    },
  );
}
