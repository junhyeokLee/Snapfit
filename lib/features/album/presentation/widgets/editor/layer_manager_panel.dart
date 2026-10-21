import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/web/web_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../../core/utils/image_url_policy.dart';
import '../../../../../core/cache/snapfit_cache_manager.dart';
import '../../../../../shared/snapfit_image.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../shared/widgets/photo_crop_viewport.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import '../../../../../shared/widgets/studio_decoration.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../controllers/layer_interaction_manager.dart';

class LayerManagerPanel extends ConsumerStatefulWidget {
  final List<LayerModel> layers;
  final LayerInteractionManager interaction;
  final bool showHandle;
  final ValueChanged<LayerModel>? onLayerSelected;

  const LayerManagerPanel({
    super.key,
    required this.layers,
    required this.interaction,
    this.showHandle = true,
    this.onLayerSelected,
  });

  @override
  ConsumerState<LayerManagerPanel> createState() => _LayerManagerPanelState();
}

class _LayerManagerPanelState extends ConsumerState<LayerManagerPanel> {
  late List<LayerModel> _localLayers;

  /// asset 썸네일 Future 재사용 (빌드마다 새 Future 생성 방지 → 성능·중복 요청 감소)
  final Map<(String, String), Future<Uint8List?>> _thumbnailCache = {};
  final _scroll = ScrollController();
  bool _closing = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _close() {
    if (!mounted || _closing || ModalRoute.of(context)?.isCurrent == false)
      return;
    _closing = true;
    Navigator.pop(context);
  }

  static const int _thumbSize = 120;

  @override
  void initState() {
    super.initState();
    // 레이어 목록의 현재 스냅샷을 로컬 리스트로 관리 (드래그 시 즉시 반영)
    // UI에서는 "맨 위 아이템 = 화면에서 가장 위에 보이는 레이어" 이므로
    // 실제 레이어 리스트를 역순으로 뒤집어서 보여준다.
    _localLayers = List<LayerModel>.from(widget.layers.reversed);
  }

  @override
  void didUpdateWidget(LayerManagerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 부모에서 레이어 순서가 바뀌었을 수 있으므로(다른 탭에서 저장 등) 최신 순서 반영
    if (!_listEquals(_localLayers.reversed.toList(), widget.layers)) {
      _localLayers = List<LayerModel>.from(widget.layers.reversed);
    }
    final assets = {
      for (final layer in widget.layers)
        if (layer.asset != null) (layer.id, layer.asset!.id),
    };
    _thumbnailCache.removeWhere((key, _) => !assets.contains(key));
  }

