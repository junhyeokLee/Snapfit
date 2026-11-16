import 'dart:convert';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/utils/album_progress.dart';
import 'package:snap_fit/features/album/presentation/utils/album_progress_document.dart';

LayerModel _photo(
  String id, {
  String? url = 'https://uploads.test/personal.jpg',
  bool? template = false,
  double opacity = 1,
}) => LayerModel(
  id: id,
  type: LayerType.image,
  position: Offset.zero,
  previewUrl: url,
  isTemplateContent: template,
  opacity: opacity,
);

LayerModel _text(String value, {bool? template = false}) => LayerModel(
  id: 'text',
  type: LayerType.text,
  position: Offset.zero,
  text: value,
  isTemplateContent: template,
);

AlbumPage _page(int index, List<LayerModel> layers, {bool cover = false}) =>
    AlbumPage(
      id: 'page-$index',
      pageIndex: index,
      isCover: cover,
      layers: layers,
    );

Map<String, dynamic> _savedPage(AlbumPage page) => {
  'index': page.pageIndex,
  'isCover': page.isCover,
  'layers': [
    for (final layer in page.layers)
      {
        'type': layer.type.name,
        'templateContent': layer.isTemplateContent,
        'opacity': layer.opacity,
        'payload': {'previewUrl': layer.previewUrl, 'text': layer.text},
      },
  ],
};

