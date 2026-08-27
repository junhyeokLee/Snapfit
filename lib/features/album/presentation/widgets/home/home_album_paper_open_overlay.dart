import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/album.dart';
import '../../../domain/entities/album_page.dart';
import '../../controllers/layer_builder.dart';
import '../reader/album_reader_page_content.dart';
import 'home_album_cover_thumbnail.dart';

class HomeAlbumPaperOpenOverlayController {
  HomeAlbumPaperOpenOverlayController._({
    required OverlayEntry entry,
    required this.opened,
    required ValueNotifier<bool> visible,
  }) : _entry = entry,
       _visible = visible;

  final OverlayEntry _entry;
  final ValueNotifier<bool> _visible;
  final Future<void> opened;

  Future<void> dismiss() async {
    if (!_entry.mounted) return;
    _visible.value = false;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (_entry.mounted) {
      _entry.remove();
    }
    _visible.dispose();
  }
}

class HomeAlbumPaperOpenOverlay {
  const HomeAlbumPaperOpenOverlay._();

  static HomeAlbumPaperOpenOverlayController? show(
    BuildContext context, {
    required Album album,
    required List<AlbumPage> pages,
    required LayerBuilder previewBuilder,
    required Size baseCanvasSize,
    required String fallbackAsset,
    required bool opensToSpread,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final visible = ValueNotifier<bool>(true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _HomeAlbumPaperOpenOverlayView(
        album: album,
        pages: pages,
        previewBuilder: previewBuilder,
        baseCanvasSize: baseCanvasSize,
        fallbackAsset: fallbackAsset,
        opensToSpread: opensToSpread,
        visible: visible,
      ),
    );
    overlay.insert(entry);

    return HomeAlbumPaperOpenOverlayController._(
      entry: entry,
      visible: visible,
      opened: Future<void>.delayed(const Duration(milliseconds: 1180)),
    );
  }
}

class _HomeAlbumPaperOpenOverlayView extends StatefulWidget {
  const _HomeAlbumPaperOpenOverlayView({
    required this.album,
    required this.pages,
    required this.previewBuilder,
    required this.baseCanvasSize,
    required this.fallbackAsset,
    required this.opensToSpread,
    required this.visible,
  });

  final Album album;
  final List<AlbumPage> pages;
  final LayerBuilder previewBuilder;
  final Size baseCanvasSize;
  final String fallbackAsset;
  final bool opensToSpread;
  final ValueNotifier<bool> visible;

