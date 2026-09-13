import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

/// Both designs receive the same sample-photo pool for each compared spread.
/// This does not mutate either published template or the user's edited study.
List<List<LayerModel>> proseComparisonPages(
  CollectionAspect aspect,
  int spread, {
  required bool study,
  bool photos = true,
  bool samePhotos = true,
}) {
  assert(spread >= 0 && spread <= luminousEditionInnerPageCount ~/ 2);
  final current = templateDocumentPages(buildLuminousEdition(aspect));
  final free = templateDocumentPages(buildProseAlbum(aspect));
  final selected = spread == 0 ? [0] : [spread * 2 - 1, spread * 2];
  final reference = study ? current : free;
  final freeSlots = selected
      .expand(
        (i) => DataTemplateEngine.buildLayersFromJson(free[i], aspect.canvas),
      )
      .where((l) => l.type == LayerType.image)
      .length;
  final pool = selected
      .expand(
        (i) =>
            DataTemplateEngine.buildLayersFromJson(current[i], aspect.canvas),
      )
      .where((l) => l.type == LayerType.image)
      .map((l) => l.imageUrl!)
      .toSet()
      .take(freeSlots)
      .toList();
  var photo = 0;
  return selected
      .map(
        (i) =>
            DataTemplateEngine.buildLayersFromJson(
              reference[i],
              aspect.canvas,
            ).map((l) {
              if (l.type != LayerType.image) return l;
              if (!photos) return l.copyWith(clearImage: true);
              return !samePhotos || pool.isEmpty
                  ? l
                  : l.copyWith(imageUrl: pool[(photo++) % pool.length]);
            }).toList(),
      )
      .toList();
}

class ProseComparison extends StatefulWidget {
  const ProseComparison({super.key});
  @override
  State<ProseComparison> createState() => _ProseComparisonState();
}

class _ProseComparisonState extends State<ProseComparison> {
  CollectionAspect _aspect = CollectionAspect.square;
  int _spread = 1;
  bool _photos = true;
  bool _samePhotos = false;
  String get _range =>
      _spread == 0 ? '표지' : '${_spread * 2 - 1}–${_spread * 2}쪽';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('무료와 비교', style: TextStyle(fontSize: 17)),
      actions: [
        IconButton(
          tooltip: _samePhotos ? '원본 사진으로 비교' : '같은 사진으로 비교',
          isSelected: _samePhotos,
          onPressed: () => setState(() => _samePhotos = !_samePhotos),
          icon: const Icon(Icons.photo_filter_outlined),
        ),
        IconButton(
          tooltip: _photos ? '비교 사진 숨기기' : '비교 사진 보이기',
          onPressed: () => setState(() => _photos = !_photos),
          icon: Icon(
            _photos ? Icons.image_outlined : Icons.hide_image_outlined,
          ),
        ),
        PopupMenuButton<CollectionAspect>(
          tooltip: '비교 규격',
          icon: const Icon(Icons.aspect_ratio_rounded),
          initialValue: _aspect,
          onSelected: (v) => setState(() => _aspect = v),
          itemBuilder: (_) => [
            for (final a in CollectionAspect.values)
              PopupMenuItem(value: a, child: Text(a.cover.name)),
          ],
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(value: 0, label: Text('표지')),
                  for (var i = 1; i <= luminousEditionInnerPageCount ~/ 2; i++)
                    ButtonSegment(
                      value: i,
                      label: Text('${i * 2 - 1}–${i * 2}'),
                    ),
                ],
                selected: {_spread},
                onSelectionChanged: (v) => setState(() => _spread = v.single),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final sideBySide = box.maxWidth >= 1050;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  child: sideBySide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _lane(false)),
                            const SizedBox(width: 28),
                            Expanded(child: _lane(true)),
                          ],
                        )
                      : Column(
                          children: [
                            _lane(false),
                            const SizedBox(height: 28),
                            _lane(true),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _lane(bool study) {
    final pages = proseComparisonPages(
      _aspect,
      _spread,
      study: study,
      photos: _photos,
      samePhotos: _samePhotos,
    );
    final tier = study ? '새 시안' : '무료';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              tier,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                study ? luminousEditionTitle : proseStudyTitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF61716B)),
              ),
            ),
            const Icon(Icons.open_in_full_rounded, size: 16),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: '$tier $_range 확대',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => _enlarge(pages, tier),
            child: _spreadView(pages),
          ),
        ),
      ],
    );
  }

  Widget _spreadView(List<List<LayerModel>> pages) => AspectRatio(
    aspectRatio: _aspect.canvas.aspectRatio * pages.length,
    child: LayoutBuilder(
      builder: (context, box) => Row(
        children: [
          for (final layers in pages)
            TemplatePageRenderer(
              layers: layers,
              width: box.maxWidth / pages.length,
              height: box.maxHeight,
              designCanvasSize: _aspect.canvas,
              preserveTypography: true,
              showCanvasChrome: false,
            ),
        ],
      ),
    ),
  );

  void _enlarge(List<List<LayerModel>> pages, String tier) => showDialog<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text('$tier · $_range', style: const TextStyle(fontSize: 17)),
          leading: IconButton(
            tooltip: '비교 확대 닫기',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _spreadView(pages),
            ),
          ),
        ),
      ),
    ),
  );
}