void main() {
  test(
    'one-page metadata counts only unfilled personal photo slots on the first unfinished interior',
    () {
      final result = analyzeAlbumDocument(
        jsonEncode({
          'pages': [
            {'index': 0, 'isCover': true, 'layers': []},
            {
              'index': 1,
              'isCover': false,
              'layers': [
                {
                  'type': 'TEXT',
                  'templateContent': false,
                  'payload': {'text': '직접 쓴 첫 쪽'},
                },
              ],
            },
            {
              'index': 2,
              'isCover': false,
              'layers': [
                {
                  'id': 'mine',
                  'type': 'IMAGE',
                  'templateContent': false,
                  'payload': {
                    'originalUrl': 'https://photos.test/original.jpg',
                  },
                },
                {
                  'id': 'example',
                  'type': 'IMAGE',
                  'templateContent': true,
                  'payload': {'originalUrl': 'asset:sample.jpg'},
                },
                {
                  'id': 'empty',
                  'type': 'IMAGE',
                  'templateContent': false,
                  'payload': {},
                },
                {
                  'id': 'caption',
                  'type': 'TEXT',
                  'templateContent': false,
                  'payload': {'text': '내 글도 사진칸을 대신하지 않아요'},
                },
              ],
            },
            {'index': 3, 'isCover': false, 'layers': []},
          ],
        }),
      );
      expect(result.completedPages, 1);
      expect(result.firstIncompletePageIndex, 2);
      expect(result.firstIncompletePageNumber, 2);
      expect(result.firstIncompletePhotoSlots, 2);
      expect(result.firstUnfilledPhotoLayerId, 'example');
    },
  );

  test(
    'prepared page uses the same completion and next-slot rules as the home card',
    () {
      final page = _page(1, [
        _photo('personal'),
        _photo('sample', template: true),
        _photo('vacant', url: null),
      ]);
      final progress = preparedAlbumPageProgress(page);
      expect(progress.isComplete, isFalse);
      expect(progress.photoSlots, 3);
      expect(progress.filledPhotoSlots, 1);
      expect(progress.firstUnfilledPhotoId, 'sample');
      expect(
        preparedAlbumPageProgress(_page(1, [_text('내가 쓴 한 줄')])).isComplete,
        isTrue,
      );
    },
  );

  test(
    'resume skips the cover and completed pages to the first empty slot',
    () {
      final pages = [
        _page(0, [], cover: true),
        _page(1, [_photo('filled')]),
        _page(2, [_photo('empty', url: null)]),
        _page(3, [_text('직접 남긴 기록')]),
      ];
      expect(firstIncompleteAlbumPageIndex(pages), 2);
    },
  );

  test('a caption does not skip a photo page with a remaining slot', () {
    expect(
      firstIncompleteAlbumPageIndex([
        _page(0, [], cover: true),
        _page(1, [_photo('filled'), _photo('empty', url: ''), _text('내가 쓴 글')]),
      ]),
      1,
    );
  });

  test('examples, unknown provenance and invisible photos stay unfinished', () {
    for (final unfinished in [
      _photo('example', template: true),
      _photo('legacy', template: null),
      _photo('hidden', opacity: 0),
      _photo('bundled', url: 'assets/template/example.jpg'),
      _text('템플릿 문구', template: true),
      _text('기존 내용', template: null),
      _text('  '),
      LayerModel(
        id: 'sticker',
        type: LayerType.sticker,
        position: Offset.zero,
        imageUrl: 'https://uploads.test/sticker.png',
      ),
    ]) {
      expect(
        firstIncompleteAlbumPageIndex([
          _page(0, [], cover: true),
          _page(1, [unfinished]),
        ]),
        1,
        reason: unfinished.id,
      );
    }
  });

  test(
    'completed interiors and a cover-only document have no missing page',
    () {
      expect(
        firstIncompleteAlbumPageIndex([
          _page(0, [], cover: true),
          _page(1, [_photo('one'), _photo('two')]),
          _page(2, [_text('나의 기록')]),
        ]),
        isNull,
      );
      expect(
        firstIncompleteAlbumPageIndex([_page(0, [], cover: true)]),
        isNull,
      );
      expect(firstIncompleteAlbumPageIndex([]), isNull);
    },
  );

  test(
    'explicit zero-based interior returns the actual editor list position',
    () {
      expect(firstIncompleteAlbumPageIndex([_page(0, [])]), 0);
    },
  );

  test(
    'saved progress and prepared editor resume use the same content rules',
    () {
      final cases = <List<LayerModel>>[
        [],
        [_photo('sample', template: true)],
        [_photo('unknown', template: null)],
        [_photo('empty', url: null), _text('직접 쓴 글')],
        [_photo('filled')],
        [_text('직접 쓴 글')],
      ];
      for (final layers in cases) {
        final pages = [_page(0, [], cover: true), _page(1, layers)];
        final metadata = analyzeAlbumDocument(
          jsonEncode({'pages': pages.map(_savedPage).toList()}),
        );
        expect(
          firstIncompleteAlbumPageIndex(pages),
          metadata.firstIncompletePageIndex,
        );
        expect(
          metadata.completedPages,
          firstIncompleteAlbumPageIndex(pages) == null ? 1 : 0,
        );
      }
    },
  );

  test(
    'malformed interiors remain unfinished and are addressable by position',
    () {
      final metadata = analyzeAlbumDocument(
        jsonEncode({
          'pages': [
            {'index': 0, 'isCover': true, 'layers': []},
            _savedPage(_page(1, [_text('첫 기록')])),
            null,
            {'index': 3, 'layers': 'damaged'},
          ],
        }),
      );
      expect(metadata.completedPages, 1);
      expect(metadata.innerPages, 3);
      expect(metadata.firstIncompletePageIndex, 2);
    },
  );

  test('duplicate page indices cannot be inferred complete', () {
    final metadata = analyzeAlbumDocument(
      jsonEncode({
        'pages': [
          _savedPage(_page(0, [], cover: true)),
          _savedPage(_page(1, [_text('첫 기록')])),
          _savedPage(_page(1, [_text('중복 번호')])),
        ],
      }),
    );
    expect(metadata.completedPages, 1);
    expect(metadata.innerPages, 2);
    expect(metadata.firstIncompletePageIndex, 2);
  });

  test(
    'legacy hidden personal photo stays unfinished after typed restore and re-save',
    () {
      final hidden = <String, dynamic>{
        'id': 'personal-hidden',
        'type': 'IMAGE',
        'x': 0.0,
        'y': 0.0,
        'width': 1.0,
        'height': 1.0,
        'rotation': 0.0,
        'hidden': true,
        'opacity': 0.8,
        'templateContent': false,
        'payload': {'previewUrl': 'https://uploads.test/my-photo.jpg'},
      };
      final restored = LayerExportMapper.fromJson(
        hidden,
        canvasSize: const Size(300, 400),
      );
      final pages = [
        _page(0, [], cover: true),
        _page(1, [restored]),
      ];
      final saved = analyzeAlbumDocument(
        jsonEncode({
          'pages': [
            _savedPage(pages[0]),
            {
              'index': 1,
              'isCover': false,
              'layers': [hidden],
            },
          ],
        }),
      );
      expect(restored.opacity, 0);
      expect(saved.completedPages, 0);
      expect(
        firstIncompleteAlbumPageIndex(pages),
        saved.firstIncompletePageIndex,
      );
      final exported = LayerExportMapper.toJson(
        restored,
        canvasSize: const Size(300, 400),
      );
      expect(exported['opacity'], 0);
      expect(
        LayerExportMapper.fromJson(
          exported,
          canvasSize: const Size(300, 400),
        ).opacity,
        0,
      );
    },
  );

  test(
    'visible legacy photo preserves explicit opacity and defaults missing opacity to one',
    () {
      final visible = <String, dynamic>{
        'id': 'personal-visible',
        'type': 'IMAGE',
        'x': 0.0,
        'y': 0.0,
        'width': 1.0,
        'height': 1.0,
        'rotation': 0.0,
        'hidden': false,
        'opacity': 0.6,
        'templateContent': false,
        'payload': {'previewUrl': 'https://uploads.test/my-photo.jpg'},
      };
      expect(
        LayerExportMapper.fromJson(
          visible,
          canvasSize: const Size(300, 400),
        ).opacity,
        0.6,
      );
      visible.remove('opacity');
      expect(
        LayerExportMapper.fromJson(
          visible,
          canvasSize: const Size(300, 400),
        ).opacity,
        1,
      );
    },
  );
}
