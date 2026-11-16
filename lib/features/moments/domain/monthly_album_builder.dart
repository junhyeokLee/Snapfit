import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/cover_size.dart';
import '../../album/data/dto/request/create_album_request.dart';
import '../../album/domain/entities/layer.dart';
import '../../album/domain/entities/layer_export_mapper.dart';
import 'moment_record.dart';

/// Preparing these exact families is required before fitting and saving text.
const monthlyMomentFontFamilies = ['NotoSans', 'Poppins', 'Eulyoo'];

const monthlyMomentCanvasSize = Size(500, 500);
const monthlyMomentAlbumCoverSize = defaultCoverSize;

// Only new monthly documents use this palette. Saved albums and drafts keep
// their authored colors and are never restyled when the journal is opened.
const _cream = Color(0xFFF7F9FA);
const _mint = Color(0xFFE7F8FB);
const _ink = Color(0xFF203139);
const _secondaryInk = Color(0xFF62757D);

/// Selects a chronological cross-section of the whole month rather than only
/// the newest records returned by the journal. For two or more choices, both
/// ends of the month's available photo sequence are always represented.
List<String> selectMonthlyMomentPhotoIds({
  required DateTime month,
  required List<MomentRecord> records,
  int limit = 9,
}) {
  RangeError.checkValueInInterval(limit, 1, 9, 'limit');
  final ordered =
      records
          .where(
            (record) =>
                record.recordDate.year == month.year &&
                record.recordDate.month == month.month,
          )
          .toList()
        ..sort((first, second) {
          final byDate = momentDate(
            first.recordDate,
          ).compareTo(momentDate(second.recordDate));
          return byDate != 0 ? byDate : first.id.compareTo(second.id);
        });
  final seen = <String>{};
  final ids = <String>[
    for (final record in ordered)
      for (final photo in record.photos)
        if (seen.add(photo.id)) photo.id,
  ];
  if (ids.length <= limit) return List.unmodifiable(ids);
  if (limit == 1) return List.unmodifiable([ids.first]);
  return List.unmodifiable([
    for (var index = 0; index < limit; index++)
      ids[(index * (ids.length - 1) / (limit - 1)).round()],
  ]);
}

/// Builds an ordinary editable album from the explicitly selected private
/// photos. It neither creates a catalog product nor publishes any content.
/// Stable references are persisted; short-lived display URLs are never saved.
CreateAlbumRequest buildMonthlyMomentAlbum({
  required DateTime month,
  required List<MomentRecord> records,
  required List<String> selectedPhotoIds,
  String? title,
}) {
  final selected = _selectedPhotos(
    month: month,
    records: records,
    selectedPhotoIds: selectedPhotoIds,
  );
  final albumTitle = _singleLine(title ?? '');
  final effectiveTitle = albumTitle.isEmpty
      ? '${month.year}년 ${month.month}월의 순간들'
      : albumTitle;
  if (effectiveTitle.characters.length > 60) {
    throw ArgumentError.value(title, 'title', '제목은 60자까지 입력해 주세요.');
  }
  final firstPhoto = selected.first.photo;
  final cover = _page(
    index: 0,
    isCover: true,
    background: _mint,
    layers: [
      _text(
        id: 'moment-cover-date',
        text: '${month.year} / ${month.month.toString().padLeft(2, '0')}',
        rect: const Rect.fromLTWH(42, 25, 420, 24),
        fontSize: 15,
        fontFamily: 'Poppins',
        color: _secondaryInk,
        tracking: 1.5,
      ),
      _text(
        id: 'moment-cover-title',
        text: effectiveTitle,
        rect: const Rect.fromLTWH(42, 53, 420, 77),
        fontSize: 33,
        fontFamily: 'Eulyoo',
        lineHeight: 1.22,
      ),
      ..._photoOrDesignLayers(
        id: 'moment-cover-photo',
        photo: firstPhoto,
        bounds: const Rect.fromLTWH(38, 143, 438, 331),
      ),
    ],
  );
  final pages = <Map<String, dynamic>>[
    cover,
    for (var index = 0; index < selected.length; index++)
      _innerPage(
        entry: selected[index],
        selectionIndex: index,
        pageIndex: index + 1,
        canvasSize: monthlyMomentCanvasSize,
      ),
  ];
  return CreateAlbumRequest(
    ratio: monthlyMomentAlbumCoverSize.ratio.toString(),
    title: effectiveTitle,
    targetPages: pages.length - 1,
    coverLayersJson: jsonEncode({
      'printProduct': monthlyMomentAlbumCoverSize.printProduct,
      'pages': pages,
    }),
    coverImageUrl: firstPhoto.storageUri,
    coverThumbnailUrl: firstPhoto.storageUri,
    coverOriginalUrl: firstPhoto.storageUri,
    coverPreviewUrl: firstPhoto.storageUri,
    coverTheme: 'classic',
  );
}

