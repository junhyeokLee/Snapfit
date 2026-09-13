import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import '../../../domain/entities/layer.dart';

/// Read-only document inspection. It never changes layers or assigns photos.
class CreationDocumentPreview extends StatefulWidget {
  const CreationDocumentPreview({
    super.key,
    required this.pages,
    required this.canvas,
    this.preserveTypography = false,
    this.pageKeyPrefix = 'creation_preview_page_',
    this.initialPage = 0,
    this.onPageChanged,
    this.inspection = false,
  });

  final List<List<LayerModel>> pages;
  final Size canvas;
  final bool preserveTypography;
  final String pageKeyPrefix;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;
  final bool inspection;

  @override
  State<CreationDocumentPreview> createState() =>
      _CreationDocumentPreviewState();
}

class _CreationDocumentPreviewState extends State<CreationDocumentPreview> {
  late int _page = _bounded(widget.initialPage);
  late List<GlobalKey> _thumbnailKeys = _keys();
  final _transform = TransformationController();
  final _viewportKey = GlobalKey();
  double _drag = 0;
  int _direction = 1;
  Size? _viewportSize;
  bool? _wide;

  int _bounded(int page) => page.clamp(0, math.max(0, widget.pages.length - 1));
  List<GlobalKey> _keys() =>
      List.generate(widget.pages.length, (_) => GlobalKey());
  double get _zoom => _transform.value.getMaxScaleOnAxis();