  static bool _listEquals(List<LayerModel> a, List<LayerModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => Container(
        height: widget.showHandle && kIsWeb ? double.infinity : widget.showHandle
            ? math.min(
                box.maxHeight,
                (MediaQuery.sizeOf(context).height * .90).clamp(0.0, 900.0),
              )
            : null,
        decoration: BoxDecoration(
          color: kIsWeb ? WebPalette.of(context).surface : ExperienceFormStyle.surface(context),
          borderRadius: kIsWeb ? BorderRadius.circular(12) : widget.showHandle
              ? const BorderRadius.vertical(top: Radius.circular(8))
              : null,
        ),
        child: SafeArea(
          top: false,
          bottom: widget.showHandle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showHandle && !kIsWeb) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: ExperienceFormStyle.line(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: 4),
              if (widget.showHandle)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
                  child: Row(
                    children: [
                      const ExperienceIcon('Layers2', size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '레이어',
                          style: ExperienceFormStyle.text(
                            context,
                            16,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${_localLayers.length}개',
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const ValueKey('editor-layer-close'),
                        tooltip: '레이어 닫기',
                        onPressed: _close,
                        icon: Transform.rotate(
                          angle: math.pi / 4,
                          child: const ExperienceIcon('Plus', size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.showHandle)
                Divider(height: 1, color: ExperienceFormStyle.line(context)),
              Expanded(
                child: _localLayers.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ExperienceIcon(
                                  'Layers2',
                                  size: 28,
                                  color: ExperienceFormStyle.muted(context),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '아직 추가한 요소가 없어요',
                                  textAlign: TextAlign.center,
                                  style: ExperienceFormStyle.text(
                                    context,
                                    13,
                                    secondary: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        key: const ValueKey('editor-layer-list'),
                        scrollController: _scroll,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _localLayers.length,
                        buildDefaultDragHandles: false,
                        onReorder: (oldIndex, newIndex) {
                          if (!mounted ||
                              _closing ||
                              ModalRoute.of(context)?.isCurrent == false ||
                              oldIndex < 0 ||
                              oldIndex >= _localLayers.length ||
                              newIndex < 0 ||
                              newIndex > _localLayers.length)
                            return;
                          // 1) 로컬 리스트 순서 즉시 변경 (UI용)
                          setState(() {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final item = _localLayers.removeAt(oldIndex);
                            _localLayers.insert(newIndex, item);
                          });

                          // 2) ViewModel에 새로운 레이어 순서를 그대로 반영
                          // _localLayers는 "위 → 아래" 이므로, 실제 페이지 레이어 리스트는 그 역순
                          final newOrderedForPage = List<LayerModel>.from(
                            _localLayers.reversed,
                          );
                          final vm = ref.read(
                            albumEditorViewModelProvider.notifier,
                          );
                          vm.updatePageLayers(newOrderedForPage);

                          // 3) InteractionManager의 Z-순서 동기화 (캔버스 상위/하위 반영)
                          widget.interaction.syncZOrder(newOrderedForPage);
                        },
                        itemBuilder: (context, index) {
                          final layer = _localLayers[index];
                          return _buildLayerItem(context, layer, index);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerItem(BuildContext context, LayerModel layer, int index) {
    final isSelected = widget.interaction.selectedLayerId == layer.id;

    return Semantics(
      key: ValueKey(layer.id),
      button: true,
      selected: isSelected,
      label: '${_layerKind(layer)} · ${_layerLabel(layer, index)}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: isSelected
              ? ExperienceFormStyle.selection(context)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              if (!mounted ||
                  _closing ||
                  ModalRoute.of(context)?.isCurrent == false)
                return;
              widget.interaction.setSelectedLayer(layer.id);
              if (widget.onLayerSelected != null) {
                widget.onLayerSelected!(layer);
              } else if (widget.showHandle) {
                _close();
              } else {
                setState(() {});
              }
            },
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxWidth < 190;
                final handle = ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: '겹침 순서 이동',
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: ExperienceFormStyle.muted(context),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                );
                final kind = Text(
                  _layerKind(layer),
                  style: ExperienceFormStyle.text(context, 11, secondary: true),
                );
                return Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 2 : 8, 10, 0, 10),
                  child: Row(
                    children: [
                      _buildLayerPreview(
                        context,
                        layer,
                        index,
                        size: compact ? 28 : 44,
                      ),
                      SizedBox(width: compact ? 6 : 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _layerLabel(layer, index),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ExperienceFormStyle.text(
                                context,
                                13,
                                weight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (compact)
                              Row(
                                children: [
                                  Expanded(child: kind),
                                  handle,
                                ],
                              )
                            else
                              kind,
                          ],
                        ),
                      ),
                      if (!compact) handle,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _layerKind(LayerModel layer) => switch (layer.type) {
    LayerType.text => '문구',
    LayerType.sticker => '스티커',
    LayerType.decoration => '장식',
    LayerType.image =>
      (layer.imageBackground ?? '').toLowerCase().startsWith('sticker')
          ? '스티커'
          : '사진',
  };

  /// [index]로 이미지/스티커 순서를 계산해 미리보기에 반영
  Widget _buildLayerPreview(
    BuildContext context,
    LayerModel layer,
    int index, {
    double size = 44,
  }) {
    final imageOrder = _imageOrderFor(layer, index);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SnapFitColors.isDark(context)
            ? const Color(0xFF303836)
            : const Color(0xFFF0F2EF),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: RepaintBoundary(
        child: Center(child: _buildPreviewContent(context, layer, imageOrder)),
      ),
    );
  }

  /// 이미지/스티커일 때만 1-based 순서 반환, 아니면 null
  int? _imageOrderFor(LayerModel layer, int index) {
    if (layer.type != LayerType.image) return null;
    final isSticker = (layer.imageBackground ?? '').toLowerCase().contains(
      'sticker',
    );
    return _localLayers.sublist(0, index + 1).where((l) {
      if (l.type != LayerType.image) return false;
      final st = (l.imageBackground ?? '').toLowerCase().contains('sticker');
      return st == isSticker;
    }).length;
  }

  Widget _buildPreviewContent(
    BuildContext context,
    LayerModel layer,
    int? imageOrder,
  ) {
    switch (layer.type) {
      case LayerType.image:
        return _buildImageLayerPreview(context, layer, imageOrder ?? 1);
      case LayerType.text:
        final ink = layer.textStyle?.color ?? const Color(0xFF182724);
        return Container(
          key: ValueKey('layer-text-preview-${layer.id}'),
          color: ink.computeLuminance() > .55
              ? const Color(0xFF303836)
              : const Color(0xFFF0F2EF),
          alignment: Alignment.center,
          child: Text(
            '가',
            style: (layer.textStyle ?? const TextStyle()).copyWith(
              fontSize: 24,
              height: 1,
              color: ink,
            ),
          ),
        );
      case LayerType.sticker:
      case LayerType.decoration:
        return _buildImageLayerPreview(context, layer, imageOrder ?? 1);
    }
  }

  /// 이미지 레이어: 썸네일 있으면 표시 + 순서 뱃지, 없으면 순서 번호를 크게 표시해 위치 파악 가능
  Widget _buildImageLayerPreview(
    BuildContext context,
    LayerModel layer,
    int imageOrder,
  ) {
    final studioSpec = _studioSpec(layer);
    if (studioSpec != null) {
      return Padding(
        padding: const EdgeInsets.all(2),
        child: Center(
          child: AspectRatio(
            aspectRatio: studioSpec.aspectRatio,
            child: StudioDecoration(spec: studioSpec),
          ),
        ),
      );
    }
    final style = layer.imageBackground ?? '';
    final isDecoStickerStyle =
        style.isNotEmpty && style.toLowerCase().startsWith('sticker');
    final shouldRenderDecoStyle =
        (layer.type == LayerType.decoration ||
            layer.type == LayerType.sticker) &&
        isDecoStickerStyle;

    if (shouldRenderDecoStyle) {
      return Center(
        child: LayerBuilder.buildStickerDecoration(
          style: style,
          width: 32,
          height: 32,
        ),
      );
    }

    if (layer.type == LayerType.decoration && !layer.hasImageSource) {
      final canvas = Size(math.max(1, layer.width), math.max(1, layer.height));
      return Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          child: TemplatePageRenderer(
            layers: [
              layer.copyWith(position: Offset.zero, rotation: 0, scale: 1),
            ],
            width: canvas.width,
            height: canvas.height,
            designCanvasSize: canvas,
            showCanvasChrome: false,
          ),
        ),
      );
    }

    Widget thumbnailWidget;
    if (layer.asset != null) {
      final future = _thumbnailCache.putIfAbsent(
        (layer.id, layer.asset!.id),
        () => layer.asset!.thumbnailDataWithSize(
          const ThumbnailSize.square(_thumbSize),
        ),
      );
      thumbnailWidget = FutureBuilder<Uint8List?>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                alignment: layer.imageAlignment,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: _thumbSize,
                cacheHeight: _thumbSize,
              ),
            );
          }
          return _imageOrderPlaceholder(context, imageOrder);
        },
      );
    } else {
      final url = layer.previewUrl ?? layer.originalUrl ?? layer.imageUrl;
      if (url != null && url.isNotEmpty) {
        final asset =
            bundledTemplateAssetPath(url) ??
            (url.startsWith('asset:') ? url.substring(6) : null);
        thumbnailWidget = ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: asset != null
              ? Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  alignment: layer.imageAlignment,
                  width: double.infinity,
                  height: double.infinity,
                  cacheWidth: _thumbSize,
                  errorBuilder: (_, __, ___) =>
                      _imageOrderPlaceholder(context, imageOrder),
                )
              : SnapfitImage(
                  urlOrGs: imageUrlByVariant(url, variant: ImageVariant.thumb),
                  fit: BoxFit.cover,
                  alignment: layer.imageAlignment,
                  memCacheWidth: _thumbSize,
                  memCacheHeight: _thumbSize,
                  cacheManager: snapfitImageCacheManager,
                  placeholder: _imageOrderPlaceholder(context, imageOrder),
                  error: _imageOrderPlaceholder(context, imageOrder),
                ),
        );
      } else {
        thumbnailWidget = _imageOrderPlaceholder(context, imageOrder);
      }
    }
    // 썸네일이 있으면 우하단에 작은 순서 뱃지 겹침 → 어떤 이미지인지 순서로 파악 가능
    // 장식/스티커 타입은 실제 썸네일 자체가 의미이므로 숫자 뱃지는 노출하지 않는다.
    final showOrderBadge = layer.type == LayerType.image;
    thumbnailWidget = PhotoCropViewport(layer: layer, child: thumbnailWidget);
    if (!showOrderBadge) {
      return thumbnailWidget;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        thumbnailWidget,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xCC182724),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '$imageOrder',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 썸네일 없을 때: 순서 번호를 크게 표시해 "몇 번째 이미지/스티커"인지 한눈에 파악
  Widget _imageOrderPlaceholder(BuildContext context, int order) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        color: ExperienceFormStyle.muted(context),
        size: 20,
      ),
    );
  }

  /// 레이어 타입 + 순서에 따른 라벨 (이미지/스티커는 "이미지 1", "스티커 2" 등으로 구분)
  String _layerLabel(LayerModel layer, int index) {
    final studioSpec = _studioSpec(layer);
    if (studioSpec != null) return studioSpec.label;
    switch (layer.type) {
      case LayerType.text:
        final text = layer.text ?? '';
        if (text.isEmpty) return '텍스트';
        return text;
      case LayerType.sticker:
        return '스티커 ${index + 1}';
      case LayerType.decoration:
        return '장식 ${index + 1}';
      case LayerType.image:
        final isSticker = (layer.imageBackground ?? '').toLowerCase().contains(
          'sticker',
        );
        if (isSticker && (layer.text ?? '').isNotEmpty) {
          final text = layer.text!;
          return text;
        }

        final sameTypeCount = _localLayers.sublist(0, index + 1).where((l) {
          if (l.type != LayerType.image) return false;
          final st = (l.imageBackground ?? '').toLowerCase().contains(
            'sticker',
          );
          return st == isSticker;
        }).length;
        return isSticker ? '스티커 $sameTypeCount' : '사진 $sameTypeCount';
    }
  }

  StudioDecorationSpec? _studioSpec(LayerModel layer) {
    final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
    return studioDecorationById(layer.imageBackground) ??
        studioDecorationByAsset(url?.replaceFirst('asset:', ''));
  }
}
