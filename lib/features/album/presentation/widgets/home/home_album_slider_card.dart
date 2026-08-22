import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../domain/entities/album.dart';
import 'home_focus_wrap.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_album_actions.dart';

/// 슬라이더용 앨범 커버 카드
class HomeAlbumSliderCard extends ConsumerStatefulWidget {
  final Album album;
  final int index;
  final double currentPage;

  const HomeAlbumSliderCard({
    super.key,
    required this.album,
    required this.index,
    required this.currentPage,
  });

  @override
  ConsumerState<HomeAlbumSliderCard> createState() =>
      _HomeAlbumSliderCardState();
}

class _AlbumStatusChip extends StatelessWidget {
  const _AlbumStatusChip({
    required this.label,
    required this.subLabel,
    required this.isDone,
    required this.isLocked,
  });

  final String label;
  final String subLabel;
  final bool isDone;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? SnapFitColors.accent
        : isLocked
        ? const Color(0xFFFFB86B)
        : Colors.white;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.48),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDone
                ? Icons.task_alt_rounded
                : isLocked
                ? Icons.edit_note_rounded
                : Icons.schedule_rounded,
            size: 12.sp,
            color: color,
          ),
          SizedBox(width: 5.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subLabel,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.74),
                  fontSize: 8.2.sp,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeAlbumSliderCardState extends ConsumerState<HomeAlbumSliderCard>
    with SingleTickerProviderStateMixin {
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
    final diff = (widget.currentPage - widget.index).abs();
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
    final targetPages = widget.album.targetPages <= 0
        ? widget.album.totalPages
        : widget.album.targetPages;
    final progress = targetPages <= 0
        ? 0.0
        : (widget.album.totalPages / targetPages).clamp(0.0, 1.0);
    final progressLabel = progress >= 1 ? '완성' : '${(progress * 100).round()}%';
    final hasCollaboratorLock = (widget.album.lockedBy ?? '').trim().isNotEmpty;
    final updatedLabel = _formatAlbumUpdatedLabel(widget.album.updatedAt);
    final statusLabel = hasCollaboratorLock
        ? '함께 편집중'
        : progress >= 1
        ? '제작 준비 완료'
        : '최근 작업';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 0.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final ratio = coverSize.ratio;
          // 정사각형을 기준 크기로 두고:
          // - 세로형: 정사각형과 높이는 같고 더 좁게
          // - 가로형: 정사각형과 폭은 같고 더 낮게
          final baseSquareSize = h * (0.69 + (0.11 * focus));
          final maxAllowedWidth = constraints.maxWidth * 0.98;
          final squareWidth = baseSquareSize > maxAllowedWidth
              ? maxAllowedWidth
              : baseSquareSize;
          final squareHeight = squareWidth;

          final bool isLandscape = ratio > 1.12;
          final bool isPortrait = ratio < 0.88;
          final contentWidth = isPortrait ? squareHeight * ratio : squareWidth;
          final contentHeight = isLandscape
              ? squareWidth / ratio
              : squareHeight;
          final pageDelta = (widget.index - widget.currentPage).clamp(
            -1.0,
            1.0,
          );
          final gapPush = pageDelta * 18.w;
          final coverContent = OverflowBox(
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: Alignment.center,
            child: SizedBox(
              width: contentWidth,
              height: contentHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: HomeAlbumCoverThumbnail(
                      album: widget.album,
                      height: contentHeight,
                      maxWidth: contentWidth,
                      showShadow: true,
                      shadowScaleMultiplier: 6.8 + (2.4 * focus),
                    ),
                  ),
                  if (focus > 0.55)
                    Positioned(
                      left: 10.w,
                      top: 10.h,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: focus.clamp(0.0, 1.0),
                        child: _AlbumStatusChip(
                          label: statusLabel,
                          subLabel: updatedLabel,
                          isDone: progress >= 1,
                          isLocked: hasCollaboratorLock,
                        ),
                      ),
                    ),
                  if (focus > 0.55)
                    Positioned(
                      left: 10.w,
                      right: 10.w,
                      bottom: 10.h,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: focus.clamp(0.0, 1.0),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 7.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.56),
                            borderRadius: BorderRadius.circular(999.r),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.24),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasCollaboratorLock
                                    ? Icons.edit_note_rounded
                                    : Icons.auto_stories_outlined,
                                size: 13.sp,
                                color: Colors.white,
                              ),
                              SizedBox(width: 5.w),
                              Expanded(
                                child: Text(
                                  hasCollaboratorLock
                                      ? '${widget.album.lockedBy} 편집 중'
                                      : '${widget.album.totalPages}/${targetPages <= 0 ? widget.album.totalPages : targetPages}p',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 7.w,
                                  vertical: 3.h,
                                ),
                                decoration: BoxDecoration(
                                  color: progress >= 1
                                      ? SnapFitColors.accent
                                      : Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(999.r),
                                ),
                                child: Text(
                                  progressLabel,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w900,
                                    decoration: TextDecoration.none,
                                  ),
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
          );

          final closedCover = HomeFocusWrap(
            focus: focus,
            applyShadow: false,
            child: Transform.translate(
              offset: Offset(gapPush, 0),
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

  String _formatAlbumUpdatedLabel(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '방금 업데이트';
    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.inMinutes < 1) return '방금 업데이트';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${parsed.month}.${parsed.day} 업데이트';
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
    try {
      await HomeAlbumActions.openAlbum(context, ref, widget.album);
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
