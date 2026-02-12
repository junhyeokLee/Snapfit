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
        final canvasHeight = constraints.maxHeight;
        
        // EditCover와 동일한 coverTop 계산 로직
        // 수동 계산 대신 Center 위젯 사용으로 정확도 향상
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.coverSide),
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
                            print('[AlbumReaderCoverEditor] Cover Size Changed: ${size.width.toStringAsFixed(1)} x ${size.height.toStringAsFixed(1)}');
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
            ),
          ],
        );
      },
    );
  }
}
