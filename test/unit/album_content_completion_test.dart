import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/design_templates.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/utils/album_progress.dart';

Map<String, dynamic> photo(String? url) => {
  'type': 'IMAGE',
  'templateContent': false,
  'payload': <String, dynamic>{'previewUrl': url},
};
Map<String, dynamic> text(String value, {bool template = false}) => {
  'type': 'TEXT',
  'templateContent': template,
  'payload': <String, dynamic>{'text': value},
};
Album book(List<List<Map<String, dynamic>>> pages, {int target = 2}) => Album(
  id: 123,
  targetPages: target,
  totalPages: 99,
  coverLayersJson: jsonEncode({
    'pages': [
      {'index': 0, 'isCover': true, 'layers': []},
      for (var i = 0; i < pages.length; i++)
        {'index': i + 1, 'layers': pages[i]},
    ],
  }),
);

void main() {
  test('the first filled interior counts without filling the facing page', () {
    final first = photo('https://uploads.example/first.jpg');
    final second = photo('https://uploads.example/second.jpg');
    for (final zeroBased in [false, true]) {
      Album saved(List<Map<String, dynamic>> secondPage) => Album(
        targetPages: 2,
        coverLayersJson: jsonEncode({
          'pages': [
            if (!zeroBased)
              {
                'index': 0,
                'isCover': true,
                'layers': [photo('https://uploads.example/cover.jpg')],
              },
            {
              'index': zeroBased ? 0 : 1,
              'isCover': false,
              'layers': [first],
            },
            {
              'index': zeroBased ? 1 : 2,
              'isCover': false,
              'layers': secondPage,
            },
          ],
        }),
      );
      final one = calculateAlbumProgress(saved([]));
      expect(one.completedPages, 1, reason: 'zero-based interiors: $zeroBased');
      expect(one.targetPages, 2);
      expect(one.ratio, .5);
      final both = calculateAlbumProgress(saved([second]));
      expect(
        both.completedPages,
        2,
        reason: 'zero-based interiors: $zeroBased',
      );
      expect(both.isCompleted, isTrue);
    }
  });

  test('zero-based interior gaps and duplicates cannot complete an album', () {
    for (final indices in [
      <int>[0, 2],
      <int>[0, 0],
    ]) {
      final progress = calculateAlbumProgress(
        Album(
          targetPages: 2,
          coverLayersJson: jsonEncode({
            'pages': [
              for (final index in indices)
                {
                  'index': index,
                  'isCover': false,
                  'layers': [photo('https://uploads.example/$index.jpg')],
                },
            ],
          }),
        ),
      );
      expect(progress.targetPages, indices.last == 2 ? 3 : 2);
      expect(progress.completedPages, indices.last == 2 ? 2 : 1);
      expect(progress.isCompleted, isFalse);
    }
  });

  test('backgrounds, frames and stickers never complete a page alone', () {
    for (final type in ['DECORATION', 'STICKER']) {
      for (final payload in [
        {'fillColor': '#E7ECEB'},
        {'imageBackground': 'studioSageRibbon'},
        {'imageUrl': 'asset:assets/sticker/scrap1.png'},
        {'previewUrl': 'https://materials.example/sticker.png'},
      ]) {
        final ornament = {
          'type': type,
          'templateContent': false,
          'payload': payload,
        };
        final result = calculateAlbumProgress(
          book([
            [ornament],
          ], target: 1),
        );
        expect(result.completedPages, 0, reason: '$type $payload');
        expect(result.isCompleted, isFalse);
        expect(
          calculateAlbumProgress(
            book([
              [ornament, text('내가 쓴 기록')],
            ], target: 1),
          ).isCompleted,
          isTrue,
        );
      }
    }
  });

  test('sample and placeholder text cannot stand in for an authored page', () {
    for (final key in ['isSample', 'isPlaceholder']) {
      for (final inPayload in [false, true]) {
        final example = text('여기에 기록을 남겨 주세요');
        (inPayload ? example['payload'] as Map : example)[key] = true;
        expect(
          calculateAlbumProgress(
            book([
              [example],
            ], target: 1),
          ).isCompleted,
          isFalse,
        );
      }
    }
  });

  test('parsing a JSON design never certifies its sample text or photo', () {
    for (final type in ['TEXT', 'IMAGE']) {
      final example = DataTemplateEngine.buildLayersFromJson({
        'strictLayout': true,
        'layers': [
          {
            'id': 'example',
            'type': type,
            'x': .1,
            'y': .1,
            'w': .5,
            'h': .5,
            'payload': {
              'text': 'Our days',
              'previewUrl': 'https://stock.example/preview.jpg',
            },
          },
        ],
      }, const Size(500, 500)).single;
      expect(example.isTemplateContent, isNull);
      Map<String, dynamic> save(LayerModel layer) =>
          LayerExportMapper.toJson(layer, canvasSize: const Size(500, 500));
      expect(
        calculateAlbumProgress(
          book([
            [save(example)],
          ], target: 1),
        ).isCompleted,
        isFalse,
      );
      final edited = type == 'TEXT'
          ? example.copyWith(text: '우리가 함께한 봄날')
          : example.copyWith(previewUrl: 'https://uploads.example/photo.jpg');
      expect(
        calculateAlbumProgress(
          book([
            [save(edited)],
          ], target: 1),
        ).isCompleted,
        isTrue,
      );
    }
  });

  test('automatic preview injection stays sample content', () {
    final empty = LayerModel(
      id: 'slot',
      type: LayerType.image,
      position: Offset.zero,
    );
    final personal = empty.copyWith(
      id: 'filled',
      previewUrl: 'https://uploads.example/personal.jpg',
    );
    final template = DesignTemplate(
      id: 'preview-policy',
      name: 'Preview',
      previewImageUrls: const ['https://stock.example/sample.jpg'],
      buildLayers: (_) => [empty, personal],
    );
    final layers = injectTemplatePreviewImages(template, [
      empty,
      personal,
    ], fillPersistentUrls: true);
    expect(layers.first.isTemplateContent, isTrue);
    expect(layers.last.isTemplateContent, isFalse);
    expect(layers.last.previewUrl, personal.previewUrl);
    expect(
      calculateAlbumProgress(
        book([
          [
            for (final layer in layers)
              LayerExportMapper.toJson(layer, canvasSize: const Size(500, 500)),
          ],
        ], target: 1),
      ).isCompleted,
      isFalse,
    );
  });

  test('layout changes and edge whitespace do not author example text', () {
    for (final marker in [true, null]) {
      final example = LayerModel(
        id: 'caption',
        type: LayerType.text,
        position: Offset.zero,
        isTemplateContent: marker,
        text: 'Our days',
      );
      final styled = example.copyWith(
        position: const Offset(40, 40),
        width: 220,
        rotation: .2,
        textStyle: const TextStyle(fontSize: 22),
        text: '\nOur days  ',
      );
      expect(styled.isTemplateContent, marker);
      expect(
        calculateAlbumProgress(
          book([
            [
              LayerExportMapper.toJson(
                styled,
                canvasSize: const Size(500, 500),
              ),
            ],
          ], target: 1),
        ).isCompleted,
        isFalse,
      );
    }
  });

  test('legacy example-only books stay unfinished without provenance', () {
    final album = book([
      for (var page = 0; page < 24; page++)
        [
          {
            'type': 'TEXT',
            'payload': {'text': 'Our days · $page'},
          },
          {
            'type': 'DECORATION',
            'payload': {'fillColor': '#E7ECEB'},
          },
          {
            'type': 'STICKER',
            'payload': {'imageBackground': 'studioSageRibbon'},
          },
        ],
    ], target: 24);
    final result = calculateAlbumProgress(album);
    expect(result.completedPages, 0);
    expect(result.targetPages, 24);
    expect(result.isCompleted, isFalse);
  });

  test('a remote URL is not proof that a legacy sample was replaced', () {
    for (final marker in [null, true, 'false', 0]) {
      final sample = photo('https://images.example/sample.jpg')
        ..['templateContent'] = marker;
      expect(
        calculateAlbumProgress(
          book([
            [sample],
          ], target: 1),
        ).isCompleted,
        isFalse,
      );
    }
  });

  test(
    'resaving unknown text does not certify it; actual edits are explicit',
    () {
      final legacy = LayerExportMapper.toJson(
        LayerModel(
          id: 'legacy-caption',
          type: LayerType.text,
          position: const Offset(30, 30),
          text: 'Our days',
        ),
        canvasSize: const Size(500, 500),
      )..remove('templateContent');
      var layer = LayerExportMapper.fromJson(
        legacy,
        canvasSize: const Size(500, 500),
      );
      for (var cycle = 0; cycle < 3; cycle++) {
        layer = AlbumCreationTemplate.preparePages(
          [
            [layer],
          ],
          sourceCanvas: const Size(500, 500),
          cover: coverSizes.first,
          clearSamplePhotos: false,
        ).single.single;
        layer = layer.copyWith(
          position: const Offset(40, 40),
          text: 'Our days',
        );
        expect(layer.isTemplateContent, isNull);
        final saved = LayerExportMapper.toJson(
          layer,
          canvasSize: const Size(500, 500),
        );
        expect(saved.containsKey('templateContent'), isFalse);
        expect(
          calculateAlbumProgress(
            book([
              [saved],
            ], target: 1),
          ).isCompleted,
          isFalse,
        );
        layer = LayerExportMapper.fromJson(
          saved,
          canvasSize: const Size(500, 500),
        );
      }
      final personal = layer.copyWith(text: '내가 직접 쓴 여행 기록');
      final saved = LayerExportMapper.toJson(
        personal,
        canvasSize: const Size(500, 500),
      );
      expect(saved['templateContent'], isFalse);
      expect(
        LayerExportMapper.fromJson(
          saved,
          canvasSize: const Size(500, 500),
        ).isTemplateContent,
        isFalse,
      );
      expect(
        calculateAlbumProgress(
          book([
            [saved],
          ], target: 1),
        ).isCompleted,
        isTrue,
      );
      expect(
        calculateAlbumProgress(
          book([
            [saved],
            [legacy],
          ]),
        ).isCompleted,
        isFalse,
      );
    },
  );
  test(
    'duplicate, missing and invisible interiors cannot imply completion',
    () {
      for (final pages in [
        [
          {
            'index': 1,
            'layers': [text('first')],
          },
          {
            'index': 1,
            'layers': [text('duplicate')],
          },
        ],
        [
          {
            'index': 2,
            'layers': [text('missing page one')],
          },
        ],
        [
          {
            'index': 1,
            'layers': [
              {...text('invisible'), 'opacity': 0},
            ],
          },
        ],
      ]) {
        expect(
          calculateAlbumProgress(
            Album(
              targetPages: 1,
              coverLayersJson: jsonEncode({'pages': pages}),
            ),
          ).isCompleted,
          isFalse,
        );
      }
    },
  );
  test('template captions and allocated pages cannot complete empty slots', () {
    final album = book([
      [text('Our days', template: true), photo(null)],
      [text('02', template: true), photo('')],
    ]);
    final progress = calculateAlbumProgress(album);
    expect(progress.completedPages, 0);
    expect(progress.targetPages, 2);
    expect(progress.isCompleted, isFalse);
  });

  test('every photo slot must be filled even when a caption is present', () {
    final progress = calculateAlbumProgress(
      book([
        [text('My story'), photo('https://upload.example/1.jpg'), photo('')],
        [photo('https://upload.example/2.jpg')],
      ]),
    );
    expect(progress.completedPages, 1);
    expect(progress.ratio, .5);
    expect(progress.isCompleted, isFalse);
    expect(
      calculateAlbumProgress(
        book([
          [
            photo('https://upload.example/1.jpg'),
            photo('https://upload.example/2.jpg'),
          ],
          [text('직접 작성한 기록')],
        ]),
      ).isCompleted,
      isTrue,
    );
  });

  test('extra blank interiors and missing documents never become complete', () {
    final progress = calculateAlbumProgress(
      book([
        [text('기록')],
        [],
      ], target: 1),
    );
    expect(progress.completedPages, 1);
    expect(progress.targetPages, 2);
    expect(progress.isCompleted, isFalse);
    expect(
      calculateAlbumProgress(
        const Album(targetPages: 24, totalPages: 25),
      ).completedPages,
      0,
    );
  });

  test('bundled sample photos and template ornaments are excluded', () {
    final progress = calculateAlbumProgress(
      book([
        [photo('asset:assets/templates/sample.jpg')],
        [
          {
            'type': 'STICKER',
            'templateContent': true,
            'payload': {'imageBackground': 'studioSageRibbon'},
          },
        ],
      ]),
    );
    expect(progress.completedPages, 0);
    expect(
      calculateAlbumProgress(
        book([
          [
            {
              'type': 'STICKER',
              'templateContent': false,
              'payload': {'imageBackground': 'studioSageRibbon'},
            },
          ],
        ], target: 1),
      ).isCompleted,
      isFalse,
    );
  });

  test(
    'replacing a template sample marks only the selected photo as personal',
    () {
      for (final marker in [true, null]) {
        final sample = LayerModel(
          id: 'sample',
          type: LayerType.image,
          position: Offset.zero,
          isTemplateContent: marker,
          previewUrl: 'https://stock.example/sample.jpg',
        );
        final untouched = LayerExportMapper.toJson(
          sample,
          canvasSize: const Size(500, 500),
        );
        expect(
          calculateAlbumProgress(
            book([
              [untouched],
            ], target: 1),
          ).isCompleted,
          isFalse,
        );
        final selected = sample.copyWith(
          previewUrl: 'https://upload.example/my-photo.jpg',
        );
        expect(selected.isTemplateContent, isFalse);
        expect(
          calculateAlbumProgress(
            book([
              [
                LayerExportMapper.toJson(
                  selected,
                  canvasSize: const Size(500, 500),
                ),
              ],
            ], target: 1),
          ).isCompleted,
          isTrue,
        );
      }
    },
  );

  test('template provenance survives scaling, copies and saved layer JSON', () {
    final template = AlbumCreationTemplate.preparePages(
      [
        [
          LayerModel(
            id: 'caption',
            type: LayerType.text,
            text: 'Our days',
            position: Offset.zero,
          ),
        ],
      ],
      sourceCanvas: const Size(500, 500),
      cover: coverSizes.first,
    ).single.single;
    expect(template.isTemplateContent, isTrue);
    final saved = LayerExportMapper.toJson(
      template,
      canvasSize: const Size(500, 500),
    );
    final restored = LayerExportMapper.fromJson(
      saved,
      canvasSize: const Size(500, 500),
    );
    expect(restored.copyWith(text: 'Our days').isTemplateContent, isTrue);
    expect(
      calculateAlbumProgress(
        book([
          [saved],
        ], target: 1),
      ).isCompleted,
      isFalse,
    );
    final changed = restored.copyWith(text: '우리가 함께한 봄날');
    expect(changed.isTemplateContent, isFalse);
    expect(
      calculateAlbumProgress(
        book([
          [LayerExportMapper.toJson(changed, canvasSize: const Size(500, 500))],
        ], target: 1),
      ).isCompleted,
      isTrue,
    );
  });
}
