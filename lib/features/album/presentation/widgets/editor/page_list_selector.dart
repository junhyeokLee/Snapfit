import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
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

  const PageListSelector({
    super.key,
    required this.pages,
    required this.currentPageIndex,
    required this.onPageSelected,
    this.onAddPage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(albumEditorViewModelProvider).asData?.value;
    final selectedTheme = editorState?.selectedTheme;
    final selectedCover = editorState?.selectedCover;

    return SizedBox(
      height: 80.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        itemCount: pages.length + 1, // 마지막에 + 버튼 추가
        separatorBuilder: (context, index) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          // 마지막 아이템 = 페이지 추가 버튼
          if (index == pages.length) {
            return _buildAddButton(context);
          }

          final page = pages[index];
          final isSelected = index == currentPageIndex;
          final isCover = index == 0;

          // 0번은 커버, 1번부터 내지
          String label = isCover ? '커버' : '${index}페이지';

          return GestureDetector(
            onTap: () => onPageSelected(index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50.w,
                  height: 50.w,
                  decoration: BoxDecoration(
                    color: SnapFitColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(8.r),
                    border: isSelected
                        ? Border.all(color: SnapFitColors.accent, width: 2)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
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
                SizedBox(height: 4.h),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isSelected ? SnapFitColors.accent : SnapFitColors.textSecondaryOf(context),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
    final logicalInnerSize = Size(300.0, 300.0 / ratio);
    final logicalCoverSize = Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
    
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
            leftSpine: 0 // 썸네일에서 spine 제거
            ,
            onCoverSizeChanged: (_) {},
            buildImage: (layer) => buildStaticImage(layer),
            buildText: (layer) => buildStaticText(layer),
            sortedByZ: (list) => list..sort((a,b) => a.id.compareTo(b.id)),
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
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: onAddPage,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: SnapFitColors.textSecondaryOf(context).withOpacity(0.5),
                style: BorderStyle.solid,
                width: 1,
              ),
            ),
            child: Icon(Icons.add, color: SnapFitColors.textSecondaryOf(context)),
          ),
          SizedBox(height: 4.h),
          Text('', style: TextStyle(fontSize: 12.sp)),
        ],
      ),
    );
  }
}

