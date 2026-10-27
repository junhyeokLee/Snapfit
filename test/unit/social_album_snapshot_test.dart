import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/social/data/social_album_snapshot.dart';

Map<String, dynamic> _text(String id, [String text = '우리의 작은 기록']) => {
  'id': id,
  'type': 'TEXT',
  'x': .1,
  'y': .15,
  'width': .8,
  'height': .3,
  'scale': 1,
  'zIndex': 2,
  'payload': {
    'text': text,
    'textStyle': {
      'fontFamily': 'NotoSans',
      'fontSizeRatio': .055,
      'color': '#FF263D35',
    },
  },
};

Map<String, dynamic> _photo(String id, String? source) => {
  'id': id,
  'type': 'IMAGE',
  'x': .1,
  'y': .1,
  'width': .8,
  'height': .8,
  'scale': 1,
  'zIndex': 0,
  'payload': {'originalUrl': source},
};

Map<String, dynamic> _page(
  int index,
  List<Map<String, dynamic>> layers, {
  bool isCover = false,
}) => {
  'index': index,
  'isCover': isCover,
  'backgroundColor': 0xffffffff,
  'layers': layers,
};

Album _album(Map<String, dynamic> document, {String ratio = '1'}) => Album(
  id: 42,
  title: '테스트용 앨범',
  userId: 'synthetic-owner',
  ratio: ratio,
  coverLayersJson: jsonEncode(document),
  totalPages: 20,
);

List<String> _pngChunks(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final result = <String>[];
  var offset = 8;
  while (offset + 12 <= bytes.length) {
    final length = data.getUint32(offset);
    result.add(ascii.decode(bytes.sublist(offset + 4, offset + 8)));
    offset += 12 + length;
  }
  return result;
}

