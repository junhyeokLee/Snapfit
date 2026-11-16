import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_work_share_sheet.dart';

const _author = SocialProfile(
  userId: 'owner',
  displayName: '기록',
  handle: 'one',
);
const _snapshot = 'https://media.test/storage/v1/object/sign/social/a.png';
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

SocialWork _work({
  String id = 'work-one',
  String status = 'published',
  bool restricted = false,
  int? revision = 1,
  String caption = '공개 캡션',
  List<String> urls = const ['$_snapshot?token=old'],
}) => SocialWork(
  id: id,
  author: _author,
  title: '공개한 하루',
  caption: caption,
  status: status,
  isRestricted: restricted,
  publicationRevision: revision,
  imageUrls: urls,
  createdAt: DateTime.utc(2026, 11, 4),
);

String _gateway(int epoch, {int expiry = 100, String signature = 'a'}) =>
    'https://media.test/functions/v1/social-media?work=work-one&position=0&'
    'token=v1.$expiry.$epoch.-.${List.filled(64, signature).join()}';

void main() {
  test('public URI exposes only the application work route', () {
    final uri = publicSocialWorkShareUri(_work())!;
    expect(uri.scheme, 'https');
    expect(uri.userInfo, isEmpty);
    expect(uri.hasQuery, isFalse);
    expect(uri.fragment, '/works/work-one');
    expect(uri.toString(), isNot(contains('media.test')));
    expect(uri.toString(), isNot(contains('token')));
    expect(publicSocialWorkShareUri(_work(status: 'private')), isNull);
    expect(publicSocialWorkShareUri(_work(restricted: true)), isNull);
    expect(publicSocialWorkShareUri(_work(id: 'a/../../private')), isNull);
  });

  test('snapshot comparison allows renewal but rejects changed artwork', () {
    final initial = _work();
    expect(
      sameSocialWorkShareSnapshot(
        initial,
        _work(urls: ['$_snapshot?token=new']),
      ),
      isTrue,
    );
    for (final fresh in [
      null,
      _work(status: 'private'),
      _work(status: 'deleted'),
      _work(restricted: true),
      _work(revision: 2),
      _work(caption: '수정한 캡션'),
      _work(urls: ['$_snapshot?token=new&width=500']),
      _work(urls: ['https://media.test/storage/v1/object/sign/social/b.png']),
    ]) {
      expect(sameSocialWorkShareSnapshot(initial, fresh), isFalse);
    }
  });

  test(
    'gateway media epoch survives capability renewal for album snapshots',
    () {
      final initial = _work(revision: null, urls: [_gateway(7)]);
      expect(
        sameSocialWorkShareSnapshot(
          initial,
          _work(
            revision: null,
            urls: [_gateway(7, expiry: 200, signature: 'b')],
          ),
        ),
        isTrue,
      );
      expect(
        sameSocialWorkShareSnapshot(
          initial,
          _work(revision: null, urls: [_gateway(8)]),
        ),
        isFalse,
      );
    },
  );

  test('validation rejects revoked or replaced public work', () async {
    for (final fresh in [
      null,
      _work(status: 'private'),
      _work(restricted: true),
      _work(revision: 2),
    ]) {
      final session = SocialWorkShareSession(
        work: _work(),
        actorId: 'owner',
        fetchWork: () async => fresh,
        isActive: () => true,
      );
      await expectLater(session.validate(), throwsFormatException);
    }
  });

  test(
    'another author or a guest only receives link and caption choices',
    () async {
      var loaded = 0;
      for (final actor in ['other', null]) {
        final session = SocialWorkShareSession(
          work: _work(),
          actorId: actor,
          fetchWork: () async => _work(),
          isActive: () => true,
          loader: (_) async {
            loaded++;
            return _png;
          },
        );
        await session.validate();
        expect(session.photos, isEmpty);
        await expectLater(
          session.render(0, ThemeData(), () => true),
          throwsFormatException,
        );
      }
      expect(loaded, 0);
    },
  );

  test('only the chosen fresh public raster enters the PNG renderer', () async {
    final urls = [
      '$_snapshot?token=old',
      'https://media.test/storage/v1/object/sign/social/b.png?token=old',
    ];
    final fresh = [for (final url in urls) url.replaceAll('old', 'renewed')];
    final loaded = <String>[];
    var rendered = 0;
    final sourceWithMetadata = Uint8List.fromList([
      ..._png,
      ...utf8.encode('PRIVATE_SOURCE_METADATA'),
    ]);
    final session = SocialWorkShareSession(
      work: _work(urls: urls),
      actorId: 'owner',
      fetchWork: () async => _work(urls: fresh),
      isActive: () => true,
      loader: (source) async {
        loaded.add(source);
        return sourceWithMetadata;
      },
      rasterizer: (page, theme, loader) async {
        rendered++;
        expect(page.layers, hasLength(1));
        expect(page.layers.single.type, LayerType.image);
        expect(page.layers.single.originalUrl, fresh[1]);
        expect(page.canvasSize, const Size(1, 1));
        expect(page.backgroundColor, Colors.transparent);
        expect(await loader(fresh[1]), sourceWithMetadata);
        await expectLater(loader(fresh[0]), throwsStateError);
        return Uint8List.fromList(_png);
      },
    );
    await session.validate();
    expect(session.photos.map((photo) => photo.id), [
      'work-one-0',
      'work-one-1',
    ]);
    final result = await session.photos[1].render(ThemeData(), () => true);
    expect(loaded, [fresh[1]]);
    expect(rendered, 1);
    expect(result, _png);
    expect(
      utf8.decode(result, allowMalformed: true),
      isNot(contains('PRIVATE_SOURCE_METADATA')),
    );
  });

  test(
    'account changes during validation cannot resume after returning',
    () async {
      var active = true;
      final response = Completer<SocialWork?>();
      final session = SocialWorkShareSession(
        work: _work(),
        actorId: 'owner',
        fetchWork: () => response.future,
        isActive: () => active,
      );
      final pending = session.validate();
      final failed = expectLater(pending, throwsStateError);
      active = false;
      response.complete(_work());
      await failed;
    },
  );

  test(
    'closing during download prevents rasterization and a stale result',
    () async {
      var active = true;
      var rendered = 0;
      final response = Completer<Uint8List>();
      final session = SocialWorkShareSession(
        work: _work(),
        actorId: 'owner',
        fetchWork: () async => _work(),
        isActive: () => true,
        loader: (_) => response.future,
        rasterizer: (_, _, _) async {
          rendered++;
          return _png;
        },
      );
      final pending = session.render(0, ThemeData(), () => active);
      final failed = expectLater(pending, throwsStateError);
      active = false;
      response.complete(_png);
      await failed;
      expect(rendered, 0);
    },
  );

  test('closing during rendering discards the completed PNG', () async {
    var active = true;
    final response = Completer<Uint8List>();
    final started = Completer<void>();
    final session = SocialWorkShareSession(
      work: _work(),
      actorId: 'owner',
      fetchWork: () async => _work(),
      isActive: () => active,
      loader: (_) async => _png,
      rasterizer: (_, _, _) {
        started.complete();
        return response.future;
      },
    );
    final pending = session.render(0, ThemeData(), () => true);
    final failed = expectLater(pending, throwsStateError);
    await started.future;
    active = false;
    response.complete(_png);
    await failed;
  });
}