List<({MomentRecord record, MomentPhoto photo})> _selectedPhotos({
  required DateTime month,
  required List<MomentRecord> records,
  required List<String> selectedPhotoIds,
}) {
  if (selectedPhotoIds.isEmpty || selectedPhotoIds.length > 9) {
    throw ArgumentError.value(selectedPhotoIds, 'selectedPhotoIds', '1~9장');
  }
  final selectedIds = selectedPhotoIds.toSet();
  if (selectedIds.length != selectedPhotoIds.length) {
    throw ArgumentError('같은 사진을 두 번 선택할 수 없습니다.');
  }
  final photos = <String, ({MomentRecord record, MomentPhoto photo})>{};
  for (final record in records) {
    if (record.recordDate.year != month.year ||
        record.recordDate.month != month.month) {
      continue;
    }
    for (final photo in record.photos) {
      if (!selectedIds.contains(photo.id)) continue;
      if (photos.containsKey(photo.id)) {
        throw ArgumentError('선택한 사진의 기록을 확인해 주세요.');
      }
      _validatePhoto(photo);
      photos[photo.id] = (record: record, photo: photo);
    }
  }
  if (photos.length != selectedPhotoIds.length) {
    throw ArgumentError('선택한 달에 없는 사진이 포함되어 있습니다.');
  }
  return selectedPhotoIds.map((id) => photos[id]!).toList();
}

/// Creates only new inner pages; the server appends them to the locked current
/// document and assigns their final indexes. Cover and existing pages stay intact.
List<Map<String, dynamic>> buildMonthlyMomentAppendPages({
  required DateTime month,
  required List<MomentRecord> records,
  required List<String> selectedPhotoIds,
  Size canvasSize = monthlyMomentCanvasSize,
}) {
  if (!canvasSize.width.isFinite ||
      !canvasSize.height.isFinite ||
      canvasSize.width <= 0 ||
      canvasSize.height <= 0) {
    throw ArgumentError.value(canvasSize, 'canvasSize');
  }
  final selected = _selectedPhotos(
    month: month,
    records: records,
    selectedPhotoIds: selectedPhotoIds,
  );
  return [
    for (var index = 0; index < selected.length; index++)
      _innerPage(
        entry: selected[index],
        selectionIndex: index,
        pageIndex: index + 1,
        canvasSize: canvasSize,
      ),
  ];
}

Map<String, dynamic> _innerPage({
  required ({MomentRecord record, MomentPhoto photo}) entry,
  required int selectionIndex,
  required int pageIndex,
  required Size canvasSize,
}) {
  final photo = entry.photo;
  if (photo.design != null) {
    return _page(
      index: pageIndex,
      background: _cream,
      canvasSize: canvasSize,
      layers: _photoOrDesignLayers(
        id: 'moment-${photo.id}-photo',
        photo: photo,
        bounds: Offset.zero & canvasSize,
      ),
    );
  }
  final sx = canvasSize.width / monthlyMomentCanvasSize.width;
  final sy = canvasSize.height / monthlyMomentCanvasSize.height;
  final textScale = math.min(sx, sy);
  Rect resize(Rect rect) => Rect.fromLTWH(
    rect.left * sx,
    rect.top * sy,
    rect.width * sx,
    rect.height * sy,
  );
  final date = entry.record.recordDate;
  return _page(
    index: pageIndex,
    background: selectionIndex.isEven ? _cream : _mint,
    canvasSize: canvasSize,
    layers: [
      _text(
        id: 'moment-${photo.id}-date',
        text: '${date.month}월 ${date.day}일',
        rect: resize(const Rect.fromLTWH(25, 20, 300, 24)),
        fontSize: 13 * textScale,
        color: _secondaryInk,
      ),
      _text(
        id: 'moment-${photo.id}-number',
        text: (selectionIndex + 1).toString().padLeft(2, '0'),
        rect: resize(const Rect.fromLTWH(420, 20, 55, 24)),
        fontSize: 13 * textScale,
        fontFamily: 'Poppins',
        color: _secondaryInk,
        align: TextAlign.right,
      ),
      _photo(
        id: 'moment-${photo.id}-photo',
        photo: photo,
        bounds: resize(const Rect.fromLTWH(25, 59, 450, 416)),
      ),
    ],
  );
}

