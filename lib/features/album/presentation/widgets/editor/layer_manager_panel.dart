import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/layer.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../controllers/layer_interaction_manager.dart';

class LayerManagerPanel extends ConsumerStatefulWidget {
  final List<LayerModel> layers;
  final LayerInteractionManager interaction;

  const LayerManagerPanel({
    super.key,
    required this.layers,
    required this.interaction,
  });

  @override
  ConsumerState<LayerManagerPanel> createState() => _LayerManagerPanelState();
}

class _LayerManagerPanelState extends ConsumerState<LayerManagerPanel> {
  late List<LayerModel> _localLayers;

  /// asset 썸네일 Future 재사용 (빌드마다 새 Future 생성 방지 → 성능·중복 요청 감소)
  final Map<String, Future<Uint8List?>> _thumbnailCache = {};

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
    if (!_listEquals(oldWidget.layers, widget.layers)) {
      _localLayers = List<LayerModel>.from(widget.layers.reversed);
    }
  }

  static bool _listEquals(List<LayerModel> a, List<LayerModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_localLayers.isEmpty) {
      return Center(
        child: Text(
          "레이어가 없습니다.",
          style: TextStyle(color: SnapFitColors.textSecondaryOf(context)),
        ),
      );
    }

    return Container(
      height: 320.h,
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12.h),
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: SnapFitColors.textPrimaryOf(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
              child: Text(
                '항목을 탭하면 캔버스에서 해당 레이어가 선택됩니다.',
                style: TextStyle(
                  color: SnapFitColors.textMutedOf(context),
                  fontSize: 11.sp,
                ),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: _localLayers.length,
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
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
                  final newOrderedForPage =
                      List<LayerModel>.from(_localLayers.reversed);
                  final vm = ref.read(albumEditorViewModelProvider.notifier);
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
    );
  }

  Widget _buildLayerItem(BuildContext context, LayerModel layer, int index) {
    final surfaceColor = SnapFitColors.surfaceOf(context);
    final isSelected = widget.interaction.selectedLayerId == layer.id;

    return GestureDetector(
      key: ValueKey(layer.id),
      onTap: () {
        // 레이어 항목을 탭 → 캔버스에서 해당 레이어 선택 후 시트 닫기 (어떤 이미지인지 확인 가능)
        widget.interaction.setSelectedLayer(layer.id);
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16.r),
          border: isSelected
              ? Border.all(color: SnapFitColors.accent, width: 2)
              : Border.all(color: SnapFitColors.overlayLightOf(context)),
        ),
        child: Row(
          children: [
            _buildLayerPreview(context, layer, index),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                _layerLabel(layer, index),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: SnapFitColors.textSecondaryOf(context),
                  fontSize: 12.sp,
                ),
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_indicator,
                color: SnapFitColors.textPrimaryOf(context).withOpacity(0.5),
                size: 22.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [index]로 이미지/스티커 순서를 계산해 미리보기에 반영
  Widget _buildLayerPreview(BuildContext context, LayerModel layer, int index) {
    final imageOrder = _imageOrderFor(layer, index);
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: SnapFitColors.textPrimaryOf(context).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.all(6.w),
      child: Center(
        child: _buildPreviewContent(context, layer, imageOrder),
      ),
    );
  }

  /// 이미지/스티커일 때만 1-based 순서 반환, 아니면 null
  int? _imageOrderFor(LayerModel layer, int index) {
    if (layer.type != LayerType.image) return null;
    final isSticker = (layer.imageBackground ?? '').toLowerCase().contains('sticker');
    return _localLayers
        .sublist(0, index + 1)
        .where((l) {
          if (l.type != LayerType.image) return false;
          final st = (l.imageBackground ?? '').toLowerCase().contains('sticker');
          return st == isSticker;
        })
        .length;
  }

  Widget _buildPreviewContent(BuildContext context, LayerModel layer, int? imageOrder) {
    switch (layer.type) {
      case LayerType.image:
        return _buildImageLayerPreview(context, layer, imageOrder ?? 1);
      case LayerType.text:
        return Icon(
          Icons.text_fields,
          color: SnapFitColors.textSecondaryOf(context),
          size: 20.sp,
        );
    }
  }

  /// 이미지 레이어: 썸네일 있으면 표시 + 순서 뱃지, 없으면 순서 번호를 크게 표시해 위치 파악 가능
  Widget _buildImageLayerPreview(BuildContext context, LayerModel layer, int imageOrder) {
    Widget thumbnailWidget;
    if (layer.asset != null) {
      final future = _thumbnailCache.putIfAbsent(
        layer.id,
        () => layer.asset!.thumbnailDataWithSize(const ThumbnailSize.square(_thumbSize)),
      );
      thumbnailWidget = FutureBuilder<Uint8List?>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
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
        thumbnailWidget = ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: _thumbSize,
            cacheHeight: _thumbSize,
            errorBuilder: (_, __, ___) => _imageOrderPlaceholder(context, imageOrder),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(child: _imageOrderPlaceholder(context, imageOrder));
            },
          ),
        );
      } else {
        thumbnailWidget = _imageOrderPlaceholder(context, imageOrder);
      }
    }
    // 썸네일이 있으면 우하단에 작은 순서 뱃지 겹침 → 어떤 이미지인지 순서로 파악 가능
    return Stack(
      fit: StackFit.expand,
      children: [
        thumbnailWidget,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: SnapFitColors.textPrimaryOf(context).withOpacity(0.75),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              '$imageOrder',
              style: TextStyle(
                color: SnapFitColors.surfaceOf(context),
                fontSize: 10.sp,
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
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.image_outlined,
          color: SnapFitColors.textSecondaryOf(context).withOpacity(0.4),
          size: 20.sp,
        ),
        Text(
          '$order',
          style: TextStyle(
            color: SnapFitColors.textPrimaryOf(context),
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// 레이어 타입 + 순서에 따른 라벨 (이미지/스티커는 "이미지 1", "스티커 2" 등으로 구분)
  String _layerLabel(LayerModel layer, int index) {
    switch (layer.type) {
      case LayerType.text:
        final text = layer.text ?? '';
        if (text.isEmpty) return '텍스트';
        return text.length <= 12 ? text : '${text.substring(0, 12)}…';
      case LayerType.image:
        final isSticker = (layer.imageBackground ?? '').toLowerCase().contains('sticker');
        if (isSticker && (layer.text ?? '').isNotEmpty) {
          final text = layer.text!;
          return text.length <= 12 ? text : '${text.substring(0, 12)}…';
        }

        final sameTypeCount = _localLayers
            .sublist(0, index + 1)
            .where((l) {
              if (l.type != LayerType.image) return false;
              final st = (l.imageBackground ?? '').toLowerCase().contains('sticker');
              return st == isSticker;
            })
            .length;
        return isSticker ? '스티커 $sameTypeCount' : '이미지 $sameTypeCount';
    }
  }
}
