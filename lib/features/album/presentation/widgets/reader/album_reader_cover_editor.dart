import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../domain/entities/album_page.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../cover/cover.dart';

/// 앨범 리더 커버 에디터
class AlbumReaderCoverEditor extends ConsumerStatefulWidget {
  final AlbumPage coverPage;
  final CoverSize selectedCover;
  final CoverTheme coverTheme;
  final double coverSide;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final GlobalKey coverKey;
  final ValueChanged<Size> onCoverSizeChanged;
  final ValueChanged<Size> onBaseCanvasSizeChanged;

  const AlbumReaderCoverEditor({
    super.key,
    required this.coverPage,
    required this.selectedCover,
    required this.coverTheme,
    required this.coverSide,
    required this.interaction,
    required this.layerBuilder,
    required this.coverKey,
    required this.onCoverSizeChanged,
    required this.onBaseCanvasSizeChanged,
  });

  @override
  ConsumerState<AlbumReaderCoverEditor> createState() => _AlbumReaderCoverEditorState();
}

class _AlbumReaderCoverEditorState extends ConsumerState<AlbumReaderCoverEditor> {
  Size _coverSize = Size.zero;
  bool _hasLoadedLayers = false;

  @override
  Widget build(BuildContext context) {
    final aspect = widget.selectedCover.ratio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalH = constraints.maxHeight;
        final coverTop = _coverSize == Size.zero
            ? (totalH * 0.5) - (totalH * 0.25)
            : (totalH - _coverSize.height) / 2;

        return Stack(
          children: [
            Positioned(
              top: coverTop,
              left: widget.coverSide,
              right: widget.coverSide,
              child: RepaintBoundary(
                key: widget.coverKey,
                child: CoverLayout(
                  aspect: aspect,
                  layers: widget.interaction.sortByZ(widget.coverPage.layers),
                  isInteracting: true,
                  leftSpine: 14.0,
                  onCoverSizeChanged: (size) {
                    if (size == Size.zero) return;
                    if (_coverSize != size && mounted) {
                      // 빌드 중 setState 호출 방지를 위해 postFrameCallback 사용
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _coverSize != size) {
                          setState(() {
                            _coverSize = size;
                            widget.onBaseCanvasSizeChanged(size);
                          });
                          final vm = ref.read(albumEditorViewModelProvider.notifier);
                          vm.setCoverCanvasSize(size);
                          if (!_hasLoadedLayers) {
                            vm.loadPendingEditAlbumIfNeeded(size);
                            setState(() => _hasLoadedLayers = true);
                          }
                        }
                      });
                    }
                    widget.onCoverSizeChanged(size);
                  },
                  buildImage: (layer) => widget.layerBuilder.buildImage(layer),
                  buildText: (layer) => widget.layerBuilder.buildText(layer),
                  sortedByZ: widget.interaction.sortByZ,
                  theme: widget.coverTheme,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