/// An authored feed canvas travels as editable layers, independently of the
/// post's caption. Uniform fitting retains every layer's shape and relative
/// position when a differently shaped album is selected.
List<LayerModel> _photoOrDesignLayers({
  required String id,
  required MomentPhoto photo,
  required Rect bounds,
}) {
  final design = photo.design;
  if (design == null) return [_photo(id: id, photo: photo, bounds: bounds)];
  final canvas = design.canvasSize;
  final scale = math.min(
    bounds.width / canvas.width,
    bounds.height / canvas.height,
  );
  final origin = Offset(
    bounds.left + (bounds.width - canvas.width * scale) / 2,
    bounds.top + (bounds.height - canvas.height * scale) / 2,
  );
  final layers = design.layersForPhoto(photo.storageUri);
  final artboard = origin & Size(canvas.width * scale, canvas.height * scale);
  final sourceBounds = Offset.zero & canvas;
  Rect fitClip(Rect clip) => Rect.fromLTWH(
    origin.dx + clip.left * scale,
    origin.dy + clip.top * scale,
    clip.width * scale,
    clip.height * scale,
  );
  final backgroundZ =
      layers.fold<int>(0, (z, layer) => math.min(z, layer.zIndex)) - 1;
  double? dimension(double? value, double reference) {
    if (value == null || value <= 1) return value;
    final pixels = value * scale;
    // Values <=1 mean relative dimensions in the saved layer format. Keep
    // subpixel absolute strokes from being reinterpreted as large percentages.
    return pixels > 1 ? pixels : math.min(1, value / reference);
  }

  return [
    LayerModel(
      id: '$id-design-background',
      type: LayerType.decoration,
      position: origin,
      width: canvas.width * scale,
      height: canvas.height * scale,
      zIndex: backgroundZ,
      canvasClip: artboard,
      decorationFillColor:
          '#${design.backgroundColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
    ),
    for (final indexed in layers.indexed)
      (() {
        final sourceClip = (indexed.$2.canvasClip ?? sourceBounds).intersect(
          sourceBounds,
        );
        return indexed.$2.copyWith(
          id: '$id-design-${indexed.$1}-${indexed.$2.id}',
          position: origin + indexed.$2.position * scale,
          width: indexed.$2.width * scale,
          height: indexed.$2.height * scale,
          // Format changes can leave intentional margins around an older
          // canvas. Carry that crop into the album instead of revealing it.
          canvasClip: sourceClip.isEmpty ? artboard : fitClip(sourceClip),
          opacity: sourceClip.isEmpty ? 0 : indexed.$2.opacity,
          imageOffset: indexed.$2.imageOffset == null
              ? null
              : indexed.$2.imageOffset! * scale,
          decorationBorderWidth: dimension(
            indexed.$2.decorationBorderWidth,
            indexed.$2.width,
          ),
          decorationCornerRadius: dimension(
            indexed.$2.decorationCornerRadius,
            math.min(indexed.$2.width, indexed.$2.height),
          ),
          textStyle: indexed.$2.textStyle?.copyWith(
            fontSize: indexed.$2.textStyle?.fontSize == null
                ? null
                : indexed.$2.textStyle!.fontSize! * scale,
            letterSpacing: indexed.$2.textStyle?.letterSpacing == null
                ? null
                : indexed.$2.textStyle!.letterSpacing! * scale,
            wordSpacing: indexed.$2.textStyle?.wordSpacing == null
                ? null
                : indexed.$2.textStyle!.wordSpacing! * scale,
            shadows: indexed.$2.textStyle?.shadows
                ?.map(
                  (shadow) => Shadow(
                    color: shadow.color,
                    offset: shadow.offset * scale,
                    blurRadius: shadow.blurRadius * scale,
                  ),
                )
                .toList(),
          ),
        );
      })(),
  ];
}

/// An unsaved view of the exact pages that would be appended. Existing page
/// maps, including custom layers and metadata, are kept verbatim and in order.
class MonthlyMomentAppendPreview {
  const MonthlyMomentAppendPreview._(this.existingPages, this.pendingPages);

  final List<Map<String, dynamic>> existingPages;
  final List<Map<String, dynamic>> pendingPages;
  List<Map<String, dynamic>> get pages => [...existingPages, ...pendingPages];
}

