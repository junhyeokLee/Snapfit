import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/album.dart';
import 'home_album_actions.dart';
import 'home_album_slider_card.dart';
import 'home_album_shelf.dart';
import 'album_open_origin.dart';
import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';

/// One floating album with a visual bookshelf for selection.
class HomeAlbumSlider extends ConsumerStatefulWidget {
  final List<Album> albums;
  final ValueChanged<Album>? onFocusedAlbumChanged;
  final VoidCallback? onCreateAlbum;
  final VoidCallback? onResumeDraft;
  final VoidCallback? onOpenAlbumTab;

  const HomeAlbumSlider({
    super.key,
    required this.albums,
    this.onFocusedAlbumChanged,
    this.onCreateAlbum,
    this.onResumeDraft,
    this.onOpenAlbumTab,
  });

  @override
  ConsumerState<HomeAlbumSlider> createState() => _HomeAlbumSliderState();
}

class _HomeAlbumSliderState extends ConsumerState<HomeAlbumSlider>
    with SingleTickerProviderStateMixin {
  int _focusedIndex = 0;
  final _position = ValueNotifier<double>(0);
  double get _visualPage => _position.value;
  set _visualPage(double value) => _position.value = value;
  int _dragAnchorIndex = 0;
  double _stageWidth = 390;
  late final AnimationController _slideController;
  Animation<double>? _slideAnimation;
  final Map<int, GlobalKey> _coverOriginKeys = {};

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
          _visualPage = animation.value;
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
    _position.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeAlbumSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _coverOriginKeys.removeWhere(
      (id, _) => !widget.albums.any((album) => album.id == id),
    );
    if (widget.albums.isEmpty) {
      _slideController.stop();
      _focusedIndex = 0;
      _visualPage = 0;
      return;
    }
    if (!identical(oldWidget.albums, widget.albums)) {
      final orderChanged = !listEquals(
        oldWidget.albums.map((album) => album.id).toList(),
        widget.albums.map((album) => album.id).toList(),
      );
      if (orderChanged) {
        final oldId = oldWidget.albums.isEmpty
            ? null
            : oldWidget
                  .albums[_focusedIndex.clamp(0, oldWidget.albums.length - 1)]
                  .id;
        final retained = widget.albums.indexWhere((album) => album.id == oldId);
        _slideController.stop();
        _focusedIndex = retained < 0 ? _clampIndex(_focusedIndex) : retained;
        _visualPage = _focusedIndex.toDouble();
      }
      final focusedIndex = _focusedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.albums.isEmpty) return;
        widget.onFocusedAlbumChanged?.call(
          widget.albums[_clampIndex(focusedIndex)],
        );
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
    final from = _visualPage;
    final to = target.toDouble();
    if (target == _focusedIndex && (to - from).abs() < .0001) return;
    setState(() {
      _focusedIndex = target;
    });
    widget.onFocusedAlbumChanged?.call(widget.albums[target]);
    _slideAnimation = Tween<double>(
      begin: from,
      end: to,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_slideController);
    _slideController.forward(from: 0);
  }

  Future<void> _openFocusedAlbum() async {
    if (widget.albums.isEmpty) return;
    try {
      if (_slideController.isAnimating) {
        await _slideController.forward().orCancel;
      }
      if (!mounted) return;
      final index = _clampIndex(_focusedIndex);
      final album = widget.albums[index];
      await HomeAlbumActions.openAlbum(
        context,
        ref,
        album,
        coverOrigin: () {
          final key = _coverOriginKeys[album.id];
          return key == null ? null : AlbumOpenOrigin.capture(key);
        },
      );
    } on TickerCanceled {
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('앨범을 열 수 없습니다: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final landscape = constraints.maxWidth > constraints.maxHeight;
      final compact = constraints.maxHeight < 580;
      final headerHeight = landscape || compact ? 48.0 : 56.0;
      final thumbnailSide = ((constraints.maxWidth - 68) / 4).clamp(44.0, 92.0);
      final shelf = HomeAlbumShelf(
        albums: widget.albums,
        selectedIndex: _focusedIndex,
        onSelected: _animateToIndex,
        grid: landscape,
      );
      final open = _ShelfOpenButton(
        size: landscape || compact ? 48 : 60,
        onTap: widget.albums.isEmpty ? null : _openFocusedAlbum,
      );
      return Stack(
        children: [
          const Positioned.fill(child: _HomeAlbumStageBackground()),
          Column(
            children: [
              SizedBox(
                height: headerHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: landscape ? 24 : 16,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.onResumeDraft == null ? 56 : 100,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Semantics(
                            container: true,
                            label: 'snapfit',
                            excludeSemantics: true,
                            child: Text(
                              's n a p f i t',
                              key: const ValueKey('home-bookshelf-wordmark'),
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                                height: 1.2,
                                color: AlbumStageStyle.ink(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _HeaderAction(
                            icon: 'Menu',
                            tooltip: '앨범 목록',
                            onTap: widget.onOpenAlbumTab,
                          ),
                          const Spacer(),
                          if (widget.onResumeDraft != null)
                            _HeaderAction(
                              icon: 'History',
                              tooltip: '이어 만들기',
                              onTap: widget.onResumeDraft,
                            ),
                          _HeaderAction(
                            icon: 'Plus',
                            tooltip: '새 앨범',
                            onTap: widget.onCreateAlbum,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: landscape
                    ? Row(
                        children: [
                          Expanded(child: _buildAlbumStage()),
                          SizedBox(
                            width: (constraints.maxWidth * .34).clamp(
                              220.0,
                              300.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: math.max(
                                    44,
                                    math.min(
                                      252,
                                      constraints.maxHeight - headerHeight - 64,
                                    ),
                                  ),
                                  child: shelf,
                                ),
                                SizedBox(
                                  height: 64,
                                  child: Center(child: open),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: _buildAlbumStage()),
                          SizedBox(height: thumbnailSide + 22, child: shelf),
                          SizedBox(
                            height: compact ? 64 : 124,
                            child: Center(child: open),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      );
    },
  );

  Widget _buildAlbumStage() => LayoutBuilder(
    builder: (context, constraints) {
      _stageWidth = constraints.maxWidth;
      // Stable children keep layer parsing and the bookshelf off the drag path.
      final cards = <int, Widget>{};
      Widget card(int index) => cards.putIfAbsent(
        index,
        () => HomeAlbumSliderCard(
          key: ValueKey('home_album_${widget.albums[index].id}'),
          album: widget.albums[index],
          index: index,
          currentPage: _focusedIndex.toDouble(),
          pagePosition: _position,
          coverOriginKey: _coverOriginKeys.putIfAbsent(
            widget.albums[index].id,
            () => GlobalKey(),
          ),
        ),
      );
      return Semantics(
        label: widget.albums.isEmpty
            ? '앨범'
            : widget.albums[_clampIndex(_focusedIndex)].title,
        onIncrease: _focusedIndex < widget.albums.length - 1
            ? () => _animateToIndex(_focusedIndex + 1)
            : null,
        onDecrease: _focusedIndex > 0
            ? () => _animateToIndex(_focusedIndex - 1)
            : null,
        child: GestureDetector(
          key: const ValueKey('home-bookshelf-swipe'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            if (widget.albums.isEmpty) return;
            _slideController.stop();
            _dragAnchorIndex = _clampIndex(_visualPage.round());
          },
          onHorizontalDragUpdate: (details) {
            if (widget.albums.isEmpty) return;
            final first = _clampIndex(_dragAnchorIndex - 1).toDouble();
            final last = _clampIndex(_dragAnchorIndex + 1).toDouble();
            _visualPage = (_visualPage - details.delta.dx / (_stageWidth + 24))
                .clamp(first, last);
          },
          onHorizontalDragCancel: () => _animateToIndex(_focusedIndex),
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            _animateToIndex(
              velocity < -180
                  ? _dragAnchorIndex + 1
                  : velocity > 180
                  ? _dragAnchorIndex - 1
                  : _visualPage.round(),
            );
          },
          child: ClipRect(
            key: const ValueKey('home-bookshelf-stage'),
            clipper: const _StageHorizontalClipper(),
            child: ValueListenableBuilder<double>(
              valueListenable: _position,
              builder: (context, page, _) {
                final visible = [
                  for (
                    var i = math.max(0, page.floor() - 1);
                    i <= math.min(widget.albums.length - 1, page.ceil() + 1);
                    i++
                  )
                    if ((i - page).abs() <= 1.35) i,
                ]..sort((a, b) => (b - page).abs().compareTo((a - page).abs()));
                return Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [for (final index in visible) card(index)],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

// Keep the book's vertical shadow while hiding offscreen neighbouring albums.
class _StageHorizontalClipper extends CustomClipper<Rect> {
  const _StageHorizontalClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -100, size.width, size.height + 100);

  @override
  bool shouldReclip(covariant _StageHorizontalClipper oldClipper) => false;
}

class _HomeAlbumStageBackground extends StatelessWidget {
  const _HomeAlbumStageBackground();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('home-album-stage-background'),
    decoration: BoxDecoration(gradient: AlbumStageStyle.gradient(context)),
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final String icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    padding: EdgeInsets.zero,
    icon: ExperienceIcon(icon, size: 25, color: AlbumStageStyle.ink(context)),
  );
}

class _ShelfOpenButton extends StatefulWidget {
  const _ShelfOpenButton({required this.size, required this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  State<_ShelfOpenButton> createState() => _ShelfOpenButtonState();
}

class _ShelfOpenButtonState extends State<_ShelfOpenButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Tooltip(
      message: '앨범 열기',
      child: Semantics(
        label: '앨범 열기',
        button: true,
        enabled: enabled,
        child: GestureDetector(
          key: const ValueKey('home-bookshelf-open'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            scale: _pressed ? .94 : 1,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(color: AlbumStageStyle.line(context)),
              ),
              child: Center(
                child: ExperienceIcon(
                  'BookOpen',
                  size: 26,
                  color: Color.lerp(
                    AlbumStageStyle.ink(context),
                    AlbumStageStyle.top(context),
                    enabled ? .20 : .65,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
