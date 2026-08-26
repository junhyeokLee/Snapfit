import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../domain/entities/album.dart';
import 'home_album_actions.dart';
import 'home_album_slider_card.dart';

/// 중앙 앨범을 강조하고 좌우 앨범이 살짝 보이도록 하는 홈 캐러셀
class HomeAlbumSlider extends ConsumerStatefulWidget {
  final List<Album> albums;
  final ValueChanged<Album>? onFocusedAlbumChanged;
  final VoidCallback? onCreateAlbum;
  final VoidCallback? onOpenAlbumTab;

  const HomeAlbumSlider({
    super.key,
    required this.albums,
    this.onFocusedAlbumChanged,
    this.onCreateAlbum,
    this.onOpenAlbumTab,
  });

  @override
  ConsumerState<HomeAlbumSlider> createState() => _HomeAlbumSliderState();
}

class _HomeAlbumSliderState extends ConsumerState<HomeAlbumSlider>
    with SingleTickerProviderStateMixin {
  int _focusedIndex = 0;
  double _visualPage = 0;
  late final AnimationController _slideController;
  Animation<double>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 520),
        )..addListener(() {
          final animation = _slideAnimation;
          if (animation == null || !mounted) return;
          setState(() => _visualPage = animation.value);
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.albums.isEmpty) return;
      final index = _clampIndex(_focusedIndex);
      widget.onFocusedAlbumChanged?.call(widget.albums[index]);
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeAlbumSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.albums.isEmpty) return;
    if (!identical(oldWidget.albums, widget.albums)) {
      final focusedIndex = _clampIndex(_focusedIndex);
      if (_focusedIndex != focusedIndex) {
        setState(() {
          _focusedIndex = focusedIndex;
          _visualPage = focusedIndex.toDouble();
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onFocusedAlbumChanged?.call(widget.albums[focusedIndex]);
      });
    }
  }

  int _clampIndex(int index) {
    if (widget.albums.isEmpty) return 0;
    final lastIndex = widget.albums.length - 1;
    if (index < 0) return 0;
    if (index > lastIndex) return lastIndex;
    return index;
  }

  Future<void> _animateToIndex(int index) async {
    if (widget.albums.isEmpty) return;
    final target = _clampIndex(index);
    if (target == _focusedIndex) return;
    final from = _visualPage;
    final to = target.toDouble();
    setState(() {
      _focusedIndex = target;
    });
    widget.onFocusedAlbumChanged?.call(widget.albums[target]);
    _slideAnimation = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _slideController.forward(from: 0);
  }

  Future<void> _openFocusedAlbum() async {
    if (widget.albums.isEmpty) return;
    final index = _clampIndex(_focusedIndex);
    try {
      await HomeAlbumActions.openAlbum(context, ref, widget.albums[index]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('앨범을 열 수 없습니다: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleIndices = <int>[];
    for (var index = 0; index < widget.albums.length; index += 1) {
      if ((index - _visualPage).abs() <= 1.35) {
        visibleIndices.add(index);
      }
    }
    visibleIndices.sort((a, b) {
      final aFocus = (a - _visualPage).abs();
      final bFocus = (b - _visualPage).abs();
      return bFocus.compareTo(aFocus);
    });
    final visibleCards = [
      for (final index in visibleIndices)
        HomeAlbumSliderCard(
          key: ValueKey('home_album_${widget.albums[index].id}'),
          album: widget.albums[index],
          index: index,
          currentPage: _visualPage,
        ),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -180) {
          _animateToIndex(_focusedIndex + 1);
        } else if (velocity > 180) {
          _animateToIndex(_focusedIndex - 1);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: _HomeAlbumStageBackground()),
          Positioned(
            top: 0,
            left: 20.w,
            right: 20.w,
            child: SizedBox(
              height: 58.h,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StageCircleButton(
                    icon: Icons.menu_rounded,
                    tooltip: '앨범 목록',
                    onTap: widget.onOpenAlbumTab,
                  ),
                  _StageCircleButton(
                    icon: Icons.add_rounded,
                    tooltip: '새 앨범',
                    onTap: widget.onCreateAlbum,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 58.h,
            bottom: 110.h,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: visibleCards,
            ),
          ),
          Positioned(
            left: 70.w,
            right: 70.w,
            bottom: 64.h,
            child: _HomeGlassControls(
              onPrevious: () => _animateToIndex(_focusedIndex - 1),
              onOpen: _openFocusedAlbum,
              onNext: () => _animateToIndex(_focusedIndex + 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAlbumStageBackground extends StatelessWidget {
  const _HomeAlbumStageBackground();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _HomeAlbumStagePainter());
  }
}

class _HomeAlbumStagePainter extends CustomPainter {
  const _HomeAlbumStagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFFEFE2D0), Color(0xFFF8EFE2)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
  }

  @override
  bool shouldRepaint(covariant _HomeAlbumStagePainter oldDelegate) => false;
}

class _StageCircleButton extends StatelessWidget {
  const _StageCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.78),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Icon(icon, size: 21.sp, color: const Color(0xFF141312)),
          ),
        ),
      ),
    );
  }
}

class _HomeGlassControls extends StatelessWidget {
  const _HomeGlassControls({
    required this.onPrevious,
    required this.onOpen,
    required this.onNext,
  });

  final VoidCallback onPrevious;
  final VoidCallback onOpen;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.54),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: Colors.white.withOpacity(0.68)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 34.r,
            offset: Offset(0, 18.h),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoundControlButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPrevious,
          ),
          SizedBox(width: 12.w),
          _RoundControlButton(
            icon: Icons.north_east_rounded,
            onTap: onOpen,
            primary: true,
          ),
          SizedBox(width: 12.w),
          _RoundControlButton(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _RoundControlButton extends StatefulWidget {
  const _RoundControlButton({
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  State<_RoundControlButton> createState() => _RoundControlButtonState();
}

class _RoundControlButtonState extends State<_RoundControlButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.94 : 1,
        child: Container(
          width: widget.primary ? 58.w : 48.w,
          height: widget.primary ? 58.w : 48.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.primary ? Colors.white : const Color(0xFF101010),
            border: widget.primary
                ? Border.all(color: const Color(0xFFDDCAB3))
                : null,
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 18.r,
                      offset: Offset(0, 8.h),
                    ),
                  ]
                : null,
          ),
          child: widget.primary
              ? null
              : Icon(widget.icon, size: 22.sp, color: Colors.white),
        ),
      ),
    );
  }
}