Future<Uint8List> _syntheticPhoto() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xff5599bb), BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 32);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<void> _withDecoded(
  Uint8List bytes,
  Future<void> Function(ui.Image image) inspect,
) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  try {
    await inspect(image);
  } finally {
    image.dispose();
    codec.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalizes legacy page index gaps while keeping saved array order', () {
    final snapshot = SocialAlbumSnapshot.fromAlbum(
      _album({
        'pages': [
          _page(99, [_text('cover')]),
          _page(30, [_text('first-interior')], isCover: true),
          _page(7, [_text('second-interior')]),
        ],
      }),
    );
    expect(snapshot.pages.map((page) => page.index), [0, 1, 2]);
    expect(snapshot.pages.map((page) => page.isCover), [true, false, false]);
    expect(snapshot.pages.map((page) => page.layers.single.id), [
      'cover',
      'first-interior',
      'second-interior',
    ]);
    expect(snapshot.pages.first.layers.single.rotation, 0);
    expect(
      () => snapshot.pages.add(snapshot.pages.first),
      throwsUnsupportedError,
    );
    expect(() => snapshot.pages.first.layers.clear(), throwsUnsupportedError);
  });

  test('legacy cover publishes only content present in its saved document', () {
    final snapshot = SocialAlbumSnapshot.fromAlbum(
      _album({
        'layers': [_text('legacy-cover')],
        'backgroundColor': 0xffeef1e8,
      }),
    );
    expect(snapshot.pages, hasLength(1));
    expect(snapshot.pages.single.isCover, isTrue);
    expect(snapshot.pages.single.layers.single.id, 'legacy-cover');
    expect(snapshot.pages.single.backgroundColor, const Color(0xffeef1e8));
  });

  test('rejects missing documents and malformed page/layer structures', () {
    for (final document in <Map<String, dynamic>>[
      {},
      {'pages': []},
      {
        'pages': [null],
      },
      {
        'pages': [
          {'layers': 'not-a-list'},
        ],
      },
      {
        'layers': [null],
      },
    ]) {
      expect(
        () => SocialAlbumSnapshot.fromAlbum(_album(document)),
        throwsFormatException,
        reason: '$document',
      );
    }
    expect(
      () => SocialAlbumSnapshot.fromAlbum(
        const Album(coverLayersJson: 'not-json'),
      ),
      throwsFormatException,
    );
  });

  for (final entry in <String, double>{
    '0.75': .75,
    '1:1': 1,
    '4/3': 4 / 3,
  }.entries) {
    test('keeps page geometry and cover spine omission for ${entry.key}', () {
      final snapshot = SocialAlbumSnapshot.fromAlbum(
        _album({
          'pages': [_page(0, []), _page(1, [])],
        }, ratio: entry.key),
      );
      expect(snapshot.pages.first.canvasSize.width, 486);
      expect(
        snapshot.pages.first.canvasSize.height,
        closeTo(500 / entry.value, .001),
      );
      expect(
        snapshot.pages.last.canvasSize.aspectRatio,
        closeTo(entry.value, .001),
      );
    });
  }

  testWidgets(
    'text-only pages flatten at all three ratios without photo requests',
    (tester) async {
      await tester.runAsync(() async {
        final font = FontLoader('NotoSans')
          ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'));
        await font.load();
      });
      await tester.pump();
      await tester.runAsync(() async {
        final renderer = SocialSnapshotRenderer(
          loader: (_) async {
            fail('Text-only pages must not request photos.');
          },
        );
        for (final ratio in [.75, 1.0, 4 / 3]) {
          final snapshot = SocialAlbumSnapshot.fromAlbum(
            _album({
              'pages': [
                _page(0, []),
                _page(1, [_text('title')]),
              ],
            }, ratio: '$ratio'),
          );
          final bytes = await renderer.renderPage(
            snapshot.pages.last,
            theme: ThemeData.light(),
          );
          expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
          await _withDecoded(bytes, (image) async {
            expect(
              image.width > image.height ? image.width : image.height,
              1440,
            );
            expect(image.width / image.height, closeTo(ratio, .002));
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            var inkPixels = 0;
            for (var index = 0; index + 3 < pixels.length; index += 4) {
              if (pixels[index] < 120 &&
                  pixels[index + 1] < 120 &&
                  pixels[index + 2] < 120)
                inkPixels++;
            }
            expect(
              inkPixels,
              greaterThan(100),
              reason: 'Rendered page must contain the saved text.',
            );
          });
        }
      });
    },
  );

  testWidgets(
    'selected pages keep requested order and PNG strips source identifiers',
    (tester) async {
      await tester.runAsync(() async {
        const source =
            'https://synthetic.invalid/private/chosen.jpg?token=example-secret';
        const hiddenSource = 'https://synthetic.invalid/private/unselected.jpg';
        final requested = <String>[];
        final photo = await _syntheticPhoto();
        final renderer = SocialSnapshotRenderer(
          loader: (value) async {
            requested.add(value);
            return photo;
          },
        );
        final snapshot = SocialAlbumSnapshot.fromAlbum(
          _album({
            'pages': [
              _page(0, []),
              _page(1, [_photo('hidden-photo', hiddenSource)]),
              _page(2, [_photo('chosen-photo', source)]),
            ],
          }),
        );
        final selected = [snapshot.pages[2], snapshot.pages[0]];
        expect(selected.map((page) => page.index), [2, 0]);
        for (final page in selected) {
          final bytes = await renderer.renderPage(
            page,
            theme: ThemeData.light(),
          );
          final encoded = latin1.decode(bytes);
          expect(encoded, isNot(contains(source)));
          expect(encoded, isNot(contains('example-secret')));
          expect(encoded, isNot(contains(hiddenSource)));
          expect(
            _pngChunks(bytes),
            isNot(anyElement(isIn(['tEXt', 'iTXt', 'zTXt', 'eXIf']))),
          );
          await _withDecoded(bytes, (_) async {});
        }
        expect(requested, [source]);
      });
    },
  );

  testWidgets(
    'missing or unreadable photo aborts instead of publishing placeholders',
    (tester) async {
      await tester.runAsync(() async {
        final snapshot = SocialAlbumSnapshot.fromAlbum(
          _album({
            'pages': [
              _page(0, [_photo('photo', 'memory:missing')]),
            ],
          }),
        );
        for (final bytes in [
          Uint8List(0),
          Uint8List.fromList([1, 2, 3]),
        ]) {
          await expectLater(
            SocialSnapshotRenderer(
              loader: (_) async => bytes,
            ).renderPage(snapshot.pages.single, theme: ThemeData.light()),
            throwsA(anything),
          );
        }
        final missingSource = SocialAlbumSnapshot.fromAlbum(
          _album({
            'pages': [
              _page(0, [_photo('photo', null)]),
            ],
          }),
        );
        await expectLater(
          SocialSnapshotRenderer(
            loader: (_) async {
              fail(
                'Missing sources must be rejected before requesting a photo.',
              );
            },
          ).renderPage(missingSource.pages.single, theme: ThemeData.light()),
          throwsFormatException,
        );
      });
    },
  );

  testWidgets(
    'local publication preview fits portrait, square and landscape pages',
    (tester) async {
      for (final ratio in [.75, 1.0, 4 / 3]) {
        final snapshot = SocialAlbumSnapshot.fromAlbum(
          _album({
            'pages': [
              _page(0, []),
              _page(1, [_text('preview')]),
            ],
          }, ratio: '$ratio'),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: SocialPublicationPagePreview(
                    page: snapshot.pages.last,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(SocialPublicationPagePreview), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
