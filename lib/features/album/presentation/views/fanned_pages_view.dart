import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/widgets/circle_action_button.dart';
import '../../../../shared/widgets/snapfit_gradient_background.dart';
import '../../domain/entities/album.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/fanned/fanned_page_stack.dart';

/// Paper 앱처럼: 부채꼴로 펼쳐진 페이지를 스와이프로 넘기기.
/// 좌상단: "날짜/제목" + "N Pages", 우하단: 흰 원형 버튼 + 진한 아이콘.
class FannedPagesView extends ConsumerStatefulWidget {
  const FannedPagesView({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  ConsumerState<FannedPagesView> createState() => _FannedPagesViewState();
}

class _FannedPagesViewState extends ConsumerState<FannedPagesView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(albumEditorViewModelProvider);
    final state = asyncState.value;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final homeAsync = ref.watch(homeViewModelProvider);
    final albums = homeAsync.value ?? const <Album>[];

    if (state == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final pages = vm.pages;
    final pageCount = pages.isEmpty ? 1 : pages.length;
    final ratio = state.selectedCover.ratio;
    final screenH = MediaQuery.sizeOf(context).height;
    final pageH = (screenH * 0.52).clamp(240.0, 400.0);
    final pageW = pageH * ratio;

    final editingId = vm.editingAlbumId;
    final Album? currentAlbum = editingId == null
        ? null
        : albums.cast<Album?>().firstWhere(
              (a) => a != null && a.id == editingId,
              orElse: () => null,
            );
    final headerTitle = currentAlbum?.createdAt.isNotEmpty == true
        ? currentAlbum!.createdAt
        : '앨범';

    return SnapFitGradientBackground(
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 16.w,
              top: 16.h,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    headerTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    '${pages.length} Pages',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15.sp,
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: PageView.builder(
                itemCount: pageCount,
                controller: _pageController,
                itemBuilder: (context, index) {
                  return FannedPageStack(
                    frontPageIndex: index,
                    pageCount: pages.length,
                    pageWidth: pageW,
                    pageHeight: pageH,
                    pages: pages,
                    selectedCover: state.selectedCover,
                    selectedTheme: state.selectedTheme,
                    coverCanvasSize: state.coverCanvasSize,
                    currentAlbum: currentAlbum,
                  );
                },
              ),
            ),
            Positioned(
              right: 20.w,
              bottom: 32.h,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleActionButton(
                    icon: Icons.more_horiz,
                    onPressed: () {},
                    variant: CircleButtonVariant.white,
                    size: 46,
                  ),
                  SizedBox(width: 10.w),
                  CircleActionButton(
                    icon: Icons.upload_outlined,
                    onPressed: () {},
                    variant: CircleButtonVariant.white,
                    size: 46,
                  ),
                  SizedBox(width: 10.w),
                  CircleActionButton(
                    icon: Icons.delete_outline,
                    onPressed: () {},
                    variant: CircleButtonVariant.white,
                    size: 46,
                  ),
                  SizedBox(width: 10.w),
                  CircleActionButton(
                    icon: Icons.add,
                    onPressed: () => vm.addPage(),
                    variant: CircleButtonVariant.white,
                    size: 46,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
