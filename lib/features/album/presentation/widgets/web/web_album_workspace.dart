import 'package:flutter/material.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../domain/entities/album_page.dart';
import '../../controllers/layer_builder.dart';
import '../reader/album_reader_page_content.dart';

/// A website document rail. Thumbnails use the same artwork and logical size
/// as the document, without a separate book mock-up or another layer model.
class WebAlbumPageRail extends StatefulWidget {
  const WebAlbumPageRail({
    super.key,
    required this.pages,
    required this.selectedIndex,
    required this.cover,
    required this.theme,
    required this.previewBuilder,
    required this.onSelected,
    this.horizontal = false,
    this.onAdd,
    this.addDescription,
    this.onDelete,
    this.includesCover = true,
  });

  final List<AlbumPage> pages;
  final int selectedIndex;
  final CoverSize cover;
  final CoverTheme theme;
  final LayerBuilder previewBuilder;
  final ValueChanged<int> onSelected;
  final bool horizontal;
  final VoidCallback? onAdd;
  final String? addDescription;
  final VoidCallback? onDelete;
  final bool includesCover;

  @override
  State<WebAlbumPageRail> createState() => _WebAlbumPageRailState();
}

class _WebAlbumPageRailState extends State<WebAlbumPageRail> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(covariant WebAlbumPageRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.horizontal != widget.horizontal ||
        oldWidget.pages.length != widget.pages.length ||
        oldWidget.cover.ratio != widget.cover.ratio) {
      _revealSelection();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double get _itemExtent => widget.horizontal
      ? 64.0
      : 92.0 / widget.cover.ratio + 54.0;

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || widget.pages.isEmpty) return;
      final position = _scroll.position;
      final target = (widget.selectedIndex * _itemExtent -
          position.viewportDimension / 2 + _itemExtent / 2)
          .clamp(0.0, position.maxScrollExtent).toDouble();
      _scroll.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;
    final selectedIndex = widget.selectedIndex;
    final cover = widget.cover;
    final theme = widget.theme;
    final previewBuilder = widget.previewBuilder;
    final onSelected = widget.onSelected;
    final horizontal = widget.horizontal;
    final onAdd = widget.onAdd;
    final addDescription = widget.addDescription;
    final onDelete = widget.onDelete;
    final base = Size(kCoverReferenceWidth, kCoverReferenceWidth / cover.ratio);
    return ColoredBox(
      color: WebPalette.of(context).surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!horizontal)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text('페이지', style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: WebPalette.of(context).ink,
                    )),
                  ),
                  Text('${pages.length}', style: TextStyle(
                    fontSize: 12, color: WebPalette.of(context).muted,
                  )),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              key: const ValueKey('web-album-page-rail'),
              controller: _scroll,
              itemExtent: _itemExtent,
              cacheExtent: _itemExtent * 2,
              scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
              padding: EdgeInsets.symmetric(
                horizontal: horizontal ? 12 : 16,
                vertical: horizontal ? 8 : 0,
              ),
              itemCount: pages.length,
              itemBuilder: (context, index) {
                final selected = index == selectedIndex;
                final thumbWidth = horizontal ? 44.0 : 92.0;
                final thumbHeight = thumbWidth / cover.ratio;
                final page = pages[index];
                final isCover = widget.includesCover && index == 0;
                final label = isCover ? '표지'
                    : '${widget.includesCover ? index : index + 1}쪽';
                return Padding(
                  padding: EdgeInsets.only(
                    right: horizontal ? 8 : 0,
                    bottom: horizontal ? 0 : 12,
                  ),
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: '$label 선택',
                    child: Material(
                      color: selected ? WebPalette.of(context).softBrand : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: ValueKey('web-album-page-$index'),
                        onTap: () => onSelected(index),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: EdgeInsets.all(horizontal ? 6 : 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: thumbWidth,
                                height: thumbHeight,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: selected
                                        ? WebPalette.of(context).brandInk
                                        : WebPalette.of(context).line,
                                  ),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: ExcludeSemantics(
                                  child: AlbumReaderPageContent(
                                    layers: page.layers,
                                    targetW: thumbWidth,
                                    targetH: thumbHeight,
                                    baseCanvasSize: base,
                                    previewBuilder: previewBuilder,
                                    theme: isCover ? theme : null,
                                    backgroundColor: page.backgroundColor == null
                                        ? null
                                        : Color(page.backgroundColor!),
                                    flatPresentation: true,
                                    isCover: isCover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(label, style: TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? WebPalette.of(context).brandInk
                                    : WebPalette.of(context).muted,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!horizontal && (onAdd != null || onDelete != null)) ...[
            Divider(height: 1, color: WebPalette.of(context).line),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onAdd != null)
                    OutlinedButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('페이지 추가'),
                    ),
                  if (onDelete != null)
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('선택 페이지 삭제'),
                    ),
                  if (addDescription != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(addDescription!, style: TextStyle(
                        color: WebPalette.of(context).muted, fontSize: 11, height: 1.5,
                      )),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class WebAlbumEditorTool {
  const WebAlbumEditorTool({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.opensProperties = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;
  final bool opensProperties;
}

/// Website chrome only. The editor owns all document, save and exit behavior.
class WebAlbumEditorWorkspace extends StatefulWidget {
  const WebAlbumEditorWorkspace({
    super.key,
    required this.title,
    required this.pageLabel,
    required this.specification,
    required this.hasUnsavedChanges,
    required this.isPersisted,
    required this.isSaving,
    required this.onBack,
    required this.onSave,
    required this.canvas,
    required this.pageRail,
    required this.compactPageRail,
    required this.properties,
    required this.tools,
    this.onUndo,
    this.onRedo,
    this.onSaveDraft,
    this.draftPending = false,
    this.draftFailed = false,
    this.onAddPage,
    this.onDeletePage,
  });

  final String title;
  final String pageLabel;
  final String specification;
  final bool hasUnsavedChanges;
  final bool isPersisted;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final Widget canvas;
  final Widget pageRail;
  final Widget compactPageRail;
  final Widget properties;
  final List<WebAlbumEditorTool> tools;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onSaveDraft;
  final bool draftPending;
  final bool draftFailed;
  final VoidCallback? onAddPage;
  final VoidCallback? onDeletePage;

  @override
  State<WebAlbumEditorWorkspace> createState() => _WebAlbumEditorWorkspaceState();
}

class _WebAlbumEditorWorkspaceState extends State<WebAlbumEditorWorkspace> {
  bool _propertiesOpen = false;
  bool _pagesOpen = true;

  @override
  Widget build(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 600;
    return SnapFitWebShell(
      title: '앨범 편집',
      workspace: true,
      showNavigation: false,
      actions: [
        if (widget.onSaveDraft != null && compactHeader)
          IconButton(
            tooltip: widget.draftFailed ? '임시 저장 다시 시도' : '임시 저장',
            onPressed: widget.isSaving || widget.draftPending
                ? null
                : widget.onSaveDraft,
            icon: const Icon(Icons.save_outlined, size: 19),
          ),
        if (widget.onSaveDraft != null && !compactHeader)
          TextButton.icon(
            onPressed: widget.isSaving || widget.draftPending
                ? null
                : widget.onSaveDraft,
            icon: Icon(
              widget.draftFailed ? Icons.error_outline : Icons.save_outlined,
              size: 17,
            ),
            label: Text(widget.draftPending ? '임시 저장 중' : '임시 저장'),
          ),
        FilledButton.icon(
          onPressed: widget.isSaving ? null : widget.onSave,
          icon: const Icon(Icons.check, size: 17),
          label: Text(widget.isSaving ? '저장 중' : compactHeader ? '저장' : '앨범 저장'),
          style: compactHeader ? FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ) : null,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1180;
          final narrow = constraints.maxWidth < 760;
          final showProperties = wide || _propertiesOpen;
          final pageLabel = widget.pageLabel;
          return Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: WebPalette.of(context).surface,
                  border: Border(bottom: BorderSide(color: WebPalette.of(context).line)),
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '편집 나가기',
                      onPressed: widget.isSaving ? null : widget.onBack,
                      icon: const Icon(Icons.arrow_back, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: WebPalette.of(context).ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.hasUnsavedChanges
                                ? '저장하지 않은 변경사항'
                                : widget.isPersisted ? '저장된 앨범' : '새 앨범 · 저장 전',
                            style: TextStyle(
                              color: WebPalette.of(context).muted, fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!narrow) ...[
                      Text(widget.specification, style: TextStyle(
                        fontSize: 12, color: WebPalette.of(context).muted,
                      )),
                      const SizedBox(width: 20),
                    ],
                    IconButton(
                      tooltip: '실행 취소 (Ctrl/⌘ Z)',
                      onPressed: widget.isSaving ? null : widget.onUndo,
                      icon: const Icon(Icons.undo, size: 20),
                    ),
                    IconButton(
                      tooltip: '다시 실행 (Ctrl/⌘ Shift Z)',
                      onPressed: widget.isSaving ? null : widget.onRedo,
                      icon: const Icon(Icons.redo, size: 20),
                    ),
                  ],
                ),
              ),
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: WebPalette.of(context).surface,
                  border: Border(bottom: BorderSide(color: WebPalette.of(context).line)),
                ),
                child: Row(
                  children: [
                    if (narrow)
                      IconButton(
                        tooltip: _pagesOpen ? '페이지 목록 접기' : '페이지 목록 보기',
                        onPressed: () => setState(() => _pagesOpen = !_pagesOpen),
                        icon: const Icon(Icons.view_sidebar_outlined, size: 19),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            for (final tool in widget.tools)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: TextButton.icon(
                                  onPressed: widget.isSaving ? null : () {
                                    tool.onPressed();
                                    if (tool.opensProperties) {
                                      setState(() => _propertiesOpen = true);
                                    }
                                  },
                                  icon: Icon(tool.icon, size: 17),
                                  label: Text(tool.label),
                                  style: TextButton.styleFrom(
                                    foregroundColor: tool.selected
                                        ? WebPalette.of(context).brandInk : WebPalette.of(context).muted,
                                    backgroundColor: tool.selected
                                        ? WebPalette.of(context).softBrand : null,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 11,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!wide)
                      IconButton(
                        tooltip: _propertiesOpen ? '속성 패널 접기' : '속성 패널 보기',
                        onPressed: () => setState(
                          () => _propertiesOpen = !_propertiesOpen,
                        ),
                        icon: const Icon(Icons.tune, size: 19),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              if (narrow && _pagesOpen)
                SizedBox(height: 112, child: widget.compactPageRail),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!narrow) ...[
                            SizedBox(width: 178, child: widget.pageRail),
                            VerticalDivider(width: 1, color: WebPalette.of(context).line),
                          ],
                          Expanded(
                            child: ColoredBox(
                              key: const ValueKey('web-editor-document-workspace'),
                              color: WebPalette.of(context).canvas,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(pageLabel, style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: WebPalette.of(context).muted,
                                        )),
                                        const Spacer(),
                                        if (narrow && widget.onAddPage != null)
                                          IconButton(
                                            tooltip: '페이지 추가',
                                            onPressed: widget.onAddPage,
                                            icon: const Icon(Icons.add, size: 18),
                                          ),
                                        if (narrow && widget.onDeletePage != null)
                                          IconButton(
                                            tooltip: '선택 페이지 삭제',
                                            onPressed: widget.onDeletePage,
                                            icon: const Icon(
                                              Icons.delete_outline, size: 18,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(child: widget.canvas),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(12, 8, 12, 18),
                                    child: Text(
                                      '클릭하여 선택 · 드래그하여 이동 · Delete 삭제',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11, color: WebPalette.of(context).muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (wide) ...[
                            VerticalDivider(width: 1, color: WebPalette.of(context).line),
                            SizedBox(width: 304, child: widget.properties),
                          ],
                        ],
                      ),
                    ),
                    if (!wide && showProperties)
                      Positioned(
                        top: 0, bottom: 0, right: 0,
                        width: narrow
                            ? constraints.maxWidth.clamp(0.0, 320.0).toDouble()
                            : 304.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: WebPalette.of(context).surface,
                            border: Border(left: BorderSide(color: WebPalette.of(context).line)),
                          ),
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  tooltip: '속성 패널 접기',
                                  onPressed: () => setState(
                                    () => _propertiesOpen = false,
                                  ),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ),
                              Expanded(child: widget.properties),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class WebAlbumReaderWorkspace extends StatelessWidget {
  const WebAlbumReaderWorkspace({
    super.key,
    required this.title,
    required this.description,
    required this.pageLabel,
    required this.canvas,
    required this.pageRail,
    required this.compactPageRail,
    required this.onBack,
    this.onEdit,
    this.onOrder,
    this.onPrevious,
    this.onNext,
    this.onDetail,
    this.managementMenu,
    this.busy = false,
  });

  final String title;
  final String description;
  final String pageLabel;
  final Widget canvas;
  final Widget pageRail;
  final Widget compactPageRail;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onOrder;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onDetail;
  final Widget? managementMenu;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SnapFitWebShell(
      title: '앨범 미리보기',
      workspace: true,
      showNavigation: false,
      actions: [
        TextButton.icon(
          onPressed: busy ? null : onBack,
          icon: const Icon(Icons.arrow_back, size: 17),
          label: const Text('내 앨범'),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 20 : 32,
                  vertical: compact ? 20 : 26,
                ),
                decoration: BoxDecoration(
                  color: WebPalette.of(context).surface,
                  border: Border(bottom: BorderSide(color: WebPalette.of(context).line)),
                ),
                child: WebPageHeading(
                  title: title,
                  eyebrow: 'ALBUM PREVIEW',
                  description: description,
                  trailing: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (onDetail != null)
                        TextButton.icon(
                          onPressed: busy ? null : onDetail,
                          icon: const Icon(Icons.zoom_in, size: 18),
                          label: const Text('페이지 상세'),
                        ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('앨범 편집'),
                      ),
                      FilledButton.icon(
                        onPressed: busy ? null : onOrder,
                        icon: const Icon(Icons.auto_stories_outlined, size: 18),
                        label: const Text('책으로 주문'),
                      ),
                      if (managementMenu != null) managementMenu!,
                    ],
                  ),
                ),
              ),
              if (compact)
                SizedBox(height: 112, child: compactPageRail),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!compact) ...[
                      SizedBox(width: 180, child: pageRail),
                      VerticalDivider(width: 1, color: WebPalette.of(context).line),
                    ],
                    Expanded(
                      child: ColoredBox(
                        color: WebPalette.of(context).canvas,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: '이전 페이지',
                                    onPressed: busy ? null : onPrevious,
                                    icon: const Icon(Icons.chevron_left, size: 20),
                                  ),
                                  SizedBox(
                                    width: 150,
                                    child: Text(pageLabel,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: WebPalette.of(context).ink,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '다음 페이지',
                                    onPressed: busy ? null : onNext,
                                    icon: const Icon(Icons.chevron_right, size: 20),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  compact ? 20 : 40, 0,
                                  compact ? 20 : 40, 28,
                                ),
                                child: canvas,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
