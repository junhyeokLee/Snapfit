import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/utils/album_progress_document.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_format.dart';
import 'package:snap_fit/features/moments/domain/monthly_album_builder.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import '../helpers/mock_repositories.dart';
import 'album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

MomentPhoto _photo(
  String id, {
  int width = 1200,
  int height = 1600,
  String? path,
}) => MomentPhoto(
  id: id,
  path: path ?? 'users/owner/moments/record/$id.jpg',
  url: 'https://private.test/$id.jpg?token=expired',
  width: width,
  height: height,
);

MomentRecord _record({
  String id = 'record',
  int month = 10,
  int day = 7,
  String caption = '함께 걸었던 가을 오후',
  List<MomentPhoto>? photos,
}) => MomentRecord(
  id: id,
  recordDate: DateTime.utc(2026, month, day),
  caption: caption,
  photos:
      photos ?? [_photo('first'), _photo('second', width: 1600, height: 1200)],
  revision: 1,
);

MomentPhoto _designedPhoto(String id) {
  final photo = _photo(id);
  return photo.withDesign(
    MomentPhotoDesign.fromLayers(
      canvasSize: const Size(400, 500),
      backgroundColor: const Color(0xFFFFE5CB),
      photoSource: photo.storageUri,
      layers: [
        LayerModel(
          id: 'original',
          type: LayerType.image,
          position: const Offset(24, 28),
          width: 352,
          height: 364,
          originalUrl: photo.storageUri,
          previewUrl: photo.storageUri,
          imageUrl: photo.storageUri,
          imageTemplate: 'free',
          imageBackground: 'polaroid',
          imageZoom: 1.5,
          imageOffset: const Offset(12, -8),
        ),
        LayerModel(
          id: 'overlay',
          type: LayerType.text,
          position: const Offset(40, 400),
          width: 280,
          height: 55,
          rotation: -.05,
          zIndex: 2,
          text: '사진 속 편집 문구',
          textStyle: const TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Color(0xFF162D3A),
            shadows: [Shadow(offset: Offset(2, 3), blurRadius: 4)],
          ),
        ),
        LayerModel(
          id: 'sticker',
          type: LayerType.decoration,
          position: const Offset(320, 400),
          width: 40,
          height: 40,
          rotation: .2,
          zIndex: 3,
          imageBackground: 'stickerBlueStar',
        ),
      ],
    ),
  );
}

CreateAlbumRequest _build({
  List<MomentRecord>? records,
  List<String> ids = const ['first', 'second'],
  String? title,
}) => buildMonthlyMomentAlbum(
  month: DateTime.utc(2026, 10),
  records: records ?? [_record()],
  selectedPhotoIds: ids,
  title: title,
);

List<Map<String, dynamic>> _pages(CreateAlbumRequest request) =>
    (jsonDecode(request.coverLayersJson)['pages'] as List)
        .map((page) => Map<String, dynamic>.from(page as Map))
        .toList();

