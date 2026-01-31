// lib/features/album/presentation/views/album_spread_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/cover_theme.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/editor/page_template_picker.dart';
import '../../../../shared/snapfit_image.dart';
import '../viewmodels/home_view_model.dart';
import 'page_editor_screen.dart';

/// 앨범 내부 페이지 편집 화면
/// - 커버 편집은 AddCoverScreen 사용
/// - 이 화면은 앨범 내부의 여러 페이지(스프레드)를 편집하는 용도
/// - EditCover에서 커버 생성/수정 후 이 화면으로 이동
class AlbumSpreadScreen extends ConsumerWidget {
  const AlbumSpreadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(albumEditorViewModelProvider);
    final state = asyncState.value;
    final vm = ref.read(albumEditorViewModelProvider.notifier);

    if (state == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 홈에서 바로 "앨범 페이지 편집"으로 들어온 경우,
    // 커버 에디터(AddCoverScreen)를 거치지 않아서 coverCanvasSize가 없고
    // _pendingCoverLayersJson만 설정되어 있는 상태일 수 있다.
    // 이때는 스프레드 썸네일에서도 커버가 보이도록, 적당한 기본 캔버스 크기로
    // pending 커버 레이어를 한 번 로드해준다.
    // 단, build 중에 provider를 수정하면 안 되므로, 빌드 완료 후에 실행한다.
    if (state.coverCanvasSize == null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final ratio = state.selectedCover.ratio;
        const double baseWidth = 358.0;
        final double baseHeight = baseWidth / ratio;
        final Size fallbackCanvasSize = Size(baseWidth, baseHeight);
        vm.loadPendingEditAlbumIfNeeded(fallbackCanvasSize);
      });
    }

    // EditCover 에서 이미 1회 생성(POST)까지 끝난 상태.
    // 이 화면의 '완료' 버튼은 페이지/레이어 변경분을 저장한 뒤 홈으로 되돌아가는 역할만 한다.

    final pages = vm.pages.where((p) => !p.isCover).toList();
    final isSaving = asyncState.isLoading; // 에디터 로딩 상태만 사용

    return Stack(
      children: [
        Scaffold(
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
                  _buildTopBar(context, ref, vm, isSaving), // 저장 상태 전달
                  Expanded(
                    child: Center(child: _buildSpreadView(context, ref, pages, state.selectedCover, vm)),
                  ),
                  _buildPageThumbnailList(ref, vm, state),
                ],
              ),
            ),
          ),
        ),
        // 저장 중 로딩 오버레이 (업로드 + 서버 저장 전체 구간)
        if (isSaving)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    AlbumEditorViewModel vm,
    bool isLoading,
  ) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text("앨범 페이지 편집", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: isLoading
                ? null
                : () async {
                    // 1) 내부 페이지/레이어 변경사항 저장 (Firebase 업로드 포함)
                    await vm.saveFullAlbum();

                    if (!context.mounted) return;

                    // 2) 홈 목록 최신화
                    await ref.read(homeViewModelProvider.notifier).refresh();
                    if (!context.mounted) return;

                    // 3) 사용자에게 안내 후 홈으로 복귀
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("앨범이 저장되었습니다.")),
                    );
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
            child: Text(
              "완료",
              style: TextStyle(
                color: isLoading ? Colors.white54 : Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadView(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> pages,
    CoverSize selectedCover,
    AlbumEditorViewModel vm,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSingleSpreadPage(context, ref, vm, 1, "왼쪽 페이지", selectedCover),
          SizedBox(width: 8.w),
          _buildSingleSpreadPage(context, ref, vm, 2, "오른쪽 페이지", selectedCover),
        ],
      ),
    );
  }

  Widget _buildSingleSpreadPage(
    BuildContext context,
    WidgetRef ref,
    AlbumEditorViewModel vm,
    int pageIndex,
    String label,
    CoverSize selectedCover,
  ) {
    final ratio = selectedCover.ratio;
    final h = 220.0.h;
    final w = h * ratio;
    return GestureDetector(
      onTap: () {
        // 내지 페이지만 편집: 필요한 만큼 페이지가 있는지 확인 후 해당 페이지로 진입
        while (vm.pages.length <= pageIndex) {
          vm.addPage();
        }
        vm.goToPage(pageIndex);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PageEditorScreen(initialPageIndex: pageIndex)),
        );
      },
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(4.r),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(2, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: pageIndex < vm.pages.length && vm.pages[pageIndex].layers.isNotEmpty
              ? _buildPageContent(ref, vm.pages[pageIndex].layers, w, h)
              : Center(child: Text(label, style: const TextStyle(color: Colors.grey))),
        ),
      ),
    );
  }

  /// 내지 페이지 레이어를 주어진 크기로 미리보기 (페이지 에디터 캔버스 300x400 기준 스케일)
  Widget _buildPageContent(WidgetRef ref, List<LayerModel> layers, double targetW, double targetH) {
    const double sourceW = 300;
    const double sourceH = 400;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.white),
        ...layers.map((layer) {
          final scaleX = targetW / sourceW;
          final scaleY = targetH / sourceH;
          final left = layer.position.dx * scaleX;
          final top = layer.position.dy * scaleY;
          final w = layer.width * scaleX;
          final h = layer.height * scaleY;
          final rotRad = layer.rotation * math.pi / 180;
          return Positioned(
            left: left,
            top: top,
            child: Transform.rotate(
              angle: rotRad,
              child: Transform.scale(
                alignment: Alignment.topLeft,
                scale: layer.scale,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: layer.type == LayerType.text
                      ? Text(
                          layer.text ?? "",
                          style: (layer.textStyle ?? const TextStyle(fontSize: 12, color: Colors.black87))
                              .copyWith(fontSize: (layer.textStyle?.fontSize ?? 14) * (targetW / sourceW).clamp(0.3, 1.5)),
                          textAlign: layer.textAlign ?? TextAlign.left,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        )
                      : _buildImageWidget(layer),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPageThumbnailList(WidgetRef ref, AlbumEditorViewModel vm, AlbumEditorState state) {
    final ratio = state.selectedCover.ratio;
    final thumbH = 80.0.h;
    final thumbW = thumbH * ratio;
    final itemWidth = thumbW + 10.w;

    return Container(
      height: 100.h,
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: vm.pages.length + 1,
        itemBuilder: (context, index) {
          if (index == vm.pages.length) {
            return _buildAddButton(context, ref, vm, state, thumbW, thumbH, itemWidth);
          }

          final isSelected = vm.currentPageIndex == index;
          final page = vm.pages[index];

          return SizedBox(
            width: itemWidth,
            child: Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {
                  vm.goToPage(index);
                  // 커버(0)가 아닌 내지만 페이지 편집 화면으로 진입
                  if (index >= 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PageEditorScreen(initialPageIndex: index)),
                    );
                  }
                },
                child: Container(
                  width: thumbW,
                  height: thumbH,
                  decoration: BoxDecoration(
                    border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                    borderRadius: BorderRadius.circular(4.r),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2.r),
                    child: index == 0
                        ? _buildCoverThumbnail(
                            ref,
                            page.layers,
                            state.selectedCover,
                            state.selectedTheme,
                            state.coverCanvasSize,
                          )
                        : _buildPageContent(ref, page.layers, thumbW, thumbH),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoverThumbnail(
    WidgetRef ref,
    List<LayerModel> layers,
    CoverSize selectedCover,
    CoverTheme selectedTheme,
    Size? coverCanvasSize,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double targetW = constraints.maxWidth;
        final double targetH = constraints.maxHeight;
        final double editorBaseWidth = coverCanvasSize?.width ?? 358.0;
        final double editorBaseHeight = coverCanvasSize?.height ?? (358.0 / selectedCover.ratio);

        // 1) 커버 레이어가 있는 경우: 기존처럼 레이어 기반으로 그린다.
        if (layers.isNotEmpty) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(decoration: selectedTheme.backgroundDecoration),
              ...layers.map((layer) {
                final double rx = layer.position.dx / editorBaseWidth;
                final double ry = layer.position.dy / editorBaseHeight;

                return Positioned(
                  left: rx * targetW,
                  top: ry * targetH,
                  child: Transform.rotate(
                    angle: layer.rotation,
                    child: Transform.scale(
                      alignment: Alignment.topLeft,
                      scale: layer.scale * (targetW / editorBaseWidth),
                      child: SizedBox(
                        width: layer.width,
                        height: layer.height,
                        child: layer.type == LayerType.text
                            ? Text(layer.text ?? "", style: layer.textStyle, textAlign: layer.textAlign)
                            : _buildImageWidget(layer),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }

        // 2) 레이어가 전혀 없으면: 홈에서 선택한 앨범의 커버 썸네일 URL을 fallback 으로 사용
        final homeAsync = ref.watch(homeViewModelProvider);
        final albums = homeAsync.value ?? const <Album>[];
        final editingId = ref.read(albumEditorViewModelProvider.notifier).editingAlbumId;

        if (editingId == null) {
          // 편집 중인 앨범 ID가 없으면, 단순 플레이스홀더만 표시
          return Container(decoration: selectedTheme.backgroundDecoration);
        }

        final Album? currentAlbum = albums.where((a) => a.id == editingId).cast<Album?>().firstWhere(
              (a) => a != null,
              orElse: () => null,
            );

        final String? coverUrl = currentAlbum?.coverPreviewUrl ??
            currentAlbum?.coverThumbnailUrl ??
            currentAlbum?.coverImageUrl;

        if (coverUrl == null || coverUrl.isEmpty) {
          // 그래도 없으면 배경만 표시
          return Container(decoration: selectedTheme.backgroundDecoration);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: selectedTheme.backgroundDecoration),
            ClipRRect(
              borderRadius: BorderRadius.circular(2.r),
              child: SnapfitImage(urlOrGs: coverUrl, fit: BoxFit.cover),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageWidget(LayerModel layer) {
    final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
    if (url != null && url.isNotEmpty) {
      return SnapfitImage(urlOrGs: url, fit: BoxFit.cover);
    } else if (layer.asset != null) {
      return AssetEntityImage(layer.asset!, fit: BoxFit.cover);
    }
    return const Icon(Icons.image, size: 20, color: Colors.grey);
  }

  Widget _buildAddButton(
    BuildContext context,
    WidgetRef ref,
    AlbumEditorViewModel vm,
    AlbumEditorState state,
    double width,
    double height,
    double itemWidth,
  ) {
    final canvasSize = state.coverCanvasSize ?? Size(300, 400);
    return SizedBox(
      width: itemWidth,
      child: Align(
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            PageTemplatePicker.show(context, onSelect: (template) {
              vm.addPageFromTemplate(template, canvasSize);
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PageEditorScreen()),
                );
              }
            });
          },
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
    );
  }
}