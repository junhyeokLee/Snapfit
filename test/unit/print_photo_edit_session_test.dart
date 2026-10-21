import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/album/presentation/utils/open_print_photo_editor.dart';
import 'package:snap_fit/features/album/presentation/utils/print_photo_issue.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';

class _Albums extends Mock implements AlbumRepository {}

Map<String, dynamic> _snapshot({bool legacy = false}) {
  final photo = {
    'id': 'photo-1',
    'type': 'image',
    'x': .1,
    'y': .2,
    'width': .4,
    'height': .4,
    'scale': 1,
    'rotation': 0,
    'imageUrl': 'https://example.invalid/photo.jpg',
  };
  return {
    'album': {
      'id': 7,
      'title': 'Our album',
      'ratio': '1',
      'cover_theme': 'classic',
      'cover_layers_json': jsonEncode(
        legacy
            ? {'layers': <dynamic>[]}
            : {
                'pages': [
                  {'index': 0, 'isCover': true, 'layers': <dynamic>[]},
                  {
                    'index': 1,
                    'isCover': false,
                    'layers': [photo],
                  },
                ],
              },
      ),
    },
    'pages': legacy
        ? [
            {
              'page_number': 0,
              'layers_json': jsonEncode({
                'layers': [photo],
              }),
            },
          ]
        : <dynamic>[],
  };
}

