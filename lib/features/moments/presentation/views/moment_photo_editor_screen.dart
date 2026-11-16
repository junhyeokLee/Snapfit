import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../core/fonts/document_font_gate.dart';
import '../../../../core/fonts/document_fonts.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/album_stage_style.dart';
import '../../../../shared/widgets/editor_modal_scope.dart';
import '../../../../shared/widgets/edit_text_overlay.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../album/data/gallery/browser_photo_asset.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/presentation/controllers/layer_builder.dart';
import '../../../album/presentation/controllers/layer_interaction_manager.dart';
import '../../../album/presentation/controllers/photo_crop_editor.dart';
import '../../../album/presentation/controllers/photo_frame_editor.dart';
import '../../../album/presentation/controllers/text_editor_manager.dart';
import '../../../album/presentation/providers/album_edit_session_provider.dart';
import '../../../album/presentation/viewmodels/album_editor_view_model.dart';
import '../../../album/presentation/viewmodels/cover_view_model.dart';
import '../../../album/presentation/widgets/editor/decorate_panel.dart';
import '../../../album/presentation/widgets/editor/editor_bottom_menu.dart';
import '../../../album/presentation/widgets/editor/editor_context_dock.dart';
import '../../../album/presentation/widgets/editor/editor_keyboard_shortcuts.dart';
import '../../../album/presentation/widgets/editor/layer_action_panel.dart';
import '../../../album/presentation/widgets/editor/layer_manager_panel.dart';
import '../../../album/presentation/widgets/editor/page_editor_canvas.dart';
import '../../../album/presentation/widgets/editor/text_style_picker_sheet.dart';
import '../../../album/presentation/widgets/web/web_album_workspace.dart';
import '../../../album/presentation/widgets/web/web_editor_tool_dialog.dart';
import '../../../album/presentation/widgets/web/web_layer_transform_inspector.dart';
import '../../data/moments_repository.dart';
import '../../domain/moment_photo_design.dart';
import '../../domain/moment_photo_format.dart';
import '../../domain/moment_record.dart';
import '../providers/moments_providers.dart';
import '../widgets/moment_photo_design_view.dart';
import '../widgets/moment_photo_format_picker.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

/// Opens a completely separate editing session. The user's current album and
/// its undo history are never reset, checkpointed, or saved by this route.
Future<MomentPhotoDesign?> openMomentPhotoEditor(
  BuildContext context, {
  MomentPhoto? photo,
  MomentUpload? upload,
  @visibleForTesting bool? useWebWorkspace,
}) async {
  if ((photo == null) == (upload == null)) {
    throw ArgumentError('Pass exactly one photo or upload.');
  }
  final parent = ProviderScope.containerOf(context, listen: false);
  String? owner() {
    try {
      return parent.read(momentsCurrentUserIdProvider);
    } catch (_) {
      return null;
    }
  }

  final actor = owner();
  if (actor == null) throw const MomentException('로그인한 뒤 다시 꾸며 주세요.');
  final repository = parent.read(momentsRepositoryProvider);
  final result = await Navigator.of(context).push<MomentPhotoDesign>(
    snapFitRoute(
      page: ProviderScope(
        overrides: [
          albumEditorViewModelProvider.overrideWith(AlbumEditorViewModel.new),
          coverViewModelProvider.overrideWith(CoverViewModel.new),
          albumEditSyncStatusProvider.overrideWith(
            AlbumEditSyncStatusNotifier.new,
          ),
          albumEditorOwnerReaderProvider.overrideWithValue(owner),
          albumEditorOwnerChangesProvider.overrideWith(
            (_) => repository.authChanges,
          ),
        ],
        child: MomentPhotoEditorScreen(
          photoSource: photo?.storageUri ?? momentPhotoOriginalSource,
          bytes: upload?.bytes,
          aspectRatio: photo == null ? null : photo.width / photo.height,
          design: photo?.design ?? upload?.design,
          ownerId: actor,
          currentOwner: owner,
          useWebWorkspace: useWebWorkspace,
        ),
      ),
    ),
  );
  return owner() == actor ? result : null;
}

