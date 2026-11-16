import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/social_models.dart';
import 'social_widgets.dart';
import 'social_snapshot_identity.dart';

/// Only published snapshot URLs are paged; the editable album is never loaded.
class SocialFeedArtwork extends StatefulWidget {
  const SocialFeedArtwork({
    super.key,
    required this.work,
    required this.onOpen,
    required this.onRetry,
    this.webLayout = kIsWeb,
    this.onPageChanged,
  });
  final SocialWork work;
  final ValueChanged<int> onOpen;
  final VoidCallback onRetry;
  final bool webLayout;
  final ValueChanged<int>? onPageChanged;

  @override
  State<SocialFeedArtwork> createState() => _SocialFeedArtworkState();
}

class _SocialFeedArtworkState extends State<SocialFeedArtwork> {
  final _controller = PageController();
  int _page = 0, _revision = 0;

  @override
  void didUpdateWidget(covariant SocialFeedArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.work.id != widget.work.id ||
        !listEquals(
          oldWidget.work.imageUrls.map(socialSnapshotIdentity).toList(),
          widget.work.imageUrls.map(socialSnapshotIdentity).toList(),
        )) {
      final revision = ++_revision;
      _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && revision == _revision) {
          widget.onPageChanged?.call(0);
          if (_controller.hasClients) _controller.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _revision++;
    _controller.dispose();
    super.dispose();
  }

  void _move(int offset) {
    final next = (_page + offset).clamp(0, widget.work.imageUrls.length - 1);
    if (next == _page || !_controller.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(next);
    } else {
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _arrow(bool next) => Material(
    color: SocialStyle.background(context).withValues(alpha: .94),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: next ? '피드 다음 페이지' : '피드 이전 페이지',
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      onPressed: () => _move(next ? 1 : -1),
      icon: Icon(next ? Icons.chevron_right : Icons.chevron_left, size: 23),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final work = widget.work;
    final count = work.imageUrls.length;
    return Focus(
      onKeyEvent: (_, event) {
        if (count < 2 || event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _move(1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _move(-1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        label:
            '${work.title}, ${count == 0 ? 0 : _page + 1} / $count${work.isMoment ? '장' : '쪽'}',
        onIncrease: count > 1 && _page < count - 1 ? () => _move(1) : null,
        onDecrease: _page > 0 ? () => _move(-1) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: LayoutBuilder(
            builder: (context, bounds) => SizedBox(
              key: ValueKey('social-feed-artwork-${work.id}'),
              width: double.infinity,
              height: socialArtworkHeight(bounds.maxWidth, work.aspectRatio),
              child: ColoredBox(
                color: SocialStyle.paper(context),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (count == 0)
                      InkWell(
                        onTap: () => widget.onOpen(0),
                        child: const SocialArtworkPlaceholder(),
                      )
                    else
                      PageView.builder(
                        key: ValueKey('social-feed-pages-${work.id}'),
                        controller: _controller,
                        itemCount: count,
                        onPageChanged: (page) {
                          setState(() => _page = page);
                          widget.onPageChanged?.call(page);
                        },
                        itemBuilder: (context, index) => Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => widget.onOpen(index),
                            child: SocialWorkImage(
                              key: ValueKey(
                                'social-feed-image-${work.id}-$index',
                              ),
                              url: work.imageUrls[index],
                              label: '${work.title} ${index + 1}번째 공개 페이지',
                              onRetry: widget.onRetry,
                            ),
                          ),
                        ),
                      ),
                    if (count > 1) ...[
                      Positioned(
                        top: 12,
                        right: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .48),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              '${_page + 1} / $count',
                              key: ValueKey(
                                'social-feed-page-count-${work.id}',
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (count <= 8)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 12,
                          child: ExcludeSemantics(
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .32),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var page = 0; page < count; page++)
                                        AnimatedContainer(
                                          key: ValueKey(
                                            'social-feed-dot-${work.id}-$page',
                                          ),
                                          duration:
                                              MediaQuery.disableAnimationsOf(
                                                context,
                                              )
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 180,
                                                ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          width: page == _page ? 12 : 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: page == _page ? 1 : .5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.webLayout && _page > 0)
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(child: _arrow(false)),
                        ),
                      if (widget.webLayout && _page < count - 1)
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(child: _arrow(true)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
