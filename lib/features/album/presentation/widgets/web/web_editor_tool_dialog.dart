import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../shared/web/web_design.dart';
import '../editor/editor_bottom_menu.dart';

/// A large web-only selector. Existing panels retain their own data, selection,
/// and apply behavior; the shell owns only navigation and dialog dismissal.
class WebEditorToolDialog extends StatefulWidget {
  const WebEditorToolDialog({
    super.key,
    required this.initialMode,
    required this.panelBuilder,
    this.onModeChanged,
  });

  final EditorMode initialMode;
  final Widget Function(BuildContext, EditorMode, VoidCallback) panelBuilder;
  final ValueChanged<EditorMode>? onModeChanged;

  @override
  State<WebEditorToolDialog> createState() => _WebEditorToolDialogState();
}

class _WebEditorToolDialogState extends State<WebEditorToolDialog>
    with SingleTickerProviderStateMixin {
  static const _tools = <({EditorMode mode, String label, IconData icon})>[
    (mode: EditorMode.layer, label: '레이어', icon: Icons.layers_outlined),
    (mode: EditorMode.layout, label: '레이아웃', icon: Icons.dashboard_outlined),
    (mode: EditorMode.template, label: '템플릿', icon: Icons.grid_view_outlined),
    (mode: EditorMode.sticker, label: '꾸미기', icon: Icons.interests_outlined),
    (
      mode: EditorMode.backgroundColor,
      label: '배경',
      icon: Icons.palette_outlined,
    ),
  ];

  late final TabController _tabs;
  late EditorMode _mode;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final index = _tools.indexWhere((tool) => tool.mode == widget.initialMode);
    final selectedIndex = index < 0 ? 0 : index;
    _mode = _tools[selectedIndex].mode;
    _tabs = TabController(
      length: _tools.length,
      initialIndex: selectedIndex,
      vsync: this,
    );
    _tabs.addListener(_syncMode);
  }

  @override
  void dispose() {
    _tabs.removeListener(_syncMode);
    _tabs.dispose();
    super.dispose();
  }

  void _syncMode() => _changeMode(_tabs.index);

  void _changeMode(int index) {
    if (_closing || _mode == _tools[index].mode) return;
    final mode = _tools[index].mode;
    setState(() => _mode = mode);
    widget.onModeChanged?.call(mode);
  }

  void _close() {
    if (!mounted || _closing) return;
    final route = ModalRoute.of(context);
    // Apply callbacks may fire twice or finish while dismissal is animating.
    // A stale callback must never pop the editor route underneath this dialog.
    if (route is! PopupRoute || !route.isCurrent) return;
    setState(() => _closing = true);
    Navigator.of(context).maybePop().then((popped) {
      if (!popped && mounted) setState(() => _closing = false);
    });
  }

  String get _subtitle => switch (_mode) {
    EditorMode.layer => '사진과 글의 순서를 조정하거나 편집할 요소를 선택하세요.',
    EditorMode.layout => '사진 배치를 비교하고 현재 페이지에 어울리는 구성을 선택하세요.',
    EditorMode.template => '디자인을 크게 살펴보세요. 선택하면 현재 페이지에 적용됩니다.',
    EditorMode.sticker => '스티커와 장식을 선택하면 현재 페이지에 추가됩니다.',
    EditorMode.backgroundColor => '배경을 선택하면 현재 페이지에 적용됩니다.',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final narrow = media.size.width < 600;
    final inset = narrow ? 12.0 : 24.0;
    final width = math.min(1120.0, math.max(0.0, media.size.width - inset * 2));
    final height = math.min(
      860.0,
      math.max(0.0, media.size.height - media.viewInsets.vertical - inset * 2),
    );
    final palette = WebPalette.of(context);
    return Dialog(
      key: const ValueKey('web-editor-tool-dialog'),
      insetPadding: EdgeInsets.all(inset),
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        key: const ValueKey('web-editor-tool-dialog-frame'),
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                narrow ? 16 : 24,
                narrow ? 14 : 20,
                narrow ? 8 : 16,
                narrow ? 12 : 18,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '앨범 편집 도구',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.ink,
                            fontSize: narrow ? 19 : 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _subtitle,
                          key: const ValueKey('web-editor-tool-subtitle'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey('web-editor-tool-close'),
                    tooltip: '편집 도구 닫기',
                    onPressed: _closing ? null : _close,
                    icon: Icon(Icons.close, color: palette.ink),
                  ),
                ],
              ),
            ),
            TabBar(
              key: const ValueKey('web-editor-tool-tabs'),
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 20),
              indicatorColor: palette.brand,
              indicatorWeight: 3,
              labelColor: palette.brandInk,
              unselectedLabelColor: palette.muted,
              dividerColor: palette.line,
              onTap: _changeMode,
              tabs: [
                for (final tool in _tools)
                  Tab(
                    key: ValueKey('web-editor-tool-tab-${tool.mode.name}'),
                    height: 56,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tool.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(tool.label),
                      ],
                    ),
                  ),
              ],
            ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('web-editor-tool-content-${_mode.name}'),
                child: widget.panelBuilder(context, _mode, _close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
