import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/album.dart';
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
    required Size baseCanvasSize,
    required String fallbackAsset,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final visible = ValueNotifier<bool>(true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _HomeAlbumPaperOpenOverlayView(
        album: album,
        baseCanvasSize: baseCanvasSize,
        fallbackAsset: fallbackAsset,
        visible: visible,
      ),
    );
    overlay.insert(entry);

    return HomeAlbumPaperOpenOverlayController._(
      entry: entry,
      visible: visible,
      opened: Future<void>.delayed(const Duration(milliseconds: 620)),
    );
  }
}

class _HomeAlbumPaperOpenOverlayView extends StatefulWidget {
  const _HomeAlbumPaperOpenOverlayView({
    required this.album,
    required this.baseCanvasSize,
    required this.fallbackAsset,
    required this.visible,
  });

  final Album album;
  final Size baseCanvasSize;
  final String fallbackAsset;
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
      duration: const Duration(milliseconds: 620),
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
                    0.72,
                    curve: Curves.easeOutQuart,
                  );
                  final backgroundFade = 1 - _segment(raw, 0.58, 1.0);

                  final size = MediaQuery.sizeOf(context);
                  final topInset = MediaQuery.paddingOf(context).top;
                  final screenTop = topInset + 38.h;
                  final ratio =
                      widget.baseCanvasSize.width /
                      math.max(1, widget.baseCanvasSize.height);
                  final maxSpreadWidth = size.width - 48.w;
                  final maxSpreadHeight =
                      (size.height -
                              MediaQuery.paddingOf(context).bottom -
                              158.h)
                          .clamp(size.height * 0.42, size.height * 0.62);
                  var readerHeight = maxSpreadHeight;
                  var readerWidth = readerHeight * ratio;
                  if (readerWidth * 2 > maxSpreadWidth) {
                    readerWidth = maxSpreadWidth / 2;
                    readerHeight = readerWidth / ratio;
                  }
                  final startSide = size.width * 0.805;
                  final endWidth = readerWidth;
                  final endHeight = endWidth / ratio;
                  final objectWidth = _mix(startSide, endWidth, objectProgress);
                  final objectHeight = _mix(
                    startSide,
                    endHeight,
                    objectProgress,
                  );
                  final top = _mix(
                    screenTop + (size.height - screenTop) * 0.415,
                    screenTop + (size.height - screenTop) * 0.42,
                    objectProgress,
                  );

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: backgroundFade,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFEFE2D0), Color(0xFFF8EFE2)],
                            ),
                          ),
                        ),
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
                            fallbackAsset: widget.fallbackAsset,
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

class _PaperObject extends StatelessWidget {
  const _PaperObject({required this.album, required this.fallbackAsset});

  final Album album;
  final String fallbackAsset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return HomeAlbumCoverThumbnail(
          album: album,
          height: constraints.maxHeight,
          maxWidth: constraints.maxWidth,
          showShadow: true,
          shadowScaleMultiplier: 1.08,
          fallbackAsset: fallbackAsset,
        );
      },
    );
  }
}
