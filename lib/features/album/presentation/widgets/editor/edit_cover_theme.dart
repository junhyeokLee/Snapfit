import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/cover_theme.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../viewmodels/cover_view_model.dart';

import './edit_cover_theme_item.dart';

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

      final double itemWidthPx = previewWidth.w;
      final double separatorPx = 20.w;
      final double horizontalPaddingPx = 20.w;

      final double screenWidth = MediaQuery.of(context).size.width;
      final double itemStart = horizontalPaddingPx + (itemWidthPx + separatorPx) * index;
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
    final editorVm = ref.read(albumEditorViewModelProvider.notifier);
    final editorSt = ref.watch(albumEditorViewModelProvider).asData?.value;

    if (editorSt == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedTheme = editorSt.selectedTheme;
    final aspect = editorSt.selectedCover.ratio;
    
    const double maxDimension = 125.0;
    final double previewBaseWidth;
    final double previewBaseHeight;
    if (aspect >= 1.0) {
      previewBaseWidth = maxDimension;
      previewBaseHeight = maxDimension / aspect;
    } else {
      previewBaseHeight = maxDimension;
      previewBaseWidth = maxDimension * aspect;
    }

    final themes = CoverTheme.values;
    final selectedIndex = themes.indexOf(selectedTheme);
    debugPrint('[CoverThemeSize] aspect=$aspect cover=${editorSt.selectedCover.name} width=$previewBaseWidth height=$previewBaseHeight');
    _scrollToSelected(selectedIndex, previewBaseWidth);

    return Material(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      color: const Color(0xFF0F1113),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 300.h,
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Column(
          children: [
            SizedBox(height: 12.h),
            Container(
              width: 48.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: SnapFitColors.overlayMediumOf(context),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),

            Expanded(
              child: Center(
                child: SizedBox(
                  height: 160.h, // 충분한 높이 확보 (스케일 효과 고려)
                  child: ListView.separated(
                    controller: _scrollController,
                    clipBehavior: Clip.none,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    itemCount: themes.length,
                    separatorBuilder: (_, __) => SizedBox(width: 20.w),
                    itemBuilder: (context, index) {
                      final theme = themes[index];
                      return EditCoverThemeItem(
                        theme: theme,
                        isSelected: theme == selectedTheme,
                        width: previewBaseWidth.w,
                        height: previewBaseHeight.w, // .w for both to preserve aspect ratio
                        onTap: () {
                          vm.updateTheme(theme);
                          editorVm.updateTheme(theme);
                          _scrollToSelected(index, previewBaseWidth);
                        },
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