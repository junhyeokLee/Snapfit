import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../domain/entities/album_page.dart';
import '../../controllers/layer_builder.dart';
import '../reader/album_reader_page_content.dart';
import 'web_editor_viewport.dart';

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

  double get _itemExtent =>
      widget.horizontal ? 64.0 : 92.0 / widget.cover.ratio + 54.0;

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || widget.pages.isEmpty) return;
      final position = _scroll.position;
      final target =
          (widget.selectedIndex * _itemExtent -
                  position.viewportDimension / 2 +
                  _itemExtent / 2)
              .clamp(0.0, position.maxScrollExtent)
              .toDouble();
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
                    child: Text(
                      '페이지',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: WebPalette.of(context).ink,
                      ),
                    ),
                  ),
                  Text(
                    '${pages.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: WebPalette.of(context).muted,
                    ),
                  ),
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
                final label = isCover
                    ? '표지'
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
                      color: selected
                          ? WebPalette.of(context).softBrand
                          : Colors.transparent,
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
                                    backgroundColor:
                                        page.backgroundColor == null
                                        ? null
                                        : Color(page.backgroundColor!),
                                    flatPresentation: true,
                                    isCover: isCover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.3,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? WebPalette.of(context).brandInk
                                      : WebPalette.of(context).muted,
                                ),
                              ),
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
                      child: Text(
                        addDescription!,
                        style: TextStyle(
                          color: WebPalette.of(context).muted,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
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

/// Compact document identity used by web editing and review workspaces.
/// The route retains ownership of exit guards and save state.
class WebAlbumDocumentTitle extends StatelessWidget {
  const WebAlbumDocumentTitle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.backLabel = '내 앨범',
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final String backLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: backLabel,
        onPressed: busy ? null : onBack,
        icon: const Icon(Icons.arrow_back, size: 20),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: WebPalette.of(context).ink,
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Tooltip(
              message: subtitle,
              // The full subtitle is already the Text semantics label. Keeping
              // the same tooltip label would announce the sentence twice.
              excludeFromSemantics: true,
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: WebPalette.of(context).muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
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
    this.lastAccountSavedAt,
    this.lastDraftSavedAt,
    this.onAddPage,
    this.onDeletePage,
    this.selectedLayerId,
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

  /// Confirmed timestamps only. A missing timestamp must not imply a save.
  final DateTime? lastAccountSavedAt;
  final DateTime? lastDraftSavedAt;
  final VoidCallback? onAddPage;
  final VoidCallback? onDeletePage;
  final String? selectedLayerId;

  @override
  State<WebAlbumEditorWorkspace> createState() =>
      _WebAlbumEditorWorkspaceState();
}

class _WebAlbumEditorWorkspaceState extends State<WebAlbumEditorWorkspace> {
  static const _minimumBottomPanelHeight = 180.0;
  static const _maximumBottomPanelHeight = 480.0;

  bool _propertiesOpen = false;
  // Narrow browsers start with the artwork visible. The page-list button can
  // reveal the strip without permanently reserving 112px of short windows.
  bool _pagesOpen = false;
  // Keep the user's preference across temporary keyboard/viewport constraints.
  // This is presentation state only; it is never written to the album.
  double? _preferredBottomPanelHeight;
  final _canvasSubtreeKey = GlobalKey();
  final _propertiesSubtreeKey = GlobalKey();

  String _savedAt(DateTime value) {
    final local = value.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String get _saveStatus {
    final account = widget.isSaving
        ? '계정에 저장 중'
        : widget.hasUnsavedChanges
        ? '계정에 저장하지 않은 변경사항'
        : widget.isPersisted
        ? '계정에 저장됨'
        : '계정에 저장 전';
    final confirmed = widget.lastAccountSavedAt;
    final accountTime = confirmed == null
        ? ''
        : ' · 마지막 계정 저장 ${_savedAt(confirmed)}';
    final browser = widget.onSaveDraft == null
        ? ''
        : widget.draftPending
        ? ' · 이 브라우저에 보관 중'
        : widget.draftFailed
        ? ' · 브라우저 보관 실패 · 다시 시도해 주세요'
        : widget.lastDraftSavedAt != null
        ? ' · 브라우저 보관 ${_savedAt(widget.lastDraftSavedAt!)}'
        : ' · 임시 보관은 이 브라우저에서만 유지돼요';
    return '$account$accountTime$browser';
  }

  @override
  void initState() {
    super.initState();
    _propertiesOpen = widget.selectedLayerId != null;
  }

  @override
  void didUpdateWidget(covariant WebAlbumEditorWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLayerId != null &&
        widget.selectedLayerId != oldWidget.selectedLayerId) {
      _propertiesOpen = true;
      _pagesOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final shortNarrowWindow =
        media.size.width < 760 &&
        media.size.height - media.viewInsets.bottom < 420;
    final compactHeader = media.size.width < 600 || shortNarrowWindow;
    final groupedActions =
        compactHeader &&
        (shortNarrowWindow ||
            MediaQuery.sizeOf(context).width < 380 ||
            MediaQuery.textScalerOf(context).scale(14) > 21);
    return SnapFitWebShell(
      title: '앨범 편집',
      compactBrand: true,
      denseHeader: true,
      // A multi-row document header can consume an entire short window. The
      // shell's compact row leaves space to reach the scrollable workspace;
      // document identity moves into its existing page caption.
      headerTitle: shortNarrowWindow
          ? null
          : WebAlbumDocumentTitle(
              key: const ValueKey('web-editor-document-header'),
              title: widget.title,
              subtitle:
                  '${widget.hasUnsavedChanges
                      ? '저장하지 않은 변경사항'
                      : widget.isPersisted
                      ? '저장된 앨범'
                      : '새 앨범 · 저장 전'}'
                  ' · ${widget.specification}',
              onBack: widget.onBack,
              backLabel: '편집 나가기',
              busy: widget.isSaving,
            ),
      workspace: true,
      showNavigation: false,
      actions: [
        if (shortNarrowWindow)
          IconButton(
            tooltip: '편집 나가기',
            onPressed: widget.isSaving ? null : widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
        if (groupedActions)
          PopupMenuButton<String>(
            tooltip: '편집 메뉴',
            icon: const Icon(Icons.more_horiz),
            onSelected: (action) {
              switch (action) {
                case 'undo':
                  widget.onUndo?.call();
                case 'redo':
                  widget.onRedo?.call();
                case 'draft':
                  widget.onSaveDraft?.call();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'undo',
                enabled: !widget.isSaving && widget.onUndo != null,
                child: const Text('실행 취소'),
              ),
              PopupMenuItem(
                value: 'redo',
                enabled: !widget.isSaving && widget.onRedo != null,
                child: const Text('다시 실행'),
              ),
              if (widget.onSaveDraft != null)
                PopupMenuItem(
                  value: 'draft',
                  enabled: !widget.isSaving && !widget.draftPending,
                  child: Text(
                    widget.draftPending ? '이 브라우저에 보관 중' : '이 브라우저에 임시 보관',
                  ),
                ),
            ],
          ),
        if (!groupedActions)
          IconButton(
            tooltip: '실행 취소 (Ctrl/⌘ Z)',
            onPressed: widget.isSaving ? null : widget.onUndo,
            icon: const Icon(Icons.undo, size: 19),
          ),
        if (!groupedActions)
          IconButton(
            tooltip: '다시 실행 (Ctrl/⌘ Shift Z)',
            onPressed: widget.isSaving ? null : widget.onRedo,
            icon: const Icon(Icons.redo, size: 19),
          ),
        if (widget.onSaveDraft != null && compactHeader && !groupedActions)
          IconButton(
            tooltip: widget.draftFailed
                ? '이 브라우저에 임시 보관 다시 시도'
                : '이 브라우저에 임시 보관',
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
            label: Text(widget.draftPending ? '브라우저에 보관 중' : '브라우저에 보관'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        FilledButton.icon(
          onPressed: widget.isSaving ? null : widget.onSave,
          icon: const Icon(Icons.check, size: 17),
          label: Text(
            widget.isSaving
                ? '계정에 저장 중'
                : compactHeader
                ? '계정 저장'
                : '계정에 저장',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1180;
          final narrow = constraints.maxWidth < 760;
          final showProperties = wide || _propertiesOpen;
          // In a medium browser the inspector shares space with the artwork.
          // The page strip takes over from the rail when all three cannot fit.
          final showPageRail =
              !narrow &&
              (wide || !showProperties || constraints.maxWidth >= 1000);
          final palette = WebPalette.of(context);
          final toolHeight =
              (MediaQuery.textScalerOf(context).scale(14) * 1.5 + 28).clamp(
                54.0,
                double.infinity,
              );
          return Column(
            children: [
              Container(
                height: toolHeight,
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(bottom: BorderSide(color: palette.line)),
                ),
                child: Row(
                  children: [
                    if (!showPageRail)
                      IconButton(
                        tooltip: _pagesOpen ? '페이지 목록 접기' : '페이지 목록 보기',
                        onPressed: () => setState(() {
                          _pagesOpen = !_pagesOpen;
                          if (_pagesOpen && narrow) _propertiesOpen = false;
                        }),
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
                                  onPressed: widget.isSaving
                                      ? null
                                      : () {
                                          tool.onPressed();
                                          if (tool.opensProperties) {
                                            setState(() {
                                              _propertiesOpen = true;
                                              if (narrow) _pagesOpen = false;
                                            });
                                          }
                                        },
                                  icon: Icon(tool.icon, size: 17),
                                  label: Text(tool.label),
                                  style: TextButton.styleFrom(
                                    foregroundColor: tool.selected
                                        ? palette.brandInk
                                        : palette.muted,
                                    backgroundColor: tool.selected
                                        ? palette.softBrand
                                        : null,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 11,
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
                        onPressed: () => setState(() {
                          _propertiesOpen = !_propertiesOpen;
                          if (_propertiesOpen && narrow) _pagesOpen = false;
                        }),
                        icon: const Icon(Icons.tune, size: 19),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              Tooltip(
                message: _saveStatus,
                excludeFromSemantics: true,
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const ValueKey('web-editor-save-status'),
                    width: double.infinity,
                    color: palette.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    child: Text(
                      _saveStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: palette.muted,
                      ),
                    ),
                  ),
                ),
              ),
              if (!showPageRail && _pagesOpen)
                SizedBox(height: 112, child: widget.compactPageRail),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    // The workspace also contains the page caption and zoom
                    // controls. Reserve enough height for the artwork itself,
                    // including their growth at larger accessibility sizes.
                    final minimumCanvasHeight =
                        320 +
                        (MediaQuery.textScalerOf(context).scale(14) - 14) * 4;
                    final canvas = KeyedSubtree(
                      key: _canvasSubtreeKey,
                      child: _canvas(
                        narrow,
                        documentTitleInCaption: shortNarrowWindow,
                      ),
                    );
                    if (narrow && showProperties) {
                      final scrollWorkspace =
                          bounds.maxHeight <
                          minimumCanvasHeight + _minimumBottomPanelHeight;
                      final maximumPanelHeight = scrollWorkspace
                          ? _maximumBottomPanelHeight
                          : (bounds.maxHeight - minimumCanvasHeight).clamp(
                              _minimumBottomPanelHeight,
                              _maximumBottomPanelHeight,
                            );
                      final automaticPanelHeight = scrollWorkspace
                          ? 280.0
                          : (bounds.maxHeight * .42).clamp(
                              _minimumBottomPanelHeight,
                              maximumPanelHeight.clamp(
                                _minimumBottomPanelHeight,
                                320.0,
                              ),
                            );
                      final panelHeight =
                          (_preferredBottomPanelHeight ?? automaticPanelHeight)
                              .clamp(
                                _minimumBottomPanelHeight,
                                maximumPanelHeight,
                              );
                      final panel = SizedBox(
                        height: panelHeight,
                        child: _properties(
                          bottom: true,
                          resizeHandle: _WebPropertiesResizeHandle(
                            height: panelHeight,
                            minimum: _minimumBottomPanelHeight,
                            maximum: maximumPanelHeight,
                            onChanged: (value) => setState(() {
                              _preferredBottomPanelHeight = value.clamp(
                                _minimumBottomPanelHeight,
                                maximumPanelHeight,
                              );
                            }),
                          ),
                        ),
                      );
                      // A short browser or an on-screen keyboard must not
                      // squeeze the artwork to zero behind a fixed inspector.
                      if (scrollWorkspace) {
                        return SingleChildScrollView(
                          key: const ValueKey(
                            'web-editor-compact-workspace-scroll',
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: minimumCanvasHeight,
                                child: canvas,
                              ),
                              panel,
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: [
                          Expanded(child: canvas),
                          panel,
                        ],
                      );
                    }
                    final workspace = Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showPageRail) ...[
                          SizedBox(width: 178, child: widget.pageRail),
                          VerticalDivider(width: 1, color: palette.line),
                        ],
                        Expanded(child: canvas),
                        if (showProperties)
                          SizedBox(
                            width: wide ? 304 : 280,
                            child: _properties(bottom: false, closable: !wide),
                          ),
                      ],
                    );
                    if (bounds.maxHeight < minimumCanvasHeight) {
                      return SingleChildScrollView(
                        child: SizedBox(
                          height: minimumCanvasHeight,
                          child: workspace,
                        ),
                      );
                    }
                    return workspace;
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _canvas(bool narrow, {bool documentTitleInCaption = false}) =>
      ColoredBox(
        key: const ValueKey('web-editor-document-workspace'),
        color: WebPalette.of(context).canvas,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? 16 : 24,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: '${widget.title} · ${widget.specification}',
                      excludeFromSemantics: true,
                      child: Text(
                        documentTitleInCaption
                            ? '${widget.title} · ${widget.pageLabel}'
                            : widget.pageLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: WebPalette.of(context).muted,
                        ),
                      ),
                    ),
                  ),
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
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                ],
              ),
            ),
            Expanded(
              child: WebEditorViewport(
                enabled: !widget.isSaving,
                child: widget.canvas,
              ),
            ),
          ],
        ),
      );

  Widget _properties({
    required bool bottom,
    bool closable = true,
    Widget? resizeHandle,
  }) {
    final palette = WebPalette.of(context);
    return DecoratedBox(
      key: ValueKey(
        bottom ? 'web-editor-bottom-properties' : 'web-editor-side-properties',
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: bottom
            ? Border(top: BorderSide(color: palette.line))
            : Border(left: BorderSide(color: palette.line)),
      ),
      child: Column(
        children: [
          if (resizeHandle != null) resizeHandle,
          if (closable)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '선택한 요소',
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '속성 패널 접기',
                    onPressed: () => setState(() => _propertiesOpen = false),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          Expanded(
            child: KeyedSubtree(
              key: _propertiesSubtreeKey,
              child: widget.properties,
            ),
          ),
        ],
      ),
    );
  }
}

/// Resizes the narrow inspector without changing the artwork or its view zoom.
/// Buttons also make resizing usable when the workspace itself must scroll.
class _WebPropertiesResizeHandle extends StatefulWidget {
  const _WebPropertiesResizeHandle({
    required this.height,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });

  final double height;
  final double minimum;
  final double maximum;
  final ValueChanged<double> onChanged;

  @override
  State<_WebPropertiesResizeHandle> createState() =>
      _WebPropertiesResizeHandleState();
}

class _WebPropertiesResizeHandleState
    extends State<_WebPropertiesResizeHandle> {
  static const _step = 32.0;
  final _focus = FocusNode(debugLabel: '속성 패널 높이 조절');
  bool _focused = false;
  double _dragStartHeight = 0;
  double _dragStartY = 0;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _resize(double value) =>
      widget.onChanged(value.clamp(widget.minimum, widget.maximum));

  String _value(double height) {
    final range = widget.maximum - widget.minimum;
    return range <= 0
        ? '최소 높이'
        : '${((height - widget.minimum) / range * 100).round()}%';
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _resize(widget.height + _step);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _resize(widget.height - _step);
    } else if (key == LogicalKeyboardKey.home) {
      _resize(widget.minimum);
    } else if (key == LogicalKeyboardKey.end) {
      _resize(widget.maximum);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final palette = WebPalette.of(context);
    final canGrow = widget.height < widget.maximum;
    final canShrink = widget.height > widget.minimum;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            key: const ValueKey('web-editor-properties-resize-handle'),
            label: '속성 패널 높이 조절',
            slider: true,
            value: _value(widget.height),
            hint: '위아래로 드래그하거나 위아래 방향키로 높이를 조절하세요',
            focusable: true,
            focused: _focused,
            onDidGainAccessibilityFocus: _focus.requestFocus,
            onIncrease: canGrow ? () => _resize(widget.height + _step) : null,
            onDecrease: canShrink ? () => _resize(widget.height - _step) : null,
            increasedValue: canGrow
                ? _value(
                    (widget.height + _step).clamp(
                      widget.minimum,
                      widget.maximum,
                    ),
                  )
                : null,
            decreasedValue: canShrink
                ? _value(
                    (widget.height - _step).clamp(
                      widget.minimum,
                      widget.maximum,
                    ),
                  )
                : null,
            child: Focus(
              focusNode: _focus,
              includeSemantics: false,
              onFocusChange: (value) => setState(() => _focused = value),
              onKeyEvent: _onKey,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeRow,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: _focus.requestFocus,
                  onVerticalDragStart: (details) {
                    _focus.requestFocus();
                    _dragStartHeight = widget.height;
                    _dragStartY = details.globalPosition.dy;
                  },
                  onVerticalDragUpdate: (details) => _resize(
                    _dragStartHeight -
                        (details.globalPosition.dy - _dragStartY),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _focused ? palette.softBrand : null,
                      border: _focused
                          ? Border.all(color: palette.brandInk, width: 2)
                          : null,
                    ),
                    child: ExcludeSemantics(
                      child: Row(
                        children: [
                          Icon(
                            Icons.drag_handle,
                            size: 20,
                            color: palette.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '속성 패널 높이',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: palette.muted,
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
          ),
        ),
        IconButton(
          tooltip: '속성 패널 작게',
          onPressed: canShrink ? () => _resize(widget.height - _step) : null,
          icon: const Icon(Icons.expand_more, size: 20),
        ),
        IconButton(
          tooltip: '속성 패널 크게',
          onPressed: canGrow ? () => _resize(widget.height + _step) : null,
          icon: const Icon(Icons.expand_less, size: 20),
        ),
      ],
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
    this.backLabel = '내 앨범',
    this.onEdit,
    this.editLabel = '앨범 편집',
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
  final String backLabel;
  final VoidCallback? onEdit;
  final String editLabel;
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
      compactBrand: true,
      denseHeader: true,
      headerTitle: WebAlbumDocumentTitle(
        key: const ValueKey('web-reader-document-header'),
        title: title,
        subtitle: description,
        onBack: onBack,
        backLabel: backLabel,
        busy: busy,
      ),
      workspace: true,
      showNavigation: false,
      actions: [
        if (onEdit != null)
          OutlinedButton.icon(
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: Text(editLabel),
          ),
        if (onOrder != null)
          FilledButton.icon(
            onPressed: busy ? null : onOrder,
            icon: const Icon(Icons.auto_stories_outlined, size: 17),
            label: const Text('책으로 주문'),
          ),
        if (managementMenu != null) managementMenu!,
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) SizedBox(height: 112, child: compactPageRail),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!compact) ...[
                      SizedBox(width: 180, child: pageRail),
                      VerticalDivider(
                        width: 1,
                        color: WebPalette.of(context).line,
                      ),
                    ],
                    Expanded(
                      child: ColoredBox(
                        color: WebPalette.of(context).canvas,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: '이전 페이지',
                                    onPressed: busy ? null : onPrevious,
                                    icon: const Icon(
                                      Icons.chevron_left,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? 110 : 150,
                                    child: Text(
                                      pageLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                                    icon: const Icon(
                                      Icons.chevron_right,
                                      size: 20,
                                    ),
                                  ),
                                  if (onDetail != null) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: '현재 페이지 크게 보기',
                                      onPressed: busy ? null : onDetail,
                                      icon: const Icon(Icons.zoom_in, size: 20),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  compact ? 12 : 32,
                                  0,
                                  compact ? 12 : 32,
                                  20,
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
