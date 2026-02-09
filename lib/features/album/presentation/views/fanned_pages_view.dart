// lib/features/album/presentation/views/fanned_pages_view.dart
// 이미지(Paper 앱)처럼: 펼쳐진 앨범 - 앞페이지는 콜라주, 뒤페이지도 내용이 보이고, 부채꼴로 겹침.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/cover_theme.dart';
import '../../../../core/cache/snapfit_cache_manager.dart';
import '../../../../shared/snapfit_image.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/album_page.dart';
import '../../domain/entities/layer.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/home_view_model.dart';

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
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        body: Center(
          child: CircularProgressIndicator(
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
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

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7d7a97), Color(0xFF9893a9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // 좌상단: 이미지처럼 "June 2024" / "4 Pages"
            Positioned(
              left: 16.w,
              top: 16.h,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                    onPressed: widget.onClose,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    headerTitle,
                    style: TextStyle(
                      color: SnapFitColors.textPrimaryOf(context),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    '${pages.length} Pages',
                    style: TextStyle(
                      color: SnapFitColors.textSecondaryOf(context),
                      fontSize: 15.sp,
                    ),
                  ),
                ],
              ),
            ),
            // 중앙: Paper처럼 부채꼴 + 스와이프로 페이지 넘기기
            Center(
              child: PageView.builder(
                itemCount: pageCount,
                controller: _pageController,
                itemBuilder: (context, index) {
                  return _FannedPageStack(
                    ref: ref,
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
            // 우하단: 이미지처럼 흰 원형 버튼 + 진한 아이콘
            Positioned(
              right: 20.w,
              bottom: 32.h,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WhiteCircleButton(icon: Icons.more_horiz, onTap: () {}),
                  SizedBox(width: 10.w),
                  _WhiteCircleButton(icon: Icons.upload_outlined, onTap: () {}),
                  SizedBox(width: 10.w),
                  _WhiteCircleButton(icon: Icons.delete_outline, onTap: () {}),
                  SizedBox(width: 10.w),
                  _WhiteCircleButton(
                    icon: Icons.add,
                    onTap: () => vm.addPage(),
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

/// 이미지처럼: 흰 원형 배경 + 진한 회색 아이콘
class _WhiteCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _WhiteCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46.w,
          height: 46.w,
          child: Icon(icon, color: Colors.grey[800], size: 24.sp),
        ),
      ),
    );
  }
}

/// Paper처럼: [frontPageIndex]가 맨 앞, 그 뒤로 부채꼴로 겹침. PageView 스와이프로 front 변경.
class _FannedPageStack extends StatelessWidget {
  final WidgetRef ref;
  final int frontPageIndex;
  final int pageCount;
  final double pageWidth;
  final double pageHeight;
  final List<AlbumPage> pages;
  final CoverSize selectedCover;
  final CoverTheme selectedTheme;
  final Size? coverCanvasSize;
  final Album? currentAlbum;

  const _FannedPageStack({
    required this.ref,
    required this.frontPageIndex,
    required this.pageCount,
    required this.pageWidth,
    required this.pageHeight,
    required this.pages,
    required this.selectedCover,
    required this.selectedTheme,
    this.coverCanvasSize,
    this.currentAlbum,
  });

  @override
  Widget build(BuildContext context) {
    if (pageCount == 0) {
      return SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: _PageCard(
          width: pageWidth,
          height: pageHeight,
          depth: 0,
          content: _buildPageContent(context, this.ref, null),
        ),
      );
    }

    const int maxVisible = 5;
    const double offsetStep = 28.0;  // 부채꼴로 더 벌어지게
    const double rotateZDeg = 4.0;   // Paper처럼 펼쳐진 느낌
    const double maxFanY = 0.12;     // 3D 깊이

    // frontPageIndex가 맨 앞, 그 뒤로 frontPageIndex+1, +2, ... 부채꼴
    final count = math.min(maxVisible, pageCount - frontPageIndex);
    if (count <= 0) {
      return SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: _PageCard(
          width: pageWidth,
          height: pageHeight,
          depth: 0,
          content: _buildPageContent(context, this.ref, pages[frontPageIndex.clamp(0, pageCount - 1)]),
        ),
      );
    }

    return SizedBox(
      width: pageWidth + 100.w,
      height: pageHeight + 50.h,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(count, (i) {
          final pageIndex = frontPageIndex + i;
          final depth = i.toDouble();
          final t = count > 1 ? depth / (count - 1) : 0.0;
          final scale = 1.0 - t * 0.05;
          final offsetX = depth * offsetStep;
          final rotateZ = -depth * (rotateZDeg * 3.141592 / 180);
          final rotateY = -t * maxFanY;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..translate(offsetX, 0)
              ..rotateY(rotateY)
              ..rotateZ(rotateZ)
              ..scale(scale),
            child: _PageCard(
              width: pageWidth,
              height: pageHeight,
              depth: i,
              content: _buildPageContent(context, this.ref, pages[pageIndex]),
            ),
          );
        }),
      ),
    );
  }

  /// 내지 페이지 에디터 캔버스 크기 (PageEditorScreen과 동일)
  static const Size _innerPageCanvasSize = Size(300, 400);

  Widget _buildPageContent(BuildContext context, WidgetRef ref, AlbumPage? page) {
    final layers = page?.layers ?? [];
    // 커버는 coverCanvasSize, 내지는 300x400
    final isCover = page?.isCover ?? false;
    final baseW = isCover ? (coverCanvasSize?.width ?? 358.0) : _innerPageCanvasSize.width;
    final baseH = isCover ? (coverCanvasSize?.height ?? (358.0 / selectedCover.ratio)) : _innerPageCanvasSize.height;

    if (layers.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: selectedTheme.backgroundDecoration),
          ...layers.map((layer) {
            final rx = layer.position.dx / baseW;
            final ry = layer.position.dy / baseH;
            return Positioned(
              left: rx * pageWidth,
              top: ry * pageHeight,
              child: Transform.rotate(
                angle: layer.rotation * (3.14159265359 / 180),
                child: Transform.scale(
                  alignment: Alignment.topLeft,
                  scale: layer.scale * (pageWidth / baseW),
                  child: SizedBox(
                    width: layer.width,
                    height: layer.height,
                    child: layer.type == LayerType.text
                        ? Text(
                            layer.text ?? '',
                            style: layer.textStyle,
                            textAlign: layer.textAlign,
                          )
                        : _imageWidget(layer),
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }

    // 커버 페이지인데 레이어 없으면 앨범 커버 이미지
    if (page != null && page.isCover && currentAlbum != null) {
      final url = currentAlbum!.coverPreviewUrl ??
          currentAlbum!.coverThumbnailUrl ??
          currentAlbum!.coverImageUrl;
      if (url != null && url.isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: selectedTheme.backgroundDecoration),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: SnapfitImage(
                urlOrGs: url,
                fit: BoxFit.cover,
                cacheManager: snapfitImageCacheManager,
              ),
            ),
          ],
        );
      }
    }

    return Container(
      decoration: selectedTheme.backgroundDecoration,
      child: Center(
        child: Text(
          page?.isCover == true ? '표지' : '${page?.pageIndex ?? 0}',
          style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
        ),
      ),
    );
  }

  Widget _imageWidget(LayerModel layer) {
    final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
    if (url != null && url.isNotEmpty) {
      return SnapfitImage(
        urlOrGs: url,
        fit: BoxFit.cover,
        cacheManager: snapfitImageCacheManager,
      );
    }
    if (layer.asset != null) {
      return AssetEntityImage(layer.asset!, fit: BoxFit.cover);
    }
    return Icon(Icons.image, size: 28.sp, color: Colors.grey[400]);
  }
}

class _PageCard extends StatelessWidget {
  final double width;
  final double height;
  final int depth;
  final Widget content;

  const _PageCard({
    required this.width,
    required this.height,
    required this.depth,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12 + depth * 0.05),
            blurRadius: 6 + depth * 6,
            offset: Offset(2 + depth * 1.5, 4 + depth * 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.r),
        child: content,
      ),
    );
  }
}
