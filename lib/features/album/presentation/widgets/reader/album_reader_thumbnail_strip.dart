import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/utils/screen_logger.dart';
import '../../../domain/entities/album_page.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../viewmodels/album_editor_view_model.dart';
import 'album_reader_page_content.dart';
import '../../../../../core/constants/cover_size.dart';
import '../cover/cover.dart';
import '../home/home_album_helpers.dart';

/// 앨범 보기 화면: 하단 썸네일 스트립 (스프레드 단위)
///
/// - 아이템 0       : 커버 (단독)
/// - 아이템 1       : 내지 1-2 페이지 (두 페이지 나란히)
/// - 아이템 2       : 내지 3-4 페이지 (두 페이지 나란히)
/// - ...
///
/// pageController 인덱스 = spreadIndex (0=커버, 1=1-2, 2=3-4 ...)
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

  // 스프레드 아이템 목록 빌드
  // 아이템[0] = 커버 페이지 인덱스 목록 [0]
  // 아이템[1] = [1, 2], 아이템[2] = [3, 4] ...
  static List<List<int>> _buildSpreadItems(int pageCount) {
    if (pageCount == 0) return [];
    final result = <List<int>>[];
    // 커버
    result.add([0]);
    // 내지 (pages[1] 이후)
    for (int i = 1; i < pageCount; i += 2) {
      if (i + 1 < pageCount) {
        result.add([i, i + 1]);
      } else {
        result.add([i]);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget(
        'AlbumReaderThumbnailStrip',
        '앨범 리더 썸네일 스트립 · 스프레드 뷰',
      );
    }

    final double aspect = baseCanvasSize.width / baseCanvasSize.height;
    final Size logicalInnerSize = Size(300.0, 300.0 / aspect);
    final Size logicalCoverSize = Size(
      kCoverReferenceWidth,
      kCoverReferenceWidth / aspect,
    );

    // 커버 썸네일은 LayerBuilder(프레임 포함)로 동일 렌더링
    final coverInteraction = LayerInteractionManager.preview(
      ref,
      () => logicalCoverSize,
    );
    final coverBuilder = LayerBuilder(coverInteraction, () => logicalCoverSize);

    // 단일 썸네일 너비
    final double singleThumbW = height * aspect;
    // 스프레드(2페이지) 썸네일 너비 = 단일 x2 + 가운데 구분선 0.5
    final double spreadThumbW = singleThumbW * 2 + 1;

    final spreadItems = _buildSpreadItems(pages.length);

    if (pageController != null) {
      return SizedBox(
        height: height + 12.h,
        child: AnimatedBuilder(
          animation: pageController!,
          builder: (context, _) {
            final spreadIdx = pageController!.hasClients
                ? (pageController!.page?.round() ?? 0)
                : 0;

            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              itemCount: spreadItems.length,
              itemBuilder: (context, i) {
                final pageIndices = spreadItems[i];
                final isSelected = i == spreadIdx;
                final isCover = i == 0;

                return GestureDetector(
                  onTap: () {
                    pageController!.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: Container(
                    width: isCover ? singleThumbW : spreadThumbW,
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
                          // ── 커버 썸네일 ──
                          ? FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: logicalCoverSize.width,
                                height: logicalCoverSize.height,
                                child: CoverLayout(
                                  aspect:
                                      logicalCoverSize.width /
                                      logicalCoverSize.height,
                                  layers: pages[0].layers,
                                  isInteracting: false,
                                  leftSpine: 0,
                                  onCoverSizeChanged: (_) {},
                                  buildImage: (layer) => coverBuilder
                                      .buildImage(layer, isCover: true),
                                  buildText: (layer) => coverBuilder.buildText(
                                    layer,
                                    isCover: true,
                                  ),
                                  sortedByZ: coverInteraction.sortByZ,
                                  theme:
                                      ref
                                          .watch(albumEditorViewModelProvider)
                                          .value
                                          ?.selectedTheme ??
                                      resolveCoverTheme(null),
                                ),
                              ),
                            )
                          // ── 스프레드 썸네일 (1~2페이지 나란히) ──
                          : Row(
                              children: [
                                for (
                                  int pi = 0;
                                  pi < pageIndices.length;
                                  pi++
                                ) ...[
                                  if (pi > 0)
                                    // 페이지 사이 구분선
                                    Container(
                                      width: 1,
                                      height: height,
                                      color: Colors.grey.shade300,
                                    ),
                                  Expanded(
                                    child: AlbumReaderPageContent(
                                      layers: pages[pageIndices[pi]].layers,
                                      targetW: singleThumbW,
                                      targetH: height,
                                      previewBuilder: previewBuilder,
                                      baseCanvasSize: logicalInnerSize,
                                      backgroundColor:
                                          pages[pageIndices[pi]]
                                                  .backgroundColor !=
                                              null
                                          ? Color(
                                              pages[pageIndices[pi]]
                                                  .backgroundColor!,
                                            )
                                          : null,
                                    ),
                                  ),
                                ],
                                // 홀수 내지(마지막 스프레드에 페이지 1개만 있을 때) 빈 공간
                                if (pageIndices.length == 1)
                                  Expanded(
                                    child: Container(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    }

    // pageController 없는 정적 버전
    return SizedBox(
      height: height + 12.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        itemCount: spreadItems.length,
        itemBuilder: (context, i) {
          final pageIndices = spreadItems[i];
          final isCover = i == 0;

          return Container(
            width: isCover ? singleThumbW : spreadThumbW,
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
                          aspect:
                              logicalCoverSize.width / logicalCoverSize.height,
                          layers: pages[0].layers,
                          isInteracting: false,
                          leftSpine: 0,
                          onCoverSizeChanged: (_) {},
                          buildImage: (layer) =>
                              coverBuilder.buildImage(layer, isCover: true),
                          buildText: (layer) =>
                              coverBuilder.buildText(layer, isCover: true),
                          sortedByZ: coverInteraction.sortByZ,
                          theme:
                              ref
                                  .watch(albumEditorViewModelProvider)
                                  .value
                                  ?.selectedTheme ??
                              resolveCoverTheme(null),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        for (int pi = 0; pi < pageIndices.length; pi++) ...[
                          if (pi > 0)
                            Container(
                              width: 1,
                              height: height,
                              color: Colors.grey.shade300,
                            ),
                          Expanded(
                            child: AlbumReaderPageContent(
                              layers: pages[pageIndices[pi]].layers,
                              targetW: singleThumbW,
                              targetH: height,
                              previewBuilder: previewBuilder,
                              baseCanvasSize: logicalInnerSize,
                              backgroundColor:
                                  pages[pageIndices[pi]].backgroundColor != null
                                  ? Color(
                                      pages[pageIndices[pi]].backgroundColor!,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                        if (pageIndices.length == 1)
                          Expanded(
                            child: Container(color: Colors.grey.shade100),
                          ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
