import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/constants/snapfit_colors.dart';
import 'grid_guideline_painter.dart';

/// 사진첩 썸네일 타일.
/// [simpleMode] true: 바텀시트 그리드용 (1:1, 체크만). false: 편집용 (6:8, 줌·가이드).
class GalleryThumbTile extends StatefulWidget {
  final AssetEntity asset;
  final bool isSelected;
  final bool simpleMode;

  const GalleryThumbTile({
    super.key,
    required this.asset,
    required this.isSelected,
    this.simpleMode = false,
  });

  @override
  State<GalleryThumbTile> createState() => GalleryThumbTileState();
}

class GalleryThumbTileState extends State<GalleryThumbTile> with AutomaticKeepAliveClientMixin {
  Uint8List? _thumbData;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    if (_loading) return;
    _loading = true;
    final data = await widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(150));
    if (!mounted) return;
    setState(() => _thumbData = data);
    _loading = false;
  }

  bool _interacting = false;
  Timer? _interactionEndTimer;

  void _onScaleStart(ScaleStartDetails details) {
    _interactionEndTimer?.cancel();
    if (!_interacting && details.pointerCount > 1) {
      setState(() {
        _interacting = true;
      });
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_interacting && details.pointerCount > 1) {
      setState(() {
        _interacting = true;
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _interactionEndTimer?.cancel();
    _interactionEndTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _interacting = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _interactionEndTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.simpleMode) {
      return AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _thumbData == null
                  ? Container(
                      color: SnapFitColors.surfaceOf(context),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: SnapFitColors.textMutedOf(context),
                          ),
                        ),
                      ),
                    )
                  : Image.memory(
                      _thumbData!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
              if (widget.isSelected)
                Container(
                  color: Colors.black.withOpacity(0.35),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.check_circle,
                    color: SnapFitColors.accent,
                    size: 28,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    // 편집용: 6:8 비율, 줌·가이드라인
    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: AspectRatio(
        aspectRatio: 6 / 8,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 3.0,
                panEnabled: true,
                scaleEnabled: true,
                child: _thumbData == null
                    ? Container(color: Colors.black26)
                    : Image.memory(
                        _thumbData!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
              AnimatedOpacity(
                opacity: _interacting ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GridGuidelinePainter(),
                    size: Size.infinite,
                  ),
                ),
              ),
              if (widget.isSelected)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.check_circle,
                    color: SnapFitColors.accent,
                    size: 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}