import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/utils/platform_ui.dart';
import '../controllers/layer_builder.dart';
import '../controllers/layer_interaction_manager.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../../domain/entities/album_page.dart';
import '../widgets/reader/album_reader_single_page_view.dart';
import '../widgets/reader/album_reader_thumbnail_strip.dart';
import '../widgets/reader/album_reader_page_content.dart';
import '../widgets/reader/album_reader_more_options_sheet.dart';
import '../widgets/reader/album_frozen_screen.dart';
import '../viewmodels/home_view_model.dart';
import '../../data/api/album_provider.dart';
import '../../../billing/data/billing_provider.dart';
import 'page_editor_screen.dart';
import 'album_invite_screen.dart';
import 'print_order_checkout_screen.dart';

class AlbumReaderScreen extends ConsumerStatefulWidget {
  final int initialSpreadIndex;

  const AlbumReaderScreen({super.key, this.initialSpreadIndex = 0});

  @override
  ConsumerState<AlbumReaderScreen> createState() => _AlbumReaderScreenState();
}

class _AlbumReaderScreenState extends ConsumerState<AlbumReaderScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final GlobalKey _coverKey;
  late final LayerInteractionManager _interaction;
  late final LayerBuilder _layerBuilder;
  Size _baseCanvasSize = const Size(
    kCoverReferenceWidth,
    kCoverReferenceWidth,
  ); // 초기값, initState에서 갱신됨
  Size _coverSize = Size.zero;
  bool _isFrozen = false; // 제작확정 여부
  bool _isDeleting = false; // 삭제 진행 중 UI 잠금
  late int _focusPageIndex;

  @override
  void initState() {
    super.initState();
    unawaited(_allowAdaptiveOrientations());
    // 스프레드 뷰에서는 한 화면에 아이템 전체(2장)가 렌더링되므로 1.0 기본값을 사용
    _pageController = PageController(initialPage: widget.initialSpreadIndex);
    _focusPageIndex = widget.initialSpreadIndex <= 0
        ? 0
        : 1 + ((widget.initialSpreadIndex - 1) * 2);
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
        final double page = _pageController.hasClients
            ? (_pageController.page ?? 0.0)
            : 0.0;
        if (page < 0.5) {
          return Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
        }
        return Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
      },
      isPreviewMode: true,
      showSelectionControls: false,
      onEditText: (layer) {},
    );

    // [10단계 Fix] LayerBuilder도 레이어 타입이나 페이지 위치에 따라 올바른 논리 사이즈를 참조해야 함
    _layerBuilder = LayerBuilder(_interaction, () {
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      final aspect = vm.selectedCover.ratio;
      final double page = _pageController.hasClients
          ? (_pageController.page ?? 0.0)
          : 0.0;

      if (page < 0.5) {
        return Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
      }
      return Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        vm.loadPendingEditAlbumIfNeeded(Size.zero);

        // [Fix] 앨범 비율에 맞게 내지 베이스 사이즈 동적 초기화
        final aspect = vm.selectedCover.ratio;
        setState(() {
          _baseCanvasSize = Size(
            kCoverReferenceWidth,
            kCoverReferenceWidth / aspect,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(_allowAdaptiveOrientations());
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _allowAdaptiveOrientations() {
    return SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  Future<T?> _pushAdaptiveRoute<T>(Route<T> route) async {
    return Navigator.push<T>(context, route);
  }

  // ... 메뉴 (수정하기 / 제작확정)
  void _showMoreOptions() {
    if (_isDeleting) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    Widget buildOptions(BuildContext ctx, {required bool compact}) {
      return AlbumReaderMoreOptionsSheet(
        onEdit: () async {
          Navigator.pop(ctx);
          // PageEditorScreen에서 저장 완료(true) 반환 시 AlbumReaderScreen도 true로 pop
          final saved = await _pushAdaptiveRoute<bool>(
            MaterialPageRoute(builder: (_) => const PageEditorScreen()),
          );
          if (saved == true && context.mounted) {
            Navigator.pop(context, true); // 홈 화면에 수정사항 있음 알림
          } else if (context.mounted) {
            // [Fix] 에디터에서 돌아왔을 때, 캔버스 사이즈 재동기화 강제 트리거
            // (에디터의 캔버스 실측 사이즈와 리더의 실측 사이즈가 미세하게 다를 수 있으므로 리더 기준으로 재조정)
            final vm = ref.read(albumEditorViewModelProvider.notifier);
            if (_coverSize != Size.zero) {
              debugPrint(
                '[AlbumReaderScreen] Returned from editor, re-syncing size: $_coverSize',
              );
              vm.setCoverCanvasSize(_coverSize);
            }
            setState(() {});
          }
        },
        onConfirm: () {
          Navigator.pop(ctx);
          _showConfirmDialog();
        },
        onDelete: () {
          Navigator.pop(ctx);
          _showDeleteConfirmDialog();
        },
        onInvite: () async {
          Navigator.pop(ctx);
          final album = vm.album;
          if (album == null || album.id <= 0) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('앨범 정보를 찾을 수 없습니다.')));
            return;
          }
          await _pushAdaptiveRoute<void>(
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
        barrierColor: Colors.black.withOpacity(0.18),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return Center(
            child: SizedBox(
              width: 232,
              child: Material(
                color: Colors.transparent,
                child: buildOptions(ctx, compact: true),
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
      builder: (ctx) => buildOptions(ctx, compact: false),
    );
  }

  Future<void> _showDeleteConfirmDialog() async {
    if (_isDeleting) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SnapFitColors.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 22.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              '앨범 삭제',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
        content: Text(
          '삭제하면 앨범 데이터와 연결된 이미지가\n스토리지/DB에서 함께 정리됩니다.\n\n이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(
            fontSize: 14.sp,
            color: SnapFitColors.textSecondaryOf(context),
            height: 1.55,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
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
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '삭제하기',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w800,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final album = ref.read(albumEditorViewModelProvider.notifier).album;
    if (album == null || album.id <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제할 앨범 정보를 찾을 수 없습니다.')));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    if (!mounted) return;
    setState(() => _isDeleting = true);

    try {
      await ref.read(albumRepositoryProvider).deleteAlbum(album.id);
      if (!mounted) return;
      // 실서비스 체감 개선: 삭제 성공 즉시 이전 화면으로 복귀
      Navigator.pop(context, <String, dynamic>{'deletedAlbumId': album.id});
      // 목록/사용량 갱신은 백그라운드에서 수행
      unawaited(ref.read(homeViewModelProvider.notifier).refresh());
      ref.invalidate(myStorageQuotaProvider);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data?.toString() ?? '';
      final alreadyDeleted = status == 400 && body.contains('앨범을 찾을 수 없습니다.');
      if (alreadyDeleted) {
        if (!mounted) return;
        Navigator.pop(context, <String, dynamic>{'deletedAlbumId': album.id});
        unawaited(ref.read(homeViewModelProvider.notifier).refresh());
        ref.invalidate(myStorageQuotaProvider);
        return;
      }
      if (mounted) {
        setState(() => _isDeleting = false);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            status == 403
                ? '인증이 만료되었거나 권한이 없습니다. 다시 로그인 후 시도해주세요.'
                : '앨범 삭제에 실패했습니다: ${e.message}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('앨범 삭제에 실패했습니다: $e')));
    }
  }

  // 제작확정 확인 다이얼로그
  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SnapFitColors.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: SnapFitColors.accent,
              size: 22.sp,
            ),
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
          '제작 확정 후 주문 화면으로 이동할 수 있습니다.\n앨범 수정은 이후에도 계속 가능합니다.\n\n지금 제작을 확정하시겠습니까?',
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
        body: Center(
          child: CircularProgressIndicator(color: SnapFitColors.accent),
        ),
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
              Text(
                '앨범을 생성하고 있습니다...',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 제작확정 완료 화면
    if (_isFrozen) {
      return AlbumFrozenScreen(
        album: vm.album,
        onClose: () {
          Navigator.pop(context, true); // 홈 갱신 필요
          ref.read(homeViewModelProvider.notifier).refresh();
        },
        onOrder: () {
          final album = vm.album;
          if (album == null || album.id <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('주문할 앨범 정보를 찾을 수 없습니다.')),
            );
            return;
          }

          unawaited(
            _pushAdaptiveRoute<bool>(
              MaterialPageRoute(
                builder: (_) => PrintOrderCheckoutScreen(
                  albumId: album.id,
                  albumTitle: album.title.trim().isEmpty
                      ? '스냅핏 앨범'
                      : album.title,
                  pageCount: vm.pages.length,
                ),
              ),
            ).then((ordered) {
              if (ordered == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('주문이 접수되었습니다. 주문내역에서 진행 상태를 확인해주세요.'),
                  ),
                );
              }
            }),
          );
        },
      );
    }

    vm.ensureCoverPage();
    final allPages = vm.pages;

    final useContinuousOpenSurface = widget.initialSpreadIndex > 0;
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final media = MediaQuery.of(context);
    final bottomSystemInset = math.max(
      media.viewPadding.bottom,
      media.viewInsets.bottom,
    );
    final rightSystemInset = math.max(
      media.viewPadding.right,
      media.viewInsets.right,
    );

    int spreadForFocusPage(int pageIndex) {
      if (pageIndex <= 0) return 0;
      return 1 + ((pageIndex - 1) ~/ 2);
    }

    void selectSpread(int spread) {
      final pageIndex = spread <= 0 ? 0 : 1 + ((spread - 1) * 2);
      final target = pageIndex.clamp(0, allPages.length - 1) as int;
      setState(() => _focusPageIndex = target);
    }

    Widget buildReaderMetaPill() {
      final isCover = _focusPageIndex == 0;
      final totalInner = allPages.length - 1;
      final label = isCover
          ? '커버'
          : '${_focusPageIndex.toString().padLeft(2, '0')} / ${totalInner.toString().padLeft(2, '0')}';
      return Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.48),
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(color: Colors.white.withOpacity(0.68)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: SnapFitColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0x9E151412),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      );
    }

    Widget readerView() {
      if (allPages.isEmpty) {
        return Center(
          child: Text(
            '아직 페이지가 없어요.',
            style: TextStyle(
              fontSize: 14.sp,
              color: SnapFitColors.textMutedOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }

      return AlbumReaderSinglePageView(
        allPages: allPages,
        selectedCover: state.selectedCover,
        coverTheme: state.selectedTheme,
        pageController: _pageController,
        interaction: _interaction,
        layerBuilder: _layerBuilder,
        canvasKey: _coverKey,
        maxSpreadWidthFactor: useContinuousOpenSurface && isLandscape
            ? 0.93
            : 1.0,
        contentAlignment: isLandscape
            ? Alignment.topCenter
            : const Alignment(0, -0.16),
        focusMode: true,
        focusBottomInset: isLandscape
            ? bottomSystemInset
            : 120.h + bottomSystemInset,
        requestedFocusPageIndex: _focusPageIndex,
        onCanvasSizeChanged: (size) {
          if (_coverSize == size) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _coverSize = size);
            vm.setCoverCanvasSize(size);
          });
        },
        onPageChanged: (index) {
          final nextFocus = index <= 0 ? 0 : 1 + ((index - 1) * 2);
          setState(
            () => _focusPageIndex =
                nextFocus.clamp(0, allPages.length - 1) as int,
          );
        },
        onFocusPageChanged: (index) {
          if (_focusPageIndex == index) return;
          setState(() => _focusPageIndex = index);
        },
        onStateChanged: () {
          if (mounted) setState(() {});
        },
      );
    }

    const paperTop = Color(0xFFEFE2D0);
    const paperBottom = Color(0xFFF8EFE2);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: WillPopScope(
        onWillPop: () async => !_isDeleting,
        child: Scaffold(
          backgroundColor: paperTop,
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [paperTop, paperBottom],
                  ),
                ),
                child: Stack(
                  children: [
                    if (useContinuousOpenSurface)
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.34,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: SnapFitColors.readerGradientOf(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    SafeArea(
                      left: !isLandscape,
                      right: !isLandscape,
                      bottom: false,
                      child: isLandscape
                          ? Stack(
                              children: [
                                Positioned.fill(child: readerView()),
                                if (allPages.isNotEmpty)
                                  Positioned(
                                    right: 8 + rightSystemInset,
                                    top: 58,
                                    bottom: 18 + bottomSystemInset,
                                    width: 56,
                                    child: _LandscapePageRail(
                                      pages: allPages,
                                      focusPageIndex: _focusPageIndex,
                                      previewBuilder: _layerBuilder,
                                      baseCanvasSize: _baseCanvasSize,
                                      onSpreadSelected: selectSpread,
                                    ),
                                  ),
                                Positioned(
                                  left: 10,
                                  top: 10,
                                  child: _LandscapeReaderButton(
                                    icon: platformBackIcon(),
                                    onTap: _isDeleting
                                        ? () {}
                                        : () => Navigator.pop(context),
                                  ),
                                ),
                                Positioned(
                                  right: 14,
                                  top: 10,
                                  child: _LandscapeReaderButton(
                                    icon: Icons.more_horiz_rounded,
                                    onTap: _showMoreOptions,
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                Positioned.fill(child: readerView()),
                                // ─── 1. 상단 헤더 ───
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                      vertical: 12.h,
                                    ),
                                    child: Row(
                                      children: [
                                        // 뒤로가기
                                        AlbumReaderCircleBtn(
                                          icon: platformBackIcon(),
                                          onTap: _isDeleting
                                              ? () {}
                                              : () => Navigator.pop(context),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: buildReaderMetaPill(),
                                          ),
                                        ),
                                        // ... 메뉴
                                        AlbumReaderCircleBtn(
                                          icon: Icons.more_horiz_rounded,
                                          onTap: _showMoreOptions,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // ─── 5. 하단 썸네일 스트립 ───
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 18.h + bottomSystemInset,
                                  child: AlbumReaderThumbnailStrip(
                                    pages: allPages,
                                    pageController: allPages.isNotEmpty
                                        ? _pageController
                                        : null,
                                    previewBuilder: _layerBuilder,
                                    baseCanvasSize: _baseCanvasSize,
                                    height: 46.h,
                                    currentSpreadIndex: spreadForFocusPage(
                                      _focusPageIndex,
                                    ),
                                    onSpreadSelected: selectSpread,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              if (_isDeleting) ...[
                Positioned.fill(
                  child: AbsorbPointer(
                    child: Container(color: Colors.black.withOpacity(0.34)),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 34.w,
                      height: 34.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: SnapFitColors.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LandscapePageRail extends StatelessWidget {
  const _LandscapePageRail({
    required this.pages,
    required this.focusPageIndex,
    required this.previewBuilder,
    required this.baseCanvasSize,
    required this.onSpreadSelected,
  });

  final List<AlbumPage> pages;
  final int focusPageIndex;
  final LayerBuilder previewBuilder;
  final Size baseCanvasSize;
  final ValueChanged<int> onSpreadSelected;

  String get _pageLabel {
    if (pages.isEmpty || focusPageIndex <= 0) return '커버';
    final totalInner = pages.length - 1;
    final left = focusPageIndex.clamp(1, totalInner);
    final right = (left + 1).clamp(1, totalInner);
    return right > left ? '$left-$right\n/$totalInner' : '$left\n/$totalInner';
  }

  int get _selectedSpread {
    if (focusPageIndex <= 0) return 0;
    return 1 + ((focusPageIndex - 1) ~/ 2);
  }

  List<List<int>> get _spreadItems {
    if (pages.isEmpty) return const [];
    final items = <List<int>>[
      [0],
    ];
    for (var i = 1; i < pages.length; i += 2) {
      items.add(i + 1 < pages.length ? [i, i + 1] : [i]);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1916).withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _pageLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ListView.builder(
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  itemCount: _spreadItems.length,
                  itemBuilder: (context, index) {
                    final pageIndices = _spreadItems[index];
                    final isSelected = index == _selectedSpread;
                    final thumbHeight = 38.0;
                    final aspect = baseCanvasSize.width / baseCanvasSize.height;
                    final singleWidth = 22.0;
                    final slotCount = pageIndices.length == 1 ? 1 : 2;
                    final itemHeight = pageIndices.length == 1
                        ? singleWidth / aspect
                        : thumbHeight;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSpreadSelected(index),
                      child: Container(
                        width: 44,
                        height: itemHeight,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? SnapFitColors.accent
                                : Colors.white.withValues(alpha: 0.34),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Row(
                          children: [
                            for (var slot = 0; slot < slotCount; slot++) ...[
                              if (slot > 0)
                                Container(
                                  width: 1,
                                  color: Colors.black.withValues(alpha: 0.08),
                                ),
                              Expanded(
                                child: slot < pageIndices.length
                                    ? AlbumReaderPageContent(
                                        layers: pages[pageIndices[slot]].layers,
                                        targetW: singleWidth,
                                        targetH: itemHeight,
                                        previewBuilder: previewBuilder,
                                        baseCanvasSize: baseCanvasSize,
                                        backgroundColor:
                                            pages[pageIndices[slot]]
                                                    .backgroundColor !=
                                                null
                                            ? Color(
                                                pages[pageIndices[slot]]
                                                    .backgroundColor!,
                                              )
                                            : null,
                                      )
                                    : ColoredBox(
                                        color: const Color(0xFFFFFCF5),
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandscapeReaderButton extends StatelessWidget {
  const _LandscapeReaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 24, color: const Color(0xFF1B1916)),
        ),
      ),
    );
  }
}
