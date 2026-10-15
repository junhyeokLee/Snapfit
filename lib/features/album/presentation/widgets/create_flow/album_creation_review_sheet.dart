import 'dart:io';
import '../../../data/gallery/browser_photo_asset.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../store/presentation/widgets/template_book_artwork.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import '../../../domain/entities/layer.dart';
import 'creation_workspace.dart';

/// -1 starts the editor; a nonnegative result opens that page for corrections.
Future<int?> showAlbumCreationReview(
  BuildContext context, {
  required List<List<LayerModel>> pages,
  required int innerPageCount,
  required Size canvasSize,
}) => kIsWeb ? showDialog<int>(
  context: context,
  builder: (dialogContext) => Dialog(
    backgroundColor: WebPalette.of(dialogContext).surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    insetPadding: const EdgeInsets.all(32),
    child: SizedBox(
      width: 1000,
      height: math.min(760.0, math.max(280.0, MediaQuery.sizeOf(dialogContext).height - 64)),
      child: AlbumCreationReviewSheet(pages: pages, innerPageCount: innerPageCount, canvasSize: canvasSize),
    ),
  ),
) : showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 1000),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
  ),
  backgroundColor: ExperienceFormStyle.surface(context),
  builder: (_) => AlbumCreationReviewSheet(
    pages: pages,
    innerPageCount: innerPageCount,
    canvasSize: canvasSize,
  ),
);

class AlbumCreationReviewSheet extends StatefulWidget {
  const AlbumCreationReviewSheet({
    super.key,
    required this.pages,
    required this.innerPageCount,
    required this.canvasSize,
  });
  final List<List<LayerModel>> pages;
  final int innerPageCount;
  final Size canvasSize;

  @override
  State<AlbumCreationReviewSheet> createState() =>
      _AlbumCreationReviewSheetState();
}

class _AlbumCreationReviewSheetState extends State<AlbumCreationReviewSheet> {
  bool _missingOnly = false;
  List<List<LayerModel>> get pages => widget.pages;
  int get innerPageCount => widget.innerPageCount;
  Size get canvasSize => widget.canvasSize;

