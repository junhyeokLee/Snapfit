import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../../../shared/widgets/editor_modal_scope.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../controllers/text_editor_manager.dart';
import '../../viewmodels/album_editor_view_model.dart';
import 'editor_bottom_menu.dart';
import 'editor_more_tools_sheet.dart';
import '../../../../../shared/widgets/experience_icon.dart';

/// A constant-size touch dock. Selecting artwork replaces tools, never the
/// canvas or its image tree. Extra controls are mounted only while requested.
class EditorContextDock extends ConsumerStatefulWidget {
  const EditorContextDock({
    super.key,
    required this.layers,
    required this.interaction,
    required this.onModeChanged,
    required this.onAddPhoto,
    required this.onRefresh,
    required this.onOpenGallery,
    required this.onOpenCrop,
    required this.onOpenDecorate,
    this.canUndo = false,
    this.canRedo = false,
    this.onUndo,
    this.onRedo,
    this.enabled = true,
    this.currentMode = EditorMode.none,
    this.onEditText,
    this.onDetailsOpenChanged,
    this.onFillPhotos,
  });

  final List<LayerModel> layers;
  final LayerInteractionManager interaction;
  final ValueChanged<EditorMode> onModeChanged;
  final VoidCallback onAddPhoto, onRefresh;
  final Future<void> Function(LayerModel) onOpenGallery, onOpenCrop;
  final ValueChanged<LayerModel> onOpenDecorate;
  final bool canUndo, canRedo, enabled;
  final EditorMode currentMode;
  final VoidCallback? onUndo, onRedo;
  final ValueChanged<LayerModel>? onEditText;
  final ValueChanged<bool>? onDetailsOpenChanged;
  final Future<void> Function()? onFillPhotos;

  @override
  ConsumerState<EditorContextDock> createState() => _EditorContextDockState();
}

class _EditorContextDockState extends ConsumerState<EditorContextDock> {
  // ModalRoute.isCurrent becomes true before an exiting sheet is removed.
  // Own the entire open/close/handoff interval, including taps from old builds.
  bool _detailsPending = false;
  bool get _canUseTools =>
      mounted &&
      widget.enabled &&
      !_detailsPending &&
      ModalRoute.of(context)?.isCurrent != false;

