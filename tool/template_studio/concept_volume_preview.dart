import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'editorial_preview.dart';
import 'lightbound_preview.dart';

List<List<LayerModel>> conceptVolumePages(
  ConceptVolume volume,
  CollectionAspect aspect, {
  EditorialCopy? copy,
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

bool conceptCopyFits(ConceptVolume volume, EditorialCopy copy) {
  if ([
    copy.place,
    copy.period,
    copy.byline,
    copy.note,
  ].any((v) => v.trim().isEmpty))
    return false;
  for (final aspect in CollectionAspect.values) {
    for (final layer in conceptVolumePages(
      volume,
      aspect,
      copy: copy,
    ).expand((p) => p)) {
      if (layer.type != LayerType.text) continue;
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(text: layer.text, style: layer.textStyle),
        strutStyle: StrutStyle.fromTextStyle(
          layer.textStyle!,
          forceStrutHeight: true,
        ),
      )..layout(maxWidth: layer.width);
      final fits =
          painter.height <= layer.height + .5 && !painter.didExceedMaxLines;
      painter.dispose();
      if (!fits) return false;
    }
  }
  return true;
}

class ConceptVolumePreview extends StatelessWidget {
  const ConceptVolumePreview({super.key, required this.volume});
  final ConceptVolume volume;
  @override
  Widget build(BuildContext context) => AuthoredDraftPreview<EditorialCopy>(
    title: volume.title,
    prioritizePageCount: true,
    chapters: volume.chapters,
    revision: volume.contentRevision,
    coverRevision: 1,
    editionLabel:
        '${volume.category} · 24쪽 · ${volume.isApprovedDesign ? '디자인 승인' : '신규 디자인 검토'} · ${conceptVolumeLaunchPointPrice}P · 출시 대기',
    initialCopy: volume.defaultCopy,
    buildPages: (aspect, copy, photos) =>
        conceptVolumePages(volume, aspect, copy: copy, photos: photos),
    copySheet: (copy) => EditorialCopySheet(
      placeLabel: '표지 제목',
      copy: copy,
      validateCopy: (value) => conceptCopyFits(volume, value),
    ),
    extraControls: [
      IconButton(
        tooltip: '유료 시안 목록',
        icon: const Icon(Icons.grid_view_outlined),
        onPressed: () {
          final nav = Navigator.of(context);
          if (ModalRoute.of(context)?.settings.arguments == 'premium-studies') {
            nav.pop();
          } else {
            nav.pushReplacementNamed('/premium-studies');
          }
        },
      ),
      IconButton(
        tooltip: '꾸밈 재료',
        icon: const Icon(Icons.auto_awesome_mosaic_outlined),
        onPressed: () => Navigator.of(context).pushNamed('/keepsake-materials'),
      ),
      CatalogFavoriteButton(
        itemKey: 'template:${volume.id}',
        label: volume.title,
      ),
    ],
  );
}
