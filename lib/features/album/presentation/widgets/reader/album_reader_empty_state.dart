import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 18.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, color: Colors.white70, size: 36.sp),
            SizedBox(height: 10.h),
            Text(
              "내지 페이지가 없습니다.",
              style: TextStyle(color: Colors.white70, fontSize: 14.sp),
            ),
            SizedBox(height: 6.h),
            Text(
              "페이지를 추가하면 이 화면에서 크게 볼 수 있어요.",
              style: TextStyle(color: Colors.white54, fontSize: 12.sp),
            ),
            SizedBox(height: 14.h),
            TextButton(
              onPressed: () => _showAddPage(context, ref),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              child: Text(
                "페이지 추가",
                style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600),
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
