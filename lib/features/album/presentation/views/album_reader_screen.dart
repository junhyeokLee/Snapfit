import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/screen_logger.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/constants/cover_size.dart';
import '../controllers/cover_size_controller.dart';
import '../controllers/layer_builder.dart';
import '../controllers/layer_interaction_manager.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/reader/album_reader_single_page_view.dart';
import '../widgets/reader/album_reader_thumbnail_strip.dart';
import '../viewmodels/home_view_model.dart';
import 'page_editor_screen.dart';

class AlbumReaderScreen extends ConsumerStatefulWidget {
  const AlbumReaderScreen({super.key});

  @override
  ConsumerState<AlbumReaderScreen> createState() => _AlbumReaderScreenState();
}

class _AlbumReaderScreenState extends ConsumerState<AlbumReaderScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final GlobalKey _coverKey;
  late final LayerInteractionManager _interaction;
  late final LayerBuilder _layerBuilder;
  Size _baseCanvasSize = const Size(300, 400); // 초기값, initState에서 갱신됨
  Size _coverSize = Size.zero;
  final CoverSizeController _layout = CoverSizeController();
  bool _isFrozen = false; // 제작확정 여부

  @override
  void initState() {
    super.initState();
    // 스프레드 뷰에서는 한 화면에 아이템 전체(2장)가 렌더링되므로 1.0 기본값을 사용
    _pageController = PageController();
    _coverKey = GlobalKey();
    // 앨범 보기 화면: 레이어 인터랙션 완전 비활성화 (드래그/탭/핀치 모두 잠금)
    _interaction = LayerInteractionManager(
      ref: ref,
      coverKey: _coverKey,
      setState: setState,
      getCoverSize: () {
        // [10단계 Fix] 리더 화면에서도 커버 인터랙션 좌표계는 500xH 기준이어야 함
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        final aspect = vm.selectedCover.ratio;
        
        // 현재 페이지가 커버인지 확인 (Page 0)
        final double page = _pageController.hasClients ? (_pageController.page ?? 0.0) : 0.0;
        if (page < 0.5) {
          return Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
        }
        return Size(300.0, 300.0 / aspect);
      },
      isPreviewMode: true,
      showSelectionControls: false,
      onEditText: (layer) {},
    );

    // [10단계 Fix] LayerBuilder도 레이어 타입이나 페이지 위치에 따라 올바른 논리 사이즈를 참조해야 함
    _layerBuilder = LayerBuilder(_interaction, () {
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      final aspect = vm.selectedCover.ratio;
      final double page = _pageController.hasClients ? (_pageController.page ?? 0.0) : 0.0;
      
      if (page < 0.5) {
        return Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
      }
      return Size(300.0, 300.0 / aspect);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        vm.loadPendingEditAlbumIfNeeded(Size.zero);
        
        // [Fix] 앨범 비율에 맞게 내지 베이스 사이즈 동적 초기화
        final aspect = vm.selectedCover.ratio;
        setState(() {
          _baseCanvasSize = Size(300.0, 300.0 / aspect);
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ... 메뉴 (수정하기 / 제작확정)
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MoreOptionsSheet(
        onEdit: () async {
          Navigator.pop(ctx);
          // PageEditorScreen에서 저장 완료(true) 반환 시 AlbumReaderScreen도 true로 pop
          final saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const PageEditorScreen()),
          );
          if (saved == true && context.mounted) {
            Navigator.pop(context, true); // 홈 화면에 수정사항 있음 알림
          } else if (context.mounted) {
            // [Fix] 에디터에서 돌아왔을 때, 캔버스 사이즈 재동기화 강제 트리거
            // (에디터의 캔버스 실측 사이즈와 리더의 실측 사이즈가 미세하게 다를 수 있으므로 리더 기준으로 재조정)
            final vm = ref.read(albumEditorViewModelProvider.notifier);
            if (_coverSize != Size.zero) {
              debugPrint('[AlbumReaderScreen] Returned from editor, re-syncing size: $_coverSize');
              vm.setCoverCanvasSize(_coverSize);
            }
            setState(() {});
          }
        },
        onConfirm: () {
          Navigator.pop(ctx);
          _showConfirmDialog();
        },
      ),
    );
  }

  // 제작확정 확인 다이얼로그
  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SnapFitColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: SnapFitColors.accent, size: 22.sp),
            SizedBox(width: 8.w),
            Text(
              '제작 확정',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
        content: Text(
          '제작을 확정하면 더 이상 앨범을\n수정할 수 없습니다.\n\n정말 확정하시겠습니까?',
          style: TextStyle(
            fontSize: 14.sp,
            color: SnapFitColors.textSecondaryOf(context),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '취소',
              style: TextStyle(
                color: SnapFitColors.textMutedOf(context),
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isFrozen = true);
            },
            child: Text(
              '확정하기',
              style: TextStyle(
                color: SnapFitColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(albumEditorViewModelProvider);
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final state = asyncState.value;

    if (state == null) {
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        body: Center(child: CircularProgressIndicator(color: SnapFitColors.accent)),
      );
    }
    if (state.isCreatingInBackground) {
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: SnapFitColors.accent),
              SizedBox(height: 24.h),
              Text('앨범을 생성하고 있습니다...',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700,
                      color: SnapFitColors.textPrimaryOf(context))),
            ],
          ),
        ),
      );
    }

    // 제작확정 완료 화면
    if (_isFrozen) {
      return _FrozenScreen(
        album: vm.album,
        onClose: () {
          Navigator.pop(context, true); // 홈 갱신 필요
          ref.read(homeViewModelProvider.notifier).refresh();
        },
        onOrder: () {
          // TODO: 주문 화면으로 이동
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('주문 기능은 준비 중입니다.')),
          );
        },
      );
    }

    vm.ensureCoverPage();
    final allPages = vm.pages;
    final totalPages = allPages.length;

    // PageController는 스프레드(2페이지 묶음) 단위로 인덱싱됨
    // itemCount = 커버(1) + 내지 스프레드 수
    final int innerPageCount = (totalPages - 1).clamp(0, totalPages);
    final int spreadCount = (innerPageCount / 2).ceil();
    final int itemCount = 1 + spreadCount; // 도트 인디케이터에 사용

    final albumTitle = vm.album?.title ?? '';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: SnapFitColors.isDark(context)
                ? [const Color(0xFF1A2E33), const Color(0xFF0D1B1F)]
                : [const Color(0xFFF0F4F8), const Color(0xFFE8EEF4)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── 1. 상단 헤더 ───
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    // 뒤로가기
                    _CircleBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    // 가운데 타이틀
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'SNAPFIT',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                              color: SnapFitColors.accent,
                            ),
                          ),
                          if (albumTitle.isNotEmpty)
                            Text(
                              albumTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: SnapFitColors.textSecondaryOf(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // ... 메뉴
                    _CircleBtn(
                      icon: Icons.more_horiz_rounded,
                      onTap: _showMoreOptions,
                    ),
                  ],
                ),
              ),

              // ─── 2. 페이지 카운터 Pill ───
              AnimatedBuilder(
                animation: _pageController,
                builder: (context, _) {
                  // spreadIdx: 0=커버, 1=1-2페이지, 2=3-4페이지 ...
                  final spreadIdx = _pageController.hasClients
                      ? (_pageController.page?.round() ?? 0)
                      : 0;
                  final isCover = spreadIdx == 0;
                  final int totalInner = allPages.length - 1; // 내지 페이지 수
                  String label;
                  if (isCover) {
                    label = '커버';
                  } else {
                    // 스프레드 인덱스 → 실제 내지 페이지 번호
                    final int leftPage  = (spreadIdx - 1) * 2 + 1;
                    final int rightPage = leftPage + 1;
                    if (rightPage <= totalInner) {
                      label = '$leftPage - $rightPage  /  $totalInner';
                    } else {
                      label = '$leftPage  /  $totalInner';
                    }
                  }
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 12.h),

              // ─── 3. 단일 페이지 뷰어 (커버 포함) ───
              Expanded(
                child: allPages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book_outlined,
                                size: 56.sp,
                                color: SnapFitColors.textMutedOf(context).withOpacity(0.4)),
                            SizedBox(height: 16.h),
                            Text(
                              '아직 페이지가 없어요.\n스냅핏 만들기에서 페이지를 추가해보세요!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: SnapFitColors.textMutedOf(context),
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      )
                    : AlbumReaderSinglePageView(
                        allPages: allPages,
                        selectedCover: state.selectedCover,
                        coverTheme: state.selectedTheme,
                        pageController: _pageController,
                        interaction: _interaction,
                        layerBuilder: _layerBuilder,
                        canvasKey: _coverKey,
                        onCanvasSizeChanged: (size) {
                          if (_coverSize == size) return;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            debugPrint('[AlbumReaderScreen] Canvas Size Changed: $size');
                            setState(() {
                              _coverSize = size;
                            });
                            // 실제 캔버스 크기가 잡히면 레이어 좌표 리스케일링 트리거
                            vm.setCoverCanvasSize(size);
                          });
                        },
                        onPageChanged: (index) {
                          setState(() {});
                        },
                        onStateChanged: () {
                          if (mounted) setState(() {});
                        },
                      ),
              ),

              SizedBox(height: 8.h),

              // ─── 4. 페이지 도트 인디케이터 (스프레드 단위) ───
              if (itemCount > 1)
                AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, _) {
                    // spreadIdx 기준으로 현재 활성 점 결정
                    final current = _pageController.hasClients
                        ? (_pageController.page?.round() ?? 0)
                        : 0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(itemCount, (i) {
                        final isActive = i == current;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: EdgeInsets.symmetric(horizontal: 3.w),
                          width: isActive ? 20.w : 6.w,
                          height: 6.w,
                          decoration: BoxDecoration(
                            color: isActive
                                ? SnapFitColors.accent
                                : SnapFitColors.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3.r),
                          ),
                        );
                      }),
                    );
                  },
                ),
              SizedBox(height: 12.h),

              // ─── 5. 하단 썸네일 스트립 ───
              AlbumReaderThumbnailStrip(
                pages: allPages,
                pageController: allPages.isNotEmpty ? _pageController : null,
                previewBuilder: _layerBuilder,
                baseCanvasSize: _baseCanvasSize,
                height: 64.h,
              ),
              SizedBox(height: 18.h),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 원형 아이콘 버튼 ──────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20.sp),
      ),
    );
  }
}

