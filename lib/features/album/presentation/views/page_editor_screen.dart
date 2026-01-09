import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../widgets/editor/edit_toolbar.dart';
import '../viewmodels/album_editor_view_model.dart';

class PageEditorScreen extends ConsumerWidget {
  const PageEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. ViewModel과 상태(State)를 가져옵니다.
    final asyncState = ref.watch(albumEditorViewModelProvider);
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final state = asyncState.value;

    return Scaffold(
      backgroundColor: const Color(0xFF7d7a97),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("페이지 편집", style: TextStyle(color: Colors.white, fontSize: 16.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("저장", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _buildLargePageCanvas(state),
            ),
          ),
          // 2. EditToolbar에 필요한 인자들을 전달합니다.
          EditToolbar(
            vm: vm, // ViewModel 전달
            // selected: state?.selectedLayer, // 필요 시 현재 선택된 레이어 전달
            onAddText: () {
              // 텍스트 추가 로직 (예: 텍스트 입력 오버레이 띄우기)
              print("텍스트 추가 클릭");
            },
            onAddPhoto: () {
              // 사진/오버레이 추가 로직 (예: 갤러리 열기)
              print("사진 추가 클릭");
            },
            onOpenCoverSelector: () {
              // 커버 또는 레이아웃 변경 로직
              print("커버/레이아웃 선택 클릭");
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLargePageCanvas(AlbumEditorState? state) {
    return Container(
      width: 300.w,
      height: 400.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20)],
      ),
      child: const Center(
        child: Text("편집할 페이지 내용", style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}