import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/platform_ui.dart';
import '../../domain/entities/album_page.dart';
import '../../domain/entities/layer.dart';
import '../controllers/layer_builder.dart';
import '../controllers/layer_interaction_manager.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/reader/album_reader_more_options_sheet.dart';
import 'page_editor_screen.dart';
import 'album_invite_screen.dart';

class AlbumReaderInnerDetailScreen extends ConsumerStatefulWidget {
  final List<AlbumPage> innerPages;
  final int initialPageIndex;
  final double singlePageW;
  final double singlePageH;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;

  const AlbumReaderInnerDetailScreen({
    super.key,
    required this.innerPages,
    required this.initialPageIndex,
    required this.singlePageW,
    required this.singlePageH,
    required this.interaction,
    required this.layerBuilder,
  });

  @override
  ConsumerState<AlbumReaderInnerDetailScreen> createState() =>
      _AlbumReaderInnerDetailScreenState();
}

class _AlbumReaderInnerDetailScreenState
    extends ConsumerState<AlbumReaderInnerDetailScreen> {
  late PageController _pageController;
  late int _currentPage;
  bool? _lastIsLandscape;
  bool _showSwipeHint = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPageIndex;
    _pageController = PageController(initialPage: widget.initialPageIndex);

    // 스와이프 힌트는 3초 뒤에 사라지게 설정
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSwipeHint = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    if (_lastIsLandscape == isLandscape) return;
    _lastIsLandscape = isLandscape;
    final oldController = _pageController;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: isLandscape ? 0.64 : 0.88,
    );
    oldController.dispose();
  }

  void _showMoreOptions() {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    // innerPages는 vm.pages.sublist(1) 기준으로 들어오기 때문에,
    // 에디터에서 사용할 실제 페이지 인덱스는 +1 해준다.
    final currentInnerIndex = _currentPage;
    final targetPageIndex = (currentInnerIndex + 1).clamp(
      1,
      vm.pages.length - 1,
    );

    Widget buildSheet(BuildContext ctx, {required bool compact}) {
      return AlbumReaderMoreOptionsSheet(
        onEdit: () async {
          Navigator.pop(ctx);
          // 내지 상세에서 편집으로 진입 시, 현재 보고 있는 페이지를 기준으로 에디터로 이동
          final saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PageEditorScreen(initialPageIndex: targetPageIndex),
            ),
          );
          if (!mounted) return;
          if (saved == true) {
            Navigator.pop(context, true);
          }
        },
        onConfirm: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('제작 확정은 메인 리더 화면에서 진행해주세요.')),
          );
        },
        onInvite: () {
          Navigator.pop(ctx);
          final album = vm.album;
          if (album == null || album.id <= 0) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('앨범 정보를 찾을 수 없습니다.')));
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AlbumInviteScreen(
                albumId: album.id,
                albumTitle: album.title.isEmpty ? 'SnapFit Album' : album.title,
              ),
            ),
          );
        },
        compact: compact,
      );
    }

    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    if (isLandscape) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '메뉴 닫기',
        barrierColor: Colors.black.withValues(alpha: 0.22),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return Center(
            child: SizedBox(
              width: 232,
              child: Material(
                color: Colors.transparent,
                child: buildSheet(ctx, compact: true),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              alignment: Alignment.center,
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => buildSheet(ctx, compact: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 앨범 사이즈 계산 (에디터/만들기 화면과 유사하게 꽉 차게)
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;
    final isLandscape = screenW > screenH;

    final vmState = ref.watch(albumEditorViewModelProvider).value;
    final vm = ref.read(albumEditorViewModelProvider.notifier);

    // 앨범 정보 파싱
    final albumTitle = vm.album?.title ?? 'SnapFit Album';
    final coverName = vmState?.selectedCover.name.toUpperCase() ?? 'ALBUM';
    final realW = vmState?.selectedCover.realSize.width.toInt() ?? 0;
    final realH = vmState?.selectedCover.realSize.height.toInt() ?? 0;
    String albumSizeInfo = '$coverName ALBUM';
    if (realW > 0 && realH > 0) {
      // 비율에 맞춰 W x H 정수 표시 (예: 20x20)
      albumSizeInfo = '$coverName ALBUM (${realW}X$realH)';
    }

    // 전달받은 singlePageW, singlePageH는 비율을 구하는 용도
    final targetRatio = widget.singlePageW / widget.singlePageH;

    final topSafe = media.padding.top;
    final bottomSafe = media.padding.bottom;

    // 가로에서는 텍스트/버튼을 오버레이로 빼고 페이지가 화면 높이를 최대한 쓰게 한다.
    final maxW = isLandscape ? screenW * 0.70 : screenW * 0.82;
    final maxH = isLandscape
        ? screenH - topSafe - bottomSafe - 44
        : screenH * 0.60;

    double detailW = maxW;
    double detailH = detailW / targetRatio;

    // 비율을 유지하되 화면 높이를 초과하면 높이에 맞춤
    if (detailH > maxH) {
      detailH = maxH;
      detailW = detailH * targetRatio;
    }

    // 목업의 딥 다크 블루/그레이 배경
    final bgColor = const Color(0xFF161C20);

    Widget pageIndicator({required bool compact}) {
      final baseSize = compact ? 11.0 : 14.sp;
      final currentSize = compact ? 16.0 : 20.sp;
      return RichText(
        text: TextSpan(
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: baseSize,
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w600,
          ),
          children: [
            const TextSpan(text: 'Page  '),
            TextSpan(
              text: '${_currentPage + 1}',
              style: TextStyle(
                color: Colors.white,
                fontSize: currentSize,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: '  of ${widget.innerPages.length}'),
          ],
        ),
      );
    }

    Widget topButton({required IconData icon, required VoidCallback onTap}) {
      return Material(
        color: Colors.white.withValues(alpha: isLandscape ? 0.12 : 0.08),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: isLandscape ? 42 : 46.w,
            height: isLandscape ? 42 : 46.w,
            child: Icon(
              icon,
              color: Colors.white,
              size: isLandscape ? 22 : 24.sp,
            ),
          ),
        ),
      );
    }

    Widget pageCarousel() {
      return PageView.builder(
        controller: _pageController,
        itemCount: widget.innerPages.length,
        onPageChanged: (idx) {
          setState(() {
            _currentPage = idx;
            _showSwipeHint = false; // 수동으로 넘기면 힌트 즉시 해제
          });
        },
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double pageDist = 0.0;
              if (_pageController.position.haveDimensions) {
                pageDist = _pageController.page! - index;
              } else if (index != widget.initialPageIndex) {
                pageDist = widget.initialPageIndex > index ? 1.0 : -1.0;
              }

              final offsetX = pageDist * (isLandscape ? 18.0 : 28.w);
              final darkness = (pageDist.abs()).clamp(0.0, 0.05);
              final sideScale = 1.0 - (pageDist.abs().clamp(0.0, 1.0) * 0.035);

              return Center(
                child: Transform.translate(
                  offset: Offset(offsetX, 0),
                  child: Transform.scale(
                    scale: sideScale,
                    child: Hero(
                      tag: 'inner_page_${widget.innerPages[index].id}',
                      child: _DetailInnerCard(
                        page: widget.innerPages[index],
                        pageW: detailW,
                        pageH: detailH,
                        interaction: widget.interaction,
                        layerBuilder: widget.layerBuilder,
                        darkness: darkness,
                        compactShadow: isLandscape,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    if (isLandscape) {
      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: pageCarousel()),
              Positioned(
                left: 14,
                top: 10,
                child: topButton(
                  icon: platformBackIcon(),
                  onTap: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                right: 14,
                top: 10,
                child: topButton(
                  icon: Icons.more_horiz_rounded,
                  onTap: _showMoreOptions,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Center(child: pageIndicator(compact: true)),
              ),
              if (_showSwipeHint && _currentPage < widget.innerPages.length - 1)
                Positioned(
                  right: 76,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _showSwipeHint ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white.withValues(alpha: 0.42),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 앱바
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Row(
                children: [
                  // 닫기/뒤로가기
                  IconButton(
                    icon: Icon(
                      platformBackIcon(),
                      color: Colors.white,
                      size: 24.sp,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          albumSizeInfo,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12.sp,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          albumTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 더보기
                  IconButton(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 28.sp,
                    ),
                    onPressed: _showMoreOptions,
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  pageCarousel(),

                  // 스와이프 안내 힌트 (오른쪽 중앙)
                  if (_showSwipeHint &&
                      _currentPage < widget.innerPages.length - 1)
                    Positioned(
                      right: 16.w, // 화면 가장자리에 가깝게
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _showSwipeHint ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 500),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56.w,
                                height: 56.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      SnapFitColors.accent.withValues(
                                        alpha: 0.5,
                                      ),
                                      SnapFitColors.accent.withValues(
                                        alpha: 0.1,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 24.sp,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'SWIPE',
                                style: TextStyle(
                                  color: SnapFitColors.accent.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.sp,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 하단 페이지 인디케이터 text ("Page 12 of 40")
            Padding(
              padding: EdgeInsets.only(bottom: 40.h, top: 20.h),
              child: pageIndicator(compact: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailInnerCard extends StatelessWidget {
  final AlbumPage page;
  final double pageW;
  final double pageH;
  final LayerInteractionManager interaction;
  final LayerBuilder layerBuilder;
  final double darkness;
  final bool compactShadow;

  const _DetailInnerCard({
    required this.page,
    required this.pageW,
    required this.pageH,
    required this.interaction,
    required this.layerBuilder,
    this.darkness = 0.0,
    this.compactShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    // 논리 좌표계 계산 (에디터 비율 일치)
    final ratio = pageW / pageH;
    const logicalW = kCoverReferenceWidth;
    final logicalH = kCoverReferenceWidth / ratio;
    final logicalBaseSize = Size(logicalW, logicalH);
    final scale = pageW / logicalW;

    final pageBackgroundColor = page.backgroundColor != null
        ? Color(page.backgroundColor!)
        : SnapFitColors.pureWhite;

    return ClipRect(
      // 바깥으로 튀어나온 레이어 자르기
      child: Container(
        width: pageW,
        height: pageH,
        decoration: BoxDecoration(
          color: pageBackgroundColor,
          borderRadius: BorderRadius.circular(4.r), // 은근한 둥글기 적용
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: compactShadow ? 0.32 : 0.4),
              blurRadius: compactShadow ? 16.0 : 20.0,
              spreadRadius: compactShadow ? 0.0 : 2.0,
              offset: Offset(0, compactShadow ? 8 : 10),
            ),
          ],
        ),
        child: ClipRRect(
          // 안쪽 이미지 컨텐츠용
          borderRadius: BorderRadius.circular(4.r),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: logicalBaseSize.width,
                  height: logicalBaseSize.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: interaction.sortByZ(page.layers).map((layer) {
                      if (layer.type == LayerType.image ||
                          layer.type == LayerType.sticker ||
                          layer.type == LayerType.decoration) {
                        return layerBuilder.buildImage(layer);
                      }
                      return layerBuilder.buildText(layer);
                    }).toList(),
                  ),
                ),
              ),
              // 측면 페이지 경계선 및 원근감을 위한 어두운 오버레이
              if (darkness > 0)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: darkness),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
