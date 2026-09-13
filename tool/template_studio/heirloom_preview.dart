import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_catalog_categories.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'editorial_preview.dart';
import 'lightbound_preview.dart';
import 'luminous_materials.dart';

List<List<LayerModel>> heirloomPages(
  HeirloomStudy study,
  CollectionAspect aspect, {
  EditorialCopy? copy,
  bool photos = true,
  bool fullEdition = false,
  int? innerPages,
}) =>
    templateDocumentPages(
          innerPages != null
              ? PremiumVolume.byId(
                  study.id,
                ).document(aspect, innerPages: innerPages, copy: copy)
              : fullEdition && study == HeirloomStudy.wedding
              ? buildVowKeepsakeEdition(aspect, copy: copy)
              : study.document(aspect, copy: copy),
        )
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

bool heirloomCopyFits(
  HeirloomStudy study,
  EditorialCopy copy, {
  bool fullEdition = false,
  int? innerPages,
}) {
  if ([
    copy.place,
    copy.period,
    copy.byline,
    copy.note,
  ].any((s) => s.trim().isEmpty))
    return false;
  for (final aspect in CollectionAspect.values) {
    for (final l in heirloomPages(
      study,
      aspect,
      copy: copy,
      fullEdition: fullEdition,
      innerPages: innerPages,
    ).expand((p) => p)) {
      if (l.type != LayerType.text) continue;
      final text = TextPainter(
        text: TextSpan(text: l.text, style: l.textStyle),
        textDirection: TextDirection.ltr,
        strutStyle: StrutStyle.fromTextStyle(
          l.textStyle!,
          forceStrutHeight: true,
        ),
      )..layout(maxWidth: l.width);
      final fits = text.height <= l.height + .5 && !text.didExceedMaxLines;
      text.dispose();
      if (!fits) return false;
    }
  }
  return true;
}

class HeirloomPreview extends StatefulWidget {
  const HeirloomPreview({super.key, required this.study});
  final HeirloomStudy study;
  @override
  State<HeirloomPreview> createState() => _HeirloomPreviewState();
}

class _HeirloomPreviewState extends State<HeirloomPreview> {
  HeirloomStudy get study => widget.study;
  PremiumVolume get volume => PremiumVolume.byId(study.id);
  late int selectedPages = volume.extendedPages;
  bool get fullEdition => selectedPages == 20;
  int? get volumePages => selectedPages >= 24 ? selectedPages : null;
  @override
  Widget build(BuildContext context) => AuthoredDraftPreview<EditorialCopy>(
    title: study.title,
    prioritizePageCount: true,
    chapters: volumePages != null
        ? (volume.document(
                    CollectionAspect.square,
                    innerPages: volumePages,
                  )['chapters']
                  as List)
              .map((c) => c['title'] as String)
              .toList()
        : fullEdition
        ? vowEditionChapters
        : study.chapters,
    revision: selectedPages,
    coverRevision: selectedPages,
    editionLabel:
        '${study.category} · $selectedPages쪽 · ${premiumVolumeLaunchPointPrice}P · 출시 대기',
    initialCopy: study.defaultCopy,
    buildPages: (aspect, copy, photos) => heirloomPages(
      study,
      aspect,
      copy: copy,
      photos: photos,
      fullEdition: fullEdition,
      innerPages: volumePages,
    ),
    copySheet: (copy) => EditorialCopySheet(
      placeLabel: '표지 제목',
      copy: copy,
      validateCopy: (value) => heirloomCopyFits(
        study,
        value,
        fullEdition: fullEdition,
        innerPages: volumePages,
      ),
    ),
    extraControls: [
      PopupMenuButton<int>(
        tooltip: '판본 선택',
        icon: const Icon(Icons.collections_bookmark_outlined),
        initialValue: selectedPages,
        onSelected: (value) => setState(() => selectedPages = value),
        itemBuilder: (_) => [
          for (final count in volume.pageCounts)
            PopupMenuItem(
              value: count,
              child: Text('$count쪽 ${count == 24 ? '기본판' : '확장판'}'),
            ),
          const PopupMenuDivider(),
          if (study == HeirloomStudy.wedding)
            const PopupMenuItem(value: 20, child: Text('20쪽 이전 확장본')),
          const PopupMenuItem(value: 8, child: Text('승인 8쪽 기준본')),
        ],
      ),
      IconButton(
        tooltip: '유료 시안 목록',
        icon: const Icon(Icons.grid_view_outlined),
        onPressed: () {
          final navigator = Navigator.of(context);
          if (ModalRoute.of(context)?.settings.arguments == 'premium-studies') {
            navigator.pop();
          } else {
            navigator.pushReplacementNamed('/premium-studies');
          }
        },
      ),
      IconButton(
        tooltip: '꾸밈 재료',
        icon: const Icon(Icons.auto_awesome_mosaic_outlined),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LuminousMaterials()),
        ),
      ),
      CatalogFavoriteButton(
        itemKey: 'template:${study.id}',
        label: study.title,
      ),
    ],
  );
}

