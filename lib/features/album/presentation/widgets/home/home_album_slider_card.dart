import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../domain/entities/album.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../viewmodels/home_view_model.dart';
import 'home_focus_wrap.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_paper_unfold_route.dart';

/// 슬라이더용 앨범 커버 카드
class HomeAlbumSliderCard extends ConsumerStatefulWidget {
  final Album album;
  final int index;
  final PageController pageController;

  const HomeAlbumSliderCard({
    super.key,
    required this.album,
    required this.index,
    required this.pageController,
  });

  @override
  ConsumerState<HomeAlbumSliderCard> createState() =>
      _HomeAlbumSliderCardState();
}

class _HomeAlbumSliderCardState extends ConsumerState<HomeAlbumSliderCard>
    with SingleTickerProviderStateMixin {
  final GlobalKey _coverRepaintKey = GlobalKey();
  late final AnimationController _tapController;
  late final Animation<double> _tapScale;
  Timer? _pendingUnpress;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _tapScale = Tween<double>(
      begin: 1,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));
  }

  void _cancelPendingUnpress() {
    _pendingUnpress?.cancel();
    _pendingUnpress = null;
  }

  @override
  void dispose() {
    _cancelPendingUnpress();
    _tapController.dispose();
    super.dispose();
  }

  /// 0..1, 포커스일수록 1 (중앙에 가까울수록 1)
  double _focusFactor() {
    final page = widget.pageController.page ?? widget.index.toDouble();
    final diff = (page - widget.index).abs();
    if (diff >= 1) return 0;
    return 1 - diff;
  }

  @override
  Widget build(BuildContext context) {
    final coverSize = coverSizes.firstWhere(
      (s) => s.ratio.toString() == widget.album.ratio,
      orElse: () => coverSizes.first,
    );
    final focus = _focusFactor();

    return Padding(
      // 카드 간격을 줄여 여러 장이 동시에 보이도록
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 40.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 홈 셀(PageView 뷰포트) 안에서 세로/가로/정사각형이 같은 비중으로 보이도록
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final base = w < h ? w : h;
          final ratio = coverSize.ratio;
          final cw = ratio >= 1 ? base : base * ratio;
          final ch = ratio <= 1 ? base : base / ratio;
          final coverContent = SizedBox(
            width: cw,
            height: ch,
            child: HomeAlbumCoverThumbnail(
              album: widget.album,
              height: ch,
              maxWidth: cw,
              showShadow: false,
            ),
          );

          final closedCover = RepaintBoundary(
            key: _coverRepaintKey,
            child: HomeFocusWrap(
              focus: focus,
              applyShadow: false,
              child: Center(child: coverContent),
            ),
          );

          return GestureDetector(
            onTapDown: (_) {
              _cancelPendingUnpress();
              _tapController.forward();
            },
            onTapUp: (_) {
              _cancelPendingUnpress();
              _pendingUnpress = Timer(const Duration(milliseconds: 120), () {
                if (mounted) _tapController.reverse();
                _pendingUnpress = null;
              });
            },
            onTapCancel: () {
              _cancelPendingUnpress();
              _tapController.reverse();
            },
            onTap: () => _onTapThenNavigate(context),
            child: AnimatedBuilder(
              animation: _tapScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _tapScale.value,
                  alignment: Alignment.center,
                  child: Opacity(opacity: _tapScale.value, child: child),
                );
              },
              child: closedCover,
            ),
          );
        },
      ),
    );
  }

  /// 눌림 애니메이션이 끝난 뒤에만 화면 전환 (짧게 눌러도 무조건 다 눌린 다음 넘어감)
  void _onTapThenNavigate(BuildContext context) {
    _cancelPendingUnpress();
    _tapController.forward();
    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _tapController.removeStatusListener(onStatus);
        _tapController.reset();
        _handleTap(context);
      }
    }

    if (_tapController.status == AnimationStatus.completed) {
      _tapController.reset();
      _handleTap(context);
      return;
    }
    _tapController.addStatusListener(onStatus);
  }

  Future<void> _handleTap(BuildContext context) async {
    Rect? cardRect;
    ui.Image? coverImage;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final offset = box.localToGlobal(Offset.zero);
      cardRect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        box.size.width,
        box.size.height,
      );
    }

    try {
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      await ref.read(albumEditorViewModelProvider.future);
      await vm.prepareAlbumForEdit(widget.album);
      if (!context.mounted) return;

      final boundary =
          _coverRepaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        try {
          coverImage = await boundary.toImage(pixelRatio: 2.0);
        } catch (_) {}
      }

      if (!context.mounted) return;
      await Navigator.of(context).push(
        HomePaperUnfoldRoute(
          album: widget.album,
          cardRect: cardRect,
          coverImage: coverImage,
        ),
      );

      // 앨범 편집 후 돌아왔을 때 홈 화면 갱신
      if (context.mounted) {
        await ref.read(homeViewModelProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) _tapController.reverse();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('앨범 편집을 열 수 없습니다: $e')));
      }
    }
  }
}
