import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/web/web_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../../core/utils/image_url_policy.dart';
import '../../../../../core/cache/snapfit_cache_manager.dart';
import '../../../../../shared/snapfit_image.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/photo_crop_viewport.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import '../../../../../shared/widgets/studio_decoration.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../controllers/layer_interaction_manager.dart';
import 'editor_asset_thumbnail.dart';
import 'editor_thumbnail_cache.dart';
import '../../../../../shared/widgets/experience_icon.dart';

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
  late List<LayerModel> _sourceLayers;
  late Object _session;
  Object _orderRevision = Object();
  String? _pageId;
  int? _albumId;

  void _captureTarget() {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    _session = vm.editSessionIdentity;
    _pageId = vm.currentPage?.id;
    _albumId = vm.editingAlbumId;
  }

  bool get _targetIsCurrent {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    return identical(vm.editSessionIdentity, _session) &&
        vm.currentPage?.id == _pageId &&
        vm.editingAlbumId == _albumId;
  }

  final _thumbnails = EditorThumbnailCache();
  final _scroll = ScrollController();
  final Map<String, int> _imageOrdinals = {};
  bool _closing = false;

  @override
  void dispose() {
    _scroll.dispose();
    _thumbnails.dispose();
    super.dispose();
  }

  void _close() {
    if (!mounted || _closing || ModalRoute.of(context)?.isCurrent == false)
      return;
    _closing = true;
    Navigator.pop(context);
  }

  static const int _thumbSize = 120;

  void _commitOrder() {
    if (!_targetIsCurrent) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final current = vm.layers;
    // A drop can finish before the rebuild following undo, deletion or another
    // edit. Only apply the requested ID order; never write the UI's old records.
    final sameOrder =
        current.length == _sourceLayers.length &&
        current.indexed.every((entry) {
          final previous = _sourceLayers[entry.$1];
          return entry.$2.id == previous.id &&
              entry.$2.zIndex == previous.zIndex;
        });
    final byId = {for (final layer in current) layer.id: layer};
    if (!sameOrder || byId.length != _localLayers.length) {
      _sourceLayers = List.of(current, growable: false);
      _localLayers = widget.interaction.sortByZ(current).reversed.toList();
      _indexImages();
      return;
    }
    final ordered = _localLayers.reversed
        .map((layer) => byId[layer.id]!)
        .indexed
        .map(
          (entry) => entry.$2.zIndex == entry.$1
              ? entry.$2
              : entry.$2.copyWith(zIndex: entry.$1),
        )
        .toList();
    _sourceLayers = List.of(ordered, growable: false);
    _localLayers = ordered.reversed.toList();
    _indexImages();
    vm.updatePageLayers(ordered);
    widget.interaction.syncZOrder(ordered);
  }

  void _moveSelected(int delta) {
    if (!mounted ||
        _closing ||
        !_targetIsCurrent ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    final index = _localLayers.indexWhere(
      (layer) => layer.id == widget.interaction.selectedLayerId,
    );
    final target = index + delta;
    if (index < 0 || target < 0 || target >= _localLayers.length) return;
    setState(() {
      final layer = _localLayers.removeAt(index);
      _localLayers.insert(target, layer);
      _commitOrder();
    });
  }

  @override
  void initState() {
    super.initState();
    _captureTarget();
    // 레이어 목록의 현재 스냅샷을 로컬 리스트로 관리 (드래그 시 즉시 반영)
    // UI에서는 "맨 위 아이템 = 화면에서 가장 위에 보이는 레이어" 이므로
    // 실제 레이어 리스트를 역순으로 뒤집어서 보여준다.
    _sourceLayers = List.of(widget.layers, growable: false);
    _localLayers = widget.interaction.sortByZ(widget.layers).reversed.toList();
    _indexImages();
  }

  @override
  void didUpdateWidget(LayerManagerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.showHandle && widget.onLayerSelected == null) _captureTarget();
    // 부모에서 레이어 순서가 바뀌었을 수 있으므로(다른 탭에서 저장 등) 최신 순서 반영
    if (identical(oldWidget.interaction, widget.interaction) &&
        _listEquals(_sourceLayers, widget.layers))
      return;
    _sourceLayers = List.of(widget.layers, growable: false);
    _localLayers = widget.interaction.sortByZ(widget.layers).reversed.toList();
    _indexImages();
    final assets = {
      for (final layer in widget.layers)
        if (layer.asset != null) layer.asset!.id,
    };
    _thumbnails.retainOnly(assets);
  }

  static bool _listEquals(List<LayerModel> a, List<LayerModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  void _indexImages() {
    _orderRevision = Object();
    _imageOrdinals.clear();
    var photos = 0, stickers = 0;
    for (final layer in _localLayers) {
      if (layer.type != LayerType.image) continue;
      final sticker = (layer.imageBackground ?? '').toLowerCase().contains(
        'sticker',
      );
      _imageOrdinals[layer.id] = sticker ? ++stickers : ++photos;
    }
  }

  void _select(LayerModel layer) {
    if (!mounted ||
        _closing ||
        !_targetIsCurrent ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    widget.interaction.setSelectedLayer(layer.id);
    // Selecting a covered element never commits z-order or closes the tools.
    // Keep the arrows available; the explicit edit button returns to the canvas.
    setState(() {});
  }

  void _editSelected() {
    if (!mounted || _closing) return;
    final selected = _localLayers
        .where((l) => l.id == widget.interaction.selectedLayerId)
        .firstOrNull;
    if (selected == null ||
        !_targetIsCurrent ||
        _closing ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    if (widget.onLayerSelected != null) {
      _closing = true;
      widget.onLayerSelected!(selected);
    } else {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final revision = _orderRevision;
    final selectedIndex = _localLayers.indexWhere(
      (l) => l.id == widget.interaction.selectedLayerId,
    );
    final line = ExperienceFormStyle.line(context);
    final selectionInk = ExperienceFormStyle.selectionInk(context);
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 240 || box.maxHeight < 360;
        final textScale = MediaQuery.textScalerOf(context);
        final rowHeight =
            60 + textScale.scale(13) * 2 + textScale.scale(11) * 1.4;
        final contentHeight =
            230 +
            textScale.scale(12) * 3 +
            _localLayers.length.clamp(1, 6) * rowHeight;
        return Container(
          height: widget.showHandle
              ? math.min(
                  contentHeight,
                  math.min(
                    box.maxHeight,
                    MediaQuery.sizeOf(context).height * .84,
                  ),
                )
              : null,
          decoration: BoxDecoration(
            color: kIsWeb
                ? WebPalette.of(context).surface
                : ExperienceFormStyle.surface(context),
            borderRadius: widget.showHandle
                ? const BorderRadius.vertical(top: Radius.circular(28))
                : null,
          ),
          child: SafeArea(
            top: false,
            bottom: widget.showHandle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showHandle) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '겹침 순서',
                            style: ExperienceFormStyle.text(
                              context,
                              20,
                              weight: FontWeight.w700,
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
                          tooltip: '겹침 순서 닫기',
                          onPressed: _close,
                          icon: const ExperienceIcon('X', size: 21),
                        ),
                      ],
                    ),
                  ),
                  if (!compact)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                      child: Text(
                        '눌러서 선택하고, 손잡이를 끌어 순서를 바꿔요.',
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                    ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '위에 있을수록 앞에 보여요',
                              style: ExperienceFormStyle.text(
                                context,
                                12,
                                secondary: true,
                              ),
                            ),
                            if (!compact) ...[
                              const SizedBox(height: 3),
                              Text(
                                selectedIndex < 0
                                    ? '순서를 바꿀 요소를 선택해 주세요'
                                    : '${_layerKind(_localLayers[selectedIndex])} 선택됨 · 앞뒤로 한 칸씩 이동',
                                style: ExperienceFormStyle.text(
                                  context,
                                  11,
                                  secondary: true,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '앞으로',
                        style: IconButton.styleFrom(
                          foregroundColor: selectionInk,
                        ),
                        onPressed: selectedIndex > 0
                            ? () => _moveSelected(-1)
                            : null,
                        icon: const Icon(Icons.flip_to_front, size: 21),
                      ),
                      IconButton(
                        tooltip: '뒤로',
                        style: IconButton.styleFrom(
                          foregroundColor: selectionInk,
                        ),
                        onPressed:
                            selectedIndex >= 0 &&
                                selectedIndex < _localLayers.length - 1
                            ? () => _moveSelected(1)
                            : null,
                        icon: const Icon(Icons.flip_to_back, size: 21),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: line),
                Expanded(
                  child: _localLayers.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ExperienceIcon('Layers2', size: 32, color: ExperienceFormStyle.muted(context),
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
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          itemCount: _localLayers.length,
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) {
                            if (!mounted ||
                                !identical(_orderRevision, revision) ||
                                !_targetIsCurrent ||
                                _closing ||
                                ModalRoute.of(context)?.isCurrent == false ||
                                oldIndex < 0 ||
                                oldIndex >= _localLayers.length ||
                                newIndex < 0 ||
                                newIndex > _localLayers.length)
                              return;
                            if (oldIndex < newIndex) newIndex--;
                            if (oldIndex == newIndex) return;
                            setState(() {
                              final item = _localLayers.removeAt(oldIndex);
                              _localLayers.insert(newIndex, item);
                              _commitOrder();
                            });
                          },
                          itemBuilder: (context, index) => _buildLayerItem(
                            context,
                            _localLayers[index],
                            index,
                          ),
                        ),
                ),
                if (widget.showHandle || widget.onLayerSelected != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: FilledButton.icon(
                      key: const ValueKey('editor-layer-edit-selected'),
                      onPressed: selectedIndex >= 0 ? _editSelected : null,
                      style: ExperienceFormStyle.primary(context),
                      icon: const Icon(Icons.touch_app_outlined, size: 20),
                      label: const Text('선택한 요소 편집'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayerItem(BuildContext context, LayerModel layer, int index) {
    final selected = widget.interaction.selectedLayerId == layer.id;
    final ink = ExperienceFormStyle.selectionInk(context);
    return Semantics(
      key: ValueKey(layer.id),
      button: true,
      selected: selected,
      label: '${_layerKind(layer)} · ${_layerLabel(layer, index)}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected
              ? ExperienceFormStyle.selection(context)
              : ExperienceFormStyle.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected
                  ? ink.withValues(alpha: .48)
                  : ExperienceFormStyle.line(context),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _select(layer),
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxWidth < 220;
                final handle = ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: '겹침 순서 이동',
                    child: SizedBox.square(
                      dimension: 44,
                      child: ExperienceIcon('GripHorizontal', color: ExperienceFormStyle.muted(context),
                        size: 20,
                      ),
                    ),
                  ),
                );
                return Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 10, 2, 10),
                  child: Row(
                    children: [
                      _buildLayerPreview(
                        context,
                        layer,
                        index,
                        size: compact ? 32 : 48,
                      ),
                      SizedBox(width: compact ? 8 : 12),
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
                                weight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_layerKind(layer)} · ${index == 0
                                  ? '맨 앞'
                                  : index == _localLayers.length - 1
                                  ? '맨 뒤'
                                  : '앞에서 ${index + 1}번째'}',
                              style: ExperienceFormStyle.text(
                                context,
                                11,
                                secondary: true,
                              ),
                            ),
                            if (compact)
                              Align(
                                alignment: Alignment.centerRight,
                                child: handle,
                              ),
                          ],
                        ),
                      ),
                      if (!compact) ...[
                        if (selected)
                          ExperienceIcon('CheckCircle2', size: 18, color: ink),
                        handle,
                      ],
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
        borderRadius: BorderRadius.circular(10),
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
    return _imageOrdinals[layer.id];
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
      thumbnailWidget = EditorAssetThumbnail(
        asset: layer.asset!,
        cache: _thumbnails,
        alignment: layer.imageAlignment,
        placeholder: _imageOrderPlaceholder(context, imageOrder),
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
      child: ExperienceIcon('Image', color: ExperienceFormStyle.muted(context),
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

        final sameTypeCount = _imageOrdinals[layer.id] ?? 1;
        return isSticker ? '스티커 $sameTypeCount' : '사진 $sameTypeCount';
    }
  }

  StudioDecorationSpec? _studioSpec(LayerModel layer) {
    final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
    return studioDecorationById(layer.imageBackground) ??
        studioDecorationByAsset(url?.replaceFirst('asset:', ''));
  }
}