MonthlyMomentAppendPreview buildMonthlyMomentAppendPreview({
  required String existingDocumentJson,
  required DateTime month,
  required List<MomentRecord> records,
  required List<String> selectedPhotoIds,
  required Size canvasSize,
}) {
  final Object? document;
  try {
    document = jsonDecode(existingDocumentJson);
  } on FormatException {
    throw ArgumentError('저장한 앨범의 페이지를 확인할 수 없어요.');
  }
  if (document is! Map ||
      document['pages'] is! List ||
      (document['pages'] as List).isEmpty) {
    throw ArgumentError('저장한 앨범의 페이지를 확인할 수 없어요.');
  }
  final saved = <Map<String, dynamic>>[];
  for (final value in document['pages'] as List) {
    if (value is! Map || value['layers'] is! List) {
      throw ArgumentError('저장한 앨범의 페이지를 확인할 수 없어요.');
    }
    saved.add(Map<String, dynamic>.from(value));
  }
  final pending = selectedPhotoIds.isEmpty
      ? <Map<String, dynamic>>[]
      : buildMonthlyMomentAppendPages(
          month: month,
          records: records,
          selectedPhotoIds: selectedPhotoIds,
          canvasSize: canvasSize,
        );
  if (saved.length + pending.length > 81) {
    throw ArgumentError('한 앨범에는 내지를 80쪽까지 담을 수 있어요. 사진을 줄여 주세요.');
  }
  return MonthlyMomentAppendPreview._(
    List.unmodifiable(saved),
    List.unmodifiable([
      for (var index = 0; index < pending.length; index++)
        {...pending[index], 'index': saved.length + index},
    ]),
  );
}

String _singleLine(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

void _validatePhoto(MomentPhoto photo) {
  final path = photo.path;
  if (photo.id.trim().isEmpty ||
      photo.width <= 0 ||
      photo.height <= 0 ||
      path.isEmpty ||
      path != path.trim() ||
      path.contains(RegExp(r'[:?#\\\x00-\x1f]')) ||
      path
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw ArgumentError('사진의 원본 정보를 확인해 주세요.');
  }
}

Map<String, dynamic> _page({
  required int index,
  required Color background,
  required List<LayerModel> layers,
  bool isCover = false,
  Size canvasSize = monthlyMomentCanvasSize,
}) => {
  'index': index,
  'isCover': isCover,
  'backgroundColor': background.toARGB32(),
  'layers': layers
      .map(
        (layer) => LayerExportMapper.toJson(
          layer,
          canvasSize: canvasSize,
          isCover: isCover,
        ),
      )
      .toList(),
};

LayerModel _photo({
  required String id,
  required MomentPhoto photo,
  required Rect bounds,
}) {
  // Match the actual image ratio so the shared renderer's cover fit does not
  // crop people or scenery. The longest edge fills the available photo area.
  final scale = math.min(
    bounds.width / photo.width,
    bounds.height / photo.height,
  );
  final width = photo.width * scale;
  final height = photo.height * scale;
  return LayerModel(
    id: id,
    type: LayerType.image,
    position: Offset(
      bounds.left + (bounds.width - width) / 2,
      bounds.top + (bounds.height - height) / 2,
    ),
    width: width,
    height: height,
    imageTemplate: 'free',
    originalUrl: photo.storageUri,
    previewUrl: photo.storageUri,
    imageUrl: photo.storageUri,
  );
}

LayerModel _text({
  required String id,
  required String text,
  required Rect rect,
  required double fontSize,
  String fontFamily = 'NotoSans',
  Color color = _ink,
  TextAlign align = TextAlign.left,
  double lineHeight = 1.25,
  double tracking = 0,
}) {
  var style = TextStyle(
    fontSize: fontSize,
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    color: color,
    height: lineHeight,
    letterSpacing: tracking,
  );
  // Fit complete user text into its editable box. Large photos never shrink
  // to accommodate a long note; the note gets its own page instead.
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: align,
  );
  while (true) {
    painter.text = TextSpan(text: text, style: style);
    painter.layout(maxWidth: rect.width);
    if (painter.height <= rect.height || style.fontSize! <= 10) break;
    style = style.copyWith(fontSize: style.fontSize! - .5);
  }
  painter.dispose();
  return LayerModel(
    id: id,
    type: LayerType.text,
    position: rect.topLeft,
    width: rect.width,
    height: rect.height,
    text: text,
    textAlign: align,
    textStyle: style,
    textStyleType: TextStyleType.none,
    zIndex: 1,
  );
}
