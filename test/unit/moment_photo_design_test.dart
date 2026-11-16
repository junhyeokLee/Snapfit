import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';

const _source = 'supabase://album-assets/owner/moments/record/photo.png';
MomentPhotoDesign _design() => MomentPhotoDesign.fromLayers(
  canvasSize: const Size(500, 400),
  backgroundColor: const Color(0xfff8edda),
  photoSource: _source,
  layers: [
    LayerModel(
      id: 'photo',
      type: LayerType.image,
      position: const Offset(20, 30),
      width: 450,
      height: 340,
      originalUrl: _source,
      previewUrl: _source,
      imageUrl: _source,
      imageBackground: 'clayContour',
      imageTemplate: 'free',
      imageZoom: 1.7,
      imageOffset: const Offset(10, -5),
      canvasClip: const Rect.fromLTWH(0, 0, 500, 400),
    ),
    LayerModel(
      id: 'text',
      type: LayerType.text,
      position: const Offset(50, 200),
      width: 300,
      height: 80,
      text: '사진 위에 남긴 글자',
      zIndex: 1,
      textStyle: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 30,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        shadows: [
          Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1)),
        ],
      ),
    ),
    LayerModel(
      id: 'sticker',
      type: LayerType.decoration,
      position: const Offset(100, 100),
      width: 40,
      height: 40,
      zIndex: 2,
      imageBackground: 'stickerBlueStar',
    ),
  ],
);

void main() {
  test(
    'portable design retains editable geometry, crop, typography and stickers without retaining a private source',
    () {
      final design = _design();
      final serialized = jsonEncode(design.toJson());
      expect(serialized, isNot(contains(_source)));
      expect(serialized, contains(momentPhotoOriginalSource));
      expect(design.aspectRatio, 1.25);
      expect(design.backgroundColor, const Color(0xfff8edda));
      expect(design.fontFamilies, ['NotoSans']);
      final layers = design.layersForPhoto(
        'replacement-original',
        canvasSize: const Size(1000, 800),
      );
      expect(layers.first.originalUrl, 'replacement-original');
      expect(layers.first.imageBackground, 'clayContour');
      expect(layers.first.position, const Offset(40, 60));
      expect(layers.first.imageZoom, 1.7);
      expect(layers.first.imageOffset, const Offset(20, -10));
      expect(layers.first.canvasClip, const Rect.fromLTWH(0, 0, 1000, 800));
      expect(layers[1].textStyle!.fontSize, 60);
      expect(layers[1].textStyle!.shadows!.single.offset, const Offset(2, 2));
      expect(layers[2].imageBackground, 'stickerBlueStar');
    },
  );

  test(
    'original-source placeholders are resolved only in image fields, never authored text',
    () {
      final json = _design().toJson();
      json['layers'][1]['payload']['text'] = momentPhotoOriginalSource;
      final layers = MomentPhotoDesign.fromJson(
        json,
      ).layersForPhoto('private-original');
      expect(layers.first.originalUrl, 'private-original');
      expect(layers[1].text, momentPhotoOriginalSource);
    },
  );

  test('a saved design is detached from source maps and returned maps', () {
    final original = _design().toJson();
    final saved = MomentPhotoDesign.fromJson(original);
    (original['layers'] as List).clear();
    (saved.toJson()['layers'] as List).clear();
    expect(saved.layersForPhoto(_source), hasLength(3));
    expect(() => saved.fontFamilies.add('another'), throwsUnsupportedError);
  });

  test(
    'draft metadata restores new uploads, retained photos and edit baseline with captions outside artwork',
    () {
      final design = _design();
      final photo = MomentPhoto(
        id: 'photo',
        path: 'owner/moments/record/photo.png',
        url: 'https://private.invalid/signed?token=secret',
        width: 1200,
        height: 800,
        design: design,
      );
      final record = MomentRecord(
        id: 'record',
        recordDate: DateTime.utc(2026, 10, 26),
        caption: '이 문장은 피드에만',
        photos: [photo],
        revision: 3,
      );
      final draft = MomentDraft(
        ownerId: 'owner',
        recordId: 'record',
        recordDate: record.recordDate,
        caption: '수정할 피드 문장',
        existingPhotos: [photo],
        originalRecord: record,
        uploads: [
          MomentDraftUpload(
            id: 'new-photo',
            filename: 'original.jpg',
            bytes: Uint8List.fromList([1, 2, 3]),
            design: design,
          ),
        ],
        updatedAt: DateTime.utc(2026, 11, 3),
      );
      final metadata = draft.toMetadata();
      final restored = MomentDraft.fromMetadata(
        metadata,
        photoBytes: [draft.uploads.single.bytes],
      );
      expect(jsonEncode(metadata), isNot(contains('token=secret')));
      expect(restored.caption, '수정할 피드 문장');
      expect(restored.originalRecord!.caption, '이 문장은 피드에만');
      for (final artwork in [
        restored.existingPhotos.single.design!,
        restored.uploads.single.design!,
        restored.originalRecord!.photos.single.design!,
      ]) {
        expect(artwork.toJson(), design.toJson());
        expect(jsonEncode(artwork.toJson()), isNot(contains('피드')));
      }
      expect(restored.uploads.single.withDesign(null).design, isNull);
      expect(
        restored.existingPhotos.single.withUrl('updated').design!.toJson(),
        design.toJson(),
      );
      expect(restored.existingPhotos.single.withDesign(null).design, isNull);
    },
  );

  test(
    'legacy photos and draft uploads remain compatible without a design',
    () {
      final photo = MomentPhoto.fromJson({
        'id': 'legacy',
        'path': 'original.jpg',
        'width': 600,
        'height': 800,
      });
      expect(photo.design, isNull);
      expect(photo.aspectRatio, .75);
      expect(photo.toJson().containsKey('design'), isFalse);
    },
  );

  test(
    'trust boundary rejects source URLs, unrelated assets, unknown payloads and malformed nested styles',
    () {
      final patches = <void Function(Map<String, dynamic>)>[
        (d) => d['caption'] = 'feed caption',
        (d) => d['canvas']['width'] = 0,
        (d) => d['layers'][0]['payload']['originalUrl'] =
            'https://private.invalid/photo.jpg',
        (d) => d['layers'][0]['payload']['imageUrl'] =
            'asset:assets/sticker/paid.png',
        (d) => d['layers'][0]['payload']['imageOffsetRatio'] = {
          'x': 0,
          'y': 0,
          'path': 'secret',
        },
        (d) => d['layers'][0]['canvasClip'] = {
          'x': 0,
          'y': 0,
          'width': -1,
          'height': 1,
        },
        (d) => d['layers'][1]['payload']['textStyle']['fontWeight'] = 2.5,
        (d) => d['layers'][1]['payload']['textStyle']['shadows'][0]['url'] =
            'https://private.invalid',
        (d) => d['layers'][2]['payload']['imageBackground'] = 'paid-sticker',
        (d) => d['layers'][2]['payload']['originalUrl'] =
            momentPhotoOriginalSource,
        (d) => d['layers'].removeAt(0),
      ];
      for (final patch in patches) {
        final json = _design().toJson();
        patch(json);
        expect(() => MomentPhotoDesign.fromJson(json), throwsFormatException);
      }
    },
  );
}
