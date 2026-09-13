import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'lightbound_preview.dart';
import 'prose_comparison.dart';

const proseStylePages = [0, 1, 3, 4, 5, 24];
const proseStyleKeys = [
  'cartouche',
  'cascade',
  'word',
  'quotation',
  'letter',
  'dedication',
];

List<List<LayerModel>> proseStudyPages(
  CollectionAspect aspect, {
  ProseStudyCopy copy = const ProseStudyCopy(),
  bool photos = true,
  bool complete = false,
}) =>
    templateDocumentPages(
          complete
              ? buildProseAlbum(aspect, copy: copy)
              : buildProseStudy(aspect, copy: copy),
        )
        .map(
          (p) => DataTemplateEngine.buildLayersFromJson(p, aspect.canvas)
              .map(
                (l) => !photos && l.type == LayerType.image
                    ? l.copyWith(clearImage: true)
                    : l,
              )
              .toList(),
        )
        .toList();

bool proseStudyCopyFits(ProseStudyCopy copy) {
  if (copy.heading.trim().isEmpty || copy.keyword.trim().isEmpty) return false;
  for (final aspect in CollectionAspect.values) {
    for (final l in proseStudyPages(
      aspect,
      copy: copy,
      complete: true,
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
  return true;
}

class ProseStudyPreview extends StatefulWidget {
  const ProseStudyPreview({super.key});
  @override
  State<ProseStudyPreview> createState() => _ProseStudyPreviewState();
}

class _ProseStudyPreviewState extends State<ProseStudyPreview> {
  int _serial = 0;
  ({int page, int serial})? _request;
  Future<void> _styles() async {
    final page = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute(builder: (_) => const ProseStyleGallery()));
    if (page != null && mounted)
      setState(() => _request = (page: page, serial: ++_serial));
  }

  @override
  Widget build(BuildContext context) => AuthoredDraftPreview<ProseStudyCopy>(
    title: proseStudyTitle,
    chapters: proseAlbumSpreads,
    editionLabel: '무료',
    initialCopy: const ProseStudyCopy(),
    pageRequest: _request,
    buildPages: (aspect, copy, photos) =>
        proseStudyPages(aspect, copy: copy, photos: photos, complete: true),
    copySheet: (copy) => ProseCopySheet(copy: copy),
    extraControls: [
      IconButton(
        tooltip: '무료와 비교',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProseComparison()),
        ),
        icon: const Icon(Icons.compare_outlined, size: 22),
      ),
      IconButton(
        tooltip: '문구 조판',
        onPressed: _styles,
        icon: const Icon(Icons.auto_awesome_mosaic_outlined, size: 22),
      ),
    ],
  );
}

class ProseStyleGallery extends StatefulWidget {
  const ProseStyleGallery({super.key});
  @override
  State<ProseStyleGallery> createState() => _ProseStyleGalleryState();
}

class _ProseStyleGalleryState extends State<ProseStyleGallery> {
  bool _favoritesOnly = false;
  final _pages = proseStudyPages(CollectionAspect.square, complete: true);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('문구 조판', style: TextStyle(fontSize: 17)),
      actions: [
        CatalogFavoriteFilter(
          selected: _favoritesOnly,
          onChanged: (value) => setState(() => _favoritesOnly = value),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: SafeArea(
      top: false,
      child: CatalogFavoritesBuilder(
        builder: (context, favorites) {
          final indices = favorites.arrange(
            List.generate(6, (i) => i),
            (i) => CatalogFavoriteKeys.textStyle(
              'prose-study:${proseStyleKeys[i]}',
            ),
            onlyFavorites: _favoritesOnly,
          );
          if (indices.isEmpty)
            return CatalogFavoritesEmpty(
              onShowAll: () => setState(() => _favoritesOnly = false),
            );
          return LayoutBuilder(
            builder: (context, box) {
              final columns = math.max(1, (box.maxWidth / 330).floor());
              final width = (box.maxWidth - 32 - 20 * (columns - 1)) / columns;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 24,
                  mainAxisExtent: width + 44,
                ),
                itemCount: indices.length,
                itemBuilder: (context, index) {
                  final i = indices[index], label = proseStudyStyles[i];
                  return CatalogFavoriteTile(
                    itemKey: CatalogFavoriteKeys.textStyle(
                      'prose-study:${proseStyleKeys[i]}',
                    ),
                    label: label,
                    child: Semantics(
                      button: true,
                      label: '$label 페이지 보기',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, proseStylePages[i]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TemplatePageRenderer(
                              layers: _pages[proseStylePages[i]],
                              width: width,
                              height: width,
                              designCanvasSize: CollectionAspect.square.canvas,
                              preserveTypography: true,
                              showCanvasChrome: false,
                            ),
                            SizedBox(
                              height: 44,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    ),
  );
}

class ProseCopySheet extends StatefulWidget {
  const ProseCopySheet({super.key, required this.copy});
  final ProseStudyCopy copy;
  @override
  State<ProseCopySheet> createState() => _ProseCopySheetState();
}

class _ProseCopySheetState extends State<ProseCopySheet> {
  late final _fields = [
    widget.copy.heading,
    widget.copy.keyword,
    widget.copy.names,
    widget.copy.date,
    widget.copy.promise,
    widget.copy.letter,
    widget.copy.closing,
  ].map((text) => TextEditingController(text: text)).toList();
  String? _error;
  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _apply() {
    final copy = ProseStudyCopy(
      heading: _fields[0].text.trim(),
      keyword: _fields[1].text.trim(),
      names: _fields[2].text.trim(),
      date: _fields[3].text.trim(),
      promise: _fields[4].text.trim(),
      letter: _fields[5].text.trim(),
      closing: _fields[6].text.trim(),
    );
    if (!proseStudyCopyFits(copy)) {
      setState(() => _error = '제목은 비워 둘 수 없어요. 문구 길이와 줄바꿈을 확인해 주세요.');
      return;
    }
    Navigator.pop(context, copy);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: math.max(
        100,
        math.min(
          680,
          MediaQuery.sizeOf(context).height * .9 -
              MediaQuery.viewInsetsOf(context).bottom,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            ListTile(
              title: const Text('문구 편집', style: TextStyle(fontSize: 17)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '문구 적용',
                    onPressed: _apply,
                    icon: const Icon(Icons.check_rounded),
                  ),
                  IconButton(
                    tooltip: '문구 편집 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  for (final field in [
                    '표제 윗줄',
                    '강조 단어',
                    '함께한 이름',
                    '날짜',
                    '4쪽 짧은 기록',
                    '당신에게 쓰는 편지',
                    '24쪽 마무리',
                  ].indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextField(
                        controller: _fields[field.$1],
                        decoration: InputDecoration(
                          labelText: field.$2,
                          border: const OutlineInputBorder(),
                        ),
                        maxLength: [12, 6, 22, 24, 80, 250, 24][field.$1],
                        minLines: field.$1 == 6
                            ? 2
                            : field.$1 >= 4
                            ? 3
                            : 1,
                        maxLines: field.$1 == 5
                            ? 8
                            : field.$1 == 4
                            ? 4
                            : field.$1 == 6
                            ? 2
                            : 1,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