void main() {
  late _Albums albums;
  late Album album;
  late Map<String, dynamic> snapshot;
  String? owner;
  late bool active, unsaved;
  late int edits, locks, unlocks, reads;
  late PrintPhotoEditSession session;
  PrintPhotoEditTarget target() => PrintPhotoEditTarget(
    pageIndex: 1,
    layerId: 'photo-1',
    reviewedRevision: printCheckoutRevision(snapshot),
  );
  Future<bool> edit(Album _, Map<String, dynamic> __) async {
    edits++;
    return true;
  }

  setUp(() {
    albums = _Albums();
    album = const Album(id: 7, userId: 'owner', memberRole: 'OWNER');
    snapshot = _snapshot();
    owner = 'owner';
    active = true;
    unsaved = false;
    edits = 0;
    locks = 0;
    unlocks = 0;
    reads = 0;
    when(() => albums.fetchAlbum('7')).thenAnswer((_) async => album);
    when(() => albums.lockAlbum(7)).thenAnswer((_) async {
      locks++;
      album = album.copyWith(lockedById: owner);
    });
    when(() => albums.unlockAlbum(7)).thenAnswer((_) async {
      unlocks++;
    });
    session = PrintPhotoEditSession(
      repository: albums,
      fetchSnapshot: (_) async {
        reads++;
        return snapshot;
      },
      currentOwner: () => owner,
      isActive: () => active,
      hasUnsavedChanges: () => unsaved,
    );
  });

  test(
    'saved correction validates again after lock and releases its own lock',
    () async {
      expect(await session.run(7, target(), edit: edit), isTrue);
      expect((edits, locks, unlocks, reads), (1, 1, 1, 2));
    },
  );
  test(
    'nested correction preserves a reader lock already held by this owner',
    () async {
      album = album.copyWith(lockedById: owner);
      expect(await session.run(7, target(), edit: edit), isTrue);
      expect((edits, locks, unlocks), (1, 0, 0));
    },
  );
  for (final state in [
    'viewer',
    'unknownRole',
    'otherLock',
    'wrongAlbum',
    'unsaved',
    'signedOut',
  ]) {
    test('correction blocks $state before opening the editor', () async {
      switch (state) {
        case 'viewer':
          album = album.copyWith(memberRole: 'VIEWER');
        case 'unknownRole':
          album = album.copyWith(memberRole: null, userId: 'someone');
        case 'otherLock':
          album = album.copyWith(lockedById: 'someone');
        case 'wrongAlbum':
          album = album.copyWith(id: 99);
        case 'unsaved':
          unsaved = true;
        case 'signedOut':
          owner = null;
      }
      await expectLater(
        session.run(7, target(), edit: edit),
        throwsA(isA<PrintPhotoEditUnavailable>()),
      );
      expect((edits, locks, unlocks), (0, 0, 0));
    });
  }
  test(
    'changed review and missing photo never select a different layer',
    () async {
      final old = target();
      (snapshot['album'] as Map)['title'] = 'Changed';
      await expectLater(
        session.run(7, old, edit: edit),
        throwsA(isA<PrintPhotoEditUnavailable>()),
      );
      final missing = PrintPhotoEditTarget(
        pageIndex: 1,
        layerId: 'deleted',
        reviewedRevision: printCheckoutRevision(snapshot),
      );
      await expectLater(
        session.run(7, missing, edit: edit),
        throwsA(isA<PrintPhotoEditUnavailable>()),
      );
      expect((edits, locks), (0, 0));
    },
  );
  test(
    'account change during fetch cannot open editor or lock under a new owner',
    () async {
      final pending = Completer<Album>();
      when(() => albums.fetchAlbum('7')).thenAnswer((_) => pending.future);
      final result = session.run(7, target(), edit: edit);
      owner = 'other';
      pending.complete(album);
      await expectLater(result, throwsA(isA<PrintPhotoEditUnavailable>()));
      expect((edits, locks, unlocks), (0, 0, 0));
    },
  );
  test(
    'changed document after acquiring lock aborts and releases it',
    () async {
      final old = target();
      when(() => albums.lockAlbum(7)).thenAnswer((_) async {
        locks++;
        album = album.copyWith(lockedById: owner);
        (snapshot['album'] as Map)['title'] = 'Changed meanwhile';
      });
      await expectLater(
        session.run(7, old, edit: edit),
        throwsA(isA<PrintPhotoEditUnavailable>()),
      );
      expect((edits, locks, unlocks), (0, 1, 1));
    },
  );
  test('failed lock and an unconfirmed lock do not open the editor', () async {
    when(() => albums.lockAlbum(7)).thenThrow(StateError('lock failed'));
    await expectLater(session.run(7, target(), edit: edit), throwsStateError);
    when(() => albums.lockAlbum(7)).thenAnswer((_) async {});
    await expectLater(
      session.run(7, target(), edit: edit),
      throwsA(isA<PrintPhotoEditUnavailable>()),
    );
    expect(edits, 0);
  });
  test('editor failure still releases the correction lock', () async {
    await expectLater(
      session.run(
        7,
        target(),
        edit: (_, __) async => throw StateError('editor failed'),
      ),
      throwsStateError,
    );
    expect((locks, unlocks), (1, 1));
  });
  test(
    'leaving during lock acquisition releases it without opening editor',
    () async {
      when(() => albums.lockAlbum(7)).thenAnswer((_) async {
        locks++;
        album = album.copyWith(lockedById: owner);
        active = false;
      });
      await expectLater(
        session.run(7, target(), edit: edit),
        throwsA(isA<PrintPhotoEditUnavailable>()),
      );
      expect((edits, locks, unlocks), (0, 1, 1));
    },
  );
  test(
    'account change during lock cannot unlock as the replacement account',
    () async {
      when(() => albums.lockAlbum(7)).thenAnswer((_) async {
        locks++;
        owner = 'other';
      });
      await expectLater(
        session.run(7, target(), edit: edit),
        throwsA(isA<PrintPhotoEditUnavailable>()),
      );
      expect((edits, locks, unlocks), (0, 1, 0));
    },
  );
  test('a new unsaved edit during preparation is protected', () async {
    when(() => albums.lockAlbum(7)).thenAnswer((_) async {
      locks++;
      album = album.copyWith(lockedById: owner);
      unsaved = true;
    });
    await expectLater(
      session.run(7, target(), edit: edit),
      throwsA(isA<PrintPhotoEditUnavailable>()),
    );
    expect((edits, locks, unlocks), (0, 1, 1));
  });
  for (final legacy in [false, true]) {
    test(
      'editable input preserves raw photo geometry and reviewed snapshot legacy=$legacy',
      () {
        final saved = _snapshot(legacy: legacy);
        final before = jsonEncode(saved);
        final editable = printPhotoEditableAlbum(album, saved);
        final document = PrintAlbumDocument.fromSnapshot({
          'album': {
            ...saved['album'] as Map,
            'cover_layers_json': editable.coverLayersJson,
          },
          'pages': <dynamic>[],
        });
        expect(printPhotoTargetMatchesDocument(target(), document), isTrue);
        final content = jsonDecode(editable.coverLayersJson) as Map;
        final photo = (content['pages'] as List)[1]['layers'][0] as Map;
        expect(
          (photo['x'], photo['y'], photo['width'], photo['height']),
          (.1, .2, .4, .4),
        );
        expect(jsonEncode(saved), before);
      },
    );
  }
}
