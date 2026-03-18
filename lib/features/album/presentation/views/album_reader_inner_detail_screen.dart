import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
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
  bool _showSwipeHint = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPageIndex;
    _pageController = PageController(
      initialPage: widget.initialPageIndex,
      viewportFraction: 0.88, // 옆 페이지가 살짝 보이는 뷰포트
    );

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

  void _showMoreOptions() {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    // innerPages는 vm.pages.sublist(1) 기준으로 들어오기 때문에,
    // 에디터에서 사용할 실제 페이지 인덱스는 +1 해준다.
    final currentInnerIndex = _currentPage;
    final targetPageIndex = (currentInnerIndex + 1).clamp(
      1,
      vm.pages.length - 1,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AlbumReaderMoreOptionsSheet(
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
                albumTitle: album.title ?? 'SnapFit Album',
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 앨범 사이즈 계산 (에디터/만들기 화면과 유사하게 꽉 차게)
    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;

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

    // 상세보기에서는 위아래 여백을 적게 두고 화면을 넓게 씁니다.
    final maxW = screenW * 0.82;
    final maxH = screenH * 0.60;

    double detailW = maxW;
    double detailH = detailW / targetRatio;

    // 비율을 유지하되 화면 높이를 초과하면 높이에 맞춤
    if (detailH > maxH) {
      detailH = maxH;
      detailW = detailH * targetRatio;
    }

    // 목업의 딥 다크 블루/그레이 배경
    final bgColor = const Color(0xFF161C20);

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
                      Icons.arrow_back_ios_new_rounded,
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
                  PageView.builder(
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
                            pageDist = widget.initialPageIndex > index
                                ? 1.0
                                : -1.0;
                          }

                          // 페이지 크기는 1.0으로 모두 동일하게 유지
                          // 페이지 간격을 없애고 자연스럽게 겹치기 위한 X축 이동
                          double offsetX = pageDist * 28.w;

                          // 측면 페이지에 들어갈 어두운 딤(Dim) 효과 정도
                          double darkness = (pageDist.abs()).clamp(0.0, 0.05);

                          return Center(
                            child: Transform.translate(
                              offset: Offset(offsetX, 0),
                              child: Hero(
                                tag:
                                    'inner_page_${widget.innerPages[index].id}',
                                child: _DetailInnerCard(
                                  page: widget.innerPages[index],
                                  pageW: detailW,
                                  pageH: detailH,
                                  interaction: widget.interaction,
                                  layerBuilder: widget.layerBuilder,
                                  darkness: darkness,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

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
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14.sp,
                    fontFamily: 'Inter', // 영문 폰트
                  ),
                  children: [
                    const TextSpan(text: 'Page  '),
                    TextSpan(
                      text: '${_currentPage + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: '  of ${widget.innerPages.length}'),
                  ],
                ),
              ),
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

  const _DetailInnerCard({
    required this.page,
    required this.pageW,
    required this.pageH,
    required this.interaction,
    required this.layerBuilder,
    this.darkness = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // 논리 좌표계 계산 (에디터 비율 일치)
    final ratio = pageW / pageH;
    const logicalW = 300.0;
    final logicalH = 300.0 / ratio;
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
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20.0,
              spreadRadius: 2.0,
              offset: const Offset(0, 10),
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
