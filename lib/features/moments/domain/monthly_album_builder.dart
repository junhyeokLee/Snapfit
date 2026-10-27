import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/cover_size.dart';
import '../../album/data/dto/request/create_album_request.dart';
import '../../album/domain/entities/layer.dart';
import '../../album/domain/entities/layer_export_mapper.dart';
import 'moment_record.dart';

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
  final albumTitle = _singleLine(title ?? '');
  final effectiveTitle = albumTitle.isEmpty
      ? '${month.year}년 ${month.month}월의 순간들'
      : albumTitle;
  if (effectiveTitle.characters.length > 60) {
    throw ArgumentError.value(title, 'title', '제목은 60자까지 입력해 주세요.');
  }
  final selected = selectedPhotoIds.map((id) => photos[id]!).toList();
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
      _photo(
        id: 'moment-cover-photo',
        photo: firstPhoto,
        bounds: const Rect.fromLTWH(38, 143, 438, 331),
      ),
    ],
  );
  final pages = <Map<String, dynamic>>[cover];
  final captionedRecords = <String>{};
  for (var index = 0; index < selected.length; index++) {
    final entry = selected[index];
    // A record may contain three selected photos. Keep its note once, beside
    // the first selected photo, rather than repeating it on three pages.
    final caption = captionedRecords.add(entry.record.id)
        ? _singleLine(entry.record.caption)
        : '';
    if (caption.characters.length > 200) {
      throw ArgumentError('기록 문장은 200자까지 사용할 수 있습니다.');
    }
    final hasShortCaption =
        caption.isNotEmpty && caption.characters.length <= 80;
    final date = entry.record.recordDate;
    pages.add(
      _page(
        index: pages.length,
        background: index.isEven ? _cream : _mint,
        layers: [
          _text(
            id: 'moment-${entry.photo.id}-date',
            text: '${date.month}월 ${date.day}일',
            rect: const Rect.fromLTWH(25, 20, 300, 24),
            fontSize: 13,
            color: _secondaryInk,
          ),
          _text(
            id: 'moment-${entry.photo.id}-number',
            text: (index + 1).toString().padLeft(2, '0'),
            rect: const Rect.fromLTWH(420, 20, 55, 24),
            fontSize: 13,
            fontFamily: 'Poppins',
            color: _secondaryInk,
            align: TextAlign.right,
          ),
          _photo(
            id: 'moment-${entry.photo.id}-photo',
            photo: entry.photo,
            bounds: Rect.fromLTWH(25, 59, 450, hasShortCaption ? 343 : 416),
          ),
          if (hasShortCaption)
            _text(
              id: 'moment-${entry.photo.id}-caption',
              text: caption,
              rect: const Rect.fromLTWH(25, 417, 450, 61),
              fontSize: 14,
              lineHeight: 1.4,
            ),
        ],
      ),
    );
    if (caption.isNotEmpty && !hasShortCaption) {
      pages.add(
        _page(
          index: pages.length,
          background: _cream,
          layers: [
            _text(
              id: 'moment-${entry.photo.id}-note-date',
              text:
                  '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
              rect: const Rect.fromLTWH(43, 43, 414, 28),
              fontSize: 15,
              fontFamily: 'Poppins',
              color: _secondaryInk,
              tracking: 1,
            ),
            _text(
              id: 'moment-${entry.photo.id}-caption',
              text: caption,
              rect: const Rect.fromLTWH(43, 108, 414, 330),
              fontSize: 25,
              fontFamily: 'Eulyoo',
              lineHeight: 1.65,
            ),
          ],
        ),
      );
    }
  }
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

/// Creates only new inner pages; the server appends them to the locked current
/// document and assigns their final indexes. Cover and existing pages stay intact.
List<Map<String, dynamic>> buildMonthlyMomentAppendPages({
  required DateTime month,
  required List<MomentRecord> records,
  required List<String> selectedPhotoIds,
}) {
  final built = buildMonthlyMomentAlbum(
    month: month,
    records: records,
    selectedPhotoIds: selectedPhotoIds,
  );
  final document = jsonDecode(built.coverLayersJson!) as Map<String, dynamic>;
  return (document['pages'] as List)
      .skip(1)
      .map((page) => Map<String, dynamic>.from(page as Map))
      .toList(growable: false);
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
}) => {
  'index': index,
  'isCover': isCover,
  'backgroundColor': background.toARGB32(),
  'layers': layers
      .map(
        (layer) => LayerExportMapper.toJson(
          layer,
          canvasSize: monthlyMomentCanvasSize,
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
