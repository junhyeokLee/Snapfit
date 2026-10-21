import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';

enum EditorMode {
  none,
  layout,
  template,
  sticker,
  backgroundColor,
  layer,
  text,
}

class EditorBottomMenu extends StatelessWidget {
  const EditorBottomMenu({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.onAddPhoto,
    this.isCover = false,
    this.onCover,
    this.showCoverMenuItem = true,
    this.canUndo = false,
    this.canRedo = false,
    this.onUndo,
    this.onRedo,
    this.useCreationStyle = false,
  });

  final EditorMode currentMode;
  final ValueChanged<EditorMode> onModeChanged;
  final VoidCallback? onAddPhoto, onCover, onUndo, onRedo;
  final bool isCover, showCoverMenuItem, canUndo, canRedo, useCreationStyle;

  @override
  Widget build(BuildContext context) {
    final items = <_EditorMenuItem>[
      _EditorMenuItem('사진', 'ImagePlus', null, onAction: onAddPhoto),
      const _EditorMenuItem('글', 'Type', EditorMode.text),
      const _EditorMenuItem('템플릿', 'PanelsTopLeft', EditorMode.template),
      const _EditorMenuItem('꾸미기', 'Shapes', EditorMode.sticker),
      if (isCover && showCoverMenuItem)
        _EditorMenuItem('커버', 'BookOpen', null, onAction: onCover),
      const _EditorMenuItem('레이아웃', 'LayoutGrid', EditorMode.layout),
      const _EditorMenuItem('배경', 'Settings2', EditorMode.backgroundColor),
      const _EditorMenuItem('레이어', 'Layers2', EditorMode.layer),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final vertical = !useCreationStyle && box.maxWidth < 120;
        final labelHeight = MediaQuery.textScalerOf(context).scale(11) * 1.4;
        final tools = SingleChildScrollView(
          key: const ValueKey('editor-tool-scroll'),
          scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
          padding: const EdgeInsets.all(4),
          child: Flex(
            direction: vertical ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i == 4)
                  vertical
                      ? SizedBox(
                          width: 44,
                          child: Divider(
                            key: const ValueKey('editor-advanced-tool-divider'),
                            height: 12,
                            color: AlbumStageStyle.line(context),
                          ),
                        )
                      : SizedBox(
                          height: 32,
                          child: VerticalDivider(
                            key: const ValueKey('editor-advanced-tool-divider'),
                            width: 12,
                            color: AlbumStageStyle.line(context),
                          ),
                        ),
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: _tool(context, items[i], labelHeight),
                ),
              ],
            ],
          ),
        );
        if (useCreationStyle) return tools;
        final history = Flex(
          direction: vertical ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          children: [
            _history(context, '되돌리기', 'Undo2', canUndo ? onUndo : null),
            _history(context, '다시하기', 'Redo2', canRedo ? onRedo : null),
          ],
        );
        return ColoredBox(
          key: const ValueKey('editor-command-surface'),
          color: AlbumStageStyle.bottom(context),
          child: vertical
              ? Column(
                  children: [
                    history,
                    Divider(height: 1, color: AlbumStageStyle.line(context)),
                    Expanded(child: tools),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(height: 1, color: AlbumStageStyle.line(context)),
                    SizedBox(
                      height: 46 + labelHeight,
                      child: Row(
                        children: [
                          Expanded(child: tools),
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: history,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _history(
    BuildContext context,
    String label,
    String icon,
    VoidCallback? action,
  ) => IconButton(
    key: ValueKey('editor-$icon'),
    tooltip: label,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    onPressed: action,
    icon: ExperienceIcon(
      icon,
      size: 21,
      color: AlbumStageStyle.ink(
        context,
      ).withValues(alpha: action == null ? .25 : 1),
    ),
  );

  Widget _tool(BuildContext context, _EditorMenuItem item, double labelHeight) {
    final selected = item.mode != null && currentMode == item.mode;
    final action = item.mode == null
        ? item.onAction
        : () => onModeChanged(selected ? EditorMode.none : item.mode!);
    final ink = selected
        ? ExperienceFormStyle.selectionInk(context)
        : AlbumStageStyle.ink(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: action != null,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: Material(
          color: selected
              ? AlbumStageStyle.controlFill(context)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: math.max(
                60,
                MediaQuery.textScalerOf(context).scale(11) * 4 + 12,
              ),
              height: 34 + labelHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExperienceIcon(item.icon, size: 22, color: ink),
                  const SizedBox(height: 5),
                  Text(
                    item.label,
                    maxLines: 1,
                    style: ExperienceFormStyle.text(
                      context,
                      11,
                      color: ink,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorMenuItem {
  const _EditorMenuItem(this.label, this.icon, this.mode, {this.onAction});
  final String label, icon;
  final EditorMode? mode;
  final VoidCallback? onAction;
}
