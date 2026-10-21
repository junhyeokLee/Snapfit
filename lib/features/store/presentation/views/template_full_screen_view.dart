import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
  final ValueChanged<int>? onPageChanged;

  const TemplateFullScreenView({
    super.key,
    required this.parsedPages,
    required this.previewImages,
    this.initialIndex = 0,
    this.designCanvasSize = const Size(3, 4),
    this.preserveTypography = false,
    this.onPageChanged,
  });

  @override
  State<TemplateFullScreenView> createState() => _TemplateFullScreenViewState();
}

class _TemplateFullScreenViewState extends State<TemplateFullScreenView> {
  late PageController _pageController;
  late int _currentIndex;
  final _webTransform = TransformationController();
  Size _webStageSize = Size.zero;
  final _nativeTransform = TransformationController();
  Size _nativeStageSize = Size.zero;
  Rect _nativePageRect = Rect.zero;
  bool _nativeZoomed = false;
  double _nativeGestureScale = 1;
  Offset _nativeGestureAnchor = Offset.zero;

  void _nativeTransformationChanged() {
    final zoomed = _nativeTransform.value.getMaxScaleOnAxis() > 1.001;
    if (mounted && zoomed != _nativeZoomed) {
      setState(() => _nativeZoomed = zoomed);
    }
  }

  void _resetNativeZoom() => _nativeTransform.value = Matrix4.identity();

  void _setNativeTransform(double scale, Offset translation) {
    final boundedScale = scale.clamp(1.0, 4.0);
    double boundAxis(
      double requested,
      double start,
      double end,
      double viewport,
    ) {
      final scaledExtent = (end - start) * boundedScale;
      if (scaledExtent <= viewport) {
        return (viewport - scaledExtent) / 2 - start * boundedScale;
      }
      return requested.clamp(
        viewport - end * boundedScale,
        -start * boundedScale,
      );
    }

    // The artwork is letterboxed within the stage. Bound the actual page,
    // otherwise a large black margin can be panned over the entire viewport.
    final dx = boundAxis(
      translation.dx,
      _nativePageRect.left,
      _nativePageRect.right,
      _nativeStageSize.width,
    );
    final dy = boundAxis(
      translation.dy,
      _nativePageRect.top,
      _nativePageRect.bottom,
      _nativeStageSize.height,
    );
    _nativeTransform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(boundedScale, boundedScale, 1, 1);
  }

  void _zoomNativeAt(Offset focalPoint, double scale) {
    final scene = _nativeTransform.toScene(focalPoint);
    final boundedScale = scale.clamp(1.0, 4.0);
    _setNativeTransform(boundedScale, focalPoint - scene * boundedScale);
  }

  void _startNativeInteraction(ScaleStartDetails details) {
    _nativeGestureScale = _nativeTransform.value.getMaxScaleOnAxis();
    _nativeGestureAnchor = _nativeTransform.toScene(details.localFocalPoint);
  }

  void _updateNativeInteraction(ScaleUpdateDetails details) {
    final scale = (_nativeGestureScale * details.scale).clamp(1.0, 4.0);
    _setNativeTransform(
      scale,
      details.localFocalPoint - _nativeGestureAnchor * scale,
    );
  }

  void _selectNativePage(int index) {
    final count = widget.parsedPages.isNotEmpty
        ? widget.parsedPages.length
        : widget.previewImages.length;
    if (index < 0 || index >= count || !_pageController.hasClients) return;
    _resetNativeZoom();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _resetWebZoom() =>
      setState(() => _webTransform.value = Matrix4.identity());

  void _zoomWebPage(double factor) {
    final previous = _webTransform.value.getMaxScaleOnAxis();
    final next = (previous * factor).clamp(.75, 3.0);
    final ratio = next / previous;
    final center = _webStageSize.center(Offset.zero);
    setState(() {
      _webTransform.value = Matrix4.identity()
        ..translate(center.dx, center.dy)
        ..scale(ratio)
        ..translate(-center.dx, -center.dy)
        ..multiply(_webTransform.value);
    });
  }

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
          child: CircularProgressIndicator(
            color: kIsWeb ? WebPalette.of(context).brand : Colors.white,
          ),
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
      color: kIsWeb
          ? WebPalette.of(context).muted
          : SnapFitStylePalette.charcoal,
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
    _nativeTransform.addListener(_nativeTransformationChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _webTransform.dispose();
    _nativeTransform.removeListener(_nativeTransformationChanged);
    _nativeTransform.dispose();
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
            key: const ValueKey('template-native-page-view'),
            controller: _pageController,
            physics: _nativeZoomed
                ? const NeverScrollableScrollPhysics()
                : null,
            itemCount: totalCount,
            onPageChanged: (index) {
              _resetNativeZoom();
              setState(() => _currentIndex = index);
              widget.onPageChanged?.call(index);
            },
            itemBuilder: (context, index) =>
                _nativePage(index, safeAspect.toDouble()),
          ),

          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: MediaQuery.paddingOf(context).left + 12,
            right: MediaQuery.paddingOf(context).right + 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: _nativeZoomControls()),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.close, size: 24),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            left: MediaQuery.paddingOf(context).left + 12,
            right: MediaQuery.paddingOf(context).right + 12,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const ValueKey('template-native-previous'),
                      tooltip: '이전 페이지',
                      onPressed: _currentIndex > 0
                          ? () => _selectNativePage(_currentIndex - 1)
                          : null,
                      color: Colors.white,
                      disabledColor: Colors.white38,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Flexible(
                      child: Text(
                        '${_currentIndex + 1} / $totalCount',
                        key: const ValueKey('template-native-page-position'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('template-native-next'),
                      tooltip: '다음 페이지',
                      onPressed: _currentIndex + 1 < totalCount
                          ? () => _selectNativePage(_currentIndex + 1)
                          : null,
                      color: Colors.white,
                      disabledColor: Colors.white38,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nativePage(int index, double aspect) => LayoutBuilder(
    builder: (context, bounds) {
      final viewport = bounds.biggest;
      final fittedSize = applyBoxFit(
        BoxFit.contain,
        Size(aspect, 1),
        viewport,
      ).destination;
      _nativePageRect = Alignment.center.inscribe(
        fittedSize,
        Offset.zero & viewport,
      );
      if (_nativeStageSize != viewport) {
        _nativeStageSize = viewport;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _resetNativeZoom();
        });
      }
      Offset? doubleTapPosition;
      return RawGestureDetector(
        key: ValueKey('template-native-zoom-stage-$index'),
        behavior: HitTestBehavior.opaque,
        gestures: {
          _TemplatePageZoomGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                _TemplatePageZoomGestureRecognizer
              >(
                _TemplatePageZoomGestureRecognizer.new,
                (recognizer) => recognizer
                  ..allowSinglePointerPan = _nativeZoomed
                  ..onStart = _startNativeInteraction
                  ..onUpdate = _updateNativeInteraction,
              ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) =>
              doubleTapPosition = details.localPosition,
          onDoubleTap: () {
            if (_nativeZoomed) {
              _resetNativeZoom();
            } else {
              _zoomNativeAt(
                doubleTapPosition ?? viewport.center(Offset.zero),
                2,
              );
            }
          },
          child: ClipRect(
            child: ValueListenableBuilder<Matrix4>(
              valueListenable: _nativeTransform,
              child: SizedBox.expand(
                child: Center(child: _webPage(index, aspect)),
              ),
              builder: (context, transform, child) => Transform(
                key: ValueKey('template-native-page-transform-$index'),
                transform: transform,
                child: child,
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _nativeZoomControls() => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(8),
    ),
    child: ValueListenableBuilder<Matrix4>(
      valueListenable: _nativeTransform,
      builder: (context, transform, _) {
        final scale = transform.getMaxScaleOnAxis();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('template-native-zoom-in'),
              tooltip: '확대',
              onPressed: scale < 3.999
                  ? () => _zoomNativeAt(
                      _nativeStageSize.center(Offset.zero),
                      scale * 1.5,
                    )
                  : null,
              color: Colors.white,
              disabledColor: Colors.white38,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.add),
            ),
            Flexible(
              child: Text(
                '${(scale * 100).round()}%',
                key: const ValueKey('template-native-zoom-value'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('template-native-zoom-reset'),
              tooltip: '화면에 맞추기',
              onPressed: _nativeZoomed ? _resetNativeZoom : null,
              color: Colors.white,
              disabledColor: Colors.white38,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.fit_screen),
            ),
          ],
        );
      },
    ),
  );

  Widget _webPage(int index, double aspect) => AspectRatio(
    aspectRatio: aspect,
    child: LayoutBuilder(
      builder: (context, bounds) {
        if (index < widget.parsedPages.length)
          return ColoredBox(
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
        if (index < widget.previewImages.length)
          return _imageWidget(widget.previewImages[index]);
        return const Center(child: Text('표시할 페이지가 없습니다.'));
      },
    ),
  );

  Widget _webViewer(int count, double aspect) {
    final palette = WebPalette.of(context);
    final current = count == 0 ? 0 : _currentIndex.clamp(0, count - 1).toInt();
    void select(int index) {
      if (index < 0 || index >= count) return;
      setState(() {
        _currentIndex = index;
        _webTransform.value = Matrix4.identity();
      });
      widget.onPageChanged?.call(index);
    }

    return SnapFitWebShell(
      title: '템플릿 미리보기',
      workspace: true,
      showNavigation: false,
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('상세로 돌아가기'),
        ),
      ],
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              select(current - 1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              select(current + 1),
          const SingleActivator(LogicalKeyboardKey.minus): () =>
              _zoomWebPage(1 / 1.2),
          const SingleActivator(LogicalKeyboardKey.equal): () =>
              _zoomWebPage(1.2),
          const SingleActivator(LogicalKeyboardKey.digit0): _resetWebZoom,
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, bounds) {
              final wide = bounds.maxWidth >= 900;
              final stage = ColoredBox(
                color: palette.canvas,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            count == 0
                                ? '미리보기'
                                : current == 0
                                ? '표지'
                                : '내지 $current쪽',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _zoomWebPage(1 / 1.2),
                                tooltip: '축소 (-)',
                                icon: const Icon(Icons.remove, size: 19),
                              ),
                              TextButton(
                                onPressed: _resetWebZoom,
                                child: Text(
                                  '${(_webTransform.value.getMaxScaleOnAxis() * 100).round()}%',
                                ),
                              ),
                              IconButton(
                                onPressed: () => _zoomWebPage(1.2),
                                tooltip: '확대 (+)',
                                icon: const Icon(Icons.add, size: 19),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: LayoutBuilder(
                          builder: (context, stageBounds) {
                            _webStageSize = Size(
                              stageBounds.maxWidth,
                              stageBounds.maxHeight,
                            );
                            final width = math.max(
                              1.0,
                              math.min(
                                stageBounds.maxWidth,
                                stageBounds.maxHeight * aspect,
                              ),
                            );
                            return InteractiveViewer(
                              transformationController: _webTransform,
                              minScale: .75,
                              maxScale: 3,
                              onInteractionEnd: (_) => setState(() {}),
                              child: Center(
                                child: SizedBox(
                                  width: width,
                                  child: _webPage(current, aspect),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: current > 0
                                ? () => select(current - 1)
                                : null,
                            tooltip: '이전 페이지 (←)',
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                '${count == 0 ? 0 : current + 1} / $count',
                                maxLines: 1,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: current + 1 < count
                                ? () => select(current + 1)
                                : null,
                            tooltip: '다음 페이지 (→)',
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              if (!wide)
                return Column(
                  children: [
                    if (count > 0)
                      Container(
                        color: palette.surface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: DropdownButton<int>(
                          value: current,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (var index = 0; index < count; index++)
                              DropdownMenuItem(
                                value: index,
                                child: Text(index == 0 ? '표지' : '내지 $index쪽'),
                              ),
                          ],
                          onChanged: (index) {
                            if (index != null) select(index);
                          },
                        ),
                      ),
                    Expanded(child: stage),
                  ],
                );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 160,
                    child: ColoredBox(
                      color: palette.surface,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: count,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextButton(
                            onPressed: () => select(index),
                            style: TextButton.styleFrom(
                              backgroundColor: current == index
                                  ? palette.softBrand
                                  : Colors.transparent,
                              foregroundColor: current == index
                                  ? palette.brandInk
                                  : palette.muted,
                              padding: const EdgeInsets.all(10),
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 82,
                                  child: ExcludeSemantics(
                                    child: _webPage(index, aspect),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  index == 0 ? '표지' : '$index쪽',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  VerticalDivider(width: 1, color: palette.line),
                  Expanded(child: stage),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Single-finger movement at 1x belongs to PageView. A pinch can still win the
/// gesture arena, and an already magnified page accepts single-finger panning.
class _TemplatePageZoomGestureRecognizer extends ScaleGestureRecognizer {
  bool allowSinglePointerPan = false;
  final _pointers = <int>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointers.add(event.pointer);
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is! PointerMoveEvent ||
        allowSinglePointerPan ||
        _pointers.length > 1) {
      super.handleEvent(event);
      // Claim a pinch before a single pointer crosses PageView's drag slop.
      // Wait until super has registered both locations for the start callback.
      if (event is PointerDownEvent && _pointers.length > 1) {
        resolve(GestureDisposition.accepted);
      }
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    _pointers.remove(pointer);
  }

  @override
  void dispose() {
    _pointers.clear();
    super.dispose();
  }
}
