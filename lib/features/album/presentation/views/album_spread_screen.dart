import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/features/album/presentation/screens/page_editor_screen.dart';
import '../viewmodels/album_editor_view_model.dart';

class AlbumSpreadScreen extends ConsumerWidget {
  const AlbumSpreadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(albumEditorViewModelProvider).value;
    final vm = ref.read(albumEditorViewModelProvider.notifier);

    if (state == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // 0번은 커버이므로 제외하고 1번부터 펼침면으로 구성 (예: 1-2, 3-4...)
    final pages = vm.pages.where((p) => !p.isCover).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7d7a97), Color(0xFF9893a9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: Center(
                  child: _buildSpreadView(context, ref, pages),
                ),
              ),
              _buildPageThumbnailList(ref, vm),
            ],
          ),
        ),
      ),
    );
  }

  // 상단 바
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text("앨범 편집", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: () => print("제작 요청"),
            child: Text("완료", style: TextStyle(color: Colors.white, fontSize: 16.sp)),
          ),
        ],
      ),
    );
  }

  // 펼침면 (왼쪽/오른쪽 페이지)
  Widget _buildSpreadView(BuildContext context, WidgetRef ref, List<dynamic> pages) {
    // 현재 선택된 페이지 인덱스를 기준으로 해당 펼침면을 찾음
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSingleSpreadPage(context, ref, "왼쪽 페이지"),
        SizedBox(width: 2.w), // 책 중앙선 느낌
        _buildSingleSpreadPage(context, ref, "오른쪽 페이지"),
      ],
    );
  }

  Widget _buildSingleSpreadPage(BuildContext context, WidgetRef ref, String label) {
    return GestureDetector(
      onTap: () {
        // 클릭 시 상세 편집 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PageEditorScreen()),
        );
      },
      child: Container(
        width: 160.w,
        height: 220.h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(4.r),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(2, 2))],
        ),
        child: Center(child: Text(label, style: TextStyle(color: Colors.grey))),
      ),
    );
  }

  // 하단 페이지 썸네일 리스트 + 추가 버튼
  Widget _buildPageThumbnailList(WidgetRef ref, AlbumEditorViewModel vm) {
    return Container(
      height: 100.h,
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: vm.pages.length + 1, // +1은 추가 버튼
        itemBuilder: (context, index) {
          if (index == vm.pages.length) {
            return _buildAddButton(vm);
          }
          final isSelected = vm.currentPageIndex == index;
          return GestureDetector(
            onTap: () => vm.goToPage(index),
            child: Container(
              width: 60.w,
              margin: EdgeInsets.only(right: 10.w),
              decoration: BoxDecoration(
                border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                borderRadius: BorderRadius.circular(4.r),
                color: Colors.white24,
              ),
              child: Center(child: Text("${index == 0 ? '커버' : index}", style: TextStyle(color: Colors.white))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddButton(AlbumEditorViewModel vm) {
    return GestureDetector(
      onTap: () => vm.addPage(),
      child: Container(
        width: 60.w,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
