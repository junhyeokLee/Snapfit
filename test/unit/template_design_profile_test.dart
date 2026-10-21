import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/published_premium_templates.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/template_design_profile.dart';

PremiumTemplate _template({
  int id = 701,
  Map<String, dynamic>? document,
  String? source,
  String Function()? builder,
}) => PremiumTemplate(
  id: id,
  title: '선택 정보 예시',
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 999,
  userCount: 0,
  templateJson: source ?? (document == null ? null : jsonEncode(document)),
  documentBuilder: builder,
);

Map<String, dynamic> _page(List<Map<String, dynamic>> layers) => {
  'layers': layers,
};

Map<String, dynamic> _photo(String id, {bool? editable, bool? locked}) => {
  'id': id,
  'type': 'image',
  if (editable != null) 'editable': editable,
  if (locked != null) 'locked': locked,
};

Map<String, dynamic> _text(
  String id, {
  String role = 'body',
  String? editorialRole,
  bool? editable,
}) => {
  'id': id,
  'type': 'text',
  'text': '문서에서 편집하는 실제 문장입니다.',
  'typographyRole': role,
  if (editorialRole != null) 'editorialTextRole': editorialRole,
  if (editable != null) 'editable': editable,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'default edition counts cover and editable inner contents exactly once',
    () {
      final cover = _page([_photo('cover-photo'), _text('cover-title')]);
      final template = _template(
        document: {
          'cover': cover,
          'pages': [
            cover,
            _page([
              _photo('first-photo'),
              _photo('second-photo'),
              _photo('fixed-art', editable: false),
              _photo('locked-art', locked: true),
              {'id': 'sticker', 'type': 'sticker'},
              _text('first-body'),
            ]),
            _page([
              _photo('third-photo'),
              _text('dates-of-us_title', editorialRole: 'headline'),
              _text('dates-of-us_folio_number'),
              _text('picture-note', role: 'caption'),
            ]),
            _page([_text('dates-of-us_note')]),
          ],
          'variants': {
            'portrait': {
              'pages': [
                _page([_photo('alternate-should-not-add')]),
              ],
            },
          },
        },
      );
      final profile = TemplateDesignProfile.of(template);
      expect(profile.hasKnownDocument, isTrue);
      expect(profile.photoSlotCount, 4);
      expect(profile.innerPhotoSlotCount, 3);
      expect(profile.innerPageCount, 3);
      expect(profile.photoPageCount, 2);
      expect(profile.recordPageCount, 2);
      expect(profile.photosPerInnerPage, 1);
      expect(profile.photoLabel, '사진 4장 구성');
      expect(profile.pageLabel, '내지 3쪽');
      expect(profile.compositionLabel, '사진 넣는 4곳 · 글쓰기 2쪽');
      expect(profile.briefLabel, '사진 4장 구성 · 내지 3쪽');
    },
  );

  test(
    'separately stored cover and explicit body roles preserve page counts',
    () {
      final profile = TemplateDesignProfile.of(
        _template(
          document: {
            'cover': _page([_photo('cover')]),
            'pages': [
              _page([_text('body', editable: false)]),
              _page([_text('poem-1', role: 'journal')]),
              _page([
                {
                  'id': 'entry_note',
                  'type': 'text',
                  'text': '노트',
                  'payload': {'text': '노트'},
                },
              ]),
            ],
          },
        ),
      );
      expect(profile.innerPageCount, 3);
      expect(profile.photoSlotCount, 1);
      expect(profile.innerPhotoSlotCount, 0);
      expect(profile.photoPageCount, 0);
      expect(profile.recordPageCount, 2);
    },
  );

  test('a readable text-only document has a verified zero photo count', () {
    final profile = TemplateDesignProfile.of(
      _template(
        document: {
          'pages': [
            _page([_text('cover-title', editorialRole: 'headline')]),
            _page([_text('essay_body')]),
          ],
        },
      ),
    );
    expect(profile.hasKnownDocument, isTrue);
    expect(profile.photoSlotCount, 0);
    expect(profile.photoLabel, '사진 0장 구성');
    expect(profile.photosPerInnerPage, 0);
    expect(profile.recordPageCount, 1);
  });

  test(
    'unknown documents stay unknown rather than borrowing advertised pages',
    () {
      final templates = [
        _template(),
        _template(source: ''),
        _template(source: 'not json'),
        _template(source: 'null'),
        _template(source: '[]'),
        _template(document: {}),
        _template(document: {'pages': []}),
        _template(document: {'pages': 'broken'}),
        _template(
          document: {
            'cover': {'layers': 'broken'},
            'pages': [
              _page([_photo('inner')]),
            ],
          },
        ),
        _template(
          document: {
            'pages': [null],
          },
        ),
        _template(
          document: {
            'pages': [
              {'layers': 'broken'},
            ],
          },
        ),
        _template(
          document: {
            'pages': [
              {
                'layers': [null],
              },
            ],
          },
        ),
        _template(
          document: {
            'pages': [_page([]), _page([])],
          },
        ),
        _template(builder: () => throw StateError('document unavailable')),
      ];
      for (final template in templates) {
        final profile = TemplateDesignProfile.of(template);
        expect(profile.hasKnownDocument, isFalse);
        expect(profile.photoSlotCount, isNull);
        expect(profile.innerPageCount, isNull);
        expect(profile.photosPerInnerPage, isNull);
        expect(profile.photoLabel, '사진 구성 확인 필요');
      }
    },
  );

  test('matching IDs cannot substitute canonical artwork or cached counts', () {
    final canonical = publishedCreationTemplates.first;
    final replacement = canonical.copyWith(
      templateJson: jsonEncode({
        'pages': [
          _page([_photo('replacement-cover')]),
          _page([_photo('replacement-inner')]),
        ],
      }),
    );
    expect(TemplateDesignProfile.of(replacement).photoSlotCount, 2);
    expect(TemplateDesignProfile.of(replacement).innerPageCount, 1);
  });

  test(
    'a selected 24-page edition uses its actual contents and not the catalog',
    () {
      final catalog = publishedPremiumTemplates.singleWhere(
        (template) =>
            template.id == premiumVolumeCatalogIds[PremiumVolume.travel],
      );
      final selected = catalog.copyWith(
        templateJson: jsonEncode(
          premiumCatalogDocument(PremiumVolume.travel, innerPages: 24),
        ),
      );
      final profile = TemplateDesignProfile.of(selected);
      final full = TemplateDesignProfile.of(catalog);
      expect(profile.innerPageCount, 24);
      expect(full.innerPageCount, 36);
      expect(profile.photoSlotCount, lessThan(full.photoSlotCount!));
      expect(profile.briefLabel, endsWith('내지 24쪽'));
    },
  );

  test(
    'favorite copies reuse a builder and changed builder output invalidates',
    () {
      var source = jsonEncode({
        'pages': [
          _page([_photo('cover')]),
          _page([_photo('inner')]),
        ],
      });
      final template = _template(builder: () => source);
      final initial = TemplateDesignProfile.of(template);
      expect(
        TemplateDesignProfile.of(template.copyWith(isLiked: true)),
        same(initial),
      );
      source = jsonEncode({
        'pages': [
          _page([_photo('cover')]),
          _page([_photo('inner-a'), _photo('inner-b')]),
        ],
      });
      final changed = TemplateDesignProfile.of(template);
      expect(changed, isNot(same(initial)));
      expect(changed.photoSlotCount, 3);
    },
  );

  test(
    'bounded cache keeps recent entries and evicts older document parses',
    () {
      final oldest = _template(
        id: 800,
        document: {
          'pages': [
            _page([_photo('oldest-cover')]),
            _page([_photo('oldest-inner')]),
          ],
        },
      );
      final first = TemplateDesignProfile.of(oldest);
      late PremiumTemplate newest;
      late TemplateDesignProfile recent;
      for (var index = 0; index < 24; index++) {
        newest = _template(
          id: 801 + index,
          document: {
            'pages': [
              _page([_photo('cover-$index')]),
              _page([_photo('inner-$index')]),
            ],
          },
        );
        recent = TemplateDesignProfile.of(newest);
      }
      expect(TemplateDesignProfile.of(newest), same(recent));
      expect(TemplateDesignProfile.of(oldest), isNot(same(first)));
    },
  );

  test('all 68 published designs expose their actual default photo slots', () {
    expect(publishedCreationTemplates, hasLength(68));
    for (final template in publishedCreationTemplates) {
      final raw = jsonDecode(template.templateJson!) as Map<String, dynamic>;
      final pages = templateDocumentPages(raw);
      int photos(Map<String, dynamic> page) => (page['layers'] as List)
          .whereType<Map>()
          .where(
            (layer) =>
                '${layer['type']}'.toLowerCase() == 'image' &&
                layer['editable'] != false &&
                layer['locked'] != true &&
                layer['isLocked'] != true,
          )
          .length;
      final profile = TemplateDesignProfile.of(template);
      expect(profile.hasKnownDocument, isTrue, reason: template.title);
      expect(profile.innerPageCount, pages.length - 1, reason: template.title);
      expect(
        profile.photoSlotCount,
        pages.fold<int>(0, (sum, page) => sum + photos(page)),
        reason: template.title,
      );
      expect(
        profile.innerPhotoSlotCount,
        pages.skip(1).fold<int>(0, (sum, page) => sum + photos(page)),
        reason: template.title,
      );
      expect(
        profile.photoPageCount,
        pages.skip(1).where((page) => photos(page) > 0).length,
        reason: template.title,
      );
      expect(profile.recordPageCount, inInclusiveRange(0, pages.length - 1));
    }
  });
}
