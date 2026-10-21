import 'package:flutter/material.dart';
import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';

/// A full-size page inspection surface, separate from the spread reader.
class ReaderPageGallery extends StatefulWidget {
  const ReaderPageGallery({
    super.key,
    required this.title,
    required this.controller,
    required this.currentPage,
    required this.pageCount,
    required this.onPageChanged,
    required this.pageBuilder,
    required this.onMore,
    this.onEdit,
  });
  final String title;
  final PageController controller;
  final int currentPage, pageCount;
  final ValueChanged<int> onPageChanged;
  final Widget Function(BuildContext, int) pageBuilder;
  final VoidCallback onMore;
  final VoidCallback? onEdit;
  @override
  State<ReaderPageGallery> createState() => _ReaderPageGalleryState();
}

class _ReaderPageGalleryState extends State<ReaderPageGallery> {
  // Retain the viewport and zoom states when the surrounding chrome rotates.
  final _pageViewKey = GlobalKey(debugLabel: 'reader-focus-pages');
  bool _zoomed = false;
  int _zoomRequest = 0;

  void _move(int delta) {
    final target = widget.currentPage + delta;
    if (target < 0 ||
        target >= widget.pageCount ||
        !widget.controller.hasClients)
      return;
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.controller.jumpToPage(target);
    } else {
      widget.controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Widget _arrow(int direction) => IconButton(
    tooltip: direction < 0 ? '이전 페이지' : '다음 페이지',
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    onPressed:
        widget.currentPage + direction < 0 ||
            widget.currentPage + direction >= widget.pageCount
        ? null
        : () => _move(direction),
    icon: Transform.flip(
      flipX: direction < 0,
      child: ExperienceIcon(
        'ChevronRight',
        size: 22,
        color: AlbumStageStyle.ink(context).withValues(
          alpha:
              widget.currentPage + direction < 0 ||
                  widget.currentPage + direction >= widget.pageCount
              ? .25
              : 1,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion(
    value: AlbumStageStyle.overlay(context),
    child: Scaffold(
      backgroundColor: AlbumStageStyle.top(context),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AlbumStageStyle.gradient(context)),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > box.maxHeight;
              final back = IconButton(
                tooltip: '앨범으로 돌아가기',
                onPressed: () => Navigator.pop(context),
                icon: const ExperienceIcon('ArrowLeft', size: 22),
              );
              final counter = Semantics(
                liveRegion: true,
                child: Text(
                  '${widget.pageCount == 0 ? 0 : widget.currentPage + 1} / ${widget.pageCount}',
                  key: const ValueKey('reader-focus-counter'),
                  textAlign: TextAlign.center,
                  style: ExperienceFormStyle.text(
                    context,
                    12,
                    weight: FontWeight.w600,
                  ),
                ),
              );
              final more = IconButton(
                tooltip: '페이지 메뉴',
                onPressed: widget.onMore,
                icon: const Icon(Icons.more_horiz_rounded, size: 24),
              );
              final zoom = IconButton(
                key: const ValueKey('reader-focus-zoom'),
                tooltip: _zoomed ? '페이지 맞춤' : '페이지 확대',
                onPressed: widget.pageCount == 0
                    ? null
                    : () => setState(() => _zoomRequest++),
                icon: ExperienceIcon(_zoomed ? 'Expand' : 'Search', size: 21),
              );
              final edit = IconButton(
                key: const ValueKey('reader-focus-edit'),
                tooltip: '현재 페이지 편집',
                onPressed: widget.onEdit,
                icon: const ExperienceIcon('Pencil', size: 21),
              );
              final pages = PageView.builder(
                key: _pageViewKey,
                controller: widget.controller,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: widget.pageCount,
                onPageChanged: (index) {
                  setState(() => _zoomed = false);
                  widget.onPageChanged(index);
                },
                itemBuilder: (context, index) => _ZoomablePage(
                  key: ValueKey('reader-focus-page-$index'),
                  active: widget.currentPage == index,
                  zoomRequest: _zoomRequest,
                  onZoomChanged: (zoomed) {
                    if (mounted && index == widget.currentPage)
                      setState(() => _zoomed = zoomed);
                  },
                  child: RepaintBoundary(
                    child: widget.pageBuilder(context, index),
                  ),
                ),
              );
              if (wide) {
                return Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Column(
                        children: [
                          back,
                          const Spacer(),
                          if (widget.onEdit != null) edit,
                          const Spacer(),
                          zoom,
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: pages,
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Column(
                        children: [
                          more,
                          const Spacer(),
                          _arrow(-1),
                          _arrow(1),
                          const Spacer(),
                          SizedBox(
                            height: 44,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: counter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        back,
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ExperienceFormStyle.text(
                              context,
                              14,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        zoom,
                        more,
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: pages,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        _arrow(-1),
                        Expanded(child: counter),
                        if (widget.onEdit != null) edit,
                        _arrow(1),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _ZoomablePage extends StatefulWidget {
  const _ZoomablePage({
    super.key,
    required this.child,
    required this.active,
    required this.onZoomChanged,
    required this.zoomRequest,
  });
  final Widget child;
  final bool active;
  final int zoomRequest;
  final ValueChanged<bool> onZoomChanged;
  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _motion;
  Animation<Matrix4>? _animation;
  Offset? _tap;
  bool _zoomed = false;

  void _update() {
    final next = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (next == _zoomed) return;
    _zoomed = next;
    widget.onZoomChanged(next);
  }

  @override
  void initState() {
    super.initState();
    _transform.addListener(_update);
    _motion =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          if (_animation != null) _transform.value = _animation!.value;
        });
  }

  void _toggle([Offset? point]) {
    final anchor =
        point ?? Offset(context.size!.width / 2, context.size!.height / 2);
    final target = _zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1)
            ..scaleByDouble(2, 2, 1, 1));
    _motion.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      _transform.value = target;
      return;
    }
    _animation = Matrix4Tween(
      begin: _transform.value.clone(),
      end: target,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_motion);
    _motion.forward(from: 0);
  }

  @override
  void didUpdateWidget(_ZoomablePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active) {
      _motion.stop();
      _transform.value = Matrix4.identity();
    }
    if (widget.active && oldWidget.zoomRequest != widget.zoomRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) _toggle();
      });
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTapDown: (details) => _tap = details.localPosition,
    onDoubleTap: () => _toggle(_tap),
    child: InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      panEnabled: _zoomed,
      onInteractionStart: (_) => _motion.stop(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: widget.child),
      ),
    ),
  );
}
