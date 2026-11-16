import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/album.dart';
import '../../../../../core/utils/context_extensions.dart';
import 'home_album_actions.dart';
import 'home_album_slider_card.dart';
import 'home_album_shelf.dart';
import 'home_album_helpers.dart';
import 'album_open_origin.dart';
import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import 'home_album_header.dart';
import 'home_album_progress_builder.dart';
import '../../utils/album_progress.dart' show albumCompletionCriteria;

/// A focused cover and a lazy bookshelf; artwork stays off the drag path.
class HomeAlbumSlider extends ConsumerStatefulWidget {
  final List<Album> albums;
  final ValueChanged<Album>? onFocusedAlbumChanged;
  final VoidCallback? onCreateAlbum;
  final VoidCallback? onResumeDraft;
  final VoidCallback? onOpenAlbumTab;
  final bool showHeader;
  final ScrollController? scrollController;
  final Widget? leadingContent;
  final Widget? footer;

  const HomeAlbumSlider({
    super.key,
    required this.albums,
    this.onFocusedAlbumChanged,
    this.onCreateAlbum,
    this.onResumeDraft,
    this.onOpenAlbumTab,
    this.showHeader = true,
    this.scrollController,
    this.leadingContent,
    this.footer,
  });

  @override
  ConsumerState<HomeAlbumSlider> createState() => _HomeAlbumSliderState();
}