List<LayerModel> _layers(Map<String, dynamic> page) => (page['layers'] as List)
    .map(
      (layer) => LayerExportMapper.fromJson(
        Map<String, dynamic>.from(layer as Map),
        canvasSize: monthlyMomentCanvasSize,
        isCover: page['isCover'] == true,
      ),
    )
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final cover in coverSizes) {
    test(
      'registered ${cover.displayName} survives saving and album import',
      () {
        final canvas = coverCanvasBaseSize(cover);
        final original = _photo('official', width: 1800, height: 3200);
        final photo = original.withDesign(
          newMomentPhotoDesign(
            photoSize: const Size(1800, 3200),
            cover: cover,
            photoSource: original.storageUri,
          ),
        );
        final savedJson = photo.toJson();
        final saved = MomentPhoto.fromJson(jsonDecode(jsonEncode(savedJson)));
        expect(saved.design!.canvasSize, canvas);
        expect(momentCoverForDesign(saved.design)?.productId, cover.productId);
        final pages = buildMonthlyMomentAppendPages(
          month: DateTime.utc(2026, 10),
          records: [
            _record(photos: [saved]),
          ],
          selectedPhotoIds: [saved.id],
          canvasSize: canvas,
        );
        final image = (pages.single['layers'] as List)
            .map(
              (value) => LayerExportMapper.fromJson(
                Map<String, dynamic>.from(value as Map),
                canvasSize: canvas,
              ),
            )
            .singleWhere((layer) => layer.type == LayerType.image);
        expect(image.width / image.height, closeTo(1800 / 3200, .00001));
        expect(image.originalUrl, saved.storageUri);
        expect(image.position.dx, greaterThanOrEqualTo(0));
        expect(image.position.dy, greaterThanOrEqualTo(0));
        expect(
          image.position.dx + image.width,
          lessThanOrEqualTo(canvas.width + .00001),
        );
        expect(
          image.position.dy + image.height,
          lessThanOrEqualTo(canvas.height + .00001),
        );
        expect(photo.toJson(), savedJson);
        expect(jsonEncode(pages), isNot(contains('token=')));
      },
    );
  }

  test('monthly import keeps the crop authored before a format change', () {
    final photo = _designedPhoto('clipped');
    final source = photo.design!;
    const crop = Rect.fromLTWH(45, 60, 210, 290);
    final clipped = photo.withDesign(
      MomentPhotoDesign.fromLayers(
        canvasSize: source.canvasSize,
        backgroundColor: source.backgroundColor,
        photoSource: photo.storageUri,
        layers: [
          for (final layer in source.layersForPhoto(photo.storageUri))
            layer.type == LayerType.image
                ? layer.copyWith(canvasClip: crop)
                : layer,
        ],
      ),
    );
    final formatted = clipped.withDesign(
      resizeMomentPhotoDesign(clipped.design!, coverSizes[1]),
    );
    final canvas = coverCanvasBaseSize(coverSizes[2]);
    final before = formatted.toJson();
    final pages = buildMonthlyMomentAppendPages(
      month: DateTime.utc(2026, 10),
      records: [
        _record(photos: [formatted]),
      ],
      selectedPhotoIds: [formatted.id],
      canvasSize: canvas,
    );
    final image = (pages.single['layers'] as List)
        .map(
          (value) => LayerExportMapper.fromJson(
            Map<String, dynamic>.from(value as Map),
            canvasSize: canvas,
          ),
        )
        .singleWhere((layer) => layer.type == LayerType.image);
    expect(
      image.canvasClip!.width / image.canvasClip!.height,
      closeTo(crop.width / crop.height, .00001),
    );
    expect(image.imageZoom, 1.5);
    expect(image.originalUrl, photo.storageUri);
    expect(formatted.toJson(), before);
  });

  test('monthly import preserves a small absolute decoration stroke', () {
    final original = _photo('subpixel');
    final design = MomentPhotoDesign.fromLayers(
      canvasSize: const Size(4000, 4000),
      backgroundColor: Colors.white,
      photoSource: original.storageUri,
      layers: [
        LayerModel(
          id: 'original',
          type: LayerType.image,
          position: Offset.zero,
          width: 4000,
          height: 4000,
          originalUrl: original.storageUri,
        ),
        LayerModel(
          id: 'paper',
          type: LayerType.decoration,
          position: const Offset(50, 50),
          width: 400,
          height: 300,
          imageBackground: 'stickerTapeBeige',
          decorationBorderWidth: 3,
          decorationCornerRadius: 4,
          zIndex: 1,
        ),
      ],
    );
    final canvas = coverCanvasBaseSize(defaultCoverSize);
    final pages = buildMonthlyMomentAppendPages(
      month: DateTime.utc(2026, 10),
      records: [
        _record(photos: [original.withDesign(design)]),
      ],
      selectedPhotoIds: [original.id],
      canvasSize: canvas,
    );
    final paper = (pages.single['layers'] as List)
        .map(
          (value) => LayerExportMapper.fromJson(
            Map<String, dynamic>.from(value as Map),
            canvasSize: canvas,
          ),
        )
        .singleWhere((layer) => layer.id.endsWith('-paper'));
    final border = paper.decorationBorderWidth!;
    final radius = paper.decorationCornerRadius!;
    expect(
      border <= 1 ? border * paper.width : border,
      closeTo(3 * canvas.width / 4000, .000001),
    );
    expect(
      radius <= 1 ? radius * math.min(paper.width, paper.height) : radius,
      closeTo(4 * canvas.width / 4000, .000001),
    );
  });

  test(
    'append builder returns only new inner pages with stable original paths',
    () {
      final pages = buildMonthlyMomentAppendPages(
        month: DateTime.utc(2026, 10),
        records: [_record()],
        selectedPhotoIds: ['second'],
      );
      expect(pages, hasLength(1));
      expect(pages.every((p) => p['isCover'] == false), isTrue);
      expect(
        jsonEncode(pages),
        contains(
          'supabase://album-assets/users/owner/moments/record/second.jpg',
        ),
      );
      expect(jsonEncode(pages), isNot(contains('moment-cover')));
    },
  );

  setUpAll(() async {
    for (final font in {
      'Eulyoo': 'assets/fonts/Eulyoo1945-Regular.ttf',
      'NotoSans': 'assets/fonts/NotoSansKR-Regular.ttf',
      'Poppins': 'assets/fonts/Poppins-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  for (final cover in [...coverSizes, legacyCoverSizes.first]) {
    test('append respects ${cover.displayName} without stretching photos', () {
      final canvas = coverCanvasBaseSize(cover);
      final caption = List.filled(100, '가').join();
      final record = _record(caption: caption);
      final pages = buildMonthlyMomentAppendPages(
        month: DateTime.utc(2026, 10),
        records: [record],
        selectedPhotoIds: ['second', 'first'],
        canvasSize: canvas,
      );
      final layers = pages
          .expand(
            (page) => (page['layers'] as List).map(
              (value) => LayerExportMapper.fromJson(
                Map<String, dynamic>.from(value as Map),
                canvasSize: canvas,
                isCover: false,
              ),
            ),
          )
          .toList();
      final photos = layers.where((layer) => layer.type == LayerType.image);
      expect(photos.map((layer) => layer.id), [
        'moment-second-photo',
        'moment-first-photo',
      ]);
      expect(photos.first.width / photos.first.height, closeTo(4 / 3, .0001));
      expect(photos.last.width / photos.last.height, closeTo(3 / 4, .0001));
      expect(photos.every((layer) => layer.imageZoom == 1), isTrue);
      expect(layers.where((layer) => layer.text == caption), isEmpty);
      expect(pages, hasLength(2));
      for (final layer in layers) {
        expect(layer.position.dx, greaterThanOrEqualTo(0));
        expect(layer.position.dy, greaterThanOrEqualTo(0));
        expect(
          layer.position.dx + layer.width,
          lessThanOrEqualTo(canvas.width),
        );
        expect(
          layer.position.dy + layer.height,
          lessThanOrEqualTo(canvas.height),
        );
        if (layer.type != LayerType.text) continue;
        final painter = TextPainter(
          text: TextSpan(text: layer.text, style: layer.textStyle),
          textAlign: layer.textAlign ?? TextAlign.left,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: layer.width);
        expect(painter.didExceedMaxLines, isFalse);
        expect(painter.height, lessThanOrEqualTo(layer.height + .001));
        painter.dispose();
      }
    });
  }

  test(
    'append preview preserves saved pages and uses the actual append output',
    () {
      final saved = {
        'printProduct': coverSizes[1].printProduct,
        'authorSettings': {'keep': true},
        'pages': [
          {
            'index': 0,
            'isCover': true,
            'backgroundColor': 0xFF20434A,
            'custom': ['keep this cover'],
            'layers': [],
          },
          {
            'index': 1,
            'isCover': false,
            'backgroundColor': 0xFFFAF7EF,
            'custom': {'handmade': true},
            'layers': [],
          },
        ],
      };
      final original = jsonEncode(saved);
      final canvas = coverCanvasBaseSize(coverSizes[1]);
      final preview = buildMonthlyMomentAppendPreview(
        existingDocumentJson: original,
        month: DateTime.utc(2026, 10),
        records: [_record()],
        selectedPhotoIds: ['second', 'first'],
        canvasSize: canvas,
      );
      final appended = buildMonthlyMomentAppendPages(
        month: DateTime.utc(2026, 10),
        records: [_record()],
        selectedPhotoIds: ['second', 'first'],
        canvasSize: canvas,
      );
      expect(preview.existingPages, saved['pages']);
      expect(preview.pages.take(2), saved['pages']);
      expect(preview.pendingPages, [
        for (var index = 0; index < appended.length; index++)
          {...appended[index], 'index': index + 2},
      ]);
      expect(
        preview.pendingPages.every((page) => page['isCover'] == false),
        isTrue,
      );
      expect(jsonEncode(saved), original);

      final cleared = buildMonthlyMomentAppendPreview(
        existingDocumentJson: original,
        month: DateTime.utc(2026, 10),
        records: [_record()],
        selectedPhotoIds: [],
        canvasSize: canvas,
      );
      expect(cleared.pages, saved['pages']);
      expect(cleared.pendingPages, isEmpty);
    },
  );

  test('append preview rejects unreadable documents and page overflow', () {
    for (final document in [
      'invalid',
      '{}',
      '{"pages":[]}',
      '{"pages":[{}]}',
    ]) {
      expect(
        () => buildMonthlyMomentAppendPreview(
          existingDocumentJson: document,
          month: DateTime.utc(2026, 10),
          records: [_record()],
          selectedPhotoIds: ['first'],
          canvasSize: monthlyMomentCanvasSize,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => buildMonthlyMomentAppendPreview(
        existingDocumentJson: jsonEncode({
          'pages': List.generate(81, (index) => {'index': index, 'layers': []}),
        }),
        month: DateTime.utc(2026, 10),
        records: [_record()],
        selectedPhotoIds: ['first'],
        canvasSize: monthlyMomentCanvasSize,
      ),
      throwsArgumentError,
    );
  });

  for (final count in [1, 2, 9]) {
    test('monthly defaults keep all $count photos in chronological order', () {
      final records = List.generate(
        count,
        (index) => _record(
          id: 'record-$index',
          day: index + 1,
          photos: [_photo('photo-$index')],
        ),
      );
      expect(
        selectMonthlyMomentPhotoIds(
          month: DateTime.utc(2026, 10),
          records: records.reversed.toList(),
        ),
        List.generate(count, (index) => 'photo-$index'),
      );
    });
  }

  test(
    'monthly defaults sample all month including the first and last photo',
    () {
      final records = List.generate(
        20,
        (index) => _record(
          id: 'record-$index',
          day: index + 1,
          photos: [_photo('photo-$index')],
        ),
      );
      final selected = selectMonthlyMomentPhotoIds(
        month: DateTime.utc(2026, 10),
        records: records.reversed.toList(),
      );
      expect(selected, [
        'photo-0',
        'photo-2',
        'photo-5',
        'photo-7',
        'photo-10',
        'photo-12',
        'photo-14',
        'photo-17',
        'photo-19',
      ]);
      expect(
        selectMonthlyMomentPhotoIds(
          month: DateTime.utc(2026, 10),
          records: records,
          limit: 2,
        ),
        ['photo-0', 'photo-19'],
      );
      expect(
        selectMonthlyMomentPhotoIds(
          month: DateTime.utc(2026, 10),
          records: records,
          limit: 1,
        ),
        ['photo-0'],
      );
    },
  );

  test(
    'monthly defaults filter month, deduplicate and break date ties stably',
    () {
      final records = [
        _record(id: 'previous', month: 9, photos: [_photo('previous')]),
        _record(
          id: 'record-b',
          day: 7,
          photos: [_photo('shared'), _photo('second')],
        ),
        _record(
          id: 'record-a',
          day: 7,
          photos: [_photo('first'), _photo('shared')],
        ),
        _record(id: 'next', month: 11, photos: [_photo('next')]),
        MomentRecord(
          id: 'last-year',
          recordDate: DateTime.utc(2025, 10, 7),
          caption: '',
          photos: [_photo('last-year')],
          revision: 1,
        ),
      ];
      for (final order in [records, records.reversed.toList()]) {
        expect(
          selectMonthlyMomentPhotoIds(
            month: DateTime.utc(2026, 10),
            records: order,
          ),
          ['first', 'shared', 'second'],
        );
      }
    },
  );

  test('empty months select nothing and invalid limits fail explicitly', () {
    expect(
      selectMonthlyMomentPhotoIds(month: DateTime.utc(2026, 10), records: []),
      isEmpty,
    );
    for (final limit in [0, 10]) {
      expect(
        () => selectMonthlyMomentPhotoIds(
          month: DateTime.utc(2026, 10),
          records: [_record()],
          limit: limit,
        ),
        throwsRangeError,
      );
    }
  });

  test(
    'uses selected order, stable originals and a supported physical size',
    () {
      final request = _build(ids: ['second', 'first']);
      final pages = _pages(request);
      final coverPhoto = _layers(
        pages.first,
      ).singleWhere((l) => l.type == LayerType.image);
      expect(coverPhoto.originalUrl, _photo('second').storageUri);
      expect(request.coverImageUrl, coverPhoto.originalUrl);
      expect(request.coverThumbnailUrl, coverPhoto.originalUrl);
      expect(request.coverOriginalUrl, coverPhoto.originalUrl);
      expect(request.coverPreviewUrl, coverPhoto.originalUrl);
      expect(request.coverLayersJson, isNot(contains('token=')));
      expect(request.coverLayersJson, isNot(contains('https://private.test')));
      expect(pages.map((p) => p['index']), [0, 1, 2]);
      expect(pages.map((p) => p['isCover']), [true, false, false]);
      expect(
        _layers(
          pages[1],
        ).singleWhere((l) => l.type == LayerType.image).originalUrl,
        _photo('second').storageUri,
      );
      final album = Album(
        ratio: request.ratio,
        coverLayersJson: request.coverLayersJson,
      );
      expect(album.physicalCoverSize.productId, 'REDP_200_SOFT');
      expect(album.physicalCoverSize.realSize, const Size(20, 20));
      expect(request.title, '2026년 10월의 순간들');
      expect(request.targetPages, 2);
    },
  );

  test(
    'selected photo retains its full ratio and fills the available photo area',
    () {
      final pages = _pages(_build());
      for (final page in pages) {
        for (final layer in _layers(page)) {
          expect(layer.position.dx, greaterThanOrEqualTo(0));
          expect(layer.position.dy, greaterThanOrEqualTo(0));
          expect(layer.position.dx + layer.width, lessThanOrEqualTo(500.001));
          expect(layer.position.dy + layer.height, lessThanOrEqualTo(500.001));
          if (layer.type == LayerType.image) {
            final source = layer.originalUrl!.contains('second')
                ? 4 / 3
                : 3 / 4;
            expect(layer.width / layer.height, closeTo(source, 0.000001));
            expect(layer.width > 330 || layer.height > 330, isTrue);
            expect(layer.imageZoom, 1);
            expect(layer.imageOffset, isNull);
            expect(layer.isTemplateContent, isFalse);
            expect(layer.previewUrl, layer.originalUrl);
          }
        }
      }
    },
  );

  test('feed captions never become album text or additional pages', () {
    final caption = List.filled(20, '소중한 순간을 기록해요').join(' ').substring(0, 200);
    final request = _build(records: [_record(caption: caption)]);
    final pages = _pages(request);
    final notes = pages.expand(_layers).where((layer) => layer.text == caption);
    expect(notes, isEmpty);
    expect(pages, hasLength(3));
    expect(request.targetPages, 2);
    final photo = _layers(
      pages[1],
    ).singleWhere((l) => l.type == LayerType.image);
    expect(photo.height, closeTo(416, .0001));
    final metadata = analyzeAlbumDocument(request.coverLayersJson);
    expect(metadata.completedPages, request.targetPages);
    expect(metadata.innerPages, request.targetPages);
  });

  test('decorated canvases retain editable overlays and stable originals', () {
    final caption = '피드 아래 본문은 앨범 밖에 남겨 두기';
    final first = _designedPhoto('first');
    final second = _designedPhoto('second');
    final request = _build(
      records: [
        _record(caption: caption, photos: [first, second]),
      ],
    );
    final pages = _pages(request);
    final all = pages.expand(_layers).toList();
    expect(pages, hasLength(3));
    expect(_layers(pages[1]), hasLength(4));
    expect(_layers(pages[2]), hasLength(4));
    expect(
      all.where((layer) => layer.text == '사진 속 편집 문구'),
      hasLength(3),
      reason: 'The cover preview and both inner pages retain the design.',
    );
    expect(
      all.where((layer) => layer.imageBackground == 'stickerBlueStar'),
      hasLength(3),
    );
    expect(all.map((layer) => layer.id).toSet(), hasLength(all.length));
    expect(all.every((layer) => layer.isTemplateContent == false), isTrue);
    expect(request.coverLayersJson, isNot(contains(caption)));
    expect(request.coverLayersJson, isNot(contains('moment-photo://')));
    expect(request.coverLayersJson, isNot(contains('token=')));
    expect(request.coverLayersJson, contains(first.storageUri));
    expect(request.coverLayersJson, contains(second.storageUri));
  });

  for (final cover in [...coverSizes, legacyCoverSizes.first]) {
    test('decorated page fits ${cover.displayName} as one uniform canvas', () {
      final canvas = coverCanvasBaseSize(cover);
      final photo = _designedPhoto('first');
      final design = photo.design!;
      final pages = buildMonthlyMomentAppendPages(
        month: DateTime.utc(2026, 10),
        records: [
          _record(caption: '가져오지 않을 본문', photos: [photo]),
        ],
        selectedPhotoIds: ['first'],
        canvasSize: canvas,
      );
      final layers = (pages.single['layers'] as List)
          .map(
            (value) => LayerExportMapper.fromJson(
              Map<String, dynamic>.from(value as Map),
              canvasSize: canvas,
            ),
          )
          .toList();
      final original = design.layersForPhoto(photo.storageUri);
      final scale = math.min(
        canvas.width / design.canvasSize.width,
        canvas.height / design.canvasSize.height,
      );
      final origin = Offset(
        (canvas.width - design.canvasSize.width * scale) / 2,
        (canvas.height - design.canvasSize.height * scale) / 2,
      );
      final background = layers.first;
      expect(background.type, LayerType.decoration);
      expect(background.position.dx, closeTo(origin.dx, .00001));
      expect(background.position.dy, closeTo(origin.dy, .00001));
      expect(
        background.width,
        closeTo(design.canvasSize.width * scale, .00001),
      );
      expect(
        background.height,
        closeTo(design.canvasSize.height * scale, .00001),
      );
      expect(background.decorationFillColor, '#ffffe5cb');
      expect(background.zIndex, lessThan(layers[1].zIndex));
      final artboard =
          origin &
          Size(
            design.canvasSize.width * scale,
            design.canvasSize.height * scale,
          );
      for (final layer in layers) {
        expect(layer.canvasClip!.left, closeTo(artboard.left, .00001));
        expect(layer.canvasClip!.top, closeTo(artboard.top, .00001));
        expect(layer.canvasClip!.width, closeTo(artboard.width, .00001));
        expect(layer.canvasClip!.height, closeTo(artboard.height, .00001));
      }
      for (var index = 0; index < original.length; index++) {
        final source = original[index];
        final actual = layers[index + 1];
        expect(actual.type, source.type);
        expect(actual.rotation, source.rotation);
        expect(actual.scale, source.scale);
        expect(actual.zIndex, source.zIndex);
        expect(actual.width, closeTo(source.width * scale, .00001));
        expect(actual.height, closeTo(source.height * scale, .00001));
        expect(
          actual.position.dx,
          closeTo(origin.dx + source.position.dx * scale, .00001),
        );
        expect(
          actual.position.dy,
          closeTo(origin.dy + source.position.dy * scale, .00001),
        );
        if (source.type == LayerType.image) {
          expect(actual.originalUrl, photo.storageUri);
          expect(actual.imageBackground, source.imageBackground);
          expect(actual.imageZoom, source.imageZoom);
          expect(
            actual.imageOffset!.dx,
            closeTo(source.imageOffset!.dx * scale, .00001),
          );
          expect(
            actual.imageOffset!.dy,
            closeTo(source.imageOffset!.dy * scale, .00001),
          );
        }
        if (source.type == LayerType.text) {
          expect(actual.text, source.text);
          expect(actual.textStyle!.fontFamily, source.textStyle!.fontFamily);
          expect(
            actual.textStyle!.fontSize,
            closeTo(source.textStyle!.fontSize! * scale, .00001),
          );
          expect(
            actual.textStyle!.letterSpacing,
            closeTo(source.textStyle!.letterSpacing! * scale, .00001),
          );
          expect(
            actual.textStyle!.shadows!.single.blurRadius,
            closeTo(
              source.textStyle!.shadows!.single.blurRadius * scale,
              .00001,
            ),
          );
        }
      }
      expect(jsonEncode(pages), isNot(contains('가져오지 않을 본문')));
    });
  }

  test(
    'append keeps previously authored captions and custom metadata intact',
    () {
      final saved = {
        'pages': [
          {'index': 0, 'isCover': true, 'layers': [], 'customCover': true},
          {
            'index': 1,
            'isCover': false,
            'customMetadata': {'keep': 'unchanged'},
            'layers': [
              {
                'id': 'old-caption',
                'payload': {'text': '기존 앨범에 직접 남긴 글'},
              },
            ],
          },
        ],
      };
      final encoded = jsonEncode(saved);
      final preview = buildMonthlyMomentAppendPreview(
        existingDocumentJson: encoded,
        month: DateTime.utc(2026, 10),
        records: [
          _record(caption: '이번 피드에만 쓴 본문', photos: [_designedPhoto('first')]),
        ],
        selectedPhotoIds: ['first'],
        canvasSize: const Size(600, 800),
      );
      expect(preview.existingPages, saved['pages']);
      expect(jsonEncode(saved), encoded);
      expect(jsonEncode(preview.pages), contains('기존 앨범에 직접 남긴 글'));
      expect(jsonEncode(preview.pendingPages), contains('사진 속 편집 문구'));
      expect(jsonEncode(preview.pendingPages), isNot(contains('이번 피드에만 쓴 본문')));
      expect(preview.pendingPages.single['index'], 2);
    },
  );

  test('empty notes omit caption layers and maximize the photo', () {
    final request = _build(
      records: [_record(caption: '  \n ')],
      ids: ['first'],
    );
    final photoPage = _pages(request)[1];
    final layers = _layers(photoPage);
    expect(layers.where((l) => l.id.endsWith('-caption')), isEmpty);
    expect(layers.singleWhere((l) => l.type == LayerType.image).height, 416);
    expect(request.targetPages, 1);
  });

  test('retains nine photos without importing their feed captions', () {
    final records = List.generate(
      9,
      (i) => _record(
        id: 'record-$i',
        day: i + 1,
        caption: List.filled(100, '가').join(),
        photos: [_photo('photo-$i')],
      ),
    );
    final request = _build(
      records: records,
      ids: List.generate(9, (i) => 'photo-$i'),
    );
    final pages = _pages(request);
    expect(request.targetPages, 9);
    expect(pages, hasLength(10));
    expect(
      pages.skip(1).expand(_layers).where((l) => l.type == LayerType.image),
      hasLength(9),
    );
    expect(
      pages.expand(_layers).map((l) => l.id).toSet(),
      hasLength(pages.expand(_layers).length),
    );
  });

  test('rejects missing, duplicated, stale-month or oversized selections', () {
    for (final ids in [
      <String>[],
      ['first', 'first'],
      ['missing'],
      List.filled(10, 'first'),
    ]) {
      expect(() => _build(ids: ids), throwsArgumentError);
    }
    expect(() => _build(records: [_record(month: 9)]), throwsArgumentError);
    expect(
      () => _build(
        records: [
          _record(),
          _record(id: 'ambiguous'),
        ],
      ),
      throwsArgumentError,
    );
  });

  test(
    'unselected content and records from other months never enter the album',
    () {
      final request = _build(
        records: [
          _record(caption: 'selected note'),
          _record(
            id: 'unselected',
            caption: 'private excluded note',
            photos: [_photo('hidden')],
          ),
          _record(
            id: 'last-month',
            month: 9,
            caption: 'last month note',
            photos: [_photo('old')],
          ),
        ],
        ids: ['first'],
      );
      expect(request.coverLayersJson, isNot(contains('selected note')));
      for (final excluded in [
        'second.jpg',
        'hidden.jpg',
        'old.jpg',
        'private excluded note',
        'last month note',
      ]) {
        expect(request.coverLayersJson, isNot(contains(excluded)));
      }
    },
  );

  test('rejects malformed storage paths and invalid image dimensions', () {
    for (final photo in [
      _photo('bad', path: ''),
      _photo('bad', path: 'https://outside.test/photo.jpg'),
      _photo('bad', path: '../other/photo.jpg'),
      _photo('bad', path: '/owner/photo.jpg'),
      _photo('bad', path: 'owner//photo.jpg'),
      _photo('bad', path: 'owner/photo.jpg?token=value'),
      _photo('bad', width: 0),
      _photo('bad', height: -1),
    ]) {
      expect(
        () => _build(
          records: [
            _record(photos: [photo]),
          ],
          ids: ['bad'],
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'complete Korean album titles fit without importing the feed caption',
    () {
      final caption = List.filled(200, '한').join();
      final title = List.filled(60, '달').join();
      final request = _build(
        records: [_record(caption: caption)],
        ids: ['first'],
        title: title,
      );
      expect(request.title, title);
      for (final layer in _pages(
        request,
      ).expand(_layers).where((l) => l.type == LayerType.text)) {
        final painter = TextPainter(
          text: TextSpan(text: layer.text, style: layer.textStyle),
          textDirection: TextDirection.ltr,
          textAlign: layer.textAlign!,
        )..layout(maxWidth: layer.width);
        expect(
          painter.height,
          lessThanOrEqualTo(layer.height + .001),
          reason: layer.id,
        );
        expect(layer.text, isNot(contains('…')));
        painter.dispose();
      }
      expect(() => _build(title: '${title}달'), throwsArgumentError);
    },
  );

  test(
    'opens and resaves through the real album editor without losing content',
    () async {
      final request = _build(
        records: [
          _record(photos: [_designedPhoto('first'), _photo('second')]),
        ],
      );
      final album = Album(
        id: 771,
        userId: 'owner',
        memberRole: 'OWNER',
        ratio: request.ratio,
        title: request.title,
        targetPages: request.targetPages,
        coverLayersJson: request.coverLayersJson,
        coverTheme: request.coverTheme,
        updatedAt: '2026-10-26T00:00:00Z',
      );
      final container = ProviderContainer(
        overrides: [
          albumEditorOwnerReaderProvider.overrideWithValue(() => 'owner'),
          albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
          albumEditorServiceProvider.overrideWithValue(
            const AlbumEditorService(),
          ),
          albumPersistenceServiceProvider.overrideWithValue(
            FakeAlbumPersistenceService(),
          ),
          storageServiceProvider.overrideWithValue(FakeStorageService()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(albumEditorViewModelProvider.future);
      final editor = container.read(albumEditorViewModelProvider.notifier);
      await editor.prepareAlbumForEdit(album);
      editor.loadPendingEditAlbumIfNeeded(monthlyMomentCanvasSize);
      expect(editor.pages, hasLength(3));
      expect(
        editor.pages.first.backgroundColor,
        _pages(request).first['backgroundColor'],
      );
      expect(editor.pages[1].layers.any((l) => l.text == '사진 속 편집 문구'), isTrue);
      editor.goToPage(1);
      editor.updatePageLayers(
        editor.pages[1].layers
            .map(
              (layer) => layer.text == '사진 속 편집 문구'
                  ? layer.copyWith(text: '다시 쓰는 나의 기록')
                  : layer,
            )
            .toList(),
      );
      final saved = editor.exportFullAlbumLayersJson(null);
      expect(saved, contains('다시 쓰는 나의 기록'));
      expect(saved, contains(_photo('first').storageUri));
      expect(saved, contains(_photo('second').storageUri));
      expect(analyzeAlbumDocument(saved).completedPages, request.targetPages);
    },
  );

  testWidgets(
    'shared preview uses layer bounds for relative decoration dimensions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TemplatePageRenderer(
              layers: [
                LayerModel(
                  id: 'small-paper',
                  type: LayerType.decoration,
                  position: const Offset(30, 30),
                  width: 80,
                  height: 40,
                  decorationFillColor: '#FFFFFFFF',
                  decorationBorderColor: '#FFFF0000',
                  decorationBorderWidth: .01,
                  decorationCornerRadius: .2,
                ),
              ],
              width: 250,
              height: 250,
              designCanvasSize: const Size(500, 500),
            ),
          ),
        ),
      );
      final decoration = tester
          .widgetList<Container>(find.byType(Container))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .singleWhere((decoration) => decoration.border != null);
      expect((decoration.border! as Border).top.width, closeTo(.4, .000001));
      expect(decoration.borderRadius, BorderRadius.circular(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the shared renderer displays the cover and decorated page without overflow',
    (tester) async {
      final request = _build(
        records: [
          _record(
            caption: List.filled(200, '한').join(),
            photos: [_designedPhoto('first')],
          ),
        ],
        ids: ['first'],
      );
      for (final page in _pages(request)) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ColoredBox(
                  color: Color(page['backgroundColor'] as int),
                  child: TemplatePageRenderer(
                    layers: _layers(page),
                    width: 320,
                    height: 320,
                    designCanvasSize: monthlyMomentCanvasSize,
                    preserveTypography: true,
                    photoBuilder: (_, _) =>
                        const ColoredBox(color: Colors.teal),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(TemplatePageRenderer), findsOneWidget);
      }
    },
  );
}
