import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../domain/entities/album_page.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart'; // [Fix] 추가
import '../cover/cover.dart';
import '../home/home_album_helpers.dart';
import '../reader/album_reader_page_content.dart';

class PageListSelector extends ConsumerWidget {
  final List<AlbumPage> pages;
  final int currentPageIndex;
  final Function(int) onPageSelected;
  final VoidCallback? onAddPage;
  final VoidCallback? onDeleteCurrentPage;
  final bool canDeleteCurrentPage;

  const PageListSelector({
    super.key,
    required this.pages,
    required this.currentPageIndex,
    required this.onPageSelected,
    this.onAddPage,
    this.onDeleteCurrentPage,
    this.canDeleteCurrentPage = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(albumEditorViewModelProvider).asData?.value;
    final selectedTheme = editorState?.selectedTheme;
    final selectedCover = editorState?.selectedCover;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerticalRail = constraints.maxWidth < 120;
        return SizedBox(
          height: isVerticalRail ? double.infinity : 88.h,
          width: isVerticalRail ? 60 : null,
          child: ListView.separated(
            padding: isVerticalRail
                ? const EdgeInsets.symmetric(horizontal: 6, vertical: 8)
                : EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 6.h),
            scrollDirection: isVerticalRail ? Axis.vertical : Axis.horizontal,
            itemCount: pages.length + 1, // 마지막에 + 버튼 추가
            separatorBuilder: (context, index) => SizedBox(
              width: isVerticalRail ? 0 : 12.w,
              height: isVerticalRail ? 8 : 0,
            ),
            itemBuilder: (context, index) {
              // 마지막 아이템 = 페이지 추가 버튼
              if (index == pages.length) {
                return _buildAddButton(context);
              }

              final page = pages[index];
              final isSelected = index == currentPageIndex;
              final isCover = index == 0;

              // 0번은 커버, 1번부터 내지
              final label = isCover ? '표지' : '${index}쪽';

              return SnapFitPressable(
                onTap: () => onPageSelected(index),
                pressedScale: 0.96,
                borderRadius: BorderRadius.circular(14.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: SnapFitMotion.settle,
                      width: isVerticalRail ? 44 : (isSelected ? 50.w : 46.w),
                      height: isVerticalRail ? 42 : (isSelected ? 48.h : 44.h),
                      padding: EdgeInsets.all(
                        isVerticalRail ? 3 : (isSelected ? 4.w : 3.w),
                      ),
                      decoration: BoxDecoration(
                        color: SnapFitColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFD6B892).withOpacity(0.72)
                              : SnapFitColors.overlayLightOf(context),
                          width: isSelected ? 1.4 : 0.8,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFD6B892,
                                  ).withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child: _buildPageThumbnail(
                                context,
                                ref: ref,
                                page: page,
                                isCover: isCover,
                                selectedTheme: selectedTheme,
                                selectedCover: selectedCover,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: TweenAnimationBuilder<double>(
                                  key: ValueKey(
                                    'pageSelectorSelectionGlow-$currentPageIndex',
                                  ),
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 96),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    final glow = math.sin(value * math.pi);
                                    return DecoratedBox(
                                      key: const Key(
                                        'pageSelectorSelectionGlow',
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFD6B892,
                                            ).withOpacity(0.22 * glow),
                                            blurRadius: 10 + 6 * glow,
                                            spreadRadius: 0.5 * glow,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          if (isSelected)
                            Positioned(
                              left: 8.w,
                              right: 8.w,
                              bottom: -3.h,
                              child: AnimatedContainer(
                                duration: SnapFitMotion.pageTurnFast,
                                curve: SnapFitMotion.pageTurnCurve,
                                height: 2.5.h,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7A5F41),
                                  borderRadius: BorderRadius.circular(999.r),
                                ),
                              ),
                            ),
                          if (isSelected && canDeleteCurrentPage && !isCover)
                            Positioned(
                              top: -5.h,
                              right: -5.w,
                              child: GestureDetector(
                                onTap: onDeleteCurrentPage,
                                child: Container(
                                  width: 20.w,
                                  height: 20.w,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFB96363,
                                    ).withOpacity(0.92),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.16),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 13.sp,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isVerticalRail) ...[
                      SizedBox(height: 3.h),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isSelected
                              ? const Color(0xFF5A4634)
                              : SnapFitColors.textSecondaryOf(context),
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 페이지 썸네일 빌드
  Widget _buildPageThumbnail(
    BuildContext context, {
    required WidgetRef ref, // [Fix] 파라미터 추가
    required AlbumPage page,
    required bool isCover,
    dynamic selectedTheme,
    dynamic selectedCover,
  }) {
    final ratio = selectedCover?.ratio ?? 3 / 4;
    final logicalInnerSize = Size(
      kCoverReferenceWidth,
      kCoverReferenceWidth / ratio,
    );
    final logicalCoverSize = Size(
      kCoverReferenceWidth,
      kCoverReferenceWidth / ratio,
    );
    final coverInteraction = LayerInteractionManager.preview(
      ref,
      () => logicalCoverSize,
    );
    final coverBuilder = LayerBuilder(coverInteraction, () => logicalCoverSize);

    if (isCover) {
      // 커버: CoverLayout으로 테마 + 레이어 렌더링
      final theme = selectedTheme ?? resolveCoverTheme(null);
      // [Fix] 커버는 언제나 메인 뷰어와 똑같은 렌더링을 보장하기 위해 CoverLayout & FittedBox 사용
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: logicalCoverSize.width,
          height: logicalCoverSize.height,
          child: CoverLayout(
            aspect: logicalCoverSize.width / logicalCoverSize.height,
            layers: page.layers,
            isInteracting: false,
            leftSpine: 0, // 썸네일에서 spine 제거
            onCoverSizeChanged: (_) {},
            buildImage: (layer) =>
                coverBuilder.buildImage(layer, isCover: true),
            buildText: (layer) => coverBuilder.buildText(layer, isCover: true),
            sortedByZ: coverInteraction.sortByZ,
            theme: theme,
          ),
        ),
      );
    }

    // 내지: 전체 레이어 렌더링 지원 (AlbumReaderPageContent 활용)
    // 썸네일 크기에 맞게 스케일링된 페이지 내용 표시
    return AlbumReaderPageContent(
      layers: page.layers,
      targetW: 50.w,
      targetH: 50.w,
      previewBuilder: LayerBuilder(
        LayerInteractionManager.preview(ref, () => logicalInnerSize),
        () => logicalInnerSize,
      ),
      baseCanvasSize: logicalInnerSize,
      backgroundColor: page.backgroundColor != null
          ? Color(page.backgroundColor!)
          : null,
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return SnapFitPressable(
      onTap: onAddPage,
      pressedScale: 0.96,
      borderRadius: BorderRadius.circular(14.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context).withOpacity(0.62),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: SnapFitColors.textSecondaryOf(context).withOpacity(0.28),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 17,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
                SizedBox(height: 1.h),
                Text(
                  '추가',
                  style: TextStyle(
                    fontSize: 8,
                    color: SnapFitColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          Text('', style: TextStyle(fontSize: 9)),
        ],
      ),
    );
  }
}
