import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../viewmodels/cover_view_model.dart';
import '../../../domain/entities/layer.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';

import './decorate_sticker_tab.dart';
import './decorate_color_tab.dart';
import './decorate_background_theme_tab.dart';

class DecoratePanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const DecoratePanel({super.key, this.onClose});

  @override
  ConsumerState<DecoratePanel> createState() => _DecoratePanelState();
}

class _DecoratePanelState extends ConsumerState<DecoratePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _closeSheet() {
    widget.onClose?.call();
    if (widget.onClose == null && mounted) {
      Navigator.of(context).pop();
    }
  }

  Size _effectiveLogicalCanvasSize({
    required AlbumEditorViewModel editorVm,
    required AlbumEditorState? stateVal,
  }) {
    final double physicalAspect = editorVm.selectedCover.ratio > 0
        ? editorVm.selectedCover.ratio
        : (3 / 4);
    final double logicalW = kCoverReferenceWidth;
    final double logicalH = logicalW / physicalAspect;
    return Size(logicalW, logicalH);
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = SnapFitColors.surfaceOf(context);
    final stateVal = ref.watch(albumEditorViewModelProvider).value;
    final selectedTheme = stateVal?.selectedTheme ?? CoverTheme.classic;

    return Container(
      height: 460.h,
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: Column(
        children: [
          // Handle
          SizedBox(height: 12.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: SnapFitColors.textPrimaryOf(
                context,
              ).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // TabBar
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              // 추천 스티커 / 배경 색상 탭 텍스트는
              // 라이트 모드: 진한 검정, 다크 모드: 흰색으로 표시
              labelColor: SnapFitColors.isDark(context)
                  ? Colors.white
                  : Colors.black87,
              unselectedLabelColor: SnapFitColors.isDark(context)
                  ? Colors.white70
                  : Colors.black54,
              indicatorColor: SnapFitColors.accent,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: "추천스티커"),
                Tab(text: "배경 색상"),
                Tab(text: "배경"),
              ],
            ),
          ),

          const Divider(color: Colors.black12, height: 1),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                DecorateStickerTab(
                  surfaceColor: surfaceColor,
                  onStickerTap: (sticker) {
                    final editorVm = ref.read(
                      albumEditorViewModelProvider.notifier,
                    );
                    final stateVal = ref
                        .read(albumEditorViewModelProvider)
                        .value;
                    final canvasSize = _effectiveLogicalCanvasSize(
                      editorVm: editorVm,
                      stateVal: stateVal,
                    );
                    if (sticker.startsWith('deco:')) {
                      final payload = sticker.replaceFirst('deco:', '');
                      final parts = payload.split('@');
                      final style = parts.first;
                      final scale = parts.length > 1
                          ? (double.tryParse(parts[1]) ?? 1.0)
                          : 1.0;
                      editorVm.addDecorationSticker(
                        style,
                        canvasSize,
                        scale: scale,
                      );
                    } else if (sticker.startsWith('asset:')) {
                      final assetPath = sticker.replaceFirst('asset:', '');
                      editorVm.addAssetSticker(assetPath, canvasSize);
                    } else {
                      editorVm.addTextLayer(
                        sticker,
                        style: TextStyle(fontSize: 60.sp),
                        mode: TextStyleType.none,
                        canvasSize: canvasSize,
                      );
                    }
                    _closeSheet();
                  },
                ),
                DecorateColorTab(
                  surfaceColor: surfaceColor,
                  onColorTap: (colorValue) {
                    ref
                        .read(albumEditorViewModelProvider.notifier)
                        .updatePageBackgroundColor(colorValue);
                    _closeSheet();
                  },
                ),
                DecorateBackgroundThemeTab(
                  surfaceColor: surfaceColor,
                  selectedTheme: selectedTheme,
                  onThemeTap: (theme) {
                    _applyBackgroundTheme(theme);
                    _closeSheet();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _applyBackgroundTheme(CoverTheme theme) {
    final editorVm = ref.read(albumEditorViewModelProvider.notifier);
    final stateVal = ref.read(albumEditorViewModelProvider).value;
    final page = editorVm.currentPage;
    if (page == null || stateVal == null) return;

    // 커버/페이지 공통으로 선택 상태를 동일하게 맞춤
    ref.read(coverViewModelProvider.notifier).updateTheme(theme);
    editorVm.updateTheme(theme);

    final canvasSize = _effectiveLogicalCanvasSize(
      editorVm: editorVm,
      stateVal: stateVal,
    );

    final layers = List<LayerModel>.from(page.layers)
      ..removeWhere((l) => l.id.startsWith('_theme_bg_'));

    final asset = theme.imageAsset;
    if (asset != null && asset.isNotEmpty) {
      layers.insert(
        0,
        LayerModel(
          id: '_theme_bg_${theme.label}',
          type: LayerType.image,
          position: Offset.zero,
          width: canvasSize.width,
          height: canvasSize.height,
          imageUrl: 'asset:$asset',
          previewUrl: 'asset:$asset',
          opacity: 1.0,
          zIndex: -999,
        ),
      );
      editorVm.clearPageBackgroundColor();
      editorVm.updatePageLayers(layers, recordHistory: false);
      return;
    }

    // 이미지 테마가 없으면 그라디언트 중앙 톤을 배경색으로 적용
    final fallbackColor = _themeFallbackColor(theme);
    editorVm.updatePageLayers(layers, recordHistory: false);
    editorVm.updatePageBackgroundColor(fallbackColor.value);
  }

  Color _themeFallbackColor(CoverTheme theme) {
    final colors = theme.gradient.colors;
    if (colors.isEmpty) return const Color(0xFFF5F5F5);
    if (colors.length == 1) return colors.first;
    return Color.lerp(colors.first, colors.last, 0.5) ?? colors.first;
  }
}
