import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album.dart';
import 'home_album_cover_thumbnail.dart';

/// Lazy cover previews; the selected album stays visible across rotation.
class HomeAlbumShelf extends StatefulWidget {
  const HomeAlbumShelf({
    super.key,
    required this.albums,
    required this.selectedIndex,
    required this.onSelected,
    this.grid = false,
  });

  final List<Album> albums;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool grid;

  @override
  State<HomeAlbumShelf> createState() => _HomeAlbumShelfState();
}

class _HomeAlbumShelfState extends State<HomeAlbumShelf> {
  final _scroll = ScrollController();
  double _extent = 0;
  double _viewport = 0;
  bool? _grid;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeAlbumShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.albums.length != widget.albums.length) {
      _queueAlignment(animate: true);
    }
  }

  void _queueAlignment({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _extent <= 0) return;
      final slot = widget.grid
          ? widget.selectedIndex ~/ 2
          : widget.selectedIndex;
      final target = (16 + (slot + .5) * _extent - _viewport / 2).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      if ((target - _scroll.offset).abs() < 1) return;
      if (animate) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 12.0;
      const padding = 16.0;
      final side = widget.grid
          ? math
                .min(
                  (constraints.maxWidth - padding * 2 - gap) / 2,
                  (constraints.maxHeight - 72) / 2,
                )
                .clamp(44.0, 92.0)
          : ((constraints.maxWidth - padding * 2 - gap * 3) / 4).clamp(
              44.0,
              92.0,
            );
      final extent = widget.grid ? side + 26 : side + gap;
      final viewport = widget.grid
          ? constraints.maxHeight
          : constraints.maxWidth;
      if (_grid != widget.grid || _extent != extent || _viewport != viewport) {
        _grid = widget.grid;
        _extent = extent;
        _viewport = viewport;
        _queueAlignment(animate: false);
      }
      Widget preview(BuildContext context, int index) => _ShelfPreview(
        key: ValueKey('home-shelf-album-${widget.albums[index].id}'),
        album: widget.albums[index],
        side: side,
        trailingGap: widget.grid ? 0 : gap,
        selected: index == widget.selectedIndex,
        onTap: () => widget.onSelected(index),
      );

      return widget.grid
          ? GridView.builder(
              key: const ValueKey('home-bookshelf-grid'),
              controller: _scroll,
              cacheExtent: extent,
              padding: const EdgeInsets.all(padding),
              itemCount: widget.albums.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: side + 14,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
              ),
              itemBuilder: preview,
            )
          : Center(
              child: SizedBox(
                width: math.min(
                  constraints.maxWidth,
                  widget.albums.length * extent + padding * 2 - gap,
                ),
                child: ListView.builder(
                  key: const ValueKey('home-bookshelf-strip'),
                  controller: _scroll,
                  cacheExtent: extent,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(
                    left: padding,
                    right: padding - gap,
                  ),
                  itemExtent: extent,
                  itemCount: widget.albums.length,
                  itemBuilder: preview,
                ),
              ),
            );
    },
  );
}

class _ShelfPreview extends StatelessWidget {
  const _ShelfPreview({
    super.key,
    required this.album,
    required this.side,
    required this.trailingGap,
    required this.selected,
    required this.onTap,
  });

  final Album album;
  final double side;
  final double trailingGap;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = album.title.trim().isEmpty ? '제목 없는 앨범' : album.title;
    final underlineWidth = side * math.min(1.0, album.physicalCoverSize.ratio);
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.only(right: trailingGap),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: side,
                  height: side,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: RepaintBoundary(
                      child: HomeAlbumCoverThumbnail(
                        key: ValueKey('home-shelf-cover-${album.id}'),
                        album: album,
                        height: side,
                        maxWidth: side,
                        showBookDepth: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  key: ValueKey('home-shelf-selection-${album.id}'),
                  duration: const Duration(milliseconds: 160),
                  width: underlineWidth,
                  height: 2,
                  color: selected ? SnapFitColors.accent : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
