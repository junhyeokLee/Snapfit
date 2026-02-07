import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../viewmodels/album_editor_view_model.dart';
import '../../views/page_editor_screen.dart';

/// 앨범 보기 화면: 페이지 번호 + 편집 버튼
class AlbumReaderFooter extends ConsumerWidget {
  final PageController pageController;
  final int totalPages;

  const AlbumReaderFooter({
    super.key,
    required this.pageController,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Row(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: pageController,
              builder: (context, _) {
                final page = pageController.hasClients ? (pageController.page ?? 0) : 0;
                final current = page.round().clamp(0, (totalPages - 1).clamp(0, totalPages));
                return Text(
                  "${current + 1} / $totalPages",
                  style: TextStyle(color: Colors.white70, fontSize: 13.sp),
                );
              },
            ),
          ),
          TextButton(
            onPressed: () {
              final page = pageController.hasClients ? (pageController.page ?? 0) : 0;
              final current = page.round().clamp(0, (totalPages - 1).clamp(0, totalPages));
              final pageIndex = current + 1;
              final vm = ref.read(albumEditorViewModelProvider.notifier);
              if (pageIndex >= 1 && pageIndex < vm.pages.length) {
                vm.goToPage(pageIndex);
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PageEditorScreen(initialPageIndex: pageIndex)),
              );
            },
            child: Text(
              "편집",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }
}