  @override
  void didUpdateWidget(covariant AlbumCreationReviewSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!pages
        .expand((page) => page)
        .any(
          (layer) => layer.type == LayerType.image && !layer.hasImageSource,
        )) {
      _missingOnly = false;
    }
  }

  Widget _filters(List<int> missingPages) => Wrap(
    key: const ValueKey('creation-review-filters'),
    spacing: 8,
    runSpacing: 4,
    children: [
      FilterChip(
        key: const ValueKey('creation-review-missing-filter'),
        selected: _missingOnly,
        onSelected: missingPages.isEmpty
            ? null
            : (selected) => setState(() => _missingOnly = selected),
        label: Text(
          '빈 사진 있는 쪽 ${missingPages.length}쪽',
          style: ExperienceFormStyle.text(context, 12),
        ),
        selectedColor: ExperienceFormStyle.selection(context),
        backgroundColor: ExperienceFormStyle.surface(context),
        side: BorderSide(color: ExperienceFormStyle.line(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      if (missingPages.isNotEmpty)
        TextButton.icon(
          key: const ValueKey('creation-review-first-missing'),
          onPressed: () => Navigator.pop(context, missingPages.first),
          icon: const ExperienceIcon('ArrowRight', size: 16),
          label: Text('첫 빈 사진으로', style: ExperienceFormStyle.text(context, 12)),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final slots = pages
        .expand((page) => page)
        .where((layer) => layer.type == LayerType.image);
    final empty = slots.where((layer) => !layer.hasImageSource).length;
    final wide =
        MediaQuery.sizeOf(context).width >= 640 &&
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final missingPages = [
      for (
        var index = 0;
        index <= innerPageCount && index < pages.length;
        index++
      )
        if (pages[index].any(
          (layer) => layer.type == LayerType.image && !layer.hasImageSource,
        ))
          index,
    ];
    final indices = _missingOnly
        ? missingPages
        : List.generate(innerPageCount + 1, (index) => index);
    return FractionallySizedBox(
      heightFactor: .94,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '앨범 확인',
                      style: ExperienceFormStyle.text(
                        context,
                        18,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (wide) ...[
                    Text(
                      '표지 · 내지 $innerPageCount쪽',
                      style: ExperienceFormStyle.text(
                        context,
                        13,
                        secondary: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        empty == 0 ? '사진 ${slots.length}장' : '빈 사진 자리 $empty개',
                        textAlign: TextAlign.end,
                        style: ExperienceFormStyle.text(
                          context,
                          13,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: Transform.rotate(
                      angle: .7853981633974483,
                      child: const ExperienceIcon('Plus'),
                    ),
                  ),
                ],
              ),
              if (!wide)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '표지 · 내지 $innerPageCount쪽',
                        style: ExperienceFormStyle.text(
                          context,
                          13,
                          secondary: true,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        empty == 0 ? '사진 ${slots.length}장' : '빈 사진 자리 $empty개',
                        style: ExperienceFormStyle.text(
                          context,
                          13,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (!wide) _filters(missingPages),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final grid = LayoutBuilder(
                      builder: (context, gridBox) {
                        final gridWidth = gridBox.maxWidth;
                        final columns = gridWidth >= 640
                            ? 4
                            : gridWidth >= 440
                            ? 3
                            : 2;
                        final width =
                            (gridWidth - 16 * (columns - 1)) / columns;
                        final captionHeight =
                            8 +
                            MediaQuery.textScalerOf(context).scale(13) * 1.6 +
                            MediaQuery.textScalerOf(context).scale(12) * 1.6;
                        final pictureHeight = wide
                            ? math.min(
                                width / canvasSize.aspectRatio,
                                math.max(
                                  36.0,
                                  gridBox.maxHeight - captionHeight,
                                ),
                              )
                            : width / canvasSize.aspectRatio;
                        return GridView.builder(
                          key: const ValueKey('creation-review-pages'),
                          itemCount: indices.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: pictureHeight + captionHeight,
                              ),
                          itemBuilder: (context, item) {
                            final index = indices[item];
                            final layers = index < pages.length
                                ? pages[index]
                                : const <LayerModel>[];
                            final missing = layers
                                .where(
                                  (layer) =>
                                      layer.type == LayerType.image &&
                                      !layer.hasImageSource,
                                )
                                .length;
                            final editable =
                                index == 0 ||
                                layers.any(
                                  (layer) => layer.type == LayerType.image,
                                );
                            final label = index == 0 ? '표지' : '$index쪽';
                            return Semantics(
                              button: editable,
                              label:
                                  '$label${missing > 0 ? ', 빈 사진 자리 $missing개' : ''}',
                              child: InkWell(
                                key: ValueKey('creation-review-page-$index'),
                                onTap: editable
                                    ? () => Navigator.pop(context, index)
                                    : null,
                                child: Column(
                                  crossAxisAlignment: wide
                                      ? CrossAxisAlignment.center
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: AspectRatio(
                                          aspectRatio: canvasSize.aspectRatio,
                                          child: RepaintBoundary(
                                            child: layers.isEmpty
                                                ? DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      border: Border.all(
                                                        color:
                                                            ExperienceFormStyle.line(
                                                              context,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        Icons
                                                            .auto_stories_outlined,
                                                        color:
                                                            ExperienceFormStyle.muted(
                                                              context,
                                                            ),
                                                        size: 24,
                                                      ),
                                                    ),
                                                  )
                                                : _ReviewPage(
                                                    layers: layers,
                                                    canvasSize: canvasSize,
                                                    cover: index == 0,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      label,
                                      style: ExperienceFormStyle.text(
                                        context,
                                        13,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      layers.isEmpty
                                          ? '편집 대기'
                                          : missing > 0
                                          ? '사진 $missing장 추가'
                                          : '구성 완료',
                                      style: ExperienceFormStyle.text(
                                        context,
                                        12,
                                        secondary: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                    if (!wide || pages.isEmpty) return grid;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 38,
                          child: CreationPaperStage(
                            title: '표지',
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: canvasSize.aspectRatio,
                                child: _ReviewPage(
                                  layers: pages.first,
                                  canvasSize: canvasSize,
                                  cover: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 62,
                          child: Column(
                            children: [
                              _filters(missingPages),
                              const SizedBox(height: 8),
                              Expanded(child: grid),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                width: kIsWeb ? 220 : double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('creation-review-start'),
                  style: ExperienceFormStyle.primary(context),
                  onPressed: () => Navigator.pop(context, -1),
                  child: const Text('편집 시작'),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewPage extends StatefulWidget {
  const _ReviewPage({
    required this.layers,
    required this.canvasSize,
    this.cover = false,
  });
  final List<LayerModel> layers;
  final Size canvasSize;
  final bool cover;
  @override
  State<_ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<_ReviewPage> {
  final Map<String, File> _files = {};
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.layers, widget.layers)) {
      _files.clear();
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final files = <String, File>{};
    for (final layer in widget.layers) {
      if (layer.asset == null || layer.asset is BrowserPhotoAsset) continue;
      try {
        final file = await layer.asset!.file;
        if (!mounted || generation != _generation) return;
        if (file != null) files[layer.id] = file;
      } catch (_) {
        // Unavailable originals remain visible as empty photo placeholders.
      }
    }
    if (mounted && generation == _generation && files.isNotEmpty) {
      setState(() => _files.addAll(files));
    }
  }

  Widget _artwork(double width, double height, {bool wrap = false}) =>
      TemplatePageRenderer(
        layers: widget.layers,
        width: width,
        height: height,
        designCanvasSize: widget.canvasSize,
        localFiles: _files,
        imageDecodeWidth:
            (math.max(width, height) *
                    MediaQuery.devicePixelRatioOf(context) *
                    1.5)
                .ceil()
                .clamp(320, 1200),
        showCanvasChrome: false,
        wrapSpineArtwork: wrap,
        cacheNetworkImages: true,
        preserveTypography: true,
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => widget.cover
        ? TemplateBookArtwork(
            canvas: widget.canvasSize,
            firstPage: 0,
            paired: false,
            pageBuilder: (index, wrap) => _artwork(
              constraints.maxWidth,
              constraints.maxHeight,
              wrap: wrap,
            ),
          )
        : _artwork(constraints.maxWidth, constraints.maxHeight),
  );
}