// ── ... 더보기 바텀시트 ───────────────────────────────────────────
class _MoreOptionsSheet extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onConfirm;
  const _MoreOptionsSheet({required this.onEdit, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: SnapFitColors.textMutedOf(context).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),

            // 수정하기
            _SheetItem(
              icon: Icons.edit_note_rounded,
              label: '수정하기',
              onTap: onEdit,
            ),

            Divider(
              height: 1,
              color: SnapFitColors.textMutedOf(context).withOpacity(0.1),
              indent: 20.w,
              endIndent: 20.w,
            ),

            // 제작 확정
            _SheetItem(
              icon: Icons.lock_outline_rounded,
              label: '제작 확정하기',
              iconColor: SnapFitColors.accent,
              labelColor: SnapFitColors.accent,
              onTap: onConfirm,
            ),

            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = labelColor ?? SnapFitColors.textPrimaryOf(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 18.h),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? SnapFitColors.textSecondaryOf(context), size: 22.sp),
            SizedBox(width: 16.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 제작확정 완료 화면 ────────────────────────────────────────────
class _FrozenScreen extends StatefulWidget {
  final dynamic album;
  final VoidCallback onClose;
  final VoidCallback onOrder;

  const _FrozenScreen({
    required this.album,
    required this.onClose,
    required this.onOrder,
  });

  @override
  State<_FrozenScreen> createState() => _FrozenScreenState();
}

class _FrozenScreenState extends State<_FrozenScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B1F),
      body: Stack(
        children: [
          // 배경 별빛 파티클
          ..._buildStars(),

          SafeArea(
            child: Column(
              children: [
                // X 닫기 버튼
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.white, size: 20.sp),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // 블러 앨범 카드 + FREEZE 배지
                FadeTransition(
                  opacity: _fadeIn,
                  child: AnimatedBuilder(
                    animation: _slideUp,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _slideUp.value),
                      child: child,
                    ),
                    child: _buildAlbumCard(context),
                  ),
                ),

                SizedBox(height: 48.h),

                // 텍스트
                FadeTransition(
                  opacity: _fadeIn,
                  child: AnimatedBuilder(
                    animation: _slideUp,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _slideUp.value * 1.5),
                      child: child,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '제작이 확정되었습니다!',
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          '이제 이 앨범은 누구도 수정할 수 없는\n소중한 기록이 되었습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white.withOpacity(0.6),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // 버튼들
                FadeTransition(
                  opacity: _fadeIn,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      children: [
                        // 주문하러가기 버튼
                        GestureDetector(
                          onTap: widget.onOrder,
                          child: Container(
                            width: double.infinity,
                            height: 56.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00D4EE),
                                  const Color(0xFF00B8D4),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28.r),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00C2E0).withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '주문하러가기',
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 20.sp),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        // 앨범 보관함으로 버튼
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            width: double.infinity,
                            height: 52.h,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(26.r),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '앨범 보관함으로',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topRight,
      children: [
        // 블러 카드
        Container(
          width: 220.w,
          height: 280.w,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: Stack(
              children: [
                // 흐림 처리된 내부
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1C3A42), Color(0xFF0F2226)],
                    ),
                  ),
                ),
                // 내부 라인 효과 (책 페이지 느낌)
                Positioned(
                  top: 20.h,
                  left: 20.w,
                  right: 20.w,
                  child: Container(
                    height: 140.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40.h,
                  left: 20.w,
                  right: 60.w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 8.h, width: 80.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4.r),
                          )),
                      SizedBox(height: 8.h),
                      Container(height: 6.h, width: 120.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(3.r),
                          )),
                      SizedBox(height: 6.h),
                      Container(height: 6.h, width: 90.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(3.r),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // FREEZE 배지
        Positioned(
          top: -12.h,
          right: -12.w,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF00D4EE), const Color(0xFF00A8C4)],
              ),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C2E0).withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.ac_unit_rounded, color: Colors.white, size: 14.sp),
                SizedBox(width: 4.w),
                Text(
                  'FREEZE',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 배경 별빛 파티클 생성
  List<Widget> _buildStars() {
    final rng = math.Random(42);
    return List.generate(18, (i) {
      final x = rng.nextDouble();
      final y = rng.nextDouble();
      final size = rng.nextDouble() * 3 + 1.5;
      final opacity = rng.nextDouble() * 0.5 + 0.2;
      return Positioned(
        left: x * MediaQuery.sizeOf(context).width,
        top: y * MediaQuery.sizeOf(context).height,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        ),
      );
    });
  }
}
