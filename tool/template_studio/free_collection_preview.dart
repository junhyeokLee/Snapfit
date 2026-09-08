import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'editorial_preview.dart';
import 'lightbound_preview.dart';

List<List<LayerModel>> freeCollectionPreviewPages(
  FreeCollectionVolume volume,
  CollectionAspect aspect,
  EditorialCopy copy, {
  bool photos = true,
}) => templateDocumentPages(volume.document(aspect, copy: copy))
    .map(
      (page) => DataTemplateEngine.buildLayersFromJson(page, aspect.canvas)
          .map(
            (layer) => !photos && layer.type == LayerType.image
                ? layer.copyWith(clearImage: true)
                : layer,
          )
          .toList(),
    )
    .toList();

bool freeCollectionCopyFits(FreeCollectionVolume volume, EditorialCopy copy) {
  for (final aspect in CollectionAspect.values) {
    for (final layer in freeCollectionPreviewPages(
      volume,
      aspect,
      copy,
    ).expand((p) => p)) {
      if (layer.type != LayerType.text) continue;
      final painter = TextPainter(
        text: TextSpan(text: layer.text, style: layer.textStyle),
        textDirection: TextDirection.ltr,
        strutStyle: StrutStyle.fromTextStyle(
          layer.textStyle!,
          forceStrutHeight: true,
        ),
      )..layout(maxWidth: layer.width);
      final fits = painter.height <= layer.height + .5;
      painter.dispose();
      if (!fits) return false;
    }
  }
  return true;
}

class FreeCollectionPreview extends StatelessWidget {
  const FreeCollectionPreview({super.key, required this.volume});
  final FreeCollectionVolume volume;
  @override
  Widget build(BuildContext context) => AuthoredDraftPreview<EditorialCopy>(
    title: volume.title,
    chapters: volume.chapters,
    initialCopy: volume.defaultCopy,
    buildPages: (aspect, copy, photos) =>
        freeCollectionPreviewPages(volume, aspect, copy, photos: photos),
    copySheet: (copy) => EditorialCopySheet(
      placeLabel: volume.category == '웨딩'
          ? '기념한 장소'
          : volume.category == '여행'
          ? '여행지'
          : '기록의 계절',
      copy: copy,
      validateCopy: (next) => freeCollectionCopyFits(volume, next),
    ),
  );
}