class PremiumStudyEntry {
  const PremiumStudyEntry({this.study, this.conceptVolume});
  final HeirloomStudy? study;
  final ConceptVolume? conceptVolume;
  String get id => conceptVolume?.id ?? study?.id ?? luminousEditionId;
  String get title =>
      conceptVolume?.title ?? study?.title ?? luminousEditionTitle;
  String get category => conceptVolume?.category ?? study?.category ?? '여행';
  String get concept =>
      conceptVolume?.concept ?? study?.concept ?? '여행 서류 포켓과 인덱스, 편지와 엽서';
  String get edition => conceptVolume != null
      ? '24쪽 · ${conceptVolumeLaunchPointPrice}P'
      : '${PremiumVolume.byId(id).pageCounts.join(' / ')}쪽 · ${premiumVolumeLaunchPointPrice}P';
  Map<String, dynamic> document(CollectionAspect aspect) =>
      conceptVolume?.document(aspect) ??
      PremiumVolume.byId(id).document(aspect);
}

final premiumStudyEntries = [
  for (final topic in templateTopicOrder)
    if (topic == '여행')
      const PremiumStudyEntry()
    else
      PremiumStudyEntry(
        study: HeirloomStudy.values.singleWhere((s) => s.category == topic),
      ),
];

final allPremiumStudyEntries = [
  for (final volume in {...lifeConceptVolumes, ...approvedConceptVolumes})
    PremiumStudyEntry(conceptVolume: volume),
  ...premiumStudyEntries,
];

class PremiumStudiesCatalog extends StatefulWidget {
  const PremiumStudiesCatalog({super.key});
  @override
  State<PremiumStudiesCatalog> createState() => _PremiumStudiesCatalogState();
}

class _PremiumStudiesCatalogState extends State<PremiumStudiesCatalog> {
  String category = '전체';
  late final covers = {
    for (final entry in allPremiumStudyEntries)
      entry.id: DataTemplateEngine.buildLayersFromJson(
        templateDocumentPages(entry.document(CollectionAspect.square)).first,
        CollectionAspect.square.canvas,
      ),
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('유료 템플릿 시안', style: TextStyle(fontSize: 17)),
      actions: [
        IconButton(
          tooltip: '무료 템플릿 스토어',
          onPressed: () => Navigator.of(context).pushNamed('/store'),
          icon: const Icon(Icons.storefront_outlined),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  '${allPremiumStudyEntries.length}종',
                  style: const TextStyle(fontSize: 13),
                ),
                const Spacer(),
                const Text(
                  '내지 24~36쪽 · 출시 대기',
                  style: TextStyle(fontSize: 12, color: Color(0xFF65716C)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final topic in ['전체', ...templateTopicOrder])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(topic, style: const TextStyle(fontSize: 13)),
                      showCheckmark: false,
                      selected: category == topic,
                      onSelected: (_) => setState(() => category = topic),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: CatalogFavoriteGrid<PremiumStudyEntry>(
              items: allPremiumStudyEntries
                  .where((s) => category == '전체' || s.category == category)
                  .toList(),
              keyOf: (s) => 'template:${s.id}',
              labelOf: (s) => s.title,
              mainAxisExtent: 315,
              maxCrossAxisExtent: 340,
              itemBuilder: (context, entry) => Semantics(
                button: true,
                label: '${entry.title} 시안 열기',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/${entry.id}', arguments: 'premium-studies'),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ExcludeSemantics(
                                child: LayoutBuilder(
                                  builder: (context, bounds) =>
                                      TemplatePageRenderer(
                                        layers: covers[entry.id]!,
                                        width: bounds.maxWidth,
                                        height: bounds.maxHeight,
                                        designCanvasSize:
                                            CollectionAspect.square.canvas,
                                        preserveTypography: true,
                                        showCanvasChrome: false,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${entry.category} · ${entry.edition}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF62756B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 34,
                          child: Text(
                            entry.concept,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF66716C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