  Future<void> _details(BuildContext context) async {
    if (!_canUseTools) return;
    setState(() => _detailsPending = true);
    widget.onDetailsOpenChanged?.call(true);
    try {
      final scope = ProviderScope.containerOf(context, listen: false);
      final vm = scope.read(albumEditorViewModelProvider.notifier);
      final pageId = vm.currentPage?.id;
      final session = vm.editSessionIdentity;
      final albumId = vm.editingAlbumId;
      final interaction = widget.interaction;
      final selectedId = interaction.selectedLayerId;
      final navigator = Navigator.of(context);
      var closing = false;
      late final ModalBottomSheetRoute<EditorMoreAction> route;
      void finish([EditorMoreAction? action]) {
        if (closing || !route.isCurrent) return;
        closing = true;
        navigator.pop(action);
      }

      route = ModalBottomSheetRoute<EditorMoreAction>(
        settings: editorModalRouteSettings(context),
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        isScrollControlled: true,
        useSafeArea: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        backgroundColor: ExperienceFormStyle.surface(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (_) => UncontrolledProviderScope(
          container: scope,
          child: EditorMoreToolsSheet(
            interaction: interaction,
            session: session,
            pageId: pageId,
            albumId: albumId,
            selectedId: selectedId,
            onAction: finish,
            onClose: finish,
            showPhotoFill: widget.onFillPhotos != null,
          ),
        ),
      );
      final action = await navigator.push(route);
      // A popped route can still paint its exit animation. Wait for removal before
      // handing control back to the canvas or opening another editor tool.
      await route.completed;
      if (!context.mounted ||
          !widget.enabled ||
          !identical(widget.interaction, interaction) ||
          action == null ||
          ModalRoute.of(context)?.isCurrent == false ||
          !identical(ProviderScope.containerOf(context, listen: false), scope))
        return;
      final current = scope.read(albumEditorViewModelProvider.notifier);
      if (!identical(current.editSessionIdentity, session) ||
          current.currentPage?.id != pageId ||
          current.editingAlbumId != albumId ||
          widget.interaction.selectedLayerId != selectedId)
        return;
      final target = selectedId == null
          ? null
          : current.findLayerById(selectedId);
      if (selectedId != null && target == null) return;
      switch (action) {
        case EditorMoreAction.photoPosition:
          if (target?.type != LayerType.image) return;
          widget.interaction.toggleImagePanMode();
          widget.onRefresh();
        case EditorMoreAction.delete:
          widget.interaction.deleteSelected();
          widget.onRefresh();
        case EditorMoreAction.decorate:
          widget.onModeChanged(EditorMode.sticker);
        case EditorMoreAction.layout:
          widget.onModeChanged(EditorMode.layout);
        case EditorMoreAction.background:
          widget.onModeChanged(EditorMode.backgroundColor);
        case EditorMoreAction.fillPhotos:
          await widget.onFillPhotos?.call();
      }
    } finally {
      if (mounted) setState(() => _detailsPending = false);
      widget.onDetailsOpenChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.layers
        .where((l) => l.id == widget.interaction.selectedLayerId)
        .firstOrNull;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final textEditor = TextEditorManager(context, vm);
    final labelHeight = MediaQuery.textScalerOf(context).scale(11) * 3.2;
    final toolHeight = math.max(66.0, 30 + labelHeight);
    Widget tool(
      String label,
      IconData icon,
      VoidCallback? callback, {
      bool highlighted = false,
    }) => Expanded(
      child: _DockTool(
        key: label == '더보기' ? const ValueKey('editor-more-tools') : null,
        label: label,
        icon: icon,
        height: toolHeight,
        highlighted: highlighted,
        onPressed: widget.enabled && !_detailsPending && callback != null
            ? () {
                if (_canUseTools) callback();
              }
            : null,
      ),
    );
    final List<Widget> tools;
    if (selected == null) {
      tools = [
        tool('사진 추가', Icons.add_photo_alternate_outlined, widget.onAddPhoto),
        tool(
          '글 추가',
          Icons.text_fields,
          () => widget.onModeChanged(EditorMode.text),
        ),
        tool(
          '템플릿',
          Icons.dashboard_outlined,
          () => widget.onModeChanged(EditorMode.template),
        ),
      ];
    } else if (selected.type == LayerType.image) {
      final hasPhoto =
          selected.asset != null ||
          [
            selected.previewUrl,
            selected.imageUrl,
            selected.originalUrl,
          ].whereType<String>().any((url) => url.trim().isNotEmpty);
      tools = [
        tool(
          '사진 바꾸기',
          Icons.image_outlined,
          () => widget.onOpenGallery(selected),
        ),
        tool(
          '자르기·구도',
          Icons.crop,
          hasPhoto ? () => widget.onOpenCrop(selected) : null,
        ),
        tool(
          '사진 꾸미기',
          Icons.auto_awesome_outlined,
          () => widget.onOpenDecorate(selected),
        ),
      ];
    } else if (selected.type == LayerType.text) {
      tools = [
        tool(
          selected.type == LayerType.text ? '글 수정' : '꾸미기',
          Icons.text_fields,
          () {
            if (widget.onEditText case final callback?) {
              callback(selected);
            } else {
              textEditor.openForExisting(selected);
            }
          },
        ),
        tool(
          selected.type == LayerType.text ? '글 꾸미기' : '요소 꾸미기',
          Icons.palette_outlined,
          () => widget.onOpenDecorate(selected),
        ),
        tool('진하기', Icons.opacity, () => _details(context)),
      ];
    } else {
      tools = [
        tool('요소 편집', Icons.tune, () => _details(context)),
        tool('진하기', Icons.opacity, () => _details(context)),
        tool(
          '삭제',
          Icons.delete_outline,
          widget.interaction.isLayerDeletable(selected)
              ? widget.interaction.deleteSelected
              : null,
        ),
      ];
    }
    tools.add(
      tool(
        '겹침 순서',
        Icons.layers_outlined,
        () => widget.onModeChanged(EditorMode.layer),
        highlighted: widget.currentMode == EditorMode.layer,
      ),
    );
    tools.add(tool('더보기', Icons.more_horiz, () => _details(context)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        key: const ValueKey('editor-context-dock'),
        color: AlbumStageStyle.bottom(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AlbumStageStyle.line(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 3, 6, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selected == null
                            ? '편집 도구'
                            : selected.type == LayerType.image
                            ? '사진 도구'
                            : selected.type == LayerType.text
                            ? '글 도구'
                            : '꾸미기 도구',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected != null)
                      IconButton(
                        key: const ValueKey('editor-deselect'),
                        tooltip: '선택 해제',
                        onPressed: widget.enabled && !_detailsPending
                            ? () {
                                if (_canUseTools)
                                  widget.interaction.clearSelection();
                              }
                            : null,
                        icon: const ExperienceIcon('X', size: 18),
                      ),
                    IconButton(
                      key: const ValueKey('editor-Undo2'),
                      tooltip: '되돌리기',
                      onPressed:
                          widget.enabled &&
                              !_detailsPending &&
                              widget.canUndo &&
                              widget.onUndo != null
                          ? () {
                              if (_canUseTools) widget.onUndo?.call();
                            }
                          : null,
                      icon: const ExperienceIcon('Undo2', size: 20),
                    ),
                    IconButton(
                      key: const ValueKey('editor-Redo2'),
                      tooltip: '다시하기',
                      onPressed:
                          widget.enabled &&
                              !_detailsPending &&
                              widget.canRedo &&
                              widget.onRedo != null
                          ? () {
                              if (_canUseTools) widget.onRedo?.call();
                            }
                          : null,
                      icon: const ExperienceIcon('Redo2', size: 20),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: toolHeight,
                child: Row(children: tools),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockTool extends StatelessWidget {
  const _DockTool({
    super.key,
    required this.label,
    required this.icon,
    required this.height,
    this.onPressed,
    this.highlighted = false,
  });
  final String label;
  final IconData icon;
  final double height;
  final VoidCallback? onPressed;
  final bool highlighted;
  @override
  Widget build(BuildContext context) {
    final ink = onPressed == null
        ? ExperienceFormStyle.muted(context)
        : highlighted
        ? ExperienceFormStyle.selectionInk(context)
        : ExperienceFormStyle.ink(context);
    final content = SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: ink),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: ExperienceFormStyle.text(
              context,
              11,
            ).copyWith(height: 1.4, color: ink),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: highlighted,
      enabled: onPressed != null,
      child: Tooltip(
        message: label,
        child: Material(
          color: highlighted
              ? ExperienceFormStyle.selection(context)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(15),
            child: content,
          ),
        ),
      ),
    );
  }
}
