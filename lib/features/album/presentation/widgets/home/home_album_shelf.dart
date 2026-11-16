import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';
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

  static double stripHeight(BuildContext context) =>
      94 + MediaQuery.textScalerOf(context).scale(11) * 1.45;

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
      final target = (20 + (slot + .5) * _extent - _viewport / 2).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      final distance = (target - _scroll.offset).abs();
      if (distance < 1) {
        // A rapid return can precede the first tick of an older animation.
        if (_scroll.position.isScrollingNotifier.value) _scroll.jumpTo(target);
        return;
      }
      if (animate &&
          distance <= _scroll.position.viewportDimension * 1.5 &&
          !SnapFitMotion.reduced(context) &&
          TickerMode.of(context)) {
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
      const gap = 8.0;
      const padding = 20.0;
      final labelHeight = MediaQuery.textScalerOf(context).scale(11) * 1.45;
      final itemWidth = widget.grid
          ? ((constraints.maxWidth - padding * 2 - gap) / 2).clamp(60.0, 96.0)
          : ((constraints.maxWidth - padding * 2 - gap * 3) / 4).clamp(
              60.0,
              96.0,
            );
      const coverHeight = 68.0;
      final itemHeight = coverHeight + labelHeight + 22;
      final extent = widget.grid ? itemHeight + gap : itemWidth + gap;
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
        width: itemWidth,
        coverHeight: coverHeight,
        trailingGap: widget.grid ? 0 : gap,
        selected: index == widget.selectedIndex,
        onTap: () => widget.onSelected(index),
      );

      return widget.grid
          ? GridView.builder(
              key: const ValueKey('home-bookshelf-grid'),
              controller: _scroll,
              cacheExtent: extent,
              addAutomaticKeepAlives: false,
              padding: const EdgeInsets.all(padding),
              itemCount: widget.albums.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: itemHeight,
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
                  addAutomaticKeepAlives: false,
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
    required this.width,
    required this.coverHeight,
    required this.trailingGap,
    required this.selected,
    required this.onTap,
  });

  final Album album;
  final double width, coverHeight;
  final double trailingGap;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = album.title.trim().isEmpty ? '제목 없는 앨범' : album.title;
    return Tooltip(
      message: label,
      child: Semantics(
        key: ValueKey('home-shelf-selection-${album.id}'),
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
            child: Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              decoration: BoxDecoration(
                color: selected
                    ? ExperienceFormStyle.selection(context)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: coverHeight,
                    width: double.infinity,
                    child: Center(
                      child: RepaintBoundary(
                        child: HomeAlbumCoverThumbnail(
                          key: ValueKey('home-shelf-cover-${album.id}'),
                          album: album,
                          height: coverHeight,
                          maxWidth: width - 12,
                          showBookDepth: true,
                          shadowScaleMultiplier: .35,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ExperienceFormStyle.text(
                      context,
                      11,
                      weight: selected ? FontWeight.w500 : FontWeight.w400,
                      secondary: !selected,
                    ).copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