class MomentPhotoEditorScreen extends ConsumerStatefulWidget {
  const MomentPhotoEditorScreen({
    super.key,
    required this.photoSource,
    required this.ownerId,
    required this.currentOwner,
    this.bytes,
    this.aspectRatio,
    this.design,
    this.useWebWorkspace,
  });

  final String photoSource, ownerId;
  final String? Function() currentOwner;
  final Uint8List? bytes;
  final double? aspectRatio;
  final MomentPhotoDesign? design;
  @visibleForTesting
  final bool? useWebWorkspace;

  @override
  ConsumerState<MomentPhotoEditorScreen> createState() =>
      _MomentPhotoEditorScreenState();
}

class _MomentPhotoEditorScreenState
    extends ConsumerState<MomentPhotoEditorScreen> {
  final _canvasKey = GlobalKey();
  late final LayerInteractionManager _interaction;
  late Future<void> _ready;
  late Size _canvas;
  BrowserPhotoAsset? _photoAsset;
  MomentPhotoDesign? _formatBase;
  String? _lastFormatJson;
  CoverSize? _selectedFormat;
  String? _initialJson;
  bool _allowPop = false,
      _toolOpen = false,
      _finishing = false,
      _saving = false;
  bool _detailsOpen = false;
  EditorMode _currentMode = EditorMode.none;
  bool _ownerExitQueued = false;
  List<LayerModel> _lastLayers = const [];

  AlbumEditorViewModel get _vm =>
      ref.read(albumEditorViewModelProvider.notifier);
  bool get _web => widget.useWebWorkspace ?? kIsWeb;
  bool get _current => mounted && widget.currentOwner() == widget.ownerId;

  @override
  void initState() {
    super.initState();
    _canvas =
        widget.design?.canvasSize ?? coverCanvasBaseSize(defaultCoverSize);
    _interaction = LayerInteractionManager(
      ref: ref,
      coverKey: _canvasKey,
      setState: (change) {
        if (mounted) setState(change);
      },
      getCoverSize: () => _canvas,
      onEditText: (layer) => _tool(() => _editText(layer)),
      onLayerTap: (_) {},
      enableWebTransforms: _web,
      enableOverlapSelection: false,
      canDeleteLayer: (layer) => layer.type != LayerType.image,
    );
    _ready = _load();
  }

  Future<void> _load() async {
    await ref.read(albumEditorViewModelProvider.future);
    await DocumentFonts.ensure({'NotoSans', ...?widget.design?.fontFamilies});
    BrowserPhotoAsset? asset;
    if (widget.bytes != null) {
      asset = await prepareMomentEditorPhoto(widget.bytes!, id: 'editor');
    }
    if (!_current) return;
    _photoAsset = asset;
    final ratio = widget.aspectRatio;
    final design =
        widget.design ??
        newMomentPhotoDesign(
          photoSize: asset != null
              ? Size(asset.width.toDouble(), asset.height.toDouble())
              : Size(
                  ratio != null && ratio.isFinite && ratio > 0 ? ratio : 1,
                  1,
                ),
          photoSource: widget.photoSource,
        );
    _canvas = design.canvasSize;
    _selectedFormat = momentCoverForDesign(design);
    final layers = design.layersForPhoto(widget.photoSource);
    _vm.startSinglePageDraft(
      layers: momentDesignLayersWithPhoto(layers, widget.photoSource, asset),
      canvasSize: _canvas,
      backgroundColor: design.backgroundColor.toARGB32(),
    );
    _initialJson = jsonEncode(_design().toJson());
    _formatBase = _design();
    _lastFormatJson = _initialJson;
    if (mounted) setState(() {});
  }

  MomentPhotoDesign _design() => MomentPhotoDesign.fromLayers(
    canvasSize: _canvas,
    backgroundColor: Color(_vm.currentPage?.backgroundColor ?? 0xffffffff),
    layers: _interaction
        .sortByZ(_vm.layers)
        .indexed
        .map((entry) => entry.$2.copyWith(zIndex: entry.$1))
        .toList(),
    photoSource: widget.photoSource,
  );

  bool get _changed {
    if (_initialJson == null) return false;
    try {
      return jsonEncode(_design().toJson()) != _initialJson;
    } on FormatException {
      return true;
    }
  }

  String get _formatLabel => _selectedFormat?.displayName ?? '기존 사진 비율 유지';

  Future<void> _selectFormat() => _tool(() async {
    if (_interaction.isInteractingNow) return;
    final cover = await showMomentPhotoFormatPicker(
      context,
      selectedCover: _selectedFormat,
      title: '이 사진의 앨범 규격',
      description: '사진과 꾸밈의 비율을 유지한 채 새 규격 안에 맞춰요. 원본 사진은 바뀌지 않아요.',
    );
    if (!_current || cover == null) return;
    final current = _design();
    final currentJson = jsonEncode(current.toJson());
    // Consecutive format choices always start from the same artwork. A real
    // content edit establishes a new base, rather than repeatedly fitting the
    // margins introduced by each previous format choice.
    if (_formatBase == null || currentJson != _lastFormatJson) {
      _formatBase = current;
    }
    final next = resizeMomentPhotoDesign(_formatBase!, cover);
    if (jsonEncode(next.toJson()) == currentJson) return;
    final changed = _vm.resizeSinglePageDraft(
      layers: momentDesignLayersWithPhoto(
        next.layersForPhoto(widget.photoSource),
        widget.photoSource,
        _photoAsset,
      ),
      canvasSize: next.canvasSize,
    );
    if (!changed || !_current) return;
    _interaction.resetForPageChange();
    setState(() {
      _canvas = next.canvasSize;
      _selectedFormat = cover;
      _lastFormatJson = jsonEncode(_design().toJson());
    });
  });

  Widget _formatControl() => OutlinedButton.icon(
    key: const ValueKey('moment-editor-format'),
    onPressed:
        _initialJson == null ||
            _toolOpen ||
            _saving ||
            _finishing ||
            _detailsOpen
        ? null
        : _selectFormat,
    icon: const ExperienceIcon('Maximize2', size: 18),
    label: Text(_formatLabel),
    style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
  );

  void _syncCanvas(AlbumEditorState? state) {
    final canvas = state?.coverCanvasSize;
    if (canvas == null || canvas == Size.zero || canvas == _canvas) return;
    _canvas = canvas;
    _selectedFormat = momentCoverForDesign(_design());
  }

  @override
  void dispose() {
    _interaction.dispose();
    super.dispose();
  }

  void _exitForOwnerChange() {
    if (_ownerExitQueued) return;
    _ownerExitQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final navigator = route?.navigator;
      // Tool dialogs are opened only from this route. Leave a different,
      // unrelated route alone if the editor was not opening one of its tools.
      if ((_toolOpen || _detailsOpen) && route != null && navigator != null) {
        navigator.popUntil((candidate) => identical(candidate, route));
      }
      if (route?.isActive == true) navigator?.removeRoute(route!);
    });
  }

  Future<void> _close() async {
    if (_finishing || _toolOpen || _detailsOpen || _saving) return;
    if (!_current) {
      _exitForOwnerChange();
      return;
    }
    if (_changed) {
      setState(() => _toolOpen = true);
      bool? discard;
      try {
        discard = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('꾸미기를 마칠까요?'),
            content: const Text('아직 적용하지 않은 꾸미기가 있어요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('계속 꾸미기'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('적용하지 않고 나가기'),
              ),
            ],
          ),
        );
      } finally {
        if (mounted) setState(() => _toolOpen = false);
      }
      if (discard != true || !_current) return;
    }
    _finish();
  }

  void _finish([MomentPhotoDesign? design]) {
    if (!mounted || _finishing) return;
    setState(() {
      _finishing = true;
      _allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(design);
    });
  }

  Future<void> _save() async {
    if (!_current ||
        _finishing ||
        _toolOpen ||
        _detailsOpen ||
        _saving ||
        _interaction.isInteractingNow) {
      return;
    }
    setState(() => _saving = true);
    try {
      final design = _design();
      await DocumentFonts.ensure(design.fontFamilies);
      if (_current) _finish(design);
    } catch (error) {
      if (_current) _message('꾸민 내용을 확인하지 못했어요. 잠시 후 다시 적용해 주세요.');
    } finally {
      if (mounted && !_finishing) setState(() => _saving = false);
    }
  }

  void _message(String message) => context.showSnack(message);

  bool get _canAdd {
    if (_vm.layers.length < MomentPhotoDesign.maximumLayers) return true;
    _message('꾸미기 요소는 한 장에 최대 40개까지 넣을 수 있어요.');
    return false;
  }

  Future<void> _tool(Future<void> Function() action) async {
    if (!_current ||
        _toolOpen ||
        _finishing ||
        _saving ||
        ModalRoute.of(context)?.isCurrent != true)
      return;
    setState(() => _toolOpen = true);
    try {
      await action();
    } catch (_) {
      if (_current) _message('꾸미기 도구를 열지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _toolOpen = false);
    }
  }

  Future<void> _editText([LayerModel? layer]) async {
    if (layer == null && !_canAdd) return;
    final session = _vm.editSessionIdentity;
    final page = _vm.currentPage?.id;
    Widget overlay(BuildContext sheet) => DocumentFontGate(
      builder: (_) => EditTextOverlay(
        initialText: layer?.text ?? '',
        initialStyle:
            layer?.textStyle ??
            const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
        initialMode: layer?.textStyleType,
        initialBubbleColor: layer?.bubbleColor,
        initialAlign: layer?.textAlign ?? TextAlign.center,
        onCancel: () => Navigator.pop(sheet),
        onSubmit: (text, style, mode, color, align) {
          if (!_current ||
              !identical(session, _vm.editSessionIdentity) ||
              page != _vm.currentPage?.id ||
              text.trim().isEmpty)
            return;
          if (layer == null) {
            if (!_canAdd) return;
            _vm.addTextLayer(
              text,
              style: style,
              mode: mode,
              color: color,
              textAlign: align,
              canvasSize: _canvas,
            );
            _interaction.setSelectedLayer(_vm.layers.last.id);
          } else {
            final current = _vm.findLayerById(layer.id);
            if (current == null) return;
            _vm.updateLayer(
              current.copyWith(
                text: text,
                textStyle: style,
                textStyleType: mode,
                bubbleColor: color,
                textAlign: align,
              ),
            );
          }
          Navigator.pop(sheet);
        },
      ),
    );
    FocusScope.of(context).unfocus();
    if (_web) {
      await showWebAwareDialog<void>(
        context: context,
        useRootNavigator: false,
        maxWidth: 1100,
        maxHeight: 760,
        builder: overlay,
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        routeSettings: editorModalRouteSettings(context),
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 960),
        backgroundColor: Colors.transparent,
        builder: overlay,
      );
    }
  }

  LayerBuilder get _builder => LayerBuilder(_interaction, () => _canvas);

  Future<void> _decorateLayer(LayerModel layer) async {
    if (layer.type == LayerType.image) {
      await editPhotoFrame(context, ref, layer, layerBuilder: _builder);
      return;
    }
    final key = await TextStylePickerSheet.show(
      context,
      currentKey: _vm.findLayerById(layer.id)?.textBackground ?? '',
    );
    if (key != null && _current && _vm.findLayerById(layer.id) != null) {
      _vm.updateTextStyle(layer.id, key);
    }
  }

  Future<void> _showPanel(Widget panel) async {
    final scope = ProviderScope.containerOf(context, listen: false);
    Widget scoped(BuildContext _) =>
        UncontrolledProviderScope(container: scope, child: panel);
    if (_web) {
      await showWebAwareDialog<void>(
        context: context,
        useRootNavigator: false,
        maxWidth: 1100,
        maxHeight: 760,
        builder: scoped,
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        routeSettings: editorModalRouteSettings(context),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: scoped,
      );
    }
  }

  bool _portableSticker(String value) {
    if (!value.contains(':')) return true; // Emoji are ordinary editable text.
    if (!value.startsWith('deco:')) return false;
    final style = value.substring('deco:'.length).split('@').first;
    return MomentPhotoDesign.freeStickerKeys.contains(style);
  }

  void _modeChanged(EditorMode mode) {
    _tool(() async {
      setState(() => _currentMode = mode);
      try {
        if (_web && mode != EditorMode.text && mode != EditorMode.none) {
          await _openWebTool(mode);
          return;
        }
        switch (mode) {
          case EditorMode.text:
            await _editText();
          case EditorMode.sticker:
            if (!_canAdd) return;
            await _showPanel(
              DecoratePanel(
                mode: DecorateSheetMode.sticker,
                canvasSize: _canvas,
                isStickerAvailable: _portableSticker,
                availabilityNotice: '피드 사진에는 기본 장식과 이모지를 사용할 수 있어요.',
                canApply: () => _current && _canAdd,
                onInserted: (layer) => _interaction.setSelectedLayer(layer.id),
              ),
            );
          case EditorMode.backgroundColor:
            await _showPanel(
              DecoratePanel(
                mode: DecorateSheetMode.backgroundColor,
                canvasSize: _canvas,
                canApply: () => _current,
              ),
            );
          case EditorMode.layer:
            await _showPanel(
              Consumer(
                builder: (context, sheetRef, _) {
                  final layers =
                      sheetRef
                          .watch(albumEditorViewModelProvider)
                          .value
                          ?.layers ??
                      const <LayerModel>[];
                  return LayerManagerPanel(
                    layers: layers,
                    interaction: _interaction,
                  );
                },
              ),
            );
          case EditorMode.template:
          case EditorMode.layout:
            await _singlePhotoNotice(
              '앨범에서 배치하기',
              '피드는 사진 한 장씩 꾸미는 공간이에요. 여러 사진을 배치하는 템플릿과 레이아웃은 앨범으로 만들 때 사용할 수 있어요. 지금 꾸민 글과 장식은 그대로 이어져요.',
            );
          case EditorMode.none:
            break;
        }
      } finally {
        if (mounted) setState(() => _currentMode = EditorMode.none);
      }
    });
  }

  Widget _toolPanel(EditorMode mode, VoidCallback close) => switch (mode) {
    EditorMode.sticker => DecoratePanel(
      mode: DecorateSheetMode.sticker,
      canvasSize: _canvas,
      isStickerAvailable: _portableSticker,
      availabilityNotice: '피드 사진에는 기본 장식과 이모지를 사용할 수 있어요.',
      canApply: () => _current && _canAdd,
      onInserted: (layer) => _interaction.setSelectedLayer(layer.id),
      onClose: close,
    ),
    EditorMode.backgroundColor => DecoratePanel(
      mode: DecorateSheetMode.backgroundColor,
      canvasSize: _canvas,
      canApply: () => _current,
      onClose: close,
    ),
    EditorMode.layer => Consumer(
      builder: (context, sheetRef, _) => LayerManagerPanel(
        layers:
            sheetRef.watch(albumEditorViewModelProvider).value?.layers ??
            const <LayerModel>[],
        interaction: _interaction,
        showHandle: false,
        onLayerSelected: (_) => close(),
      ),
    ),
    EditorMode.template || EditorMode.layout => Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExperienceIcon(
              'Bookmark',
              size: 36,
              color: WebPalette.of(context).muted,
            ),
            const SizedBox(height: 16),
            Text(
              '앨범에서 배치하기',
              style: ExperienceFormStyle.text(
                context,
                18,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '피드는 사진 한 장씩 꾸미는 공간이에요. 여러 사진을 배치하는 템플릿과 레이아웃은 앨범으로 만들 때 사용할 수 있어요. 지금 꾸민 글과 장식은 그대로 이어져요.',
              textAlign: TextAlign.center,
              style: ExperienceFormStyle.text(context, 14, secondary: true),
            ),
          ],
        ),
      ),
    ),
    _ => const SizedBox.shrink(),
  };

  Future<void> _openWebTool(EditorMode mode) async {
    final scope = ProviderScope.containerOf(context, listen: false);
    final session = _vm.editSessionIdentity;
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      routeSettings: editorModalRouteSettings(context),
      builder: (_) => UncontrolledProviderScope(
        container: scope,
        child: WebEditorToolDialog(
          initialMode: mode,
          onModeChanged: (mode) {
            if (mounted) setState(() => _currentMode = mode);
          },
          panelBuilder: (_, mode, close) =>
              _current && identical(session, _vm.editSessionIdentity)
              ? _toolPanel(mode, close)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _canvasArea(List<LayerModel> layers, {bool web = false}) => Padding(
    padding: web
        ? const EdgeInsets.fromLTRB(24, 4, 24, 12)
        : const EdgeInsets.fromLTRB(8, 4, 8, 12),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final scale = math.min(
          math.max(1.0, bounds.maxWidth - 16) / _canvas.width,
          math.max(1.0, bounds.maxHeight - 16) / _canvas.height,
        );
        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _interaction.clearSelection,
            child: PageEditorCanvas(
              canvasKey: _canvasKey,
              canvasW: _canvas.width * scale,
              canvasH: _canvas.height * scale,
              layers: layers,
              interaction: _interaction,
              flatPresentation: web,
              logicalCanvasSize: _canvas,
              layerBuilder: _builder,
              onCanvasSizeChanged: (_) {},
              backgroundColor: Color(
                _vm.currentPage?.backgroundColor ?? 0xffffffff,
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _webWorkspace(AlbumEditorState? editor, List<LayerModel> layers) {
    final selected = layers
        .where((layer) => layer.id == _interaction.selectedLayerId)
        .firstOrNull;
    final preview = LayerBuilder(
      LayerInteractionManager.printPreview(() => _canvas),
      () => _canvas,
    );
    Widget rail({bool horizontal = false}) => WebAlbumPageRail(
      pages: _vm.pages,
      selectedIndex: 0,
      cover: _vm.selectedCover,
      theme: _vm.selectedTheme,
      previewBuilder: preview,
      onSelected: (_) {},
      horizontal: horizontal,
      includesCover: false,
      logicalCanvasSize: _canvas,
    );
    WebAlbumEditorTool tool(String label, IconData icon, EditorMode mode) =>
        WebAlbumEditorTool(
          label: label,
          icon: icon,
          selected: _currentMode == mode,
          onPressed: () => _modeChanged(mode),
          opensProperties: false,
        );
    return WebAlbumEditorWorkspace(
      workspaceTitle: '사진 편집',
      title: '한 장 꾸미기',
      pageLabel: '피드 사진',
      specification: _formatLabel,
      documentSubtitle: '피드 사진 · 꾸민 글과 장식을 앨범으로 이어서',
      saveStatusLabel: _saving
          ? '꾸민 사진을 적용하는 중'
          : _changed
          ? '아직 적용하지 않은 꾸미기'
          : '원본 사진을 유지하며 편집해요',
      hasUnsavedChanges: _changed,
      isPersisted: false,
      isSaving: _saving,
      selectedLayerId: _interaction.selectedLayerId,
      onBack: _close,
      onSave: _save,
      saveActionLabel: '적용',
      onUndo: editor?.canUndo == true ? _undo : null,
      onRedo: editor?.canRedo == true ? _redo : null,
      pageRail: rail(),
      compactPageRail: rail(horizontal: true),
      canvas: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _formatControl(),
          ),
          Expanded(child: _canvasArea(layers, web: true)),
        ],
      ),
      properties: ColoredBox(
        color: WebPalette.of(context).surface,
        child: selected == null
            ? SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 32,
                        color: WebPalette.of(context).muted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '사진이나 글을 선택해 주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: WebPalette.of(context).ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '사진 자르기와 글 편집을 바로 할 수 있어요.\n수치 입력은 고급 조정에서 확인하세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: WebPalette.of(context).muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                key: const ValueKey('web-editor-properties-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: IgnorePointer(
                        ignoring: _toolOpen || _saving,
                        child: LayerActionPanel(
                          layers: layers,
                          interaction: _interaction,
                          textEditor: TextEditorManager(context, _vm),
                          onEditText: (layer) => _tool(() => _editText(layer)),
                          onRefresh: () {
                            if (mounted) setState(() {});
                          },
                          onOpenGallery: (_) async => _photoSelectionNotice(),
                          onOpenPhotoCrop: (layer) => _tool(() async {
                            await editPhotoCrop(
                              context,
                              ref,
                              layer,
                              layerBuilder: _builder,
                              logicalCanvasSize: _canvas,
                            );
                          }),
                          onOpenDecorateSheet: (layer) =>
                              _tool(() => _decorateLayer(layer)),
                          showLabels: true,
                        ),
                      ),
                    ),
                    WebLayerTransformInspector(
                      key: ValueKey('transform-${selected.id}'),
                      layer: _interaction.currentTransformFor(selected),
                      baseSize: _interaction.baseSizeFor(selected),
                      logicalCanvasSize: _canvas,
                      positionBounds: Rect.fromLTRB(
                        -4 * _canvas.width,
                        -4 * _canvas.height,
                        4 * _canvas.width,
                        4 * _canvas.height,
                      ),
                      enabled: !_toolOpen && !_saving,
                      onChanged: ({x, y, width, height, rotation}) =>
                          _interaction.updateTransform(
                            selected,
                            x: x,
                            y: y,
                            width: width,
                            height: height,
                            rotation: rotation,
                          ),
                    ),
                  ],
                ),
              ),
      ),
      tools: [
        WebAlbumEditorTool(
          label: '사진 추가',
          icon: Icons.add_photo_alternate_outlined,
          onPressed: _photoSelectionNotice,
          opensProperties: false,
        ),
        tool('텍스트', Icons.text_fields, EditorMode.text),
        tool('겹침 순서', Icons.layers_outlined, EditorMode.layer),
        tool('레이아웃', Icons.dashboard_outlined, EditorMode.layout),
        tool('템플릿', Icons.grid_view_outlined, EditorMode.template),
        tool('꾸미기', Icons.interests_outlined, EditorMode.sticker),
        tool('배경', Icons.palette_outlined, EditorMode.backgroundColor),
      ],
    );
  }

  Future<void> _singlePhotoNotice(String title, String message) =>
      showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('확인'),
            ),
          ],
        ),
      );

  void _photoSelectionNotice() => _tool(
    () => _singlePhotoNotice(
      '사진 선택은 피드에서',
      '원본을 유지하며 이 사진을 꾸미고 있어요. 다른 사진을 추가하거나 바꾸려면 적용한 뒤 피드 작성 화면에서 선택해 주세요.',
    ),
  );

  void _undo() {
    _vm.undo();
    _syncCanvas(ref.read(albumEditorViewModelProvider).value);
    _interaction.resetForPageChange();
  }

  void _redo() {
    _vm.redo();
    _syncCanvas(ref.read(albumEditorViewModelProvider).value);
    _interaction.resetForPageChange();
  }

  void _syncLayers(List<LayerModel> layers) {
    // Freezed may expose a fresh unmodifiable view for the same layer list.
    // Compare its elements, otherwise the z-order callback schedules a new
    // frame forever while the document itself has not changed.
    if (listEquals(_lastLayers, layers)) return;
    final snapshot = List<LayerModel>.of(layers, growable: false);
    _lastLayers = snapshot;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_lastLayers, snapshot)) return;
      _interaction.syncLayers(snapshot);
      final ordered = List<LayerModel>.of(snapshot)
        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
      _interaction.syncZOrder(ordered);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(momentsCurrentUserIdProvider, (_, owner) {
      if (owner != widget.ownerId) _exitForOwnerChange();
    });
    return PopScope<MomentPhotoDesign>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: EditorKeyboardShortcuts(
        enabled:
            _initialJson != null &&
            !_toolOpen &&
            !_detailsOpen &&
            !_saving &&
            !_finishing,
        onDelete: _interaction.deleteSelected,
        onUndo: _undo,
        onRedo: _redo,
        onSave: _save,
        onEscape: _interaction.clearSelection,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          appBar: _web
              ? null
              : AppBar(
                  toolbarHeight: 52,
                  backgroundColor: AlbumStageStyle.top(context),
                  surfaceTintColor: Colors.transparent,
                  systemOverlayStyle: AlbumStageStyle.overlay(context),
                  elevation: 0,
                  centerTitle: true,
                  leading: IconButton(
                    tooltip: '꾸미기 닫기',
                    onPressed: _close,
                    icon: const ExperienceIcon('ArrowLeft', size: 22),
                  ),
                  title: Text(
                    '한 장 꾸미기',
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      weight: FontWeight.w600,
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 12,
                        top: 4,
                        bottom: 4,
                      ),
                      child: FilledButton.icon(
                        key: const ValueKey('moment-photo-design-apply'),
                        onPressed:
                            _initialJson == null ||
                                _toolOpen ||
                                _detailsOpen ||
                                _finishing ||
                                _saving
                            ? null
                            : _save,
                        style: ExperienceFormStyle.primary(context).copyWith(
                          minimumSize: const WidgetStatePropertyAll(
                            Size(76, 48),
                          ),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 12),
                          ),
                          textStyle: WidgetStatePropertyAll(
                            ExperienceFormStyle.text(
                              context,
                              13,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const ExperienceIcon('Check', size: 17),
                        label: const Text('적용'),
                      ),
                    ),
                  ],
                ),
          body: Container(
            decoration: BoxDecoration(
              gradient: AlbumStageStyle.gradient(context),
            ),
            child: FutureBuilder<void>(
              future: _ready,
              builder: (context, ready) {
                if (ready.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (ready.hasError) {
                  assert(() {
                    debugPrint(
                      'Moment photo editor preparation failed: '
                      '${ready.error}\n${ready.stackTrace}',
                    );
                    return true;
                  }());
                  return Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _ready = _load()),
                      icon: const ExperienceIcon('RefreshCw'),
                      label: const Text('꾸미기 다시 열기'),
                    ),
                  );
                }
                if (!_current) {
                  _exitForOwnerChange();
                  return const SizedBox.shrink();
                }
                final editor = ref.watch(albumEditorViewModelProvider).value;
                _syncCanvas(editor);
                final layers = editor?.layers ?? const <LayerModel>[];
                _syncLayers(layers);
                if (_web) return _webWorkspace(editor, layers);
                return SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: _formatControl(),
                      ),
                      Expanded(child: _canvasArea(layers)),
                      EditorContextDock(
                        layers: layers,
                        interaction: _interaction,
                        currentMode: _currentMode,
                        enabled: !_toolOpen && !_saving && !_finishing,
                        canUndo: editor?.canUndo == true,
                        canRedo: editor?.canRedo == true,
                        onUndo: _undo,
                        onRedo: _redo,
                        onModeChanged: _modeChanged,
                        onAddPhoto: _photoSelectionNotice,
                        onOpenGallery: (_) async => _photoSelectionNotice(),
                        onOpenCrop: (layer) => _tool(() async {
                          await editPhotoCrop(
                            context,
                            ref,
                            layer,
                            layerBuilder: _builder,
                            logicalCanvasSize: _canvas,
                          );
                        }),
                        onOpenDecorate: (layer) =>
                            _tool(() => _decorateLayer(layer)),
                        onEditText: (layer) => _tool(() => _editText(layer)),
                        onDetailsOpenChanged: (open) {
                          if (mounted) setState(() => _detailsOpen = open);
                        },
                        onRefresh: () {
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
