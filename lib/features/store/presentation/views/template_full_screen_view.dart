import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;
import '../../../../shared/web/web_design.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../album/domain/entities/layer.dart';
import '../widgets/template_page_renderer.dart';

class TemplateFullScreenView extends StatefulWidget {
  final List<List<LayerModel>> parsedPages;
  final List<String> previewImages; // Fallback
  final int initialIndex;
  final Size designCanvasSize;
  final bool preserveTypography;

  const TemplateFullScreenView({
    super.key,
    required this.parsedPages,
    required this.previewImages,
    this.initialIndex = 0,
    this.designCanvasSize = const Size(3, 4),
    this.preserveTypography = false,
  });

  @override
  State<TemplateFullScreenView> createState() => _TemplateFullScreenViewState();
}

class _TemplateFullScreenViewState extends State<TemplateFullScreenView> {
  late PageController _pageController;
  late int _currentIndex;

  Widget _imageWidget(String rawUrl) {
    final trimmed = rawUrl.trim();
    final bundledAsset = bundledTemplateAssetPath(trimmed);
    if (bundledAsset != null) {
      return Image.asset(
        bundledAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _imageError(),
      );
    }
    if (trimmed.startsWith('asset:')) {
      return Image.asset(
        trimmed.substring('asset:'.length),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _imageError(),
      );
    }
    return Image.network(
      imageUrlByVariant(trimmed, variant: ImageVariant.detail),
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: CircularProgressIndicator(color: kIsWeb ? WebPalette.of(context).brand : Colors.white),
        );
      },
      errorBuilder: (_, __, ___) => _imageError(),
    );
  }

  Widget _imageError() => Container(
    color: kIsWeb ? WebPalette.of(context).canvas : SnapFitColors.deepCharcoal,
    alignment: Alignment.center,
    child: Icon(
      Icons.photo_outlined,
      color: kIsWeb ? WebPalette.of(context).muted : SnapFitStylePalette.charcoal,
      size: 36,
    ),
  );

  Color? _parseHexColor(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    var hex = value.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  Color _inferredTemplateSurfaceColor(List<LayerModel>? layers) {
    if (layers == null || layers.isEmpty) {
      return Colors.white;
    }

    final canvasW = widget.designCanvasSize.width <= 0
        ? 1.0
        : widget.designCanvasSize.width;
    final canvasH = widget.designCanvasSize.height <= 0
        ? 1.0
        : widget.designCanvasSize.height;

    LayerModel? best;
    double bestScore = -1;

    for (final layer in layers) {
      if (layer.type != LayerType.decoration) continue;
      final fill = _parseHexColor(layer.decorationFillColor);
      if (fill == null || fill.opacity <= 0.02) continue;

      final areaScore = (layer.width * layer.height) / (canvasW * canvasH);
      if (areaScore < 0.82) continue;
      final zBonus = (1000 - layer.zIndex).clamp(0, 1000) / 1000.0;
      final score = areaScore * 10 + zBonus;
      if (score > bestScore) {
        best = layer;
        bestScore = score;
      }
    }

    return _parseHexColor(best?.decorationFillColor) ?? Colors.white;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Total pages is max of parsed or preview
    final totalCount = widget.parsedPages.isNotEmpty
        ? widget.parsedPages.length
        : widget.previewImages.length;

    final safeAspect = widget.designCanvasSize.height > 0
        ? (widget.designCanvasSize.width / widget.designCanvasSize.height)
              .clamp(0.6, 1.8)
        : 0.75;

    if (kIsWeb) return _webViewer(totalCount, safeAspect.toDouble());
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: totalCount,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return Center(
                child: AspectRatio(
                  aspectRatio: safeAspect,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Render Parsed Page
                        if (index < widget.parsedPages.length) {
                          return ColoredBox(
                            color: _inferredTemplateSurfaceColor(
                              widget.parsedPages[index],
                            ),
                            child: TemplatePageRenderer(
                              layers: widget.parsedPages[index],
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              designCanvasSize: widget.designCanvasSize,
                              preserveTypography: widget.preserveTypography,
                              showCanvasChrome: false,
                            ),
                          );
                        }
                        // Fallback Image
                        if (index < widget.previewImages.length) {
                          return _imageWidget(widget.previewImages[index]);
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          // Close Button
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: MediaQuery.paddingOf(context).right + 12,
            child: IconButton(
              tooltip: '닫기',
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                foregroundColor: Colors.white,
                fixedSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.close, size: 24),
            ),
          ),

          // Page Indicator
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            left: MediaQuery.paddingOf(context).left,
            right: MediaQuery.paddingOf(context).right,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${totalCount == 0 ? 0 : _currentIndex + 1} / $totalCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _webPage(int index, double aspect) => AspectRatio(
    aspectRatio: aspect,
    child: LayoutBuilder(builder: (context, bounds) {
      if (index < widget.parsedPages.length) return ColoredBox(
        color: _inferredTemplateSurfaceColor(widget.parsedPages[index]),
        child: TemplatePageRenderer(
          layers: widget.parsedPages[index],
          width: bounds.maxWidth,
          height: bounds.maxHeight,
          designCanvasSize: widget.designCanvasSize,
          preserveTypography: widget.preserveTypography,
          showCanvasChrome: false,
        ),
      );
      if (index < widget.previewImages.length) return _imageWidget(widget.previewImages[index]);
      return const Center(child: Text('표시할 페이지가 없습니다.'));
    }),
  );

  Widget _webViewer(int count, double aspect) {
    final current = count == 0 ? 0 : _currentIndex.clamp(0, count - 1).toInt();
    void select(int index) { if (index >= 0 && index < count) setState(() => _currentIndex = index); }
    return SnapFitWebShell(
      title: '템플릿 미리보기',
      workspace: true,
      showNavigation: false,
      actions: [TextButton.icon(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close, size: 18), label: const Text('상세로 돌아가기'))],
      child: LayoutBuilder(builder: (context, bounds) {
        final wide = bounds.maxWidth >= 900;
        final stage = ColoredBox(color: WebPalette.of(context).canvas, child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), child: Row(children: [
            Expanded(child: Text(current == 0 ? '표지' : '내지 $current쪽', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            Text('전체 $count페이지', style: TextStyle(fontSize: 12, color: WebPalette.of(context).muted)),
          ])),
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: LayoutBuilder(builder: (context, stage) {
            final width = math.max(1.0, math.min(stage.maxWidth, stage.maxHeight * aspect));
            return InteractiveViewer(minScale: .75, maxScale: 3, child: Center(child: SizedBox(width: width, child: _webPage(current, aspect))));
          }))),
          Padding(padding: const EdgeInsets.only(bottom: 20), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: current > 0 ? () => select(current - 1) : null, tooltip: '이전 페이지', icon: const Icon(Icons.chevron_left)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('${count == 0 ? 0 : current + 1} / $count')),
            IconButton(onPressed: current + 1 < count ? () => select(current + 1) : null, tooltip: '다음 페이지', icon: const Icon(Icons.chevron_right)),
          ])),
        ]));
        if (!wide) return Column(children: [
          if (count > 0) Container(color: WebPalette.of(context).surface, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: DropdownButton<int>(
            value: current, isExpanded: true, underline: const SizedBox.shrink(),
            items: [for (var index = 0; index < count; index++) DropdownMenuItem(value: index, child: Text(index == 0 ? '표지' : '내지 $index쪽'))],
            onChanged: (index) { if (index != null) select(index); },
          )),
          Expanded(child: stage),
        ]);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 160, child: ColoredBox(color: WebPalette.of(context).surface, child: ListView.builder(
            padding: const EdgeInsets.all(16), itemCount: count,
            itemBuilder: (context, index) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextButton(
              onPressed: () => select(index),
              style: TextButton.styleFrom(
                backgroundColor: current == index ? WebPalette.of(context).softBrand : Colors.transparent,
                foregroundColor: current == index ? WebPalette.of(context).brandInk : WebPalette.of(context).muted,
                padding: const EdgeInsets.all(10),
              ),
              child: Column(children: [
                SizedBox(width: 82, child: ExcludeSemantics(child: _webPage(index, aspect))),
                const SizedBox(height: 8),
                Text(index == 0 ? '표지' : '$index쪽', style: const TextStyle(fontSize: 11)),
              ]),
            )),
          ))),
          VerticalDivider(width: 1, color: WebPalette.of(context).line),
          Expanded(child: stage),
        ]);
      }),
    );
  }
}
