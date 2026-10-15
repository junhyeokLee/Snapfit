import 'package:flutter/material.dart';

import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../domain/entities/album.dart';
import 'album_open_origin.dart';
import 'home_album_cover_thumbnail.dart';

class HomeAlbumPaperOpenOverlayController {
  HomeAlbumPaperOpenOverlayController._(this._overlay, this._entry, this._key);

  final OverlayState _overlay;
  final OverlayEntry _entry;
  final GlobalKey<_HomeAlbumPaperOpenOverlayViewState> _key;
  bool _dismissed = false;

  Future<void> moveTo(GlobalKey readerCoverKey) async {
    // Navigator inserts its route after our entry. Keep the same album above it.
    _overlay.rearrange([_entry], below: _entry);
    for (var frame = 0; frame < 4; frame++) {
      await WidgetsBinding.instance.endOfFrame;
      if (_dismissed || !_entry.mounted) return;
      final target = AlbumOpenOrigin.capture(readerCoverKey);
      final view = _key.currentState;
      if (target != null && view != null) {
        await view.moveTo(target, readerCoverKey);
        return;
      }
    }
  }

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    if (_overlay.mounted) _entry.remove();
    _entry.dispose();
  }
}

class HomeAlbumPaperOpenOverlay {
  const HomeAlbumPaperOpenOverlay._();

  static HomeAlbumPaperOpenOverlayController show(
    BuildContext context, {
    required Album album,
    required Size baseCanvasSize,
    required String fallbackAsset,
    AlbumOpenOrigin? origin,
  }) {
    // Direct links pass the root Navigator's own context, which sits above its
    // Overlay. Normal home cards still resolve their existing ancestor Overlay.
    final overlay =
        Overlay.maybeOf(context, rootOverlay: true) ??
        Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null) throw StateError('album_open_overlay_unavailable');
    final screen = MediaQuery.sizeOf(context);
    final width = screen.width * .60;
    final height = width * baseCanvasSize.height / baseCanvasSize.width;
    final start =
        origin ??
        AlbumOpenOrigin(
          size: Size(width, height),
          transform: Matrix4.translationValues(
            (screen.width - width) / 2,
            (screen.height - height) / 2,
            0,
          ),
        );
    final key = GlobalKey<_HomeAlbumPaperOpenOverlayViewState>();
    final entry = OverlayEntry(
      builder: (_) => _HomeAlbumPaperOpenOverlayView(
        key: key,
        album: album,
        fallbackAsset: fallbackAsset,
        origin: start,
      ),
    );
    overlay.insert(entry);
    return HomeAlbumPaperOpenOverlayController._(overlay, entry, key);
  }
}

class _HomeAlbumPaperOpenOverlayView extends StatefulWidget {
  const _HomeAlbumPaperOpenOverlayView({
    super.key,
    required this.album,
    required this.fallbackAsset,
    required this.origin,
  });

  final Album album;
  final String fallbackAsset;
  final AlbumOpenOrigin origin;

  @override
  State<_HomeAlbumPaperOpenOverlayView> createState() =>
      _HomeAlbumPaperOpenOverlayViewState();
}

class _HomeAlbumPaperOpenOverlayViewState
    extends State<_HomeAlbumPaperOpenOverlayView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  AlbumOpenOrigin? _target;
  GlobalKey? _targetKey;

  Future<void> moveTo(AlbumOpenOrigin target, GlobalKey targetKey) async {
    _target = target;
    _targetKey = targetKey;
    try {
      await _controller.forward().orCancel;
    } on TickerCanceled {
      // The reader can be popped while its opening is in flight.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AbsorbPointer(
        child: AnimatedBuilder(
          animation: _controller,
          child: SizedBox(
            width: widget.origin.size.width,
            height: widget.origin.size.height,
            child: HomeAlbumCoverThumbnail(
              album: widget.album,
              height: widget.origin.size.height,
              maxWidth: widget.origin.size.width,
              showBookDepth: true,
              bookMotion: _controller,
              fallbackAsset: widget.fallbackAsset,
            ),
          ),
          builder: (context, child) {
            final progress = Curves.easeInOutCubic.transform(_controller.value);
            final pose = AlbumOpenOrigin.interpolate(
              widget.origin,
              (_targetKey == null
                      ? null
                      : AlbumOpenOrigin.capture(_targetKey!)) ??
                  _target ??
                  widget.origin,
              progress,
            );
            final transform = Matrix4.copy(pose.transform)
              ..scaleByDouble(
                pose.size.width / widget.origin.size.width,
                pose.size.height / widget.origin.size.height,
                pose.size.width / widget.origin.size.width,
                1,
              );
            final reveal = Curves.easeOut.transform(
              ((_controller.value - .60) / .40).clamp(0.0, 1.0),
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: 1 - reveal,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AlbumStageStyle.gradient(context),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Transform(
                    alignment: Alignment.topLeft,
                    transform: transform,
                    child: child,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
