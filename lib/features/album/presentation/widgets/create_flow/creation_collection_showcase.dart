import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../../core/templates/data_template_engine.dart';
import '../../../../../core/templates/template_document_pages.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../domain/entities/layer.dart';
import '../../../data/bundled_creation_templates.dart';
import '../../../../store/domain/entities/premium_template.dart';
import '../../../../store/presentation/widgets/template_book_artwork.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import 'creation_catalog_cover.dart';

class CreationCollectionShowcase extends StatefulWidget {
  const CreationCollectionShowcase({
    super.key,
    required this.template,
    required this.onOpen,
    this.showTitle = false,
    this.accessBadge,
    this.editorial = false,
  });
  final PremiumTemplate template;
  final VoidCallback? onOpen;
  final bool showTitle;
  final Widget? accessBadge;
  final bool editorial;
  @override
  State<CreationCollectionShowcase> createState() =>
      _CreationCollectionShowcaseState();
}

class _CreationCollectionShowcaseState
    extends State<CreationCollectionShowcase> {
  List<List<LayerModel>> _inner = [];
  Size _canvas = const Size(500, 500);
  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(CreationCollectionShowcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.template, widget.template)) _read();
  }

  void _read() {
    _inner = [];
    try {
      final data =
          jsonDecode(widget.template.templateJson!) as Map<String, dynamic>;
      final metadata = data['metadata'] as Map? ?? const {};
      _canvas = Size(
        (data['designWidth'] as num? ?? metadata['designWidth'] as num? ?? 500)
            .toDouble(),
        (data['designHeight'] as num? ??
                metadata['designHeight'] as num? ??
                500)
            .toDouble(),
      );
      if (_canvas.width <= 0 || _canvas.height <= 0) {
        _canvas = const Size(500, 500);
        return;
      }
      // Build only the first spread's layer models.
      _inner = templateDocumentPages(data)
          .skip(1)
          .take(2)
          .map(
            (page) => DataTemplateEngine.buildLayersFromJson({
              'strictLayout': true,
              'designWidth': _canvas.width,
              'designHeight': _canvas.height,
              'layers': page['layers'] ?? [],
            }, _canvas),
          )
          .toList();
    } catch (_) {
      _inner = [];
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: widget.onOpen != null,
    label: '${widget.template.title} ${_inner.isEmpty ? '표지' : '표지와 내지'} 미리보기',
    child: InkWell(
      key: const ValueKey('creation-collection-showcase'),
      onTap: widget.onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: widget.editorial
                ? LayoutBuilder(
                    builder: (context, box) {
                      final tall = box.maxHeight > box.maxWidth * .56;
                      final coverWidth = box.maxWidth * (tall ? .48 : .34);
                      final spreadWidth = box.maxWidth * (tall ? .70 : .58);
                      final cover = CreationCatalogCover(
                        template: widget.template,
                        useThumbnail: true,
                        showBookMaterial: true,
                      );
                      final spread = _inner.isEmpty
                          ? null
                          : TemplateBookArtwork(
                              canvas: _canvas,
                              firstPage: 1,
                              paired: _inner.length == 2,
                              pageBuilder: (index, wrap) => FittedBox(
                                child: TemplatePageRenderer(
                                  layers: _inner[index - 1],
                                  width: _canvas.width,
                                  height: _canvas.height,
                                  designCanvasSize: _canvas,
                                  preserveTypography: isBundledCreationTemplate(
                                    widget.template,
                                  ),
                                  cacheNetworkImages: true,
                                  imageDecodeWidth: 640,
                                  showCanvasChrome: false,
                                ),
                              ),
                            );
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 12,
                            top: 12,
                            width: coverWidth,
                            height:
                                box.maxHeight -
                                (tall && spread != null ? 52 : 24),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: _canvas.aspectRatio,
                                child: cover,
                              ),
                            ),
                          ),
                          if (spread != null)
                            Positioned(
                              right: 8,
                              bottom: 12,
                              width: spreadWidth,
                              height: tall
                                  ? box.maxHeight * .48
                                  : box.maxHeight - 24,
                              child: spread,
                            ),
                        ],
                      );
                    },
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: AspectRatio(
                            aspectRatio: _canvas.aspectRatio,
                            child: CreationCatalogCover(
                              template: widget.template,
                              useThumbnail: true,
                              showBookMaterial: true,
                            ),
                          ),
                        ),
                      ),
                      if (_inner.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: AspectRatio(
                            aspectRatio: _canvas.aspectRatio * _inner.length,
                            child: TemplateBookArtwork(
                              canvas: _canvas,
                              firstPage: 1,
                              paired: _inner.length == 2,
                              pageBuilder: (index, wrap) => FittedBox(
                                child: TemplatePageRenderer(
                                  layers: _inner[index - 1],
                                  width: _canvas.width,
                                  height: _canvas.height,
                                  designCanvasSize: _canvas,
                                  preserveTypography: isBundledCreationTemplate(
                                    widget.template,
                                  ),
                                  cacheNetworkImages: true,
                                  imageDecodeWidth: 640,
                                  showCanvasChrome: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.showTitle
                ? widget.template.title
                : _inner.isEmpty
                ? '표지'
                : '표지와 내지',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExperienceFormStyle.text(
              context,
              16,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.template.category ?? '앨범'} · 내지 ${widget.template.pageCount}쪽',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
              ),
              if (widget.accessBadge != null) ...[
                const SizedBox(width: 12),
                widget.accessBadge!,
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
