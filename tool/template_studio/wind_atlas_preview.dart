import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'editorial_preview.dart';
import 'lightbound_preview.dart';

List<List<LayerModel>> windAtlasPreviewPages(
  CollectionAspect aspect, {
  WindAtlasCover cover = WindAtlasCover.illustrated,
  EditorialCopy copy = windAtlasCopy,
  bool photos = true,
  String? replacementPhoto,
}) => templateDocumentPages(buildWindAtlas(aspect, cover: cover, copy: copy))
    .map(
      (p) => DataTemplateEngine.buildLayersFromJson(p, aspect.canvas)
          .map(
            (layer) => layer.type != LayerType.image
                ? layer
                : !photos
                ? layer.copyWith(clearImage: true)
                : replacementPhoto != null
                ? layer.copyWith(imageUrl: replacementPhoto)
                : layer,
          )
          .toList(),
    )
    .toList();

bool windAtlasCopyFits(EditorialCopy copy) {
  for (final aspect in CollectionAspect.values) {
    for (final cover in WindAtlasCover.values) {
      for (final l in windAtlasPreviewPages(
        aspect,
        copy: copy,
        cover: cover,
      ).expand((p) => p)) {
        if (l.type != LayerType.text) continue;
        final painter = TextPainter(
          text: TextSpan(text: l.text, style: l.textStyle),
          textDirection: TextDirection.ltr,
          strutStyle: StrutStyle.fromTextStyle(
            l.textStyle!,
            forceStrutHeight: true,
          ),
        )..layout(maxWidth: l.width);
        final fits = painter.height <= l.height + .5;
        painter.dispose();
        if (!fits) return false;
      }
    }
  }
  return true;
}

class WindAtlasPreview extends StatefulWidget {
  const WindAtlasPreview({super.key});
  @override
  State<WindAtlasPreview> createState() => _WindAtlasPreviewState();
}

class _WindAtlasPreviewState extends State<WindAtlasPreview> {
  WindAtlasCover _cover = WindAtlasCover.illustrated;
  String? _replacement;
  @override
  Widget build(BuildContext context) => AuthoredDraftPreview<EditorialCopy>(
    title: windAtlasTitle,
    chapters: windAtlasSpreads,
    initialCopy: windAtlasCopy,
    revision: (_cover, _replacement),
    coverRevision: _cover,
    buildPages: (aspect, copy, photos) => windAtlasPreviewPages(
      aspect,
      copy: copy,
      cover: _cover,
      photos: photos,
      replacementPhoto: _replacement,
    ),
    copySheet: (copy) => EditorialCopySheet(
      copy: copy,
      placeLabel: '여행지',
      validateCopy: windAtlasCopyFits,
    ),
    extraControls: [
      PopupMenuButton<WindAtlasCover>(
        tooltip: '표지 디자인',
        icon: const Icon(Icons.style_outlined, size: 21),
        initialValue: _cover,
        itemBuilder: (_) => [
          for (final c in WindAtlasCover.values)
            CheckedPopupMenuItem(
              value: c,
              checked: c == _cover,
              child: Text(c.label),
            ),
        ],
        onSelected: (value) => setState(() => _cover = value),
      ),
      PopupMenuButton<String>(
        tooltip: '사진 교체 확인',
        icon: const Icon(Icons.swap_horiz_rounded, size: 22),
        itemBuilder: (_) => const [
          PopupMenuItem(value: '', child: Text('여행 사진')),
          PopupMenuItem(value: 'couple_walk', child: Text('인물 사진')),
          PopupMenuItem(value: 'family_friends', child: Text('여럿이 함께한 사진')),
          PopupMenuItem(value: 'lightbound_twilight', child: Text('어두운 저녁 사진')),
        ],
        onSelected: (value) => setState(
          () => _replacement = value.isEmpty
              ? null
              : 'asset:assets/templates/original_editorial/images/$value.png',
        ),
      ),
    ],
  );
}