  @override
  State<_HomeAlbumPaperOpenOverlayView> createState() =>
      _HomeAlbumPaperOpenOverlayViewState();
}

class _HomeAlbumPaperOpenOverlayViewState
    extends State<_HomeAlbumPaperOpenOverlayView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1180),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _segment(
    double value,
    double begin,
    double end, {
    Curve curve = Curves.easeOutCubic,
  }) {
    if (value <= begin) return 0;
    if (value >= end) return 1;
    return curve.transform((value - begin) / (end - begin));
  }

  double _mix(double begin, double end, double t) {
    return begin + ((end - begin) * t);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.album.title.trim().isEmpty
        ? '스냅핏 앨범'
        : widget.album.title.trim();

    return ValueListenableBuilder<bool>(
      valueListenable: widget.visible,
      builder: (context, visible, child) {
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          opacity: visible ? 1 : 0,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEFE2D0), Color(0xFFF8EFE2)],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final raw = _controller.value;
                  final objectProgress = _segment(
                    raw,
                    0.0,
                    0.52,
                    curve: Curves.easeOutQuart,
                  );
                  final openProgress = widget.opensToSpread
                      ? _segment(raw, 0.18, 0.74, curve: Curves.easeOutQuart)
                      : 0.0;
                  final stackProgress = widget.opensToSpread
                      ? _segment(raw, 0.46, 0.90, curve: Curves.easeOutQuart)
                      : 0.0;
                  final chromeProgress = _segment(raw, 0.56, 1.0);

                  final size = MediaQuery.sizeOf(context);
                  final topInset = MediaQuery.paddingOf(context).top;
                  final screenTop = topInset + 38.h;
                  final ratio =
                      widget.baseCanvasSize.width /
                      math.max(1, widget.baseCanvasSize.height);
                  final maxReaderWidth = size.width - 44.w;
                  final maxReaderHeight = size.height * 0.57;
                  var readerWidth = maxReaderWidth;
                  var readerHeight = readerWidth / ratio;
                  if (readerHeight > maxReaderHeight) {
                    readerHeight = maxReaderHeight;
                    readerWidth = readerHeight * ratio;
                  }
                  final startSide = size.width * 0.805;
                  final endWidth = readerWidth;
                  final endHeight = readerHeight;
                  final objectWidth = _mix(
                    startSide,
                    widget.opensToSpread ? endWidth : startSide,
                    objectProgress,
                  );
                  final objectHeight = _mix(
                    startSide,
                    widget.opensToSpread ? endHeight : startSide,
                    objectProgress,
                  );
                  final top = _mix(
                    screenTop + (size.height - screenTop) * 0.415,
                    screenTop + (size.height - screenTop) * 0.365,
                    objectProgress,
                  );

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: 0.34 * chromeProgress,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFBF8F3), Color(0xFFEAF4F7)],
                            ),
                          ),
                        ),
                      ),
                      _ReaderChrome(
                        title: title,
                        opacity: chromeProgress,
                        opensToSpread: widget.opensToSpread,
                      ),
                      Positioned(
                        left: (size.width - objectWidth) / 2,
                        top: top - (objectHeight / 2),
                        width: objectWidth,
                        height: objectHeight,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0014)
                            ..rotateY(_mix(-0.16, 0.0, objectProgress))
                            ..rotateZ(_mix(-0.024, 0.0, objectProgress)),
                          child: _PaperObject(
                            album: widget.album,
                            pages: widget.pages,
                            previewBuilder: widget.previewBuilder,
                            baseCanvasSize: widget.baseCanvasSize,
                            fallbackAsset: widget.fallbackAsset,
                            openProgress: openProgress,
                            stackProgress: stackProgress,
                            opensToSpread: widget.opensToSpread,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderChrome extends StatelessWidget {
  const _ReaderChrome({
    required this.title,
    required this.opacity,
    required this.opensToSpread,
  });

  final String title;
  final double opacity;
  final bool opensToSpread;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  const _ReaderCircleButton(icon: Icons.chevron_left_rounded),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF141312).withValues(alpha: 0.66),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const _ReaderCircleButton(icon: Icons.more_horiz_rounded),
                ],
              ),
            ),
            if (opensToSpread) ...[
              Positioned(
                top: 68.h,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      '1 - 2  /  10',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 104.h,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final active = index == 1;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: EdgeInsets.symmetric(horizontal: 3.w),
                      width: active ? 20.w : 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF08B8D0)
                            : const Color(0xFF08B8D0).withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    );
                  }),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24.h,
                child: SizedBox(
                  height: 76.h,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 6.h,
                    ),
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      _ReaderThumb(asset: 'assets/snapfit_home_square.jpg'),
                      _ReaderSpreadThumb(active: true),
                      _ReaderSpreadThumb(),
                      _ReaderSpreadThumb(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaperObject extends StatelessWidget {
  const _PaperObject({
    required this.album,
    required this.pages,
    required this.previewBuilder,
    required this.baseCanvasSize,
    required this.fallbackAsset,
    required this.openProgress,
    required this.stackProgress,
    required this.opensToSpread,
  });

  final Album album;
  final List<AlbumPage> pages;
  final LayerBuilder previewBuilder;
  final Size baseCanvasSize;
  final String fallbackAsset;
  final double openProgress;
  final double stackProgress;
  final bool opensToSpread;

  double _mix(double begin, double end, double t) {
    return begin + ((end - begin) * t);
  }

  @override
  Widget build(BuildContext context) {
    final coverOpacity = opensToSpread
        ? (1 - ((openProgress - 0.12) / 0.62).clamp(0.0, 1.0))
        : 1.0;
    final pageOpacity = ((openProgress - 0.10) / 0.46).clamp(0.0, 1.0);
    final leftPage = pages.length > 1 ? pages[1] : null;
    final rightPage = pages.length > 2 ? pages[2] : null;
    final coverPage = pages.isNotEmpty ? pages[0] : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 34.r,
            offset: Offset(0, 30.h),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (opensToSpread) ...[
            _PaperTailPage(
              page: pages.length > 4 ? pages[4] : rightPage,
              previewBuilder: previewBuilder,
              baseCanvasSize: baseCanvasSize,
              opacity: _mix(0, 0.34, stackProgress),
              dx: _mix(0, 50.w, stackProgress),
              rotation: _mix(0, 0.052, stackProgress),
              scale: _mix(1, 0.956, stackProgress),
            ),
            _PaperTailPage(
              page: pages.length > 3 ? pages[3] : leftPage,
              previewBuilder: previewBuilder,
              baseCanvasSize: baseCanvasSize,
              opacity: _mix(0, 0.58, stackProgress),
              dx: _mix(0, 34.w, stackProgress),
              rotation: _mix(0, 0.035, stackProgress),
              scale: _mix(1, 0.972, stackProgress),
            ),
            _PaperTailPage(
              page: rightPage ?? leftPage,
              previewBuilder: previewBuilder,
              baseCanvasSize: baseCanvasSize,
              opacity: _mix(0, 0.86, stackProgress),
              dx: _mix(0, 18.w, stackProgress),
              rotation: _mix(0, 0.018, stackProgress),
              scale: _mix(1, 0.988, stackProgress),
            ),
            Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: pageOpacity,
                    child: _PaperPage(
                      page: leftPage,
                      previewBuilder: previewBuilder,
                      baseCanvasSize: baseCanvasSize,
                      isLeft: true,
                    ),
                  ),
                ),
                Expanded(
                  child: Opacity(
                    opacity: pageOpacity,
                    child: _PaperPage(
                      page: rightPage,
                      previewBuilder: previewBuilder,
                      baseCanvasSize: baseCanvasSize,
                      isLeft: false,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: Opacity(
                opacity: pageOpacity,
                child: Container(
                  width: 14.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99.r),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.34),
                        Colors.black.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          Opacity(
            opacity: coverOpacity,
            child: Transform.scale(
              scaleX: opensToSpread ? _mix(1, 0.54, openProgress) : 1,
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18.r),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return HomeAlbumCoverThumbnail(
                          album: album,
                          height: constraints.maxHeight,
                          maxWidth: constraints.maxWidth,
                          showShadow: false,
                          fallbackAsset: fallbackAsset,
                        );
                      },
                    ),
                    if (coverPage != null)
                      Opacity(
                        opacity: ((openProgress - 0.04) / 0.30).clamp(0.0, 1.0),
                        child: _PaperPage(
                          page: coverPage,
                          previewBuilder: previewBuilder,
                          baseCanvasSize: baseCanvasSize,
                          isLeft: true,
                        ),
                      ),
                    const _SpineHighlight(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperPage extends StatelessWidget {
  const _PaperPage({
    required this.page,
    required this.previewBuilder,
    required this.baseCanvasSize,
    required this.isLeft,
  });

  final AlbumPage? page;
  final LayerBuilder previewBuilder;
  final Size baseCanvasSize;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.horizontal(
        left: Radius.circular(isLeft ? 18.r : 5.r),
        right: Radius.circular(isLeft ? 5.r : 18.r),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (page == null)
            Container(color: Colors.white)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return AlbumReaderPageContent(
                  layers: page!.layers,
                  targetW: constraints.maxWidth,
                  targetH: constraints.maxHeight,
                  previewBuilder: previewBuilder,
                  baseCanvasSize: baseCanvasSize,
                  backgroundColor: page!.backgroundColor != null
                      ? Color(page!.backgroundColor!)
                      : null,
                );
              },
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.09),
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperTailPage extends StatelessWidget {
  const _PaperTailPage({
    required this.page,
    required this.previewBuilder,
    required this.baseCanvasSize,
    required this.opacity,
    required this.dx,
    required this.rotation,
    required this.scale,
  });

  final AlbumPage? page;
  final LayerBuilder previewBuilder;
  final Size baseCanvasSize;
  final double opacity;
  final double dx;
  final double rotation;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FractionallySizedBox(
        alignment: Alignment.centerRight,
        widthFactor: 0.5,
        child: Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..translate(dx)
              ..rotateY(-rotation * 2.2)
              ..rotateZ(rotation)
              ..scale(scale),
            child: ClipRRect(
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(5.r),
                right: Radius.circular(18.r),
              ),
              child: _PaperPage(
                page: page,
                previewBuilder: previewBuilder,
                baseCanvasSize: baseCanvasSize,
                isLeft: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpineHighlight extends StatelessWidget {
  const _SpineHighlight();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 34.w,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.36),
              Colors.white.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderCircleButton extends StatelessWidget {
  const _ReaderCircleButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20.sp),
    );
  }
}

class _ReaderThumb extends StatelessWidget {
  const _ReaderThumb({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48.w,
      height: 64.h,
      margin: EdgeInsets.only(right: 8.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: Colors.white),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(asset, fit: BoxFit.cover),
    );
  }
}

class _ReaderSpreadThumb extends StatelessWidget {
  const _ReaderSpreadThumb({this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96.w,
      height: 64.h,
      margin: EdgeInsets.only(right: 8.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: Colors.white, width: active ? 2 : 1),
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xFF08B8D0).withValues(alpha: 0.34),
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Image.asset(
              'assets/snapfit_splash_album_cover.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Container(width: 1, color: Colors.grey.shade300),
          Expanded(
            child: Image.asset(
              'assets/snapfit_home_square.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}
