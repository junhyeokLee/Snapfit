import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/album_page.dart';
import '../../controllers/layer_builder.dart';
import '../editor/page_template_picker.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../views/page_editor_screen.dart';
import 'album_reader_page_content.dart';

/// 앨범 보기 화면: 하단 썸네일 스트립 + 페이지 추가 버튼
class AlbumReaderThumbnailStrip extends ConsumerWidget {
  final List<AlbumPage> pages;
  final PageController? pageController;
  final LayerBuilder previewBuilder;
  final Size baseCanvasSize;
  final double height;

  const AlbumReaderThumbnailStrip({
    super.key,
    required this.pages,
    this.pageController,
    required this.previewBuilder,
    required this.baseCanvasSize,
    this.height = 70,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratio = baseCanvasSize.width / baseCanvasSize.height;
    final thumbW = height * ratio;
    return SizedBox(
      height: height + 12.h,
      child: pageController != null
          ? AnimatedBuilder(
              animation: pageController!,
              builder: (context, _) {
                final page = pageController!.hasClients ? (pageController!.page ?? 0) : 0;
                final current = page.round().clamp(0, (pages.length - 1).clamp(0, pages.length));
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  itemCount: pages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == pages.length) {
                      return _AddPageThumb(
                        width: thumbW,
                        height: height,
                        onTap: () => _showAddPage(context, ref),
                      );
                    }
                    final pageLayers = pages[index].layers;
                    final isSelected = index == current;
                    return GestureDetector(
                      onTap: () {
                        pageController!.animateToPage(
                          index,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: Container(
                  width: thumbW,
                  height: height,
                  margin: EdgeInsets.only(right: 8.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5.r),
                    child: AlbumReaderPageContent(
                      layers: pageLayers,
                      targetW: thumbW,
                      targetH: height,
                      previewBuilder: previewBuilder,
                      baseCanvasSize: baseCanvasSize,
                    ),
                  ),
                ),
              );
            },
          );
              },
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              itemCount: pages.length,
              itemBuilder: (context, index) {
                final pageLayers = pages[index].layers;
                return Container(
                  width: thumbW,
                  height: height,
                  margin: EdgeInsets.only(right: 8.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: Colors.white24, width: 1),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5.r),
                    child: AlbumReaderPageContent(
                      layers: pageLayers,
                      targetW: thumbW,
                      targetH: height,
                      previewBuilder: previewBuilder,
                      baseCanvasSize: baseCanvasSize,
                    ),
                  ),
                );
              },
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

class _AddPageThumb extends StatelessWidget {
  final double width;
  final double height;
  final VoidCallback onTap;

  const _AddPageThumb({
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: EdgeInsets.only(right: 8.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: Colors.white24, width: 1),
          color: Colors.white.withOpacity(0.08),
        ),
        child: Icon(Icons.add, color: Colors.white, size: 22.sp),
      ),
    );
  }
}
