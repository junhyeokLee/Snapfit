import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('keeps one full long note per record on a separate editable page', () {
    final caption = List.filled(20, '소중한 순간을 기록해요').join(' ').substring(0, 200);
    final request = _build(records: [_record(caption: caption)]);
    final pages = _pages(request);
    final notes = pages.expand(_layers).where((layer) => layer.text == caption);
    expect(notes, hasLength(1));
    expect(notes.single.isTemplateContent, isFalse);
    expect(notes.single.textStyle!.fontSize, greaterThanOrEqualTo(14));
    expect(pages, hasLength(4));
    expect(request.targetPages, 3);
    final notePage = pages.singleWhere(
      (page) => _layers(page).any((l) => l.text == caption),
    );
    expect(_layers(notePage).where((l) => l.type == LayerType.image), isEmpty);
    final photo = _layers(
      pages[1],
    ).singleWhere((l) => l.type == LayerType.image);
    expect(photo.height, closeTo(416, .0001));
    final metadata = analyzeAlbumDocument(request.coverLayersJson);
    expect(metadata.completedPages, request.targetPages);
    expect(metadata.innerPages, request.targetPages);
  });

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

  test(
    'retains all requested photos and counts up to nine long note pages',
    () {
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
      expect(request.targetPages, 18);
      expect(pages, hasLength(19));
      expect(
        pages.skip(1).expand(_layers).where((l) => l.type == LayerType.image),
        hasLength(9),
      );
      expect(
        pages.expand(_layers).map((l) => l.id).toSet(),
        hasLength(pages.expand(_layers).length),
      );
    },
  );

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
      expect(request.coverLayersJson, contains('selected note'));
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
    'complete Korean titles and notes fit their text boxes without ellipsis',
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
      final request = _build();
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
      expect(
        editor.pages[1].layers.any((l) => l.text == '함께 걸었던 가을 오후'),
        isTrue,
      );
      editor.goToPage(1);
      editor.updatePageLayers(
        editor.pages[1].layers
            .map(
              (layer) => layer.id.endsWith('-caption')
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
    'the shared renderer displays generated cover and note without overflow',
    (tester) async {
      final request = _build(
        records: [_record(caption: List.filled(200, '한').join())],
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
