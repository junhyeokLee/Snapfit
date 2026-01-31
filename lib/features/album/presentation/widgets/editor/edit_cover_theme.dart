import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../shared/widgets/spine_painter.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../viewmodels/cover_view_model.dart';

class EditCoverTheme extends ConsumerStatefulWidget {
  const EditCoverTheme({super.key});
  @override
  ConsumerState<EditCoverTheme> createState() => _EditCoverThemeState();
}

class _EditCoverThemeState extends ConsumerState<EditCoverTheme> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected(int index, double previewWidth) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || index < 0) return;

      // 실제 픽셀 기준으로 환산된 아이템/간격/패딩 폭 계산
      final double itemWidthPx = previewWidth.w;   // 각 아이템의 실제 렌더 폭
      final double separatorPx = 20.w;             // ListView.separated 의 간격
      final double horizontalPaddingPx = 20.w;     // ListView 의 좌/우 패딩

      final double screenWidth = MediaQuery.of(context).size.width;

      // index 번째 아이템의 왼쪽 시작 위치 (패딩 포함)
      final double itemStart =
          horizontalPaddingPx + (itemWidthPx + separatorPx) * index;

      // 선택된 아이템이 화면 정중앙에 오도록 타깃 오프셋 계산
      // 중앙정렬: itemCenter - screenWidth/2
      final double itemCenter = itemStart + (itemWidthPx / 2);
      final double targetOffset = itemCenter - (screenWidth / 2);

      final min = _scrollController.position.minScrollExtent;
      final max = _scrollController.position.maxScrollExtent;

      _scrollController.animateTo(
        targetOffset.clamp(min, max),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(coverViewModelProvider.notifier);
    final st = ref.watch(coverViewModelProvider).asData?.value;
    final editorVm = ref.read(albumEditorViewModelProvider.notifier);
    final editorSt = ref.watch(albumEditorViewModelProvider).asData?.value;

    if (editorSt == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // if (st == null) {
    //   return const Center(child: CircularProgressIndicator());
    // }

    // final selectedTheme = st.selectedTheme;

    // final aspect = st.selectedCover.ratio; // 선택된 커버 비율
    final selectedTheme = editorSt.selectedTheme; // ✅ editorState의 테마 사용
    final aspect = editorSt.selectedCover.ratio;
    double previewBaseHeight = 0.0;
    double previewBaseWidth = 0.0;

    if (aspect < 1) { // 세로형
      previewBaseHeight = 115.0;
      previewBaseWidth = previewBaseHeight * aspect;
    } else if (aspect > 1) { // 가로형
      previewBaseHeight = 110.0;
      previewBaseWidth = previewBaseHeight * aspect;
    } else { // 정사각형
      previewBaseHeight = 125.0;
      previewBaseWidth = previewBaseHeight * aspect;
    }

    final themes = CoverTheme.values;
    final selectedIndex = themes.indexOf(selectedTheme);
    _scrollToSelected(selectedIndex, previewBaseWidth);

    const double miniLeftSpine = 8.0;
    const double miniRightRadius = 4.0;
    const double miniBottomRadius = 4.0;

    return Material(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      color: const Color(0xFF9893a9),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 300.h,
        child: Column(
          children: [
            SizedBox(height: 12.h),
            Container(
              width: 48.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),

            // 테마 리스트
            Expanded(
              child: Center(
                child: SizedBox(
                  height: 120.h,
                  child: ListView.separated(
                    controller: _scrollController,
                    clipBehavior: Clip.none,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    itemCount: themes.length,
                    separatorBuilder: (_, __) => SizedBox(width: 20.w),
                    itemBuilder: (context, index) {
                      final theme = themes[index];
                      final isSelected = theme == selectedTheme;

                      return GestureDetector(
                        onTap: () {
                          vm.updateTheme(theme);
                          editorVm.updateTheme(theme);
                          _scrollToSelected(index, previewBaseWidth);
                        },
                        child: AnimatedScale(
                          scale: isSelected ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            transform: isSelected
                                ? (Matrix4.identity()..translate(0.0, -6.h))
                                : Matrix4.identity(),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12.r),
                                bottomRight: Radius.circular(12.r),
                              ),
                              boxShadow: isSelected
                                  ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 4.r,
                                  offset: Offset(5.w, 20.h),
                                ),
                              ]
                                  : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 4.r,
                                  offset: Offset(4.w, 8.h),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(miniRightRadius.r),
                                bottomRight: Radius.circular(miniBottomRadius.r),
                              ),
                              child: SizedBox(
                                width: previewBaseWidth.w,
                                height: previewBaseHeight.h,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // 커버 이미지 or 그라데이션
                                    Container(
                                      decoration: BoxDecoration(
                                        image: theme.imageAsset != null
                                            ? DecorationImage(
                                          image: AssetImage(theme.imageAsset!),
                                          fit: BoxFit.cover,
                                        )
                                            : null,
                                        gradient: theme.imageAsset == null ? theme.gradient : null,
                                      ),
                                    ),
                                    // 왼쪽 봉제선
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: CustomPaint(
                                        painter: SpinePainter(
                                          baseStart: Colors.black.withOpacity(0.1),
                                          baseEnd: Colors.black.withOpacity(0.1),
                                        ),
                                        size: Size(miniLeftSpine.w, double.infinity),
                                      ),
                                    ),
                                    // 라벨
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        margin: EdgeInsets.only(bottom: 6.h),
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(10.r),
                                        ),
                                        child: Text(
                                          theme.label,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}