import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../../../shared/widgets/snapfit_primary_gradient_background.dart';
import '../editor/page_template_picker.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../views/page_editor_screen.dart';

/// 앨범 보기 화면: 내지 페이지가 없을 때 표시
class AlbumReaderEmptyState extends ConsumerWidget {
  final bool isLoading;
  final Size baseCanvasSize;

  const AlbumReaderEmptyState({
    super.key,
    required this.isLoading,
    required this.baseCanvasSize,
  });

  static bool _logged = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('AlbumReaderEmptyState', '앨범 리더 빈 상태 · 페이지 추가 유도');
    }
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: SnapFitColors.textSecondaryOf(context),
        ),
      );
    }
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 18.h),
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: SnapFitColors.overlayLightOf(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              color: SnapFitColors.textSecondaryOf(context),
              size: 36.sp,
            ),
            SizedBox(height: 10.h),
            Text(
              "내지 페이지가 없습니다.",
              style: TextStyle(
                color: SnapFitColors.textSecondaryOf(context),
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              "페이지를 추가하면 이 화면에서 크게 볼 수 있어요.",
              style: TextStyle(
                color: SnapFitColors.textMutedOf(context),
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 14.h),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showAddPage(context, ref),
                borderRadius: BorderRadius.circular(10.r),
                child: SnapFitPrimaryGradientBackground(
                  borderRadius: BorderRadius.circular(10.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Text(
                      "페이지 추가",
                      style: TextStyle(
                        color: SnapFitColors.pureWhite,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPage(BuildContext context, WidgetRef ref) {
    PageTemplatePicker.show(context, onSelect: (template) {
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      vm.addPageFromTemplate(template, baseCanvasSize);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PageEditorScreen(
              initialPageIndex: vm.currentPageIndex,
            ),
          ),
        );
        if (!context.mounted) return;
        if (saved != true) {
          ref.read(albumEditorViewModelProvider.notifier).removeLastPage();
        }
      });
    });
  }
}
