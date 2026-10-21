import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import '../../../../shared/widgets/album_stage_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../../../../core/constants/cover_theme.dart';
import 'dart:math' as math;

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../shared/web/web_design.dart';
import '../controllers/layer_builder.dart';
import '../controllers/layer_interaction_manager.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../../domain/entities/album_page.dart';
import '../widgets/reader/album_reader_single_page_view.dart';
import '../widgets/reader/album_reader_thumbnail_strip.dart';
import '../widgets/reader/album_reader_page_content.dart';
import '../widgets/reader/album_reader_more_options_sheet.dart';
import '../widgets/reader/album_completion_confirmation.dart';
import '../widgets/web/web_album_workspace.dart';
import '../viewmodels/home_view_model.dart';
import '../../data/api/album_provider.dart';
import '../../../billing/data/billing_provider.dart';
import 'page_editor_screen.dart';
import 'album_reader_inner_detail_screen.dart';
import '../../domain/entities/album.dart';
import 'album_invite_screen.dart';
import 'print_order_preview_screen.dart';

class AlbumReaderScreen extends ConsumerStatefulWidget {
  final int initialSpreadIndex;
  final GlobalKey? openingCoverKey;
  final ValueListenable<bool>? openingCoverVisible;

  const AlbumReaderScreen({
    super.key,
    this.initialSpreadIndex = 0,
    this.openingCoverKey,
    this.openingCoverVisible,
  });

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
  bool _isDeleting = false; // 삭제 진행 중 UI 잠금
  late int _focusPageIndex;
  int? _requestedSpreadFocus;

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
    if (vm.album?.allowsEditing == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보기 전용 앨범이에요. 편집은 앨범 소유자에게 요청해 주세요.')),
      );
      return;
    }
    Widget buildOptions(BuildContext ctx, {required bool compact}) {
      return AlbumReaderMoreOptionsSheet(
        onEdit: () async {
          final albumId = vm.album?.id;
          Navigator.pop(ctx);
          await _pushAdaptiveRoute<bool>(
            MaterialPageRoute(
              settings: albumId != null && albumId > 0
                  ? WebAppRouteSettings(
                      WebAppLocation(WebAppPage.editor, '$albumId'),
                    )
                  : null,
              builder: (_) =>
                  const PageEditorScreen(returnToPreviousOnSave: true),
            ),
          );
          if (context.mounted) {
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
          unawaited(_prepareBookOrder());
        },
        onDelete: vm.album?.allowsManagement == false
            ? null
            : () {
                Navigator.pop(ctx);
                _showDeleteConfirmDialog();
              },
        onInvite: vm.album?.allowsManagement == false
            ? null
            : () async {
                Navigator.pop(ctx);
                final album = vm.album;
                if (album == null || album.id <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('앨범 정보를 찾을 수 없습니다.')),
                  );
                  return;
                }
                await _pushAdaptiveRoute<void>(
                  MaterialPageRoute(
                    builder: (_) => AlbumInviteScreen(
                      album: album,
                      albumId: album.id,
                      albumTitle: album.title.isEmpty
                          ? 'SnapFit Album'
                          : album.title,
                    ),
                  ),
                );
              },
        compact: compact,
      );
    }

    if (kIsWeb) {
      showWebAwareDialog<void>(
        context: context,
        maxWidth: 380,
        maxHeight: 520,
        builder: (ctx) => buildOptions(ctx, compact: true),
      );
      return;
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
        backgroundColor: kIsWeb
            ? WebPalette.of(context).surface
            : SnapFitColors.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kIsWeb ? 12 : 20.r),
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

  Future<void> _openAlbumEditor() async {
    if (_isDeleting) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (vm.album?.allowsEditing == false) return;
    final albumId = vm.album?.id;
    await _pushAdaptiveRoute<bool>(
      MaterialPageRoute(
        settings: albumId != null && albumId > 0
            ? WebAppRouteSettings(WebAppLocation(WebAppPage.editor, '$albumId'))
            : null,
        builder: (_) => PageEditorScreen(
          initialPageIndex: _focusPageIndex,
          returnToPreviousOnSave: true,
        ),
      ),
    );
    if (!mounted) return;
    final current = ref.read(albumEditorViewModelProvider.notifier);
    if (_coverSize != Size.zero) current.setCoverCanvasSize(_coverSize);
    setState(() {});
  }

  Future<void> _prepareBookOrder() async {
    if (_isDeleting) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (vm.album?.allowsEditing == false) return;
    final confirmed = await showAlbumCompletionConfirmation(context);
    if (!mounted || !confirmed) return;
    final album = ref.read(albumEditorViewModelProvider.notifier).album;
    if (album == null || album.id <= 0 || !album.allowsEditing) return;
    final result = await _pushAdaptiveRoute<String>(
      MaterialPageRoute(
        settings: WebAppRouteSettings(
          WebAppLocation(WebAppPage.print, '${album.id}'),
        ),
        builder: (_) => PrintOrderPreviewScreen(
          albumId: album.id,
          albumTitle: album.title.trim().isEmpty ? '스냅핏 앨범' : album.title,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'edit_album') {
      await _openAlbumEditor();
    } else {
      setState(() {});
    }
  }

  Future<void> _inviteFromWeb() async {
    if (_isDeleting) return;
    final album = ref.read(albumEditorViewModelProvider.notifier).album;
    if (album == null || album.id <= 0 || !album.allowsManagement) return;
    await _pushAdaptiveRoute<void>(
      MaterialPageRoute(
        builder: (_) => AlbumInviteScreen(
          album: album,
          albumId: album.id,
          albumTitle: album.title.trim().isEmpty ? '스냅핏 앨범' : album.title,
        ),
      ),
    );
  }

  Future<void> _openWebPageDetail() async {
    if (_isDeleting || _focusPageIndex <= 0) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final pages = vm.pages.skip(1).toList();
    if (pages.isEmpty) return;
    await _pushAdaptiveRoute<void>(
      MaterialPageRoute(
        builder: (_) => AlbumReaderInnerDetailScreen(
          innerPages: pages,
          initialPageIndex: (_focusPageIndex - 1).clamp(0, pages.length - 1),
          singlePageW: kCoverReferenceWidth,
          singlePageH: kCoverReferenceWidth / vm.selectedCover.ratio,
          interaction: _interaction,
          layerBuilder: _layerBuilder,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _buildWebReader({
    required List<AlbumPage> pages,
    required CoverSize cover,
    required CoverTheme theme,
  }) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final album = vm.album;
    final focus = pages.isEmpty
        ? 0
        : _focusPageIndex.clamp(0, pages.length - 1).toInt();
    final base = Size(kCoverReferenceWidth, kCoverReferenceWidth / cover.ratio);
    final previewInteraction = LayerInteractionManager.preview(ref, () => base);
    final previewBuilder = LayerBuilder(previewInteraction, () => base);

    void selectPage(int index) {
      if (_isDeleting || index < 0 || index >= pages.length) return;
      setState(() => _focusPageIndex = index);
    }

    Widget rail({bool horizontal = false}) => WebAlbumPageRail(
      pages: pages,
      selectedIndex: focus,
      cover: cover,
      theme: theme,
      previewBuilder: previewBuilder,
      onSelected: selectPage,
      horizontal: horizontal,
    );

    Widget document() {
      if (pages.isEmpty) {
        return Center(
          child: Text(
            '아직 페이지가 없어요.',
            style: TextStyle(color: WebPalette.of(context).muted),
          ),
        );
      }
      final page = pages[focus];
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(
            constraints.maxWidth,
            constraints.maxHeight * cover.ratio,
          );
          if (width <= 0 || !width.isFinite) return const SizedBox.shrink();
          final height = width / cover.ratio;
          return Center(
            child: RepaintBoundary(
              child: ClipRect(
                child: AlbumReaderPageContent(
                  key: ValueKey('web-reader-document-$focus'),
                  layers: page.layers,
                  targetW: width,
                  targetH: height,
                  baseCanvasSize: base,
                  previewBuilder: previewBuilder,
                  theme: focus == 0 ? theme : null,
                  backgroundColor: page.backgroundColor == null
                      ? null
                      : Color(page.backgroundColor!),
                  flatPresentation: true,
                  isCover: focus == 0,
                ),
              ),
            ),
          );
        },
      );
    }

    return WillPopScope(
      onWillPop: () async => !_isDeleting,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AbsorbPointer(
            absorbing: _isDeleting,
            child: WebAlbumReaderWorkspace(
              title: album?.title.trim().isNotEmpty == true
                  ? album!.title
                  : '스냅핏 앨범',
              description:
                  '${cover.displayName}'
                  '${cover.productId == null ? '' : ' · ${cover.coverType.label}'}'
                  ' · 내지 ${math.max(0, pages.length - 1)}쪽'
                  '${album?.allowsEditing == false ? ' · 보기 전용' : ''}',
              pageLabel: focus == 0
                  ? '표지'
                  : '내지 $focus / ${math.max(0, pages.length - 1)}쪽',
              canvas: document(),
              pageRail: rail(),
              compactPageRail: rail(horizontal: true),
              busy: _isDeleting,
              onBack: () => Navigator.maybePop(context),
              onEdit: album?.allowsEditing == false
                  ? null
                  : () => unawaited(_openAlbumEditor()),
              onOrder: album == null || album.id <= 0 || !album.allowsEditing
                  ? null
                  : () => unawaited(_prepareBookOrder()),
              onPrevious: focus > 0 ? () => selectPage(focus - 1) : null,
              onNext: focus + 1 < pages.length
                  ? () => selectPage(focus + 1)
                  : null,
              onDetail: focus > 0
                  ? () => unawaited(_openWebPageDetail())
                  : null,
              managementMenu: album?.allowsManagement == false
                  ? null
                  : PopupMenuButton<String>(
                      tooltip: '앨범 관리',
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (action) {
                        if (action == 'invite') unawaited(_inviteFromWeb());
                        if (action == 'delete') {
                          unawaited(_showDeleteConfirmDialog());
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'invite',
                          child: Text('함께 편집할 사람 초대'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('앨범 삭제')),
                      ],
                    ),
            ),
          ),
          if (_isDeleting)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x44FFFFFF),
                child: Center(child: CircularProgressIndicator()),
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

    if (kIsWeb && (state == null || state.isCreatingInBackground)) {
      return SnapFitWebShell(
        title: '앨범 미리보기',
        showNavigation: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 18),
              Text(
                state?.isCreatingInBackground == true
                    ? '앨범을 준비하고 있습니다'
                    : '앨범을 불러오고 있습니다',
                style: TextStyle(
                  color: WebPalette.of(context).muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

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

    vm.ensureCoverPage();
    final allPages = vm.pages;

    if (kIsWeb) {
      return _buildWebReader(
        pages: allPages,
        cover: state.selectedCover,
        theme: state.selectedTheme,
      );
    }

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
    final leftSystemInset = math.max(
      media.viewPadding.left,
      media.viewInsets.left,
    );

    int spreadForFocusPage(int pageIndex) {
      if (pageIndex <= 0) return 0;
      return 1 + ((pageIndex - 1) ~/ 2);
    }

    void selectSpread(int spread) {
      final pageIndex = spread <= 0 ? 0 : 1 + ((spread - 1) * 2);
      final target = pageIndex.clamp(0, allPages.length - 1) as int;
      setState(() {
        _requestedSpreadFocus = target;
        _focusPageIndex = target;
      });
    }

    Widget buildReaderPosition() {
      final isCover = _focusPageIndex == 0;
      final totalInner = allPages.length - 1;
      final left = isCover ? 0 : 1 + ((_focusPageIndex - 1) ~/ 2) * 2;
      final right = math.min(left + 1, totalInner);
      final label = isCover
          ? '표지'
          : '${left == right ? left : '$left-$right'} / $totalInner';
      return Semantics(
        liveRegion: true,
        child: Text(
          label,
          key: const ValueKey('reader-page-position'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AlbumStageStyle.ink(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
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
        openingCoverKey: widget.openingCoverKey,
        openingCoverVisible: widget.openingCoverVisible,
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
          // Riffle frames must not pull the picker away from its chosen target.
          if (_requestedSpreadFocus != null &&
              nextFocus != _requestedSpreadFocus)
            return;
          setState(() {
            _focusPageIndex = nextFocus.clamp(0, allPages.length - 1) as int;
            _requestedSpreadFocus = null;
          });
        },
        onFocusPageChanged: (index) {
          if (_requestedSpreadFocus != null && index != _requestedSpreadFocus)
            return;
          if (_focusPageIndex == index && _requestedSpreadFocus == null) return;
          setState(() {
            _focusPageIndex = index;
            _requestedSpreadFocus = null;
          });
        },
        onStateChanged: () {
          if (mounted) setState(() {});
        },
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AlbumStageStyle.overlay(context),
      child: WillPopScope(
        onWillPop: () async => !_isDeleting,
        child: Scaffold(
          backgroundColor: AlbumStageStyle.top(context),
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: AlbumStageStyle.gradient(context),
                ),
                child: Stack(
                  children: [
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
                                  left: 10 + leftSystemInset,
                                  top: 10,
                                  child: _ReaderHeaderButton(
                                    icon: platformBackIcon(),
                                    tooltip: '앨범 목록으로 돌아가기',
                                    onTap: _isDeleting
                                        ? () {}
                                        : () => Navigator.pop(context),
                                  ),
                                ),
                                Positioned(
                                  right: 14 + rightSystemInset,
                                  top: 10,
                                  child: _ReaderHeaderButton(
                                    icon: Icons.more_horiz_rounded,
                                    tooltip: '앨범 메뉴',
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
                                        _ReaderHeaderButton(
                                          icon: platformBackIcon(),
                                          tooltip: '앨범 목록으로 돌아가기',
                                          onTap: _isDeleting
                                              ? () {}
                                              : () => Navigator.pop(context),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: buildReaderPosition(),
                                          ),
                                        ),
                                        // ... 메뉴
                                        _ReaderHeaderButton(
                                          icon: Icons.more_horiz_rounded,
                                          tooltip: '앨범 메뉴',
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

class _LandscapePageRail extends StatefulWidget {
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

  @override
  State<_LandscapePageRail> createState() => _LandscapePageRailState();
}

class _LandscapePageRailState extends State<_LandscapePageRail> {
  final _scroll = ScrollController();
  String? _alignment;
  List<AlbumPage> get pages => widget.pages;
  int get focusPageIndex => widget.focusPageIndex;
  Size get baseCanvasSize => widget.baseCanvasSize;
  LayerBuilder get previewBuilder => widget.previewBuilder;
  ValueChanged<int> get onSpreadSelected => widget.onSpreadSelected;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _alignSelection(BuildContext context) {
    final aspect = baseCanvasSize.width / baseCanvasSize.height;
    final caption = MediaQuery.textScalerOf(context).scale(10) * 1.4;
    final signature =
        '$_selectedSpread:$aspect:$caption:${MediaQuery.sizeOf(context)}:${MediaQuery.viewPaddingOf(context)}:${MediaQuery.viewInsetsOf(context)}:${pages.length}';
    if (_alignment == signature) return;
    final animate = _alignment != null;
    _alignment = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final coverExtent = math.max(44.0, 30 / aspect) + caption + 16;
      final spreadExtent = math.max(44.0, 22 / aspect) + caption + 16;
      final top = _selectedSpread == 0
          ? 3.0
          : 3 + coverExtent + (_selectedSpread - 1) * spreadExtent;
      final extent = _selectedSpread == 0 ? coverExtent : spreadExtent;
      final target = (top + extent / 2 - _scroll.position.viewportDimension / 2)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      if ((target - _scroll.offset).abs() < 1) return;
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  String get _pageLabel {
    return '${math.max(0, pages.length - 1)}쪽';
  }

  int get _selectedSpread {
    if (focusPageIndex <= 0) return 0;
    return 1 + ((focusPageIndex - 1) ~/ 2);
  }

  List<List<int>> get _spreadItems =>
      AlbumReaderThumbnailStrip.spreads(pages.length);

  @override
  Widget build(BuildContext context) {
    _alignSelection(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AlbumStageStyle.line(context))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        child: Column(
          children: [
            Container(
              width: 44,
              alignment: Alignment.center,
              child: Text(
                _pageLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AlbumStageStyle.ink(context).withValues(alpha: .65),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: ListView.builder(
                  key: const ValueKey('reader-spread-rail'),
                  controller: _scroll,
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  itemCount: _spreadItems.length,
                  itemBuilder: (context, index) {
                    final pageIndices = _spreadItems[index];
                    final isSelected = index == _selectedSpread;
                    final aspect = baseCanvasSize.width / baseCanvasSize.height;
                    final slotCount = index == 0 ? 1 : 2;
                    final previewWidth = index == 0 ? 30.0 : 44.0;
                    final singleWidth = previewWidth / slotCount;
                    final itemHeight = singleWidth / aspect;
                    final label = AlbumReaderThumbnailStrip.label(pageIndices);

                    return Semantics(
                      label: index == 0 ? label : '$label쪽',
                      button: true,
                      selected: isSelected,
                      excludeSemantics: true,
                      onTap: () => onSpreadSelected(index),
                      child: GestureDetector(
                        key: ValueKey('reader-rail-spread-$index'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSpreadSelected(index),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                child: Center(
                                  child: Container(
                                    width: previewWidth,
                                    height: itemHeight,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: isSelected
                                            ? SnapFitColors.accent
                                            : AlbumStageStyle.line(context),
                                        width: 1.5,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Row(
                                      children: [
                                        for (
                                          var slot = 0;
                                          slot < slotCount;
                                          slot++
                                        ) ...[
                                          if (slot > 0)
                                            Container(
                                              width: 1,
                                              color: Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                            ),
                                          Expanded(
                                            child: slot < pageIndices.length
                                                ? AlbumReaderPageContent(
                                                    layers:
                                                        pages[pageIndices[slot]]
                                                            .layers,
                                                    targetW: singleWidth,
                                                    targetH: itemHeight,
                                                    previewBuilder:
                                                        previewBuilder,
                                                    baseCanvasSize:
                                                        baseCanvasSize,
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
                                                    color: const Color(
                                                      0xFFFFFCF5,
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.4,
                                  letterSpacing: 0,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: AlbumStageStyle.ink(
                                    context,
                                  ).withValues(alpha: isSelected ? 1 : .6),
                                ),
                              ),
                            ],
                          ),
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

class _ReaderHeaderButton extends StatelessWidget {
  const _ReaderHeaderButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: Icon(icon, size: 24, color: AlbumStageStyle.ink(context)),
    );
  }
}