class _HomeAlbumSliderState extends ConsumerState<HomeAlbumSlider>
    with SingleTickerProviderStateMixin {
  ScrollController? _localScroll;
  ScrollController get _scroll =>
      widget.scrollController ?? (_localScroll ??= ScrollController());
  int _focusedIndex = 0;
  final _position = ValueNotifier<double>(0);
  double get _visualPage => _position.value;
  set _visualPage(double value) => _position.value = value;
  int _dragAnchorIndex = 0;
  double _stageWidth = 390;
  bool _coverFocusVisible = false;
  late final AnimationController _slideController;
  Animation<double>? _slideAnimation;
  final Map<int, GlobalKey> _coverOriginKeys = {};

  @override
  void initState() {
    super.initState();
    _slideController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
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
    _localScroll?.dispose();
    _slideController.dispose();
    _position.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeAlbumSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.albums.isEmpty) {
      _coverOriginKeys.clear();
      _slideController.stop();
      _focusedIndex = 0;
      _visualPage = 0;
      return;
    }
    if (!identical(oldWidget.albums, widget.albums)) {
      final albumIds = widget.albums.map((album) => album.id).toSet();
      _coverOriginKeys.removeWhere((id, _) => !albumIds.contains(id));
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
    if (target != _focusedIndex) HapticFeedback.selectionClick();
    setState(() {
      _focusedIndex = target;
    });
    widget.onFocusedAlbumChanged?.call(widget.albums[target]);
    _slideAnimation = Tween<double>(
      begin: from,
      end: to,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_slideController);
    // Shelf selection can jump across the entire collection. Do not mount
    // every intermediate cover just to animate through albums not selected.
    if (MediaQuery.disableAnimationsOf(context) || (to - from).abs() > 1) {
      _slideController.stop();
      _slideAnimation = null;
      _visualPage = to;
      return;
    }
    _slideController.forward(from: 0);
  }

  Future<void> _openFocusedAlbum() async {
    if (widget.albums.isEmpty) return;
    try {
      if (_slideController.isAnimating) {
        // Settle on the selected cover before capturing its opening origin;
        // a tap should not wait for the remainder of the slide animation.
        _slideController.stop();
        _slideAnimation = null;
        _visualPage = _focusedIndex.toDouble();
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted ||
          widget.albums.isEmpty ||
          !TickerMode.getValuesNotifier(context).value.enabled)
        return;
      final index = _clampIndex(_focusedIndex);
      final album = widget.albums[index];
      await HomeAlbumActions.openAlbum(
        context,
        ref,
        album,
        canContinue: () =>
            mounted &&
            widget.albums.isNotEmpty &&
            TickerMode.getValuesNotifier(context).value.enabled &&
            widget.albums[_clampIndex(_focusedIndex)].id == album.id,
        coverOrigin: () {
          final key = _coverOriginKeys[album.id];
          return key == null ? null : AlbumOpenOrigin.capture(key);
        },
      );
    } on TickerCanceled {
      return;
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnack('앨범을 열 수 없습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) => PrimaryScrollController(
    controller: _scroll,
    automaticallyInheritForPlatforms: const {},
    child: DecoratedBox(
      decoration: BoxDecoration(gradient: AlbumStageStyle.gradient(context)),
      child: Column(
        children: [
          if (widget.showHeader)
            HomeAlbumHeader(
              collection: false,
              onToggleView: widget.onOpenAlbumTab,
              onCreateAlbum: widget.onCreateAlbum,
              onResumeDraft: widget.onResumeDraft,
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                if (widget.albums.isEmpty) return const SizedBox.expand();
                final album = widget.albums[_clampIndex(_focusedIndex)];
                final landscape =
                    box.maxWidth >= 600 && box.maxWidth > box.maxHeight;
                final shelfHeight = HomeAlbumShelf.stripHeight(context);
                final shelf = HomeAlbumShelf(
                  albums: widget.albums,
                  selectedIndex: _focusedIndex,
                  onSelected: _animateToIndex,
                );
                final details = _FocusedAlbumDetails(
                  album: album,
                  onOpen: _openFocusedAlbum,
                  onPrevious: _focusedIndex > 0
                      ? () => _animateToIndex(_focusedIndex - 1)
                      : null,
                  onNext: _focusedIndex < widget.albums.length - 1
                      ? () => _animateToIndex(_focusedIndex + 1)
                      : null,
                );
                final shelfHeading = Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '나의 앨범',
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.albums.length}권',
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                    ],
                  ),
                );
                if (landscape && widget.leadingContent == null) {
                  return Row(
                    children: [
                      Expanded(child: _buildAlbumStage()),
                      SizedBox(
                        width: (box.maxWidth * .46).clamp(280.0, 440.0),
                        child: SingleChildScrollView(
                          controller: _scroll,
                          primary: false,
                          key: const PageStorageKey(
                            'home-cover-landscape-scroll',
                          ),
                          child: Column(
                            children: [
                              details,
                              shelfHeading,
                              SizedBox(height: shelfHeight, child: shelf),
                              if (widget.footer != null)
                                _RetainedScrollSpace(
                                  active: TickerMode.of(context),
                                  child: widget.footer!,
                                ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
                // Cover size follows the viewport width. Metadata and the
                // shelf scroll below it instead of squeezing the album.
                return SingleChildScrollView(
                  key: const PageStorageKey('home-album-cover-scroll'),
                  controller: _scroll,
                  primary: false,
                  child: Column(
                    children: [
                      if (widget.leadingContent != null) ...[
                        _RetainedScrollSpace(
                          active: TickerMode.of(context),
                          child: widget.leadingContent!,
                        ),
                        Padding(
                          key: const ValueKey('home-album-section'),
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 16,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Semantics(
                                        header: true,
                                        child: Text(
                                          '나의 앨범',
                                          key: const ValueKey(
                                            'home-album-section-title',
                                          ),
                                          style: ExperienceFormStyle.text(
                                            context,
                                            20,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${widget.albums.length}권',
                                      style: ExperienceFormStyle.text(
                                        context,
                                        12,
                                        secondary: true,
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.onOpenAlbumTab != null)
                                  TextButton(
                                    key: const ValueKey(
                                      'home-album-section-open',
                                    ),
                                    onPressed: widget.onOpenAlbumTab,
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          ExperienceFormStyle.selectionInk(
                                            context,
                                          ),
                                      minimumSize: const Size(48, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      textStyle: ExperienceFormStyle.text(
                                        context,
                                        12,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('전체보기'),
                                        SizedBox(width: 5),
                                        ExperienceIcon(
                                          'ChevronRight',
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      SizedBox(
                        height: landscape
                            ? (box.maxHeight * .9).clamp(180.0, 320.0)
                            : (box.maxWidth * .84).clamp(260.0, 480.0),
                        child: _buildAlbumStage(),
                      ),
                      if (!landscape && widget.albums.length > 1)
                        _buildDotsIndicator(context),
                      details,
                      shelfHeading,
                      SizedBox(height: shelfHeight, child: shelf),
                      if (widget.footer != null)
                        _RetainedScrollSpace(
                          active: TickerMode.of(context),
                          child: widget.footer!,
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildDotsIndicator(BuildContext context) =>
      ValueListenableBuilder<double>(
        valueListenable: _position,
        builder: (context, page, _) {
          final count = widget.albums.length;
          if (count > 10) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    width: i == page.round() ? 8.0 : 5.0,
                    height: i == page.round() ? 8.0 : 5.0,
                    decoration: BoxDecoration(
                      color: i == page.round()
                          ? ExperienceFormStyle.selectionInk(context)
                          : ExperienceFormStyle.muted(
                              context,
                            ).withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
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
          animateIdle: false,
          pagePosition: _position,
          coverOriginKey: _coverOriginKeys.putIfAbsent(
            widget.albums[index].id,
            () => GlobalKey(),
          ),
        ),
      );
      return FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (visible) {
          if (_coverFocusVisible != visible) {
            setState(() => _coverFocusVisible = visible);
          }
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _openFocusedAlbum();
              return null;
            },
          ),
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: _coverFocusVisible
                ? Border.all(
                    color: ExperienceFormStyle.selectionInk(context),
                    width: 2,
                  )
                : null,
          ),
          child: Semantics(
            key: const ValueKey('home-bookshelf-open'),
            button: true,
            excludeSemantics: true,
            onTap: _openFocusedAlbum,
            label: widget.albums.isEmpty
                ? '앨범'
                : '${widget.albums[_clampIndex(_focusedIndex)].title}, 앨범 열기',
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
                _visualPage =
                    (_visualPage - details.delta.dx / (_stageWidth + 24)).clamp(
                      first,
                      last,
                    );
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
                        var i = math.max(0, page.floor());
                        i <= math.min(widget.albums.length - 1, page.ceil());
                        i++
                      )
                        // At rest, neighbours are entirely outside the stage.
                        // Mount their artwork only when a swipe brings it in.
                        if ((i - page).abs() < 1) i,
                    ]..sort((a, b) => (b - page).abs().compareTo((a - page).abs()));
                    // A drag can reverse or pass multiple indices. Cache only the
                    // currently mounted cards, not its complete movement history.
                    cards.removeWhere((index, _) => !visible.contains(index));
                    _coverOriginKeys.removeWhere(
                      (id, _) => !visible.any(
                        (index) => widget.albums[index].id == id,
                      ),
                    );
                    return Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [for (final index in visible) card(index)],
                    );
                  },
                ),
              ),
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

/// Hidden journal widgets stop their work and collapse. Keep their last active
/// space so switching views or opening a reader cannot clamp this scroll.
class _RetainedScrollSpace extends SingleChildRenderObjectWidget {
  const _RetainedScrollSpace({required this.active, required super.child});
  final bool active;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRetainedScrollSpace(active);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderRetainedScrollSpace renderObject,
  ) => renderObject.active = active;
}

class _RenderRetainedScrollSpace extends RenderProxyBox {
  _RenderRetainedScrollSpace(this._active);
  bool _active;
  double? _lastActiveHeight;

  set active(bool value) {
    if (_active == value) return;
    _active = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    if (_active) {
      _lastActiveHeight = size.height;
    } else if (_lastActiveHeight != null) {
      size = constraints.constrain(Size(size.width, _lastActiveHeight!));
    }
  }
}

class _FocusedAlbumDetails extends StatelessWidget {
  const _FocusedAlbumDetails({
    required this.album,
    required this.onOpen,
    required this.onPrevious,
    required this.onNext,
  });

  final Album album;
  final VoidCallback onOpen;
  final VoidCallback? onPrevious, onNext;

  @override
  Widget build(BuildContext context) => HomeAlbumProgressBuilder(
    album: album,
    builder: (context, progress) {
      final completed = !isDraftAlbum(album) && progress?.isCompleted == true;
      final title = album.title.trim().isEmpty ? '제목 없는 앨범' : album.title;
      final status = !album.allowsEditing
          ? '보기 전용'
          : progress == null
          ? '상태 확인 중'
          : completed
          ? '완성한 앨범'
          : '만드는 중';
      final pages = progress == null
          ? ''
          : progress.hasTarget
          ? '${progress.completedPages}/${progress.targetPages}쪽'
          : '${progress.completedPages}쪽';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '이전 앨범',
                onPressed: onPrevious,
                icon: const ExperienceIcon('ChevronLeft', size: 22),
              ),
              Expanded(
                child: Column(
                  children: [
                    Tooltip(
                      message: title,
                      child: Text(
                        title,
                        key: const ValueKey('home-focused-album-title'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ExperienceFormStyle.text(
                          context,
                          19,
                          weight: FontWeight.w600,
                        ).copyWith(height: 1.4, letterSpacing: -.4),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Tooltip(
                      message: albumCompletionCriteria,
                      child: Text(
                        progress == null
                            ? '$status${!album.allowsEditing ? ' · 상태 확인 중' : ''}'
                            : '$status · $pages',
                        key: const ValueKey('home-focused-album-status'),
                        semanticsLabel: progress == null
                            ? '앨범 상태 확인 중'
                            : '앨범 상태, $status, ${progress.pageProgressLabel}',
                        textAlign: TextAlign.center,
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          color: ExperienceFormStyle.selectionInk(context),
                        ).copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '다음 앨범',
                onPressed: onNext,
                icon: const ExperienceIcon('ChevronRight', size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FilledButton.icon(
              key: const ValueKey('home-focused-album-open'),
              onPressed: onOpen,
              icon: const ExperienceIcon(
                'ChevronRight',
                size: 16,
                color: SnapFitColors.onAccent,
              ),
              iconAlignment: IconAlignment.end,
              label: const Text('앨범보기'),
              style: FilledButton.styleFrom(
                backgroundColor: ExperienceFormStyle.selectionInk(context),
                foregroundColor: SnapFitColors.onAccent,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                textStyle: ExperienceFormStyle.text(
                  context,
                  13,
                  weight: FontWeight.w600,
                ).copyWith(height: 1.4),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      );
    },
  );
}
