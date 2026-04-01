import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dio/dio.dart';
import 'dart:async';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/constants/cover_size.dart';
import '../controllers/cover_size_controller.dart';
import '../controllers/layer_builder.dart';
import '../controllers/layer_interaction_manager.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/reader/album_reader_single_page_view.dart';
import '../widgets/reader/album_reader_thumbnail_strip.dart';
import '../widgets/reader/album_reader_more_options_sheet.dart';
import '../widgets/reader/album_frozen_screen.dart';
import '../viewmodels/home_view_model.dart';
import '../../data/api/album_provider.dart';
import '../../../billing/data/billing_provider.dart';
import 'page_editor_screen.dart';
import 'album_reader_inner_detail_screen.dart';
import 'album_invite_screen.dart';
import 'print_order_checkout_screen.dart';

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
  Size _baseCanvasSize = const Size(
    kCoverReferenceWidth,
    kCoverReferenceWidth,
  ); // 초기값, initState에서 갱신됨
  Size _coverSize = Size.zero;
  bool _isFrozen = false; // 제작확정 여부
  bool _isDeleting = false; // 삭제 진행 중 UI 잠금

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
          _baseCanvasSize = Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
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
    if (_isDeleting) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AlbumReaderMoreOptionsSheet(
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
        onDetail: () {
          Navigator.pop(ctx);
          final safePage = _pageController.hasClients
              ? (_pageController.page ?? 0.0)
              : 0.0;
          if (safePage < 0.5) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('상세 보기는 앨범 내지에서 이용 가능합니다.')),
            );
            return;
          }
          final currentIndex = safePage.round();
          final leftIndex = 1 + (currentIndex - 1) * 2;
          final innerInitialIndex = leftIndex - 1;

          final vm = ref.read(albumEditorViewModelProvider.notifier);
          final innerPages = vm.pages.sublist(1);

          if (innerPages.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('보여줄 페이지가 없습니다.')));
            return;
          }

          final screenW = MediaQuery.sizeOf(context).width;
          final screenH = MediaQuery.sizeOf(context).height;

          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false, // 투명한 배경
              pageBuilder: (context, animation, secondaryAnimation) =>
                  FadeTransition(
                    opacity: animation,
                    child: AlbumReaderInnerDetailScreen(
                      innerPages: innerPages,
                      initialPageIndex: innerInitialIndex,
                      singlePageW: _baseCanvasSize.width,
                      singlePageH: _baseCanvasSize.height,
                      interaction: _interaction,
                      layerBuilder: _layerBuilder,
                    ),
                  ),
            ),
          );
        },
      ),
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

          Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => PrintOrderCheckoutScreen(
                albumId: album.id,
                albumTitle: (album.title ?? '').trim().isEmpty
                    ? '스냅핏 앨범'
                    : album.title!,
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
          });
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

    return WillPopScope(
      onWillPop: () async => !_isDeleting,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: SnapFitColors.readerGradientOf(context),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // ─── 1. 상단 헤더 ───
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      child: Row(
                        children: [
                          // 뒤로가기
                          AlbumReaderCircleBtn(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: _isDeleting
                                ? () {}
                                : () => Navigator.pop(context),
                          ),
                          // 가운데 타이틀
                          Expanded(
                            child: Column(
                              children: [
                                if (albumTitle.isNotEmpty)
                                  Text(
                                    albumTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      color: SnapFitColors.textSecondaryOf(
                                        context,
                                      ),
                                      // color: SnapFitColors.accent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
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
                          final int leftPage = (spreadIdx - 1) * 2 + 1;
                          final int rightPage = leftPage + 1;
                          if (rightPage <= totalInner) {
                            label = '$leftPage - $rightPage  /  $totalInner';
                          } else {
                            label = '$leftPage  /  $totalInner';
                          }
                        }
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18.w,
                            vertical: 6.h,
                          ),
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
                                  Icon(
                                    Icons.menu_book_outlined,
                                    size: 56.sp,
                                    color: SnapFitColors.textMutedOf(
                                      context,
                                    ).withOpacity(0.4),
                                  ),
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
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;
                                  debugPrint(
                                    '[AlbumReaderScreen] Canvas Size Changed: $size',
                                  );
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
                      pageController: allPages.isNotEmpty
                          ? _pageController
                          : null,
                      previewBuilder: _layerBuilder,
                      baseCanvasSize: _baseCanvasSize,
                      height: 64.h,
                    ),
                    SizedBox(height: 18.h),
                  ],
                ),
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
    );
  }
}
