import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/cache/snapfit_cache_manager.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../shared/snapfit_image.dart';
import '../../../domain/entities/album.dart';
import '../../../domain/entities/layer.dart';
import '../../../domain/entities/layer_export_mapper.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../cover/cover.dart';
import 'focus_wrap.dart';
import 'paper_unfold_route.dart';

/// 홈 슬라이더의 앨범 커버 카드 (포커스에 따른 scale/그림자, 탭 시 앨범 열기)
class AlbumCoverCard extends ConsumerStatefulWidget {
  final Album album;
  final int index;
  final PageController pageController;

  const AlbumCoverCard({
    super.key,
    required this.album,
    required this.index,
    required this.pageController,
  });

  @override
  ConsumerState<AlbumCoverCard> createState() => _AlbumCoverCardState();
}

class _AlbumCoverCardState extends ConsumerState<AlbumCoverCard>
    with SingleTickerProviderStateMixin {
  final GlobalKey _coverRepaintKey = GlobalKey();
  late final AnimationController _tapController;
  late final Animation<double> _tapScale;
  Timer? _pendingUnpress;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _tapScale = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOut),
    );
  }

  void _cancelPendingUnpress() {
    _pendingUnpress?.cancel();
    _pendingUnpress = null;
  }

  @override
  void dispose() {
    _cancelPendingUnpress();
    _tapController.dispose();
    super.dispose();
  }

  double _focusFactor() {
    final page = widget.pageController.page ?? widget.index.toDouble();
    final diff = (page - widget.index).abs();
    if (diff >= 1) return 0;
    return 1 - diff;
  }

  @override
  Widget build(BuildContext context) {
    final coverSize = coverSizes.firstWhere(
      (s) => s.ratio.toString() == widget.album.ratio,
      orElse: () => coverSizes.first,
    );
    final focus = _focusFactor();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 40.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final base = w < h ? w : h;
          final ratio = coverSize.ratio;
          final canvasSize = ratio <= 1
              ? Size(base * ratio, base)
              : Size(base, base / ratio);

          Widget coverContent;

          if (widget.album.coverLayersJson.isNotEmpty) {
            List<LayerModel>? layers;
            try {
              final decoded =
                  jsonDecode(widget.album.coverLayersJson) as Map<String, dynamic>;
              final pages = decoded['pages'] as List<dynamic>?;
              final List<dynamic> layerList = (pages != null && pages.isNotEmpty)
                  ? ((pages[0] as Map<String, dynamic>)['layers'] as List?) ?? []
                  : (decoded['layers'] as List?) ?? [];
              layers = layerList
                  .map(
                    (l) => LayerExportMapper.fromJson(
                      l as Map<String, dynamic>,
                      canvasSize: canvasSize,
                    ),
                  )
                  .toList();
            } catch (_) {
              layers = null;
            }
            if (layers != null && layers.isNotEmpty) {
              coverContent = SizedBox(
                width: base,
                height: base,
                child: CoverLayout(
                  aspect: coverSize.ratio,
                  layers: layers,
                  isInteracting: false,
                  leftSpine: 14.0,
                  onCoverSizeChanged: (_) {},
                  buildImage: (layer) => _buildStaticImage(layer),
                  buildText: (layer) => _buildStaticText(layer),
                  sortedByZ: (list) =>
                      list..sort((a, b) => a.id.compareTo(b.id)),
                  theme: CoverTheme.classic,
                ),
              );
            } else {
              coverContent = _buildImageFallback(coverSize, base, ratio, focus);
            }
          } else {
            coverContent = _buildImageFallback(coverSize, base, ratio, focus);
          }

          final closedCover = RepaintBoundary(
            key: _coverRepaintKey,
            child: FocusWrap(
              focus: focus,
              applyShadow: false,
              child: Center(child: coverContent),
            ),
          );

          return GestureDetector(
            onTapDown: (_) {
              _cancelPendingUnpress();
              _tapController.forward();
            },
            onTapUp: (_) {
              _cancelPendingUnpress();
              _pendingUnpress = Timer(const Duration(milliseconds: 120), () {
                if (mounted) _tapController.reverse();
                _pendingUnpress = null;
              });
            },
            onTapCancel: () {
              _cancelPendingUnpress();
              _tapController.reverse();
            },
            onTap: () => _onTapThenNavigate(context),
            child: AnimatedBuilder(
              animation: _tapScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _tapScale.value,
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: _tapScale.value,
                    child: child,
                  ),
                );
              },
              child: closedCover,
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageFallback(CoverSize coverSize, double base, double ratio, double focus) {
    final imageUrl =
        widget.album.coverThumbnailUrl ??
        widget.album.coverPreviewUrl ??
        widget.album.coverImageUrl;
    final hasUrl = imageUrl != null && imageUrl.isNotEmpty;
    final cw = ratio >= 1 ? base : base * ratio;
    final ch = ratio <= 1 ? base : base / ratio;
    final shadowScale = cw / 180;

    return SizedBox(
      width: cw,
      height: ch,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: coverRadius,
          boxShadow: FocusWrap.coverStyleShadowForScale(shadowScale, focus),
        ),
        child: ClipRRect(
          borderRadius: coverRadius,
          child: hasUrl
              ? SnapfitImage(
                  urlOrGs: imageUrl,
                  fit: BoxFit.cover,
                  cacheManager: snapfitImageCacheManager,
                )
              : Container(
                  color: Colors.grey[300],
                  child: Icon(
                    Icons.photo_album_outlined,
                    size: 48.sp,
                    color: Colors.grey[600],
                  ),
                ),
        ),
      ),
    );
  }

  void _onTapThenNavigate(BuildContext context) {
    _cancelPendingUnpress();
    _tapController.forward();
    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _tapController.removeStatusListener(onStatus);
        _tapController.reset();
        _handleTap(context);
      }
    }
    if (_tapController.status == AnimationStatus.completed) {
      _tapController.reset();
      _handleTap(context);
      return;
    }
    _tapController.addStatusListener(onStatus);
  }

  Future<void> _handleTap(BuildContext context) async {
    Rect? cardRect;
    ui.Image? coverImage;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final offset = box.localToGlobal(Offset.zero);
      cardRect = Rect.fromLTWH(offset.dx, offset.dy, box.size.width, box.size.height);
    }

    try {
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      await ref.read(albumEditorViewModelProvider.future);
      await vm.prepareAlbumForEdit(widget.album);
      if (!context.mounted) return;

      final boundary = _coverRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        try {
          coverImage = await boundary.toImage(pixelRatio: 2.0);
        } catch (_) {}
      }

      if (!context.mounted) return;
      Navigator.of(context).push(
        PaperUnfoldRoute(cardRect: cardRect, coverImage: coverImage),
      );
    } catch (e) {
      if (mounted) _tapController.reverse();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('앨범 편집을 열 수 없습니다: $e')),
        );
      }
    }
  }

  Widget _buildStaticImage(LayerModel layer) {
    final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl ?? '';
    if (url.isEmpty) {
      return Container(color: Colors.grey[300]);
    }
    return SnapfitImage(
      urlOrGs: url,
      fit: BoxFit.cover,
      cacheManager: snapfitImageCacheManager,
    );
  }

  Widget _buildStaticText(LayerModel layer) {
    return Text(
      layer.text ?? '',
      style: layer.textStyle,
      textAlign: layer.textAlign,
    );
  }
}
