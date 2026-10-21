import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../domain/entities/album_page.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../cover/cover.dart';
import '../home/home_album_helpers.dart';
import 'album_reader_page_content.dart';

/// Real cover and paired inner-page previews, with a readable spread index.
class AlbumReaderThumbnailStrip extends ConsumerStatefulWidget {
  const AlbumReaderThumbnailStrip({
    super.key,
    required this.pages,
    this.pageController,
    required this.previewBuilder,
    required this.baseCanvasSize,
    this.height = 70,
    this.currentSpreadIndex,
    this.onSpreadSelected,
  });
  final List<AlbumPage> pages;
  final PageController? pageController;
  final LayerBuilder previewBuilder;
  final Size baseCanvasSize;
  final double height;
  final int? currentSpreadIndex;
  final ValueChanged<int>? onSpreadSelected;

  static List<List<int>> spreads(int count) => [
    if (count > 0) [0],
    for (var i = 1; i < count; i += 2) [i, if (i + 1 < count) i + 1],
  ];

  static String label(List<int> pages) => pages.first == 0
      ? '표지'
      : pages.length == 1
      ? '${pages.first}'
      : '${pages.first}-${pages.last}';

  @override
  ConsumerState<AlbumReaderThumbnailStrip> createState() =>
      _ThumbnailStripState();
}

class _ThumbnailStripState extends ConsumerState<AlbumReaderThumbnailStrip> {
  final _scroll = ScrollController();
  int _active = -1;
  double _viewport = 0, _coverWidth = 0, _spreadWidth = 0;
  static const _gap = 12.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _align(bool animate) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final left = _active == 0
          ? 16.0
          : 16 + _coverWidth + _gap + (_active - 1) * (_spreadWidth + _gap);
      final width = _active == 0 ? _coverWidth : _spreadWidth;
      final target = (left + width / 2 - _viewport / 2).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
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

  @override
  Widget build(BuildContext context) {
    final items = AlbumReaderThumbnailStrip.spreads(widget.pages.length);
    if (items.isEmpty) return const SizedBox.shrink();
    final aspect = widget.baseCanvasSize.width / widget.baseCanvasSize.height;
    final logical = Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
    final coverInteraction = LayerInteractionManager.preview(
      ref,
      () => logical,
    );
    final coverBuilder = LayerBuilder(coverInteraction, () => logical);
    final theme =
        ref.watch(
          albumEditorViewModelProvider.select(
            (value) => value.value?.selectedTheme,
          ),
        ) ??
        resolveCoverTheme(null);
    final singleWidth = widget.height * aspect;
    final spreadWidth = singleWidth * 2 + 1;
    final captionHeight = MediaQuery.textScalerOf(context).scale(10) * 1.4;

    Widget artwork(List<int> indices) => RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: indices.first == 0
            ? FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: logical.width,
                  height: logical.height,
                  child: CoverLayout(
                    aspect: aspect,
                    layers: widget.pages.first.layers,
                    isInteracting: false,
                    leftSpine: 0,
                    backgroundColor: widget.pages.first.backgroundColor == null
                        ? null
                        : Color(
                            widget.pages.first.backgroundColor!,
                          ).withAlpha(255),
                    onCoverSizeChanged: (_) {},
                    buildImage: (layer) =>
                        coverBuilder.buildImage(layer, isCover: true),
                    buildText: (layer) =>
                        coverBuilder.buildText(layer, isCover: true),
                    sortedByZ: coverInteraction.sortByZ,
                    theme: theme,
                  ),
                ),
              )
            : Row(
                children: [
                  for (var slot = 0; slot < 2; slot++) ...[
                    if (slot > 0)
                      SizedBox(
                        width: 1,
                        child: ColoredBox(color: AlbumStageStyle.line(context)),
                      ),
                    Expanded(
                      child: slot >= indices.length
                          ? ColoredBox(
                              color: AlbumStageStyle.controlFill(context),
                            )
                          : AlbumReaderPageContent(
                              layers: widget.pages[indices[slot]].layers,
                              targetW: singleWidth,
                              targetH: widget.height,
                              previewBuilder: widget.previewBuilder,
                              baseCanvasSize: logical,
                              backgroundColor:
                                  widget.pages[indices[slot]].backgroundColor ==
                                      null
                                  ? null
                                  : Color(
                                      widget
                                          .pages[indices[slot]]
                                          .backgroundColor!,
                                    ),
                            ),
                    ),
                  ],
                ],
              ),
      ),
    );

    return SizedBox(
      height: widget.height + captionHeight + 14,
      child: AnimatedBuilder(
        animation: widget.pageController ?? const AlwaysStoppedAnimation(0),
        builder: (context, _) => LayoutBuilder(
          builder: (context, box) {
            final active =
                (widget.currentSpreadIndex ??
                        (widget.pageController?.hasClients == true
                            ? widget.pageController!.page?.round() ?? 0
                            : 0))
                    .clamp(0, items.length - 1);
            final coverSlot = math.max(44.0, singleWidth);
            final spreadSlot = math.max(44.0, spreadWidth);
            if (_active != active ||
                _viewport != box.maxWidth ||
                _coverWidth != coverSlot ||
                _spreadWidth != spreadSlot) {
              final animate = _active >= 0 && _active != active;
              _active = active;
              _viewport = box.maxWidth;
              _coverWidth = coverSlot;
              _spreadWidth = spreadSlot;
              _align(animate);
            }
            return ListView.builder(
              key: const ValueKey('reader-spread-strip'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              cacheExtent: spreadSlot * 2,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final indices = items[index];
                final selected = index == active;
                final label = AlbumReaderThumbnailStrip.label(indices);
                final enabled =
                    widget.onSpreadSelected != null ||
                    widget.pageController != null;
                void select() {
                  if (index == active) return;
                  if (widget.onSpreadSelected != null) {
                    widget.onSpreadSelected!(index);
                  } else if (widget.pageController?.hasClients == true) {
                    widget.pageController!.animateToPage(
                      index,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  }
                }

                return Semantics(
                  label: index == 0 ? label : '$label쪽',
                  selected: selected,
                  button: enabled,
                  excludeSemantics: true,
                  onTap: enabled ? select : null,
                  child: GestureDetector(
                    key: ValueKey('reader-spread-$index'),
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? select : null,
                    child: Padding(
                      padding: const EdgeInsets.only(right: _gap),
                      child: SizedBox(
                        width: index == 0 ? coverSlot : spreadSlot,
                        child: Column(
                          children: [
                            SizedBox(
                              width: index == 0 ? singleWidth : spreadWidth,
                              height: widget.height,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: selected
                                        ? SnapFitColors.accent
                                        : AlbumStageStyle.line(context),
                                    width: 1.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(1.5),
                                  child: artwork(indices),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.4,
                                letterSpacing: 0,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AlbumStageStyle.ink(
                                  context,
                                ).withValues(alpha: selected ? 1 : .6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
