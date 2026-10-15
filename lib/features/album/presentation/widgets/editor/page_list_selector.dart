import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../domain/entities/album_page.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart'; // [Fix] 추가
import '../cover/cover.dart';
import '../home/home_album_helpers.dart';
import '../reader/album_reader_page_content.dart';

class PageListSelector extends ConsumerStatefulWidget {
  final List<AlbumPage> pages;
  final int currentPageIndex;
  final Function(int) onPageSelected;
  final VoidCallback? onAddPage;
  final String addPageDescription;
  final VoidCallback? onDeleteCurrentPage;
  final bool canDeleteCurrentPage;

  const PageListSelector({
    super.key,
    required this.pages,
    required this.currentPageIndex,
    required this.onPageSelected,
    this.onAddPage,
    this.addPageDescription = '내지 2쪽 추가 · 표지 별도, 최대 80쪽',
    this.onDeleteCurrentPage,
    this.canDeleteCurrentPage = false,
  });

  @override
  ConsumerState<PageListSelector> createState() => _PageListSelectorState();
}

class _PageListSelectorState extends ConsumerState<PageListSelector> {
  final _scroll = ScrollController();
  bool? _vertical;
  double _extent = 80;
  bool _revealPending = false;

  @override
  void didUpdateWidget(covariant PageListSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPageIndex != widget.currentPageIndex ||
        oldWidget.pages.length != widget.pages.length) {
      _revealSelection();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealSelection() {
    if (_revealPending) return;
    _revealPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealPending = false;
      if (!mounted || !_scroll.hasClients || widget.pages.isEmpty) return;
      final position = _scroll.position;
      final index = widget.currentPageIndex.clamp(0, widget.pages.length - 1);
      final target =
          (index * _extent - position.viewportDimension / 2 + _extent / 2)
              .clamp(0.0, position.maxScrollExtent);
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(albumEditorViewModelProvider).asData?.value;
    final selectedTheme = editorState?.selectedTheme;
    final selectedCover = editorState?.selectedCover;

    final coverRatio = selectedCover?.ratio ?? 1.0; // width/height

    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 120;
        final thumbHeight = vertical ? 54.0 : 56.h.clamp(44.0, 56.0);
        final captionHeight = MediaQuery.textScalerOf(context).scale(11) * 1.5;
        final height = thumbHeight + captionHeight + 16;
        final extent = vertical
            ? height
            : (thumbHeight * coverRatio + 18).clamp(62.0, 86.0);
        if (_vertical != vertical || _extent != extent) {
          _vertical = vertical;
          _extent = extent;
          _revealSelection();
        }
        final rail = ListView.builder(
          key: const ValueKey('editor-page-rail'),
          controller: _scroll,
          scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
          padding: const EdgeInsets.all(4),
          itemExtent: extent,
          cacheExtent: extent,
          itemCount: widget.pages.length,
          itemBuilder: (context, index) {
            final selected = index == widget.currentPageIndex;
            final label = index == 0 ? '표지' : '$index쪽';
            final maxThumbWidth = vertical ? 52.0 : extent - 14;
            final width = math.min(maxThumbWidth, thumbHeight * coverRatio);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              child: Semantics(
                key: ValueKey('editor-page-$index'),
                button: true,
                selected: selected,
                label: '$label 선택',
                child: SnapFitPressable(
                  onTap: () => widget.onPageSelected(index),
                  pressedScale: .98,
                  borderRadius: BorderRadius.circular(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: thumbHeight,
                        child: Center(
                          child: AnimatedContainer(
                            key: ValueKey('editor-page-frame-$index'),
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 120),
                            width: width,
                            height: width / coverRatio,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: SnapFitColors.surfaceOf(context),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: selected
                                    ? ExperienceFormStyle.selectionInk(context)
                                    : ExperienceFormStyle.line(context),
                                width: 1.5,
                              ),
                            ),
                            child: RepaintBoundary(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(1),
                                child: ExcludeSemantics(
                                  child: IgnorePointer(
                                    child: _buildPageThumbnail(
                                      context,
                                      ref: ref,
                                      page: widget.pages[index],
                                      isCover: index == 0,
                                      selectedTheme: selectedTheme,
                                      selectedCover: selectedCover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExperienceFormStyle.text(
                          context,
                          11,
                          weight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? ExperienceFormStyle.selectionInk(context)
                              : ExperienceFormStyle.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
        final actions = Padding(
          padding: const EdgeInsets.all(4),
          child: Flex(
            direction: vertical ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAddButton(context),
              if (widget.canDeleteCurrentPage && widget.currentPageIndex > 0)
                IconButton(
                  key: const ValueKey('deleteCurrentInnerPageButton'),
                  tooltip: '${widget.currentPageIndex}쪽 삭제',
                  onPressed: widget.onDeleteCurrentPage,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: ExperienceFormStyle.muted(context),
                  ),
                ),
            ],
          ),
        );
        return SizedBox(
          height: vertical ? double.infinity : height + 8,
          width: vertical ? 78 : null,
          child: Flex(
            direction: vertical ? Axis.vertical : Axis.horizontal,
            children: [
              Expanded(child: rail),
              actions,
            ],
          ),
        );
      },
    );
  }

  /// 페이지 썸네일 빌드
  Widget _buildPageThumbnail(
    BuildContext context, {
    required WidgetRef ref, // [Fix] 파라미터 추가
    required AlbumPage page,
    required bool isCover,
    dynamic selectedTheme,
    dynamic selectedCover,
  }) {
    final ratio = selectedCover?.ratio ?? 1.0;
    final logicalInnerSize = Size(
      kCoverReferenceWidth,
      kCoverReferenceWidth / ratio,
    );
    final logicalCoverSize = Size(
      kCoverReferenceWidth,
      kCoverReferenceWidth / ratio,
    );
    final coverInteraction = LayerInteractionManager.preview(
      ref,
      () => logicalCoverSize,
    );
    final coverBuilder = LayerBuilder(coverInteraction, () => logicalCoverSize);

    if (isCover) {
      // 커버: CoverLayout으로 테마 + 레이어 렌더링
      final theme = selectedTheme ?? resolveCoverTheme(null);
      // [Fix] 커버는 언제나 메인 뷰어와 똑같은 렌더링을 보장하기 위해 CoverLayout & FittedBox 사용
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: logicalCoverSize.width,
          height: logicalCoverSize.height,
          child: CoverLayout(
            aspect: logicalCoverSize.width / logicalCoverSize.height,
            layers: page.layers,
            isInteracting: false,
            leftSpine: 0, // 썸네일에서 spine 제거
            onCoverSizeChanged: (_) {},
            buildImage: (layer) =>
                coverBuilder.buildImage(layer, isCover: true),
            buildText: (layer) => coverBuilder.buildText(layer, isCover: true),
            sortedByZ: coverInteraction.sortByZ,
            theme: theme,
          ),
        ),
      );
    }

    // 내지: 전체 레이어 렌더링 지원 (AlbumReaderPageContent 활용)
    // 썸네일 크기에 맞게 스케일링된 페이지 내용 표시
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 24.w;
        final targetH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 44.h;
        return AlbumReaderPageContent(
          layers: page.layers,
          targetW: targetW,
          targetH: targetH,
          previewBuilder: LayerBuilder(
            LayerInteractionManager.preview(ref, () => logicalInnerSize),
            () => logicalInnerSize,
          ),
          baseCanvasSize: logicalInnerSize,
          backgroundColor: page.backgroundColor != null
              ? Color(page.backgroundColor!)
              : null,
        );
      },
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Tooltip(
      message: widget.addPageDescription,
      child: Semantics(
        label: widget.addPageDescription,
        button: true,
        enabled: widget.onAddPage != null,
        child: SnapFitPressable(
          key: const Key('addInnerPagesButton'),
          onTap: widget.onAddPage,
          pressedScale: .96,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: ExperienceIcon(
                'Plus',
                size: 20,
                color: widget.onAddPage == null
                    ? ExperienceFormStyle.line(context)
                    : ExperienceFormStyle.ink(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
