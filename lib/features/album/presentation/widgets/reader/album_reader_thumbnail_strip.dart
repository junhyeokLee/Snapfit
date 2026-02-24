import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/utils/screen_logger.dart';
import '../../../domain/entities/album_page.dart';
import '../../controllers/layer_builder.dart';
import '../editor/page_template_picker.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../views/page_editor_screen.dart';
import 'album_reader_page_content.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../cover/cover.dart';
import '../home/home_album_helpers.dart';

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

  static bool _logged = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('AlbumReaderThumbnailStrip', '앨범 리더 썸네일 스트립 · 페이지 추가');
    }
    // [Fix] 내지 썸네일은 300xH, 커버 썸네일은 500xH (kCoverReferenceWidth) 논리 좌표계 사용
    final double aspect = baseCanvasSize.width / baseCanvasSize.height;
    final Size logicalInnerSize = Size(300.0, 300.0 / aspect);
    final Size logicalCoverSize = Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
    
    final thumbW = height * aspect;
    
    return SizedBox(
      height: height + 12.h,
      child: pageController != null
          ? AnimatedBuilder(
              animation: pageController!,
              builder: (context, _) {
                final pageValue = pageController!.hasClients ? (pageController!.page ?? 0) : 0;
                final current = pageValue.round().clamp(0, (pages.length - 1).clamp(0, pages.length));
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  itemCount: pages.length, // [Fix] '+' 버튼 제거
                  itemBuilder: (context, index) {
                    final page = pages[index];
                    final pageLayers = page.layers;
                    final isSelected = index == current;
                    final isCover = index == 0;
                    
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
                          child: isCover
                              // [Fix] 커버는 언제나 메인 뷰어와 똑같은 렌더링을 보장하기 위해 CoverLayout & FittedBox 사용
                              // (CoverLayout 자체는 AspectRatio로 동작하므로 내부에서 500xH 기준임을 강제해야 폰트 크기 등이 비례 축소됨)
                              ? FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: logicalCoverSize.width,
                                    height: logicalCoverSize.height,
                                    child: CoverLayout(
                                      aspect: logicalCoverSize.width / logicalCoverSize.height,
                                      layers: pageLayers,
                                      isInteracting: false,
                                      leftSpine: 0,
                                      onCoverSizeChanged: (_) {},
                                      buildImage: (layer) => buildStaticImage(layer),
                                      buildText: (layer) => buildStaticText(layer),
                                      sortedByZ: (list) => list..sort((a,b) => a.id.compareTo(b.id)),
                                      theme: ref.watch(albumEditorViewModelProvider).value?.selectedTheme ?? resolveCoverTheme(null),
                                    ),
                                  ),
                                )
                              // [Fix] 내지는 300xH 공통 렌더링 사용
                              : AlbumReaderPageContent(
                                  layers: pageLayers,
                                  targetW: thumbW,
                                  targetH: height,
                                  previewBuilder: previewBuilder,
                                  baseCanvasSize: logicalInnerSize,
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
                final isCover = index == 0;
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
                    child: isCover
                        ? FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: logicalCoverSize.width,
                              height: logicalCoverSize.height,
                              child: CoverLayout(
                                aspect: logicalCoverSize.width / logicalCoverSize.height,
                                layers: pageLayers,
                                isInteracting: false,
                                leftSpine: 0,
                                onCoverSizeChanged: (_) {},
                                buildImage: (layer) => buildStaticImage(layer),
                                buildText: (layer) => buildStaticText(layer),
                                sortedByZ: (list) => list..sort((a,b) => a.id.compareTo(b.id)),
                                theme: ref.watch(albumEditorViewModelProvider).value?.selectedTheme ?? resolveCoverTheme(null),
                              ),
                            ),
                          )
                        : AlbumReaderPageContent(
                            layers: pageLayers,
                            targetW: thumbW,
                            targetH: height,
                            previewBuilder: previewBuilder,
                            baseCanvasSize: logicalInnerSize,
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
