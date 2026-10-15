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
  });
  final String title;
  final PageController controller;
  final int currentPage, pageCount;
  final ValueChanged<int> onPageChanged;
  final Widget Function(BuildContext, int) pageBuilder;
  final VoidCallback onMore;
  @override
  State<ReaderPageGallery> createState() => _ReaderPageGalleryState();
}

class _ReaderPageGalleryState extends State<ReaderPageGallery> {
  final _pageViewKey = GlobalKey(debugLabel: 'reader-focus-pages');
  bool _zoomed = false;
  void _move(int delta) {
    final target = widget.currentPage + delta;
    if (target < 0 || target >= widget.pageCount) return;
    widget.controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  Widget _arrow(String name, int direction) => IconButton(
    tooltip: direction < 0 ? '이전 페이지' : '다음 페이지',
    onPressed:
        widget.currentPage + direction < 0 ||
            widget.currentPage + direction >= widget.pageCount
        ? null
        : () => _move(direction),
    icon: Transform.flip(
      flipX: direction < 0,
      child: const ExperienceIcon('ChevronRight', size: 21),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AlbumStageStyle.top(context),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight;
          final back = IconButton(
            tooltip: '앨범으로 돌아가기',
            onPressed: () => Navigator.pop(context),
            icon: const ExperienceIcon('ArrowLeft', size: 22),
          );
          final counter = Text(
            '${widget.currentPage + 1} / ${widget.pageCount}',
            key: const ValueKey('reader-focus-counter'),
            textAlign: TextAlign.center,
            style: ExperienceFormStyle.text(
              context,
              13,
              weight: FontWeight.w600,
            ),
          );
          final more = IconButton(
            tooltip: '페이지 메뉴',
            onPressed: widget.onMore,
            icon: const Icon(Icons.more_horiz_rounded, size: 24),
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
              onZoomChanged: (zoomed) {
                if (mounted && index == widget.currentPage)
                  setState(() => _zoomed = zoomed);
              },
              child: widget.pageBuilder(context, index),
            ),
          );
          final controls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _arrow('ChevronLeft', -1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: counter,
              ),
              _arrow('ChevronRight', 1),
            ],
          );
          if (wide)
            return Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: back,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: pages,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Column(
                    children: [
                      more,
                      const Spacer(),
                      counter,
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _arrow('ChevronLeft', -1),
                          _arrow('ChevronRight', 1),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            );
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
                          15,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    more,
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: pages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: controls,
              ),
            ],
          );
        },
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
  });
  final Widget child;
  final bool active;
  final ValueChanged<bool> onZoomChanged;
  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  final _transform = TransformationController();
  Offset _tap = Offset.zero;
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
  }

  @override
  void didUpdateWidget(_ZoomablePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active)
      _transform.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTapDown: (details) => _tap = details.localPosition,
    onDoubleTap: () => _transform.value = _zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(-_tap.dx, -_tap.dy, 0, 1)
            ..scaleByDouble(2, 2, 1, 1)),
    child: InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      panEnabled: _zoomed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(child: widget.child),
      ),
    ),
  );
}