  @override
  void didUpdateWidget(covariant CreationDocumentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pages != widget.pages || oldWidget.canvas != widget.canvas) {
      _page = _bounded(widget.initialPage);
      _thumbnailKeys = _keys();
      _transform.value = Matrix4.identity();
      _revealSelection();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.inspection || _thumbnailKeys.isEmpty) return;
      final target = _thumbnailKeys[_page].currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: .5,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
      );
    });
  }

  void _go(int target) {
    target = _bounded(target);
    if (_page == target) return;
    setState(() {
      _direction = target > _page ? 1 : -1;
      _page = target;
      _transform.value = Matrix4.identity();
    });
    widget.onPageChanged?.call(_page);
    _revealSelection();
  }

  List<int> _indices(bool wide) {
    final first = wide && _page > 0 ? ((_page - 1) ~/ 2) * 2 + 1 : _page;
    return [
      first,
      if (wide && first > 0 && first + 1 < widget.pages.length) first + 1,
    ];
  }

  void _move(int delta, List<int> indices) =>
      _go(delta > 0 ? indices.last + 1 : indices.first - 1);

  Future<void> _inspect(int page) async {
    var selected = page;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: SnapFitColors.backgroundOf(context),
          appBar: AppBar(
            backgroundColor: SnapFitColors.backgroundOf(context),
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: '확대 보기 닫기',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
            title: const Text('디자인 미리보기', style: TextStyle(fontSize: 16)),
          ),
          body: SafeArea(
            top: false,
            child: CreationDocumentPreview(
              pages: widget.pages,
              canvas: widget.canvas,
              preserveTypography: widget.preserveTypography,
              initialPage: page,
              inspection: true,
              onPageChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    if (mounted) _go(selected);
  }

  void _setZoom(double value, {Offset? anchor}) {
    final size = _viewportKey.currentContext?.size;
    if (size == null) return;
    final scale = value.clamp(1.0, 4.0);
    final center = anchor ?? size.center(Offset.zero);
    final scene = _transform.toScene(center);
    _transform.value = scale == 1
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(
              center.dx - scene.dx * scale,
              center.dy - scene.dy * scale,
              0,
              1,
            )
            ..scaleByDouble(scale, scale, 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return const Center(child: Text('미리볼 페이지가 없어요'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            !widget.inspection &&
            constraints.maxWidth >= 600 &&
            constraints.maxWidth > constraints.maxHeight;
        if (_wide != wide) {
          _wide = wide;
          _revealSelection();
        }
        final indices = _indices(wide);
        final content = Column(
          children: [
            Expanded(child: _stage(indices)),
            _navigation(indices),
          ],
        );
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _move(-1, indices),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _move(1, indices),
          },
          child: Focus(
            autofocus: true,
            child: wide
                ? Row(
                    children: [
                      Expanded(child: content),
                      SizedBox(width: 108, child: _rail(indices, wide: true)),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: content),
                      if (!widget.inspection)
                        SizedBox(
                          height:
                              88 + MediaQuery.textScalerOf(context).scale(16),
                          child: _rail(indices, wide: false),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _stage(List<int> indices) {
    final stageColor = SnapFitColors.isDark(context)
        ? const Color(0xFF222626)
        : const Color(0xFFEEF1F0);
    return ColoredBox(
      color: stageColor,
      child: LayoutBuilder(
        builder: (context, area) {
          final viewport = Size(area.maxWidth, area.maxHeight);
          if (_viewportSize != viewport) {
            _viewportSize = viewport;
            // Reset only the viewing transform on rotation, never the page.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _transform.value = Matrix4.identity();
            });
          }
          final scale = math.max(
            .001,
            math.min(
              math.max(1, area.maxWidth - 40) /
                  (widget.canvas.width * indices.length),
              math.max(1, area.maxHeight - 32) / widget.canvas.height,
            ),
          );
          Widget page(int index) => Semantics(
            // Recreate web hit bounds when the physical format or viewport changes.
            key: ValueKey((index, widget.canvas, scale)),
            container: true,
            label: index == 0 ? '표지 미리보기' : '$index쪽 미리보기',
            button: !widget.inspection,
            child: GestureDetector(
              onTap: widget.inspection ? null : () => _inspect(index),
              child: _render(index, widget.canvas.width * scale),
            ),
          );
          final book = Center(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0x19000000),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                key: const ValueKey('creation_document_canvas'),
                mainAxisSize: MainAxisSize.min,
                children: [for (final index in indices) page(index)],
              ),
            ),
          );
          Widget viewportChild;
          if (widget.inspection) {
            Offset? doubleTapPosition;
            viewportChild = GestureDetector(
              onDoubleTapDown: (details) =>
                  doubleTapPosition = details.localPosition,
              onDoubleTap: () =>
                  _setZoom(_zoom > 1.01 ? 1 : 2, anchor: doubleTapPosition),
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 4,
                child: SizedBox.expand(child: book),
              ),
            );
          } else {
            viewportChild = AnimatedSwitcher(
              key: ValueKey(viewport),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween(
                        begin: Offset(.025 * _direction, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(indices.join('-')),
                child: book,
              ),
            );
          }
          return ClipRect(
            key: const ValueKey('creation_document_stage'),
            child: GestureDetector(
              key: _viewportKey,
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: widget.inspection
                  ? null
                  : (_) => _drag = 0,
              onHorizontalDragUpdate: widget.inspection
                  ? null
                  : (d) => _drag += d.delta.dx,
              onHorizontalDragEnd: widget.inspection
                  ? null
                  : (_) {
                      if (_drag.abs() >= 40) _move(_drag < 0 ? 1 : -1, indices);
                    },
              onHorizontalDragCancel: widget.inspection
                  ? null
                  : () => _drag = 0,
              child: viewportChild,
            ),
          );
        },
      ),
    );
  }

  Widget _render(int index, double width) => RepaintBoundary(
    child: ColoredBox(
      color: Colors.white,
      child: TemplatePageRenderer(
        layers: widget.pages[index],
        width: width,
        height: width / widget.canvas.aspectRatio,
        designCanvasSize: widget.canvas,
        preserveTypography: widget.preserveTypography,
        // A portrait crop needs more source pixels than its displayed width.
        imageDecodeWidth:
            (math.max(width, width / widget.canvas.aspectRatio) *
                    MediaQuery.devicePixelRatioOf(context) *
                    (widget.inspection ? 4 : 2))
                .ceil()
                .clamp(64, 2048),
        showCanvasChrome: false,
      ),
    ),
  );

  Widget _navigation(List<int> indices) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        IconButton(
          tooltip: '이전 페이지',
          onPressed: indices.first > 0 ? () => _move(-1, indices) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              indices.first == 0
                  ? '표지'
                  : '${indices.join('–')} / ${widget.pages.length - 1}쪽',
              key: const ValueKey('creation_document_position'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: SnapFitColors.textSecondaryOf(context),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '다음 페이지',
          onPressed: indices.last < widget.pages.length - 1
              ? () => _move(1, indices)
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        if (!widget.inspection)
          IconButton(
            tooltip: '페이지 확대',
            onPressed: () => _inspect(_page),
            icon: const Icon(Icons.open_in_full_rounded, size: 20),
          )
        else
          ValueListenableBuilder<Matrix4>(
            valueListenable: _transform,
            builder: (context, _, child) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '축소',
                  onPressed: _zoom > 1.01 ? () => _setZoom(_zoom - .5) : null,
                  icon: const Icon(Icons.remove_rounded, size: 20),
                ),
                IconButton(
                  tooltip: '화면에 맞추기',
                  onPressed: () => _setZoom(1),
                  icon: const Icon(Icons.fit_screen_rounded, size: 20),
                ),
                IconButton(
                  tooltip: '확대',
                  onPressed: _zoom < 3.99 ? () => _setZoom(_zoom + .5) : null,
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _rail(List<int> indices, {required bool wide}) {
    final ink = SnapFitColors.textPrimaryOf(context);
    final children = <Widget>[
      for (var index = 0; index < widget.pages.length; index++)
        Padding(
          key: _thumbnailKeys[index],
          padding: const EdgeInsets.all(4),
          child: Semantics(
            button: true,
            selected: indices.contains(index),
            label: index == 0 ? '표지 선택' : '$index쪽 선택',
            child: InkWell(
              key: ValueKey('${widget.pageKeyPrefix}$index'),
              onTap: () => _go(index),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 80,
                padding: const EdgeInsets.fromLTRB(5, 5, 5, 3),
                decoration: BoxDecoration(
                  color: indices.contains(index)
                      ? ink.withValues(alpha: .06)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    width: 2,
                    color: indices.contains(index) ? ink : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 66,
                        height: 46,
                        child: Center(
                          child: _render(
                            index,
                            math.min(66, 46 * widget.canvas.aspectRatio),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      index == 0 ? '표지' : '$index',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
    return SingleChildScrollView(
      key: const ValueKey('creation_document_rail'),
      scrollDirection: wide ? Axis.vertical : Axis.horizontal,
      padding: const EdgeInsets.all(4),
      child: wide
          ? Column(children: children)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
    );
  }
}
