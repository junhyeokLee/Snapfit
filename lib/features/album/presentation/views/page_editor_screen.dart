import '../../../../core/fonts/document_font_gate.dart';
import '../../../../core/fonts/document_fonts.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../shared/widgets/editor_modal_scope.dart';
import '../../data/album_creation_draft_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/layer.dart';
import '../../domain/entities/album_save_progress.dart';
import '../../domain/entities/album_creation_draft.dart';
import '../../domain/entities/album_edit_failure.dart';
import '../../data/gallery/browser_photo_asset.dart';
import '../providers/album_edit_session_provider.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart' show SnapFitRadius;
import '../../../../core/constants/cover_size.dart';
import '../../../../shared/widgets/album_stage_style.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../core/navigation/web_unsaved_work_guard.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/web/web_design.dart';
import '../controllers/text_editor_manager.dart';
import '../controllers/layer_interaction_manager.dart';
import '../controllers/layer_builder.dart';
import '../widgets/editor/layer_action_panel.dart';
import '../widgets/editor/page_editor_canvas.dart';
import '../widgets/reader/album_reader_page_content.dart';
import '../widgets/editor/page_list_selector.dart';
import '../widgets/editor/editor_bottom_menu.dart';
import '../widgets/editor/editor_context_dock.dart';
import '../widgets/editor/editor_photo_fill_screen.dart';
import '../widgets/create_flow/template_photo_fill_step.dart';
import '../widgets/editor/editor_overlap_picker.dart';
import '../widgets/editor/editor_keyboard_shortcuts.dart';
import '../widgets/editor/decorate_panel.dart';
import '../widgets/editor/edit_cover.dart';
import '../widgets/editor/layer_manager_panel.dart';
import '../widgets/editor/template_selection_panel.dart';
import '../widgets/editor/design_template_panel.dart';
import '../widgets/editor/text_style_picker_sheet.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/home_view_model.dart';
import '../controllers/toolbar_action_handler.dart';
import '../controllers/store_material_insertion.dart';
import '../controllers/photo_crop_editor.dart';
import '../controllers/photo_frame_editor.dart';
import '../widgets/editor/page_editor_overlays.dart';
import '../widgets/web/web_album_workspace.dart';
import '../widgets/web/web_layer_transform_inspector.dart';
import '../widgets/web/web_editor_tool_dialog.dart';
import '../../data/api/storage_service.dart';
import '../utils/album_save_error_message.dart';
import '../utils/album_progress.dart';
import '../utils/saved_album_experience.dart';
import 'album_saved_experience_screen.dart';
import '../../../point_shop/data/point_shop_provider.dart';

class _PageEditorEntranceReveal extends StatelessWidget {
  final Widget child;
  final bool includeScale;
  final bool disabled;

  const _PageEditorEntranceReveal({
    super.key,
    required this.child,
    this.includeScale = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (disabled) return child;
    const duration = Duration(milliseconds: 360);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final t = value;
        final scale = includeScale ? 0.96 + (0.04 * t) : 1.0;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

class _PageEditorPageTurnReveal extends StatelessWidget {
  const _PageEditorPageTurnReveal({
    super.key,
    required this.forward,
    required this.child,
    this.disabled = false,
  });

  final bool forward;
  final Widget child;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    if (disabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: SnapFitMotion.pageTurn,
      curve: SnapFitMotion.pageTurnCurve,
      builder: (context, value, child) {
        final direction = forward ? 1.0 : -1.0;
        final t = value.clamp(0.0, 1.0);
        final settleT = ((t - 0.72) / 0.28).clamp(0.0, 1.0);
        final settlePulse = math.sin(settleT * math.pi);
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..translate(18.0 * direction * (1 - t), 0.0)
          ..rotateY(direction * 0.16 * (1 - t));
        return Opacity(
          key: const Key('pageEditorPageTurnOpacity'),
          opacity: (0.18 + t * 0.82).clamp(0.0, 1.0),
          child: Transform(
            key: const Key('pageEditorPageTurnReveal'),
            alignment: Alignment.center,
            transform: matrix,
            child: Transform.scale(
              key: const Key('pageEditorPageSettleScale'),
              scale: 0.965 + (0.035 * t) + (0.006 * settlePulse),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: (0.16 * (1 - t) + 0.045 * settlePulse).clamp(
                          0.0,
                          0.18,
                        ),
                      ),
                      blurRadius: 18 + 10 * (1 - t) + 8 * settlePulse,
                      offset: Offset(0, 8 + 6 * (1 - t) + 3 * settlePulse),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    child ?? const SizedBox.shrink(),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: forward ? 0 : null,
                      left: forward ? null : 0,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.18 * (1 - t),
                          child: Container(
                            key: const Key('pageEditorPageEdgeHighlight'),
                            width: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class PageEditorScreen extends ConsumerStatefulWidget {
  final bool _fontsPrepared;

  /// Initial document page; 0 selects the cover. Null keeps the current page.
  final int? initialPageIndex;

  /// Select this photo after opening its page; ignored for absent/non-photo IDs.
  final String? initialSelectedLayerId;
  final String? initialMaterialKey;

  const PageEditorScreen({
    super.key,
    this.initialPageIndex,
    this.initialSelectedLayerId,
    this.initialMaterialKey,
    this.returnToPreviousOnSave = false,
    this.creationDraftId,
    this.creationDraftOwner,
    this.onePageGoal = false,
    this.initialPhotoFillSession,
  }) : _fontsPrepared = false;

  final bool returnToPreviousOnSave;
  final String? creationDraftId;
  final String? creationDraftOwner;

  /// Home's small, explicit goal uses the same editor and durable album save.
  /// Ordinary album editing retains its existing save destination.
  final bool onePageGoal;
  final TemplatePhotoFillSession? initialPhotoFillSession;

  PageEditorScreen._withFontsReady(PageEditorScreen original)
    : _fontsPrepared = true,
      initialPageIndex = original.initialPageIndex,
      initialSelectedLayerId = original.initialSelectedLayerId,
      initialMaterialKey = original.initialMaterialKey,
      returnToPreviousOnSave = original.returnToPreviousOnSave,
      creationDraftId = original.creationDraftId,
      creationDraftOwner = original.creationDraftOwner,
      onePageGoal = original.onePageGoal,
      initialPhotoFillSession = original.initialPhotoFillSession;

  @override
  ConsumerState<PageEditorScreen> createState() =>
      // ignore: no_logic_in_create_state — intentional: selects a different State subtype for deferred font loading
      DocumentFonts.deferred && !_fontsPrepared
      ? DocumentFontEntryState<PageEditorScreen>(
          PageEditorScreen._withFontsReady,
        )
      : _PageEditorScreenState();
}

class _PageEditorScreenState extends ConsumerState<PageEditorScreen>
    with WidgetsBindingObserver {
  final GlobalKey<EditCoverState> _coverEditorKey = GlobalKey<EditCoverState>();
  final GlobalKey _canvasKey = GlobalKey();
  Size _canvasSize = Size.zero;

  late final LayerInteractionManager _interaction;
  late final LayerBuilder _layerBuilder;
  late final ToolbarActionHandler _toolbarActionHandler;

  EditorMode _currentMode = EditorMode.none; // Current bottom panel mode
  bool _webToolDialogOpen = false;
  bool _photoFillOpen = false;
  final _photoFillQueue = TemplatePhotoFillSession();
  TemplatePhotoFillSession _entryPhotoFillQueue = TemplatePhotoFillSession();
  Object? _photoFillSessionIdentity;
  String? _photoFillOwner;
  int? _photoFillAlbumId;
  int _photoFillQueueRevision = 0;
  int _savedPhotoFillQueueRevision = 0;

  // 저장 진행률 상태
  bool _isSaving = false;
  AlbumSaveProgress _saveStatus = const AlbumSaveProgress(
    AlbumSavePhase.preparing,
  );
  AlbumEditCheckpoint? _entryCheckpoint;
  bool _exitPromptOpen = false;
  Timer? _editorHintTimer;
  Timer? _remoteCheckTimer;
  int? _lastSyncedPageIndex;
  int? _initialSelectionPageIndex;
  String? _pendingInitialSelectedLayerId;
  bool _pendingOnePagePhotoPrompt = false;
  bool _onePageChoiceOpen = false;
  String? _lastLayerSyncSignature;
  bool _showEditorHint = false;
  int _pageTurnNonce = 0;
  bool _pageTurnForward = true;
  Future<void> _draftWrites = Future.value();
  int _pendingDraftWrites = 0;
  bool _draftWriteFailed = false;
  DateTime? _lastDraftSavedAt;

  bool get _hasCreationDraft =>
      widget.creationDraftId != null && widget.creationDraftOwner != null;

  bool get _hasUnsavedPhotoFillQueue {
    if (!_hasCreationDraft ||
        _photoFillQueueRevision == _savedPhotoFillQueueRevision)
      return false;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    return identical(_photoFillSessionIdentity, vm.editSessionIdentity) &&
        _photoFillAlbumId == vm.editingAlbumId &&
        _photoFillOwner == ref.read(albumEditorOwnerReaderProvider)();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _editorHintTimer?.cancel();
    _remoteCheckTimer?.cancel();
    _interaction.dispose();
    _photoFillQueue.reset();
    _entryPhotoFillQueue.reset();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ScreenLogger.enter(
      'PageEditorScreen',
      widget.initialPageIndex != null
          ? '내지 페이지 편집 (페이지 ${widget.initialPageIndex})'
          : '내지 페이지 편집',
    );
    _interaction = LayerInteractionManager(
      ref: ref,
      coverKey: _canvasKey,
      setState: setState,
      // [Inner Page Fix] 내지는 항상 300x400 논리적 좌표계를 사용함.
      // 인터랙션 매니저가 스냅 가이드나 좌표 계산 시 이 기준을 따르게 함.
      getCoverSize: () {
        final currentVm = ref.read(albumEditorViewModelProvider.notifier);
        final aspect = currentVm.selectedCover.ratio;
        if (currentVm.currentPageIndex == 0) {
          // [10단계 Fix] 커버 편집 시에도 500xH 논리 좌표계를 사용함
          return Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
        }
        // 페이지도 커버와 동일한 500xH 논리 좌표계를 사용
        return Size(kCoverReferenceWidth, kCoverReferenceWidth / aspect);
      },
      onEditText: (layer) {
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        TextEditorManager(context, vm).openForExisting(layer);
      },
      onLayerTap: (layer) => setState(() {}),
      onTapPlaceholder: (layer) => _openGalleryForPlaceholder(layer),
      enableWebTransforms: kIsWeb,
      enableOverlapSelection: !kIsWeb,
    );
    _layerBuilder = LayerBuilder(_interaction, () => _canvasSize);
    _toolbarActionHandler = ToolbarActionHandler(context, ref);
    // 내지 페이지만 편집: initialPageIndex가 있으면 즉시 해당 페이지로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      final idx = widget.initialPageIndex ?? vm.currentPageIndex;
      vm.loadPendingEditAlbumIfNeeded(
        Size(
          kCoverReferenceWidth,
          kCoverReferenceWidth / vm.selectedCover.ratio,
        ),
      );
      _entryCheckpoint = vm.captureEditCheckpoint();
      _bindPhotoFillQueue(vm, initial: widget.initialPhotoFillSession);
      _entryPhotoFillQueue = _copyPhotoFillQueue(_photoFillQueue);
      _startRemoteChecks();
      final maxIdx = vm.pages.length - 1;
      final pageIndex = idx.clamp(0, maxIdx > 0 ? maxIdx : 0);
      vm.goToPage(pageIndex);
      _initialSelectionPageIndex = pageIndex;
      _pendingInitialSelectedLayerId = idx == pageIndex
          ? widget.initialSelectedLayerId
          : null;
      _pendingOnePagePhotoPrompt = widget.onePageGoal;
      setState(() {});
      if (widget.initialMaterialKey != null) {
        unawaited(_insertInitialMaterial(widget.initialMaterialKey!));
      }
    });
  }

  void _selectInitialPhotoIfReady() {
    final id = _pendingInitialSelectedLayerId;
    final targetPage = _initialSelectionPageIndex;
    if (targetPage == null || (id == null && !_pendingOnePagePhotoPrompt))
      return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (_lastSyncedPageIndex != targetPage ||
        vm.currentPageIndex != targetPage) {
      return;
    }
    _pendingInitialSelectedLayerId = null;
    _initialSelectionPageIndex = null;
    final prompt = _pendingOnePagePhotoPrompt;
    _pendingOnePagePhotoPrompt = false;
    final photo = vm.currentPage?.layers
        .where((layer) => layer.id == id && layer.type == LayerType.image)
        .firstOrNull;
    if (photo != null) _interaction.setSelectedLayer(photo.id);
    if (!prompt || _isSaving || ModalRoute.of(context)?.isCurrent == false)
      return;
    if (photo != null) {
      unawaited(_openGalleryForPlaceholder(photo));
    } else if (vm.currentPage?.layers.isEmpty == true) {
      unawaited(_toolbarActionHandler.addPhoto());
    }
  }

  Future<void> _insertInitialMaterial(String key) async {
    try {
      if (!isStoreMaterialSupported(key)) return;
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      final albumId = vm.editingAlbumId;
      final pageIndex = vm.currentPageIndex;
      final shop = ref.read(pointShopRepositoryProvider);
      final userId = shop.currentUserId;
      final photo = key.startsWith('frame:')
          ? await showPhotoSelectionSheet(context, ref)
          : null;
      if (!mounted ||
          albumId != vm.editingAlbumId ||
          pageIndex != vm.currentPageIndex ||
          userId != shop.currentUserId)
        return;
      final inserted = await insertStoreMaterial(vm, key, photo: photo);
      if (mounted && inserted) {
        context.showSnack('선택한 소재를 넣었어요. 저장하면 앨범에 반영돼요.');
      }
    } catch (_) {
      if (mounted) {
        context.showErrorSnack('소재를 넣지 못했어요. 편집 도구에서 다시 선택해 주세요.');
      }
    }
  }

  Future<void> _openGalleryForPlaceholder(LayerModel layer) async {
    if (!mounted) return;
    if (_showEditorHint) setState(() => _showEditorHint = false);
    final changed = await replacePhotoInSlot(
      context,
      ref,
      layer,
      layerBuilder: _layerBuilder,
    );
    if (changed && mounted) setState(() {});
  }

  void _bindPhotoFillQueue(
    AlbumEditorViewModel vm, {
    TemplatePhotoFillSession? initial,
  }) {
    final owner = ref.read(albumEditorOwnerReaderProvider)();
    _photoFillQueue.reset();
    _photoFillSessionIdentity = vm.editSessionIdentity;
    _photoFillOwner = owner;
    _photoFillAlbumId = vm.editingAlbumId;
    _photoFillQueueRevision = 0;
    _savedPhotoFillQueueRevision = 0;
    if (owner == null ||
        initial == null ||
        widget.creationDraftOwner != null && widget.creationDraftOwner != owner)
      return;
    _photoFillQueue.pendingPhotos.addAll(
      initial.pendingPhotos.where(
        (photo) => photo is! BrowserPhotoAsset || photo.ownerId == owner,
      ),
    );
    _photoFillQueue.selectedPhoto =
        _photoFillQueue.pendingPhotos
            .where((photo) => photo.id == initial.selectedPhoto?.id)
            .firstOrNull ??
        _photoFillQueue.pendingPhotos.firstOrNull;
    _photoFillQueue.page = initial.page;
  }

  TemplatePhotoFillSession _copyPhotoFillQueue(
    TemplatePhotoFillSession source,
  ) => TemplatePhotoFillSession()
    ..pendingPhotos.addAll(source.pendingPhotos)
    ..selectedPhoto = source.selectedPhoto
    ..page = source.page;

  bool _photoFillQueueMatches(EditorPhotoFillResult result) {
    final before = _photoFillQueue.pendingPhotos;
    if (before.length != result.pendingPhotos.length ||
        _photoFillQueue.selectedPhoto?.id != result.selectedPhoto?.id ||
        before.isNotEmpty && _photoFillQueue.page != result.pageIndex)
      return false;
    for (var index = 0; index < before.length; index++) {
      if (before[index].id != result.pendingPhotos[index].id) return false;
    }
    return true;
  }

  /// 여러 사진을 작업본에서 채운 뒤, 적용한 내용과 남은 사진만 이어받는다.
  Future<void> _openPhotoFill() async {
    if (!mounted ||
        _isSaving ||
        _photoFillOpen ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    final scope = ProviderScope.containerOf(context, listen: false);
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (!_canFillPhotos(vm)) return;
    final draft = vm.beginPhotoFill();
    if (draft == null) {
      context.showSnack('계정과 앨범 편집 권한을 확인한 뒤 다시 시도해주세요.');
      return;
    }
    if (!identical(_photoFillSessionIdentity, draft.sessionIdentity) ||
        _photoFillOwner != draft.ownerId ||
        _photoFillAlbumId != draft.albumId) {
      _bindPhotoFillQueue(vm);
    }
    setState(() => _photoFillOpen = true);
    try {
      final route = snapFitRoute<EditorPhotoFillResult>(
        page: UncontrolledProviderScope(
          container: scope,
          child: EditorPhotoFillScreen(
            draft: draft,
            initialSession: _photoFillQueue,
          ),
        ),
        settings: editorModalRouteSettings(context),
      );
      final result = await Navigator.of(context).push(route);
      await route.completed;
      if (!mounted ||
          result == null ||
          ModalRoute.of(context)?.isCurrent == false ||
          !identical(
            ProviderScope.containerOf(context, listen: false),
            scope,
          ) ||
          !identical(ref.read(albumEditorViewModelProvider.notifier), vm))
        return;
      if (!vm.applyPhotoFill(draft, result.pages)) {
        context.showSnack('앨범이 변경돼 사진을 적용하지 않았어요. 다시 열어주세요.');
        return;
      }
      if (!_photoFillQueueMatches(result)) _photoFillQueueRevision++;
      _photoFillQueue.reset();
      _photoFillQueue.pendingPhotos.addAll(result.pendingPhotos);
      _photoFillQueue.selectedPhoto = result.selectedPhoto;
      _photoFillQueue.page = result.pageIndex;
      _interaction.resetForPageChange();
      if (_hasCreationDraft) {
        final saved = await _saveCreationEditorDraft(notify: false);
        if (!saved && mounted && _hasUnsavedPhotoFillQueue) {
          context.showSnack('선택한 사진을 임시 저장하지 못했어요. 나가기 전에 다시 저장해주세요.');
        }
      }
    } finally {
      if (mounted) setState(() => _photoFillOpen = false);
    }
  }

  bool _canFillPhotos(AlbumEditorViewModel vm) {
    if (!vm.editingAllowed) return false;
    final hasEmptySlot = vm.pages.any(
      (page) => page.layers.any(
        (layer) => layer.type == LayerType.image && !layer.hasImageSource,
      ),
    );
    return hasEmptySlot ||
        identical(_photoFillSessionIdentity, vm.editSessionIdentity) &&
            _photoFillAlbumId == vm.editingAlbumId &&
            _photoFillOwner == ref.read(albumEditorOwnerReaderProvider)() &&
            _photoFillQueue.pendingPhotos.isNotEmpty;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRemoteChecks();
    } else {
      _remoteCheckTimer?.cancel();
    }
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        _hasCreationDraft &&
        _entryCheckpoint != null &&
        !_isSaving &&
        !_exitPromptOpen) {
      unawaited(_saveCreationEditorDraft(notify: false));
    }
  }

  void _startRemoteChecks() {
    _remoteCheckTimer?.cancel();
    if (!mounted) return;
    void check() {
      if (mounted)
        unawaited(
          ref.read(albumEditorViewModelProvider.notifier).checkRemoteAlbum(),
        );
    }

    check();
    _remoteCheckTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => check(),
    );
  }

  Future<bool> _saveCreationEditorDraft({
    bool notify = true,
    AlbumEditCheckpoint? checkpoint,
  }) {
    final owner = widget.creationDraftOwner;
    final draftId = widget.creationDraftId;
    final readOwner = ref.read(albumEditorOwnerReaderProvider);
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final albumId = checkpoint?.albumId ?? vm.editingAlbumId;
    final cover = checkpoint?.cover ?? vm.selectedCover;
    if (owner == null ||
        draftId == null ||
        albumId == null ||
        readOwner() != owner ||
        ref.read(authViewModelProvider).asData?.value?.id != owner) {
      if (notify && mounted) {
        context.showSnack('로그인한 계정을 확인해 주세요. 편집 내용은 유지돼요.');
      }
      return Future.value(false);
    }
    final draftCheckpoint = checkpoint == null
        ? vm.captureCreationEditorCheckpoint()
        : AlbumCreationEditorCheckpoint(
            pages: checkpoint.pages,
            pageIndex: checkpoint.pageIndex,
            coverCanvas: checkpoint.coverCanvas == Size.zero
                ? Size(kCoverReferenceWidth, kCoverReferenceWidth / cover.ratio)
                : checkpoint.coverCanvas,
            innerCanvas: checkpoint.innerCanvas == Size.zero
                ? Size(300, 300 / cover.ratio)
                : checkpoint.innerCanvas,
            theme: checkpoint.theme,
            sourceUpdatedAt: checkpoint.sourceAlbum?.updatedAt,
            sourceOwnerId: checkpoint.sourceAlbum?.userId,
            sourceMemberRole: checkpoint.sourceAlbum?.memberRole,
            sourceTemplateProductKey: checkpoint.sourceTemplateProductKey,
          );
    final queue = checkpoint == null ? _photoFillQueue : _entryPhotoFillQueue;
    final queueCurrent =
        _photoFillOwner == owner &&
        _photoFillAlbumId == albumId &&
        identical(_photoFillSessionIdentity, vm.editSessionIdentity) &&
        (checkpoint == null ||
            identical(checkpoint.sessionIdentity, _photoFillSessionIdentity));
    final pendingPhotos = queueCurrent ? List.of(queue.pendingPhotos) : null;
    final selectedPhotoId = queue.selectedPhoto?.id;
    final photoPage = queue.page;
    final queueRevision = _photoFillQueueRevision;
    final queueSession = _photoFillSessionIdentity;
    final store = ref.read(albumCreationDraftStoreProvider);
    setState(() {
      _pendingDraftWrites++;
      _draftWriteFailed = false;
    });
    final result = _draftWrites.then((_) async {
      try {
        final written = await store.updateLinked(owner, draftId, albumId, (
          draft,
        ) {
          if (readOwner() != owner ||
              mounted &&
                  ref.read(authViewModelProvider).asData?.value?.id != owner) {
            throw StateError('Draft account changed');
          }
          return draft.withEditorCheckpoint(
            draftCheckpoint,
            cover: cover,
            pendingPhotos: pendingPhotos,
            selectedPhotoId: selectedPhotoId,
            currentPage: queueCurrent ? photoPage : null,
          );
        });
        if (!written) throw StateError('Linked draft no longer exists');
        if (mounted) {
          if (checkpoint == null &&
              queueCurrent &&
              identical(_photoFillSessionIdentity, queueSession) &&
              identical(vm.editSessionIdentity, queueSession) &&
              _photoFillAlbumId == albumId &&
              readOwner() == owner) {
            // A completed older write must not mark a newer queue as saved.
            _savedPhotoFillQueueRevision = math.max(
              _savedPhotoFillQueueRevision,
              queueRevision,
            );
          }
          _draftWriteFailed = false;
          _lastDraftSavedAt = DateTime.now();
          ref.invalidate(albumCreationDraftProvider);
          if (notify) context.showSnack('이 기기에 임시 저장했어요. 홈에서 이어 만들 수 있어요.');
        }
        return true;
      } catch (_) {
        if (mounted) {
          _draftWriteFailed = true;
          if (notify)
            context.showErrorSnack('임시 저장하지 못했어요. 편집 내용은 유지돼요. 다시 시도해 주세요.');
        }
        return false;
      } finally {
        if (mounted) setState(() => _pendingDraftWrites--);
      }
    });
    _draftWrites = result.then<void>((_) {});
    return result;
  }

  /// 앨범 저장 로직 추출
  Future<void> _onSaveAlbum(
    AlbumEditorViewModel vm,
    List<LayerModel> layers,
  ) async {
    // A pointer transform commits on pointer-up. Consume the save shortcut
    // without saving an older document while the user is still dragging.
    if (_isSaving ||
        _onePageChoiceOpen ||
        (kIsWeb && _interaction.isInteractingNow))
      return;
    if (!vm.editingAllowed) {
      context.showSnack(const AlbumEditAccessRevoked().message);
      return;
    }
    final session = vm.editSessionIdentity;
    final actor = ref.read(albumEditorOwnerReaderProvider)();
    final albumBeforeSave = vm.album;
    final savedPageId = vm.currentPage?.id;
    bool current() =>
        mounted &&
        identical(session, vm.editSessionIdentity) &&
        ref.read(albumEditorOwnerReaderProvider)() == actor;

    try {
      setState(() {
        _isSaving = true;
        _saveStatus = const AlbumSaveProgress(AlbumSavePhase.preparing);
      });

      // 1. Z-index 정렬 동기화 (VM 현재 페이지 레이어를 _z 순서로 맞춰 저장 시 순서 유지)
      final currentPage = vm.currentPage;
      if (currentPage != null && currentPage.layers.isNotEmpty) {
        final sorted = _interaction.sortByZ(List.of(currentPage.layers));
        vm.updatePageLayers(sorted, recordHistory: false);
      }

      if (_hasCreationDraft) {
        final draftSaved = await _saveCreationEditorDraft(notify: false);
        if (!current()) return;
        if (!draftSaved && _hasUnsavedPhotoFillQueue) {
          throw StateError('선택한 사진을 임시 저장하지 못했어요. 다시 저장하거나 편집을 계속해주세요.');
        }
      }

      // 2. 서버 저장
      Uint8List? coverCapture;
      try {
        coverCapture = await _coverEditorKey.currentState?.captureCoverBytes();
      } catch (e) {
        debugPrint('Failed to capture cover in Screen: $e');
      }
      if (!current()) return;

      final isSuccess = await vm.saveFullAlbum(
        coverImageBytes: coverCapture,
        onProgress: (value) {
          if (current()) setState(() => _saveStatus = value);
        },
      );
      if (!current()) return;
      if (!isSuccess) {
        throw vm.lastSaveError ?? StateError('앨범 저장에 실패했습니다.');
      }

      if (context.mounted && isSuccess) {
        if (vm.hasUnsavedChanges) {
          context.showSnack('저장 중 새 편집이 있어요. 남은 변경 내용도 저장해 주세요.');
          return;
        }
        if (widget.onePageGoal) {
          ref.invalidate(homeViewModelProvider);
          _entryCheckpoint = vm.captureEditCheckpoint();
          _entryPhotoFillQueue = _copyPhotoFillQueue(_photoFillQueue);
          setState(() => _isSaving = false);
          await _showOnePageSaved(vm, savedPageId, current);
          return;
        }
        var savedMessage = '앨범을 저장했어요.';
        if (widget.creationDraftOwner != null &&
            widget.creationDraftId != null) {
          try {
            await _draftWrites;
            await ref
                .read(albumCreationDraftStoreProvider)
                .remove(widget.creationDraftOwner!, widget.creationDraftId!);
            if (mounted) ref.invalidate(albumCreationDraftProvider);
          } catch (_) {
            savedMessage = '앨범은 저장했지만 임시 저장은 정리하지 못했어요.';
          }
        }
        if (!current()) return;
        final savedAlbum = vm.album;
        var previouslyComplete = false;
        var nowComplete = false;
        if (savedAlbum != null && !widget.returnToPreviousOnSave) {
          final requests = [
            if (albumBeforeSave != null)
              AlbumProgressLoader.request(albumBeforeSave),
            AlbumProgressLoader.request(savedAlbum),
          ];
          try {
            final progress = await Future.wait(requests.map((r) => r.result));
            previouslyComplete =
                albumBeforeSave != null && progress.first?.isCompleted == true;
            nowComplete = progress.last?.isCompleted == true;
          } finally {
            for (final request in requests) {
              request.cancel();
            }
          }
          if (!current()) return;
        }
        // 3. 홈 화면 갱신 및 이동
        // Refresh when observed, without holding navigation on a network request.
        ref.invalidate(homeViewModelProvider);

        // popUntil 이전에 캡처해야 한다. popUntil 이후 context는 deactivated 상태가
        // 되어 SnackBar 애니메이션 완료 시점에 ancestor 조회가 실패한다.
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        final container = ProviderScope.containerOf(context, listen: false);
        final savedId = savedAlbum?.id;
        final celebrate = shouldCelebrateAlbumSave(
          creationFlow: widget.creationDraftId != null,
          previouslyComplete: previouslyComplete,
          nowComplete: nowComplete,
          returnToPrevious: widget.returnToPreviousOnSave,
        );
        void openSavedAlbum() {
          if (!navigator.mounted ||
              actor == null ||
              savedId == null ||
              savedId <= 0 ||
              container.read(albumEditorOwnerReaderProvider)() != actor)
            return;
          // A snackbar from an old editing session must not open over a new
          // editor whose local canvas may have changed in the meantime.
          if (!identical(
            session,
            container
                .read(albumEditorViewModelProvider.notifier)
                .editSessionIdentity,
          ))
            return;
          navigator.push<void>(
            snapFitRoute<void>(
              page: AlbumSavedExperienceScreen(
                albumId: savedId,
                ownerId: actor,
                reason: nowComplete && !previouslyComplete
                    ? AlbumSavedReason.completed
                    : celebrate
                    ? AlbumSavedReason.firstSave
                    : AlbumSavedReason.saved,
              ),
            ),
          );
        }

        if (widget.returnToPreviousOnSave && Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(savedMessage),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            action:
                celebrate ||
                    widget.returnToPreviousOnSave ||
                    savedId == null ||
                    savedId <= 0
                ? null
                : SnackBarAction(label: '앨범 보기', onPressed: openSavedAlbum),
          ),
        );
        if (celebrate) {
          WidgetsBinding.instance.addPostFrameCallback((_) => openSavedAlbum());
        }
      }
    } catch (e) {
      if (!current()) return;
      if (e is AlbumRevisionConflict || e is AlbumRevisionRequired) {
        setState(() => _isSaving = false);
        await _confirmReload(vm);
        return;
      }
      if (e is StorageQuotaExceededException && context.mounted) {
        setState(() => _isSaving = false);
        await _showQuotaExceededSheet(context);
        return;
      }
      if (context.mounted) {
        setState(() => _isSaving = false);
        context.showErrorSnack(albumSaveErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showOnePageSaved(
    AlbumEditorViewModel vm,
    String? savedPageId,
    bool Function() current,
  ) async {
    if (!current() || vm.hasUnsavedChanges) return;
    final savedIndex = vm.pages.indexWhere((page) => page.id == savedPageId);
    if (savedIndex < 0) return;
    final page = vm.pages[savedIndex];
    final summary = preparedAlbumPageProgress(page);
    final number = vm.pages
        .take(savedIndex + 1)
        .where((page) => !page.isCover)
        .length;
    final advance = page.isCover || summary.isComplete;
    final nextIndex = advance
        ? firstIncompleteAlbumPageIndex(vm.pages)
        : savedIndex;
    final nextNumber = nextIndex == null
        ? null
        : vm.pages.take(nextIndex + 1).where((page) => !page.isCover).length;
    _onePageChoiceOpen = true;
    try {
      final choice = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: false,
        routeSettings: editorModalRouteSettings(context),
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              key: const ValueKey('one-page-saved-choice'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  page.isCover
                      ? '표지를 저장했어요.'
                      : summary.isComplete
                      ? '$number쪽을 완성했어요.'
                      : '$number쪽을 저장했어요.',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  page.isCover
                      ? '내 계정에 저장했어요. 이어서 내지 한 쪽을 채워볼까요?'
                      : summary.isComplete
                      ? '사진과 글이 내 계정에 저장됐어요. 오늘의 한 쪽을 남겼네요.'
                      : summary.photoSlots > summary.filledPhotoSlots
                      ? '내 계정에 저장했어요. 사진 ${summary.photoSlots - summary.filledPhotoSlots}칸은 이어서 채울 수 있어요.'
                      : '내 계정에 저장했어요. 사진이나 내 글을 남기면 이 쪽이 완성돼요.',
                ),
                const SizedBox(height: 24),
                if (nextIndex != null) ...[
                  FilledButton(
                    key: const ValueKey('one-page-next'),
                    onPressed: () => Navigator.pop(sheetContext, 'next'),
                    child: Text(advance ? '$nextNumber쪽 이어 채우기' : '이 쪽 계속 채우기'),
                  ),
                  const SizedBox(height: 8),
                ],
                TextButton(
                  key: const ValueKey('one-page-finish-today'),
                  onPressed: () => Navigator.pop(sheetContext, 'today'),
                  child: const Text('오늘은 여기까지'),
                ),
              ],
            ),
          ),
        ),
      );
      if (!current() || vm.hasUnsavedChanges) return;
      if (choice == 'today') {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (choice == 'next' &&
          nextIndex != null &&
          nextIndex < vm.pages.length) {
        final next = vm.pages[nextIndex];
        _interaction.resetForPageChange();
        vm.goToPage(nextIndex);
        setState(() {
          _pageTurnForward = nextIndex > savedIndex;
          _pageTurnNonce++;
          _canvasSize = Size.zero;
          _initialSelectionPageIndex = nextIndex;
          _pendingInitialSelectedLayerId = preparedAlbumPageProgress(
            next,
          ).firstUnfilledPhotoId;
          _pendingOnePagePhotoPrompt = true;
        });
      }
    } finally {
      if (mounted)
        setState(() => _onePageChoiceOpen = false);
      else
        _onePageChoiceOpen = false;
    }
  }

  Future<void> _showQuotaExceededSheet(BuildContext context) async {
    if (kIsWeb) {
      await showWebAwareDialog<bool>(
        context: context,
        useRootNavigator: false,
        routeSettings: editorModalRouteSettings(context),
        maxWidth: 560,
        maxHeight: 340,
        builder: (dialogContext) => Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '저장 공간이 부족합니다',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: WebPalette.of(context).ink,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '저장 공간을 초과했습니다. 사용하지 않는 앨범이나 사진을 정리한 뒤 다시 저장해 주세요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: WebPalette.of(context).muted,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      routeSettings: editorModalRouteSettings(context),
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '저장 공간이 부족합니다',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '저장 공간을 초과했습니다. 사용하지 않는 앨범이나 사진을 정리한 뒤 다시 저장해 주세요.',
                  style: TextStyle(
                    color: SnapFitColors.textSecondaryOf(context),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteCurrentPage(AlbumEditorViewModel vm) async {
    if (!vm.canDeleteCurrentPage) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      routeSettings: editorModalRouteSettings(context),
      builder: (ctx) => AlertDialog(
        backgroundColor: SnapFitColors.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '페이지 삭제',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        content: Text(
          vm.deleteCurrentPageDescription,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              '취소',
              style: TextStyle(color: SnapFitColors.textMutedOf(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '삭제',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    vm.deleteCurrentPage();
    _interaction.clearSelection();
    setState(() => _canvasSize = Size.zero);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(albumEditorViewModelProvider);
    ref.watch(albumEditSyncStatusProvider);
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final state = asyncState.value;
    final canUndo = state?.canUndo ?? false;
    final canRedo = state?.canRedo ?? false;
    final canFillPhotos = !_isSaving && _canFillPhotos(vm);
    final viewport = MediaQuery.sizeOf(context);
    final desktopWorkspace = viewport.width >= 1100 && viewport.height >= 600;
    if (vm.editingAccessRevoked && vm.editingAlbumId != null) {
      return _readOnlyAfterAccessChange(vm);
    }

    // aspect: 내지 LayoutBuilder에서 canvasH 계산에 사용
    final double aspect = vm.selectedCover.ratio;

    // Logic for displaying layers
    // If initialPageIndex is set, we might be forcing a specific page
    // But generally we should follow vm.currentPageIndex which is the source of truth
    final currentPageIndex = vm.currentPageIndex;
    final List<LayerModel> layers = (state != null && state.layers.isNotEmpty)
        ? state.layers
        : [];
    final layerSyncSignature =
        '$currentPageIndex:${layers.length}:${layers.map((e) => e.id).join('|')}';

    if (_lastSyncedPageIndex != currentPageIndex) {
      _lastSyncedPageIndex = currentPageIndex;
      _lastLayerSyncSignature = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _interaction.resetForPageChange();
        _selectInitialPhotoIfReady();
      });
    } else if (_lastLayerSyncSignature != layerSyncSignature) {
      _lastLayerSyncSignature = layerSyncSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _interaction.syncLayers(layers);
        _selectInitialPhotoIfReady();
      });
    }

    final pages = vm.pages; // For the top selector

    void handlePageSelected(int index) {
      if (index == currentPageIndex) return;
      _pendingInitialSelectedLayerId = null;
      _initialSelectionPageIndex = null;
      _pendingOnePagePhotoPrompt = false;
      _pageTurnForward = index > currentPageIndex;
      _pageTurnNonce++;
      _interaction.clearSelection();
      vm.goToPage(index);
      // 페이지 전환 시 _canvasSize 리셋 → 다음 렌더에서 PageEditorCanvas가 실제 크기 재측정
      setState(() => _canvasSize = Size.zero);
    }

    void handleAddPage() {
      final addedPages = vm.pagesToAdd;
      if (!vm.addPage()) return;
      _pageTurnForward = true;
      _pageTurnNonce++;
      context.showSnack('빈 내지 $addedPages쪽을 추가했어요.');
      setState(() {});
    }

    Widget buildPageSelector() {
      return SnapFitFadeIn(
        key: const Key('pageEditorSelectorReveal'),
        delay: const Duration(milliseconds: 80),
        child: PageListSelector(
          pages: pages,
          currentPageIndex: currentPageIndex,
          onPageSelected: handlePageSelected,
          onAddPage: vm.canAddPage ? handleAddPage : null,
          addPageDescription: vm.addPageDescription,
          canDeleteCurrentPage: vm.canDeleteCurrentPage,
          onDeleteCurrentPage: () => _confirmDeleteCurrentPage(vm),
        ),
      );
    }

    Widget editableInner(double width, double height, {bool flat = false}) {
      return PageEditorCanvas(
        canvasKey: _canvasKey,
        canvasW: width,
        canvasH: height,
        flatPresentation: flat || kIsWeb,
        layers: layers,
        interaction: _interaction,
        layerBuilder: _layerBuilder,
        onCanvasSizeChanged: (size) {
          if (_canvasSize == size) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _canvasSize == size) return;
            setState(() => _canvasSize = size);
            vm.loadPendingEditAlbumIfNeeded(size);
            vm.setCoverCanvasSize(size, isCover: false);
          });
        },
        backgroundColor: vm.currentPage?.backgroundColor == null
            ? null
            : Color(vm.currentPage!.backgroundColor!),
        isCover: false,
        onAddPhoto: () {
          if (!_isSaving) _toolbarActionHandler.addPhoto();
        },
        onChooseDesign: () {
          if (!_isSaving) _handleModeChange(EditorMode.template, layers);
        },
        emptyPageActionsEnabled: !_isSaving,
      );
    }

    Widget buildCanvasArea({required EdgeInsets padding, bool spread = false}) {
      return Padding(
        padding: padding,
        child: _PageEditorEntranceReveal(
          key: const Key('pageEditorCanvasReveal'),
          disabled: kIsWeb || MediaQuery.disableAnimationsOf(context),
          includeScale: true,
          child: _PageEditorPageTurnReveal(
            key: ValueKey('page-turn-$currentPageIndex-$_pageTurnNonce'),
            disabled: kIsWeb || MediaQuery.disableAnimationsOf(context),
            forward: _pageTurnForward,
            child: _buildWorkspaceFrame(
              context,
              child: currentPageIndex == 0
                  ? EditCover(
                      key: _coverEditorKey,
                      flatPresentation: true,
                      editAlbum: vm.album,
                      showAppBar: false,
                      initialCoverSize: vm.selectedCover,
                      showBottomToolbar: false,
                      interaction: _interaction,
                      canvasKey: _canvasKey,
                      onSizeChanged: (size) => _canvasSize = size,
                    )
                  : LayoutBuilder(
                      builder: (context, box) {
                        final count = spread ? 2 : 1;
                        final width = math.min(
                          math.max(1, box.maxWidth - 24) / count,
                          math.max(1, box.maxHeight - 24) * aspect,
                        );
                        final height = width / aspect;
                        if (!spread)
                          return Center(child: editableInner(width, height));
                        final left = currentPageIndex.isOdd
                            ? currentPageIndex
                            : currentPageIndex - 1;
                        final base = Size(
                          kCoverReferenceWidth,
                          kCoverReferenceWidth / aspect,
                        );
                        final preview = LayerBuilder(
                          LayerInteractionManager.preview(ref, () => base),
                          () => base,
                        );
                        return Center(
                          child: DecoratedBox(
                            key: const ValueKey('editor-open-spread'),
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .12),
                                  blurRadius: 22,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final index in [left, left + 1])
                                  SizedBox(
                                    width: width,
                                    height: height,
                                    child: index == currentPageIndex
                                        ? DecoratedBox(
                                            position:
                                                DecorationPosition.foreground,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color:
                                                    ExperienceFormStyle.selectionInk(
                                                      context,
                                                    ).withValues(alpha: .55),
                                              ),
                                            ),
                                            child: editableInner(
                                              width,
                                              height,
                                              flat: true,
                                            ),
                                          )
                                        : Semantics(
                                            button: index < pages.length,
                                            label: '$index쪽 편집',
                                            child: GestureDetector(
                                              key: ValueKey(
                                                'editor-facing-page-$index',
                                              ),
                                              behavior: HitTestBehavior.opaque,
                                              onTap: index < pages.length
                                                  ? () => handlePageSelected(
                                                      index,
                                                    )
                                                  : null,
                                              child: index < pages.length
                                                  ? ClipRect(
                                                      child: AlbumReaderPageContent(
                                                        layers:
                                                            pages[index].layers,
                                                        targetW: width,
                                                        targetH: height,
                                                        previewBuilder: preview,
                                                        baseCanvasSize: base,
                                                        flatPresentation: true,
                                                        backgroundColor: Color(
                                                          pages[index]
                                                                  .backgroundColor ??
                                                              0xFFFFFFFF,
                                                        ),
                                                      ),
                                                    )
                                                  : const ColoredBox(
                                                      color: Colors.white,
                                                    ),
                                            ),
                                          ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      );
    }

    Widget buildLayerActions({bool showLabels = false}) {
      return AnimatedSwitcher(
        duration: SnapFitMotion.medium,
        switchInCurve: SnapFitMotion.entrance,
        switchOutCurve: Curves.easeInCubic,
        child: _interaction.selectedLayerId != null
            ? LayerActionPanel(
                showLabels: showLabels,
                layers: layers,
                interaction: _interaction,
                textEditor: TextEditorManager(
                  context,
                  ref.read(albumEditorViewModelProvider.notifier),
                ),
                onRefresh: () => setState(() {}),
                onOpenGallery: (LayerModel layer) =>
                    _openGalleryForPlaceholder(layer),
                onOpenPhotoCrop: (layer) => editPhotoCrop(
                  context,
                  ref,
                  layer,
                  layerBuilder: _layerBuilder,
                ),
                onOpenDecorateSheet: (LayerModel layer) =>
                    _openDecorateSheetForLayer(layer),
              )
            : const SizedBox.shrink(),
      );
    }

    Widget buildBottomMenu() {
      return SnapFitFadeIn(
        key: const Key('pageEditorDockReveal'),
        delay: const Duration(milliseconds: 140),
        beginOffset: const Offset(0, 0.055),
        child: EditorBottomMenu(
          currentMode: _currentMode,
          isCover: currentPageIndex == 0,
          showCoverMenuItem: false,
          canUndo: canUndo,
          canRedo: canRedo,
          onUndo: () {
            vm.undo();
            _interaction.resetForPageChange();
            if (mounted) setState(() {});
          },
          onRedo: () {
            vm.redo();
            _interaction.resetForPageChange();
            if (mounted) setState(() {});
          },
          onModeChanged: (mode) => _handleModeChange(mode, layers),
          onAddPhoto: () {
            _toolbarActionHandler.addPhoto();
          },
          onCover: () => _toolbarActionHandler.openCoverTheme(),
          onFillPhotos: canFillPhotos
              ? () => unawaited(_openPhotoFill())
              : null,
        ),
      );
    }

    Widget buildContextDock() => SnapFitFadeIn(
      key: const Key('pageEditorDockReveal'),
      delay: const Duration(milliseconds: 140),
      beginOffset: const Offset(0, 0.055),
      child: EditorContextDock(
        currentMode: _currentMode,
        layers: layers,
        interaction: _interaction,
        enabled: !_isSaving,
        canUndo: canUndo,
        canRedo: canRedo,
        onUndo: () {
          vm.undo();
          _interaction.resetForPageChange();
        },
        onRedo: () {
          vm.redo();
          _interaction.resetForPageChange();
        },
        onModeChanged: (mode) => _handleModeChange(mode, layers),
        onAddPhoto: () => _toolbarActionHandler.addPhoto(),
        onFillPhotos: canFillPhotos ? _openPhotoFill : null,
        onRefresh: () {
          if (mounted) setState(() {});
        },
        onOpenGallery: _openGalleryForPlaceholder,
        onOpenCrop: (layer) =>
            editPhotoCrop(context, ref, layer, layerBuilder: _layerBuilder),
        onOpenDecorate: _openDecorateSheetForLayer,
      ),
    );

    Widget buildLandscapeLayout() {
      return Row(
        children: [
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
              child: buildPageSelector(),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: buildCanvasArea(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 4,
                    ),
                    spread: true,
                  ),
                ),
                if (_interaction.selectedLayerId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 96),
                      child: SingleChildScrollView(child: buildLayerActions()),
                    ),
                  ),
              ],
            ),
          ),
          if (_currentMode != EditorMode.none)
            SizedBox(
              key: const ValueKey('editor-side-inspector'),
              width: math.min(240, MediaQuery.sizeOf(context).width * .29),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                child: _EditorToolPanelReveal(
                  child: _buildInlineToolPanel(
                    context,
                    _currentMode,
                    layers,
                    fillAvailableHeight: true,
                  ),
                ),
              ),
            ),
          SizedBox(
            width: math
                .max(72.0, MediaQuery.textScalerOf(context).scale(11) * 4 + 20)
                .clamp(72.0, 112.0),
            child: buildBottomMenu(),
          ),
        ],
      );
    }

    Widget desktopTool(
      String label,
      IconData icon,
      VoidCallback action, {
      bool selected = false,
    }) => SizedBox(
      width: 94,
      child: TextButton(
        onPressed: _isSaving ? null : action,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 62),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          backgroundColor: selected
              ? ExperienceFormStyle.selection(context)
              : Colors.transparent,
          foregroundColor: ExperienceFormStyle.ink(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 5),
            Text(label),
          ],
        ),
      ),
    );

    Widget buildDesktopLayout() {
      final mode = _currentMode == EditorMode.none
          ? EditorMode.layer
          : _currentMode;
      return Row(
        key: const ValueKey('page-editor-desktop-workspace'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const ValueKey('page-editor-desktop-pages'),
            width: 112,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
              child: Column(
                children: [
                  Text(
                    '페이지',
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: buildPageSelector()),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: ExperienceFormStyle.line(context)),
          Expanded(
            key: const ValueKey('page-editor-desktop-canvas'),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          currentPageIndex == 0
                              ? '표지 편집'
                              : '내지 $currentPageIndex쪽 편집',
                          style: ExperienceFormStyle.text(
                            context,
                            15,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('editor-desktop-undo'),
                        tooltip: '실행 취소 (Ctrl/⌘ Z)',
                        onPressed: !_isSaving && canUndo
                            ? () {
                                vm.undo();
                                _interaction.resetForPageChange();
                              }
                            : null,
                        icon: const ExperienceIcon('Undo2', size: 21),
                      ),
                      IconButton(
                        key: const ValueKey('editor-desktop-redo'),
                        tooltip: '다시 실행 (Ctrl/⌘ Shift Z)',
                        onPressed: !_isSaving && canRedo
                            ? () {
                                vm.redo();
                                _interaction.resetForPageChange();
                              }
                            : null,
                        icon: const ExperienceIcon('Redo2', size: 21),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _isSaving ? null : _interaction.clearSelection,
                    child: buildCanvasArea(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '클릭해서 선택 · 드래그로 이동 · Delete 삭제 · Ctrl/⌘ Z 실행 취소',
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: ExperienceFormStyle.line(context)),
          SizedBox(
            key: const ValueKey('page-editor-desktop-tools'),
            width: 324,
            child: ColoredBox(
              color: ExperienceFormStyle.surface(context),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        desktopTool(
                          '사진 추가',
                          Icons.add_photo_alternate_outlined,
                          () {
                            _toolbarActionHandler.addPhoto();
                          },
                        ),
                        desktopTool(
                          '글 추가',
                          Icons.text_fields,
                          () => _handleModeChange(EditorMode.text, layers),
                        ),
                        desktopTool(
                          '겹침 순서',
                          Icons.layers_outlined,
                          () => _handleModeChange(EditorMode.layer, layers),
                          selected: mode == EditorMode.layer,
                        ),
                        desktopTool(
                          '레이아웃',
                          Icons.dashboard_outlined,
                          () => _handleModeChange(EditorMode.layout, layers),
                          selected: mode == EditorMode.layout,
                        ),
                        desktopTool(
                          '템플릿',
                          Icons.auto_awesome_mosaic_outlined,
                          () => _handleModeChange(EditorMode.template, layers),
                          selected: mode == EditorMode.template,
                        ),
                        desktopTool(
                          '꾸미기',
                          Icons.emoji_emotions_outlined,
                          () => _handleModeChange(EditorMode.sticker, layers),
                          selected: mode == EditorMode.sticker,
                        ),
                        desktopTool(
                          '배경',
                          Icons.palette_outlined,
                          () => _handleModeChange(
                            EditorMode.backgroundColor,
                            layers,
                          ),
                          selected: mode == EditorMode.backgroundColor,
                        ),
                        if (canFillPhotos)
                          desktopTool(
                            '사진 여러 장 넣기',
                            Icons.photo_library_outlined,
                            () => unawaited(_openPhotoFill()),
                          ),
                      ],
                    ),
                  ),
                  if (_interaction.selectedLayerId != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: buildLayerActions(),
                    ),
                  Expanded(
                    child: _buildInlineToolPanel(
                      context,
                      mode,
                      layers,
                      fillAvailableHeight: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    Widget buildWebWorkspace() {
      final selectedMode = _currentMode;
      final selectedLayer = layers
          .where((layer) => layer.id == _interaction.selectedLayerId)
          .firstOrNull;
      final referenceSize = Size(
        kCoverReferenceWidth,
        kCoverReferenceWidth / aspect,
      );
      final previewInteraction = LayerInteractionManager.preview(
        ref,
        () => referenceSize,
      );
      final previewBuilder = LayerBuilder(
        previewInteraction,
        () => referenceSize,
      );

      Widget pageRail({bool horizontal = false}) => WebAlbumPageRail(
        pages: pages,
        selectedIndex: currentPageIndex,
        cover: vm.selectedCover,
        theme: vm.selectedTheme,
        previewBuilder: previewBuilder,
        onSelected: handlePageSelected,
        horizontal: horizontal,
        onAdd: !_isSaving && vm.canAddPage ? handleAddPage : null,
        addDescription: vm.addPageDescription,
        onDelete: !_isSaving && vm.canDeleteCurrentPage
            ? () => _confirmDeleteCurrentPage(vm)
            : null,
      );

      WebAlbumEditorTool tool(String label, IconData icon, EditorMode mode) =>
          WebAlbumEditorTool(
            label: label,
            icon: icon,
            selected: selectedMode == mode,
            onPressed: () => _handleModeChange(mode, layers),
            opensProperties: false,
          );

      Widget progressOverlay({required String title, double? progress}) =>
          Stack(
            fit: StackFit.expand,
            children: [
              const ModalBarrier(dismissible: false, color: Color(0x66000000)),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: WebSurface(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: WebPalette.of(context).ink,
                            ),
                          ),
                          const SizedBox(height: 20),
                          LinearProgressIndicator(value: progress),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

      return Stack(
        fit: StackFit.expand,
        children: [
          WebAlbumEditorWorkspace(
            title: vm.album?.title.trim().isNotEmpty == true
                ? vm.album!.title
                : '새 앨범',
            pageLabel: currentPageIndex == 0
                ? '표지'
                : '내지 $currentPageIndex쪽 / ${math.max(0, pages.length - 1)}쪽',
            specification: vm.selectedCover.displayName,
            hasUnsavedChanges: vm.hasUnsavedChanges,
            isPersisted: (vm.album?.id ?? 0) > 0,
            isSaving: _isSaving,
            lastAccountSavedAt: (vm.album?.id ?? 0) > 0
                ? DateTime.tryParse(vm.album?.updatedAt ?? '')
                : null,
            lastDraftSavedAt: _lastDraftSavedAt,
            selectedLayerId: _interaction.selectedLayerId,
            onBack: () async {
              final shouldPop = await _handleWillPop(vm, layers);
              if (shouldPop && mounted) Navigator.pop(context);
            },
            onSave: () => unawaited(_onSaveAlbum(vm, layers)),
            saveActionLabel: widget.onePageGoal ? '이 쪽 저장' : null,
            onSaveDraft: _hasCreationDraft
                ? () => unawaited(_saveCreationEditorDraft())
                : null,
            draftPending: _pendingDraftWrites > 0,
            draftFailed: _draftWriteFailed,
            onUndo: canUndo
                ? () {
                    vm.undo();
                    _interaction.resetForPageChange();
                    if (mounted) setState(() {});
                  }
                : null,
            onRedo: canRedo
                ? () {
                    vm.redo();
                    _interaction.resetForPageChange();
                    if (mounted) setState(() {});
                  }
                : null,
            onAddPage: !_isSaving && vm.canAddPage ? handleAddPage : null,
            onDeletePage: !_isSaving && vm.canDeleteCurrentPage
                ? () => _confirmDeleteCurrentPage(vm)
                : null,
            pageRail: pageRail(),
            compactPageRail: pageRail(horizontal: true),
            canvas: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _isSaving ? null : _interaction.clearSelection,
              child: buildCanvasArea(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              ),
            ),
            properties: ColoredBox(
              color: WebPalette.of(context).surface,
              child: selectedLayer == null
                  ? SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                              '사진 교체·자르기와 글 편집을 바로 할 수 있어요.\n수치 입력은 고급 조정에서 확인하세요.',
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
                  : LayoutBuilder(
                      builder: (context, _) => SingleChildScrollView(
                        key: const ValueKey('web-editor-properties-scroll'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                12,
                              ),
                              child: buildLayerActions(showLabels: true),
                            ),
                            WebLayerTransformInspector(
                              key: ValueKey('transform-${selectedLayer.id}'),
                              layer: _interaction.currentTransformFor(
                                selectedLayer,
                              ),
                              baseSize: _interaction.baseSizeFor(selectedLayer),
                              enabled: !_isSaving,
                              onChanged: ({x, y, width, height, rotation}) =>
                                  _interaction.updateTransform(
                                    selectedLayer,
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
            ),
            tools: [
              WebAlbumEditorTool(
                label: '사진 추가',
                icon: Icons.add_photo_alternate_outlined,
                onPressed: () => unawaited(_toolbarActionHandler.addPhoto()),
                opensProperties: false,
              ),
              WebAlbumEditorTool(
                label: '텍스트',
                icon: Icons.text_fields,
                onPressed: () => _handleModeChange(EditorMode.text, layers),
                opensProperties: false,
              ),
              if (currentPageIndex == 0)
                WebAlbumEditorTool(
                  label: '표지 테마',
                  icon: Icons.style_outlined,
                  onPressed: () =>
                      unawaited(_toolbarActionHandler.openCoverTheme()),
                  opensProperties: false,
                ),
              tool('겹침 순서', Icons.layers_outlined, EditorMode.layer),
              tool('레이아웃', Icons.dashboard_outlined, EditorMode.layout),
              tool('템플릿', Icons.grid_view_outlined, EditorMode.template),
              tool('꾸미기', Icons.interests_outlined, EditorMode.sticker),
              tool('배경', Icons.palette_outlined, EditorMode.backgroundColor),
              if (canFillPhotos)
                WebAlbumEditorTool(
                  label: '사진 여러 장 넣기',
                  icon: Icons.photo_library_outlined,
                  onPressed: () => unawaited(_openPhotoFill()),
                  opensProperties: false,
                ),
            ],
          ),
          if (_isSaving)
            progressOverlay(
              progress: _saveStatus.phase == AlbumSavePhase.uploading
                  ? _saveStatus.fraction
                  : null,
              title: _saveStatus.label,
            ),
          if (!_isSaving &&
              (state?.backgroundUploadProgress ?? 0) > 0 &&
              (state?.backgroundUploadProgress ?? 0) < 1)
            Positioned(
              right: 20,
              bottom: 20,
              child: WebSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Text(
                  '사진 업로드 중 ${(state!.backgroundUploadProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: WebPalette.of(context).ink,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          if (state?.isCreatingInBackground ?? false)
            progressOverlay(title: '앨범을 준비하고 있습니다'),
        ],
      );
    }

    final editor = WebUnsavedWorkGuard(
      hasUnsavedChanges: () =>
          ref.read(albumEditorViewModelProvider.notifier).hasUnsavedChanges ||
          _hasUnsavedPhotoFillQueue ||
          _pendingDraftWrites > 0,
      child: EditorKeyboardShortcuts(
        enabled:
            !_isSaving &&
            !_onePageChoiceOpen &&
            !_exitPromptOpen &&
            !(state?.isCreatingInBackground ?? false),
        onDelete: _interaction.selectedLayerId == null
            ? null
            : _interaction.deleteSelected,
        onUndo: canUndo
            ? () {
                vm.undo();
                _interaction.resetForPageChange();
              }
            : null,
        onRedo: canRedo
            ? () {
                vm.redo();
                _interaction.resetForPageChange();
              }
            : null,
        onSave: () => unawaited(_onSaveAlbum(vm, layers)),
        onEscape: () {
          _interaction.clearSelection();
          setState(() => _currentMode = EditorMode.none);
        },
        child: WillPopScope(
          onWillPop: () => _handleWillPop(vm, layers),
          child: kIsWeb
              ? buildWebWorkspace()
              : Scaffold(
                  resizeToAvoidBottomInset: false,
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    toolbarHeight: desktopWorkspace ? 64 : 52,
                    backgroundColor: AlbumStageStyle.top(context),
                    surfaceTintColor: Colors.transparent,
                    systemOverlayStyle: AlbumStageStyle.overlay(context),
                    elevation: 0,
                    centerTitle: true,
                    leading: IconButton(
                      tooltip: '편집 마치기',
                      icon: const ExperienceIcon('ArrowLeft', size: 22),
                      onPressed: () async {
                        final shouldPop = await _handleWillPop(vm, layers);
                        if (shouldPop && mounted) Navigator.pop(context);
                      },
                    ),
                    title: Text(
                      desktopWorkspace
                          ? '앨범 편집'
                          : currentPageIndex == 0
                          ? '표지'
                          : '$currentPageIndex / ${math.max(0, pages.length - 1)}쪽',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ExperienceFormStyle.text(
                        context,
                        14,
                        weight: FontWeight.w600,
                      ),
                    ),
                    actions: [
                      if (_hasCreationDraft)
                        IconButton(
                          key: const ValueKey('editor-save-draft'),
                          tooltip: _draftWriteFailed
                              ? '임시 저장 다시 시도'
                              : '이 기기에 임시 저장',
                          onPressed: _isSaving || _pendingDraftWrites > 0
                              ? null
                              : () => _saveCreationEditorDraft(),
                          icon: _pendingDraftWrites > 0
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _draftWriteFailed
                                      ? Icons.error_outline
                                      : Icons.save_outlined,
                                  size: 21,
                                ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 12,
                          top: 4,
                          bottom: 4,
                        ),
                        child: FilledButton.icon(
                          key: const ValueKey('editor-save-album'),
                          onPressed: _isSaving
                              ? null
                              : () => _onSaveAlbum(vm, layers),
                          icon: ExperienceIcon(
                            'Check',
                            size: 17,
                            color: ExperienceFormStyle.primary(
                              context,
                            ).foregroundColor?.resolve({}),
                          ),
                          label: Text(
                            widget.onePageGoal
                                ? '이 쪽 저장'
                                : desktopWorkspace
                                ? '앨범 저장'
                                : '저장',
                          ),
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
                        ),
                      ),
                    ],
                  ),
                  body: Container(
                    decoration: BoxDecoration(
                      gradient: AlbumStageStyle.gradient(context),
                    ),
                    child: Stack(
                      children: [
                        SafeArea(
                          top: false,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              if (desktopWorkspace) return buildDesktopLayout();
                              final isLandscape =
                                  constraints.maxWidth > constraints.maxHeight;
                              if (isLandscape) return buildLandscapeLayout();

                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: buildPageSelector(),
                                  ),
                                  Expanded(
                                    child: buildCanvasArea(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        4,
                                        8,
                                        12,
                                      ),
                                    ),
                                  ),
                                  buildContextDock(),
                                ],
                              );
                            },
                          ),
                        ),

                        if (!_isSaving &&
                            _interaction.overlapLayerIds.length > 1)
                          Positioned(
                            top: 90,
                            left: 12,
                            right: 12,
                            child: Center(
                              child: EditorOverlapPicker(
                                layers: layers,
                                interaction: _interaction,
                              ),
                            ),
                          ),

                        if (_showEditorHint &&
                            !_isSaving &&
                            _interaction.selectedLayerId == null &&
                            _currentMode == EditorMode.none)
                          _buildEditorHint(
                            context,
                            isCover: currentPageIndex == 0,
                          ),

                        // 저장 중 진행률 오버레이
                        if (_isSaving)
                          PageEditorSaveOverlay(
                            progress:
                                _saveStatus.phase == AlbumSavePhase.uploading
                                ? _saveStatus.fraction
                                : null,
                            status: _saveStatus.label,
                          ),

                        // 백그라운드 이미지 업로드 진행률 배지 (저장 이후에도 계속 업로드되는 경우)
                        if (!_isSaving &&
                            (state?.backgroundUploadProgress ?? 0) > 0 &&
                            (state?.backgroundUploadProgress ?? 0) < 1)
                          Positioned(
                            bottom: 80,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: SnapFitColors.overlayStrongOf(context),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: state!.backgroundUploadProgress,
                                      color: const Color(0xFF8F6846),
                                      backgroundColor: Colors.white24,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '사진 업로드 중... ${(state.backgroundUploadProgress * 100).toInt()}%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // 전역 로딩 오버레이 (생성 플로우 전환용)
                        if (state?.isCreatingInBackground ?? false)
                          const PageEditorPreparingOverlay(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
    if (vm.syncKind == AlbumEditSyncKind.current) return editor;
    return Column(
      children: [
        _syncNotice(vm),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: editor,
          ),
        ),
      ],
    );
  }

  Widget _syncNotice(AlbumEditorViewModel vm) => Material(
    color: ExperienceFormStyle.surface(context),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              vm.syncKind == AlbumEditSyncKind.offline
                  ? '연결이 불안정해요. 편집 내용은 유지돼요.'
                  : '다른 사람이 먼저 저장했어요. 내 편집은 유지돼요.',
              style: ExperienceFormStyle.text(context, 13),
            ),
            TextButton(
              onPressed: () => vm.syncKind == AlbumEditSyncKind.offline
                  ? vm.checkRemoteAlbum()
                  : _confirmReload(vm),
              child: Text(
                vm.syncKind == AlbumEditSyncKind.offline ? '다시 확인' : '최신 내용 확인',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _confirmReload(AlbumEditorViewModel vm) async {
    final session = vm.editSessionIdentity;
    final actor = ref.read(albumEditorOwnerReaderProvider)();
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      routeSettings: editorModalRouteSettings(context),
      builder: (context) => AlertDialog(
        title: const Text('최신 앨범을 불러올까요?'),
        content: const Text(
          '편집한 내용은 아직 이 화면에 유지돼요. 최신 앨범을 불러오면 지금 편집한 내용과 되돌리기 기록은 사라져요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('편집 유지'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('버리고 불러오기'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        !identical(session, vm.editSessionIdentity) ||
        ref.read(albumEditorOwnerReaderProvider)() != actor)
      return;
    if (await vm.reloadAlbumDiscardingLocalChanges()) {
      if (!mounted || ref.read(albumEditorOwnerReaderProvider)() != actor)
        return;
      _entryCheckpoint = vm.captureEditCheckpoint();
      _interaction.resetForPageChange();
      setState(() {
        _lastSyncedPageIndex = null;
        _lastLayerSyncSignature = null;
        _currentMode = EditorMode.none;
      });
    } else if (mounted &&
        ref.read(albumEditorOwnerReaderProvider)() == actor &&
        identical(session, vm.editSessionIdentity)) {
      context.showErrorSnack(
        albumSaveErrorMessage(
          vm.lastSaveError ?? const AlbumEditAccessRevoked(),
        ),
      );
    }
  }

  Widget _readOnlyAfterAccessChange(AlbumEditorViewModel vm) =>
      WebUnsavedWorkGuard(
        hasUnsavedChanges: () =>
            vm.hasUnsavedChanges ||
            _hasUnsavedPhotoFillQueue ||
            _pendingDraftWrites > 0,
        child: WillPopScope(
          onWillPop: () => _handleWillPop(vm, vm.layers),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('앨범 편집'),
              leading: IconButton(
                tooltip: '편집 마치기',
                icon: const ExperienceIcon('ArrowLeft'),
                onPressed: () async {
                  if (await _handleWillPop(vm, vm.layers) && mounted)
                    Navigator.pop(context);
                },
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    const AlbumEditAccessRevoked().message,
                    style: ExperienceFormStyle.text(context, 14),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: vm.pages.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final page = vm.pages[index];
                          final width = math.min(640.0, constraints.maxWidth);
                          return Center(
                            child: AlbumReaderPageContent(
                              layers: page.layers,
                              targetW: width,
                              targetH: width / vm.selectedCover.ratio,
                              previewBuilder: _layerBuilder,
                              baseCanvasSize: Size(
                                kCoverReferenceWidth,
                                kCoverReferenceWidth / vm.selectedCover.ratio,
                              ),
                              backgroundColor: page.backgroundColor == null
                                  ? null
                                  : Color(page.backgroundColor!),
                              theme: page.isCover ? vm.selectedTheme : null,
                              flatPresentation: true,
                              isCover: page.isCover,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildWorkspaceFrame(BuildContext context, {required Widget child}) {
    // The album itself should be the visual object, matching Home/Reader.
    // Avoid a separate oversized editor card behind it.
    return Center(child: child);
  }

  Widget _buildEditorHint(BuildContext context, {required bool isCover}) {
    return Positioned(
      top: 104,
      left: 20,
      right: 20,
      child: IgnorePointer(
        child: SnapFitFadeIn(
          delay: const Duration(milliseconds: 220),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1E1CB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.touch_app_outlined,
                    size: 18,
                    color: const Color(0xFF8F6846),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isCover
                        ? '표지 사진·제목·레이어를 그대로 편집할 수 있어요.'
                        : '사진·레이아웃·템플릿·스티커·배경을 아래에서 바로 조정해요.',
                    style: TextStyle(
                      color: SnapFitColors.textSecondaryOf(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _handleWillPop(
    AlbumEditorViewModel vm,
    List<LayerModel> layers,
  ) async {
    if (_isSaving ||
        _exitPromptOpen ||
        _photoFillOpen ||
        _pendingDraftWrites > 0)
      return false;
    if (!vm.hasUnsavedChanges && !_hasUnsavedPhotoFillQueue) return true;

    _exitPromptOpen = true;
    final session = vm.editSessionIdentity;
    final actor = ref.read(albumEditorOwnerReaderProvider)();
    final revoked = vm.editingAccessRevoked;
    try {
      final result = await showDialog<String>(
        context: context,
        useRootNavigator: false,
        routeSettings: editorModalRouteSettings(context),
        builder: (ctx) {
          return AlertDialog(
            scrollable: _hasCreationDraft,
            title: Text(
              revoked
                  ? '편집을 마칠까요?'
                  : _hasCreationDraft
                  ? '편집을 마칠까요?'
                  : '변경 내용을 저장할까요?',
            ),
            content: Text(
              revoked
                  ? '편집 권한이 바뀌어 앨범에 저장할 수 없어요. 나가면 이 화면의 편집 내용은 사라져요.'
                  : _hasCreationDraft
                  ? _hasUnsavedPhotoFillQueue
                        ? '선택한 사진이 아직 임시 저장되지 않았어요.\n임시 저장한 선택은 이 기기에서 이어서 사용할 수 있어요.'
                        : '임시 저장은 이 기기에 남아요.\n앨범에는 저장 후 반영돼요.'
                  : '나가기 전에 편집한 내용을 저장하시겠어요?',
            ),
            actions: revoked
                ? [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, 'cancel'),
                      child: const Text('편집 유지'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, 'discard'),
                      child: const Text('버리고 나가기'),
                    ),
                  ]
                : _hasCreationDraft
                ? [_creationExitActions(ctx)]
                : [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('discard'),
                      child: const Text('저장 안함'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('cancel'),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('save'),
                      child: const Text('저장'),
                    ),
                  ],
          );
        },
      );
      if (!mounted ||
          !identical(session, vm.editSessionIdentity) ||
          ref.read(albumEditorOwnerReaderProvider)() != actor)
        return false;

      if (result == 'draft') {
        return await _saveCreationEditorDraft();
      }
      if (result == 'discard') {
        final checkpoint = _entryCheckpoint;
        // Replace any background checkpoint with the entry state, so discarded
        // edits cannot reappear when the user resumes from home.
        if (_hasCreationDraft &&
            checkpoint != null &&
            !await _saveCreationEditorDraft(
              checkpoint: checkpoint,
              notify: false,
            )) {
          if (mounted) context.showSnack('임시 저장을 정리하지 못했어요. 편집 내용은 유지돼요.');
          return false;
        }
        if (!mounted) return false;
        if (checkpoint != null) {
          vm.restoreEditCheckpoint(checkpoint);
          _photoFillQueue.reset();
          _photoFillQueue.pendingPhotos.addAll(
            _entryPhotoFillQueue.pendingPhotos,
          );
          _photoFillQueue.selectedPhoto = _entryPhotoFillQueue.selectedPhoto;
          _photoFillQueue.page = _entryPhotoFillQueue.page;
          _savedPhotoFillQueueRevision = _photoFillQueueRevision;
        }
        return true;
      }
      if (result == 'save') {
        // Saving handles its own destination; do not pop a second route.
        await _onSaveAlbum(vm, layers);
      }
      return false;
    } finally {
      _exitPromptOpen = false;
    }
  }

  Widget _creationExitActions(BuildContext dialogContext) {
    final wide = MediaQuery.sizeOf(dialogContext).width > 600;
    final draft = OutlinedButton(
      onPressed: () => Navigator.pop(dialogContext, 'draft'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: const StadiumBorder(),
      ),
      child: const Text('임시 저장 후 나가기', textAlign: TextAlign.center),
    );
    final save = FilledButton(
      onPressed: () => Navigator.pop(dialogContext, 'save'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: const StadiumBorder(),
      ),
      child: const Text('앨범 저장', textAlign: TextAlign.center),
    );
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            Row(
              children: [
                Expanded(child: draft),
                const SizedBox(width: 10),
                Expanded(child: save),
              ],
            )
          else ...[
            draft,
            const SizedBox(height: 8),
            save,
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext, 'discard'),
                  child: const Text('저장 안함'),
                ),
              ),
              Flexible(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext, 'cancel'),
                  child: const Text('계속 편집'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openDecorateSheetForLayer(LayerModel layer) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (layer.type == LayerType.image) {
      editPhotoFrame(context, ref, layer, layerBuilder: _layerBuilder).then((
        changed,
      ) {
        if (changed && mounted) setState(() {});
      });
    } else {
      final currentKey =
          vm.findLayerById(layer.id)?.textBackground ??
          layer.textBackground ??
          '';
      TextStylePickerSheet.show(context, currentKey: currentKey).then((key) {
        if (key != null && mounted) {
          vm.updateTextStyle(layer.id, key);
          setState(() {});
        }
      });
    }
  }

  Widget _buildInlineToolPanel(
    BuildContext context,
    EditorMode mode,
    List<LayerModel> layers, {
    bool fillAvailableHeight = false,
  }) {
    final title = switch (mode) {
      EditorMode.layout => '레이아웃',
      EditorMode.template => '템플릿',
      EditorMode.layer => '겹침 순서',
      EditorMode.sticker => '스티커',
      EditorMode.backgroundColor => '배경',
      _ => '',
    };
    final panel = switch (mode) {
      EditorMode.sticker => DecoratePanel(
        mode: DecorateSheetMode.sticker,
        onClose: () => setState(() => _currentMode = EditorMode.none),
      ),
      EditorMode.backgroundColor => DecoratePanel(
        mode: DecorateSheetMode.backgroundColor,
        onClose: () => setState(() => _currentMode = EditorMode.none),
      ),
      EditorMode.layer => LayerManagerPanel(
        layers: layers,
        interaction: _interaction,
        showHandle: false,
      ),
      EditorMode.layout => const TemplateSelectionPanel(
        title: '레이아웃',
        closeOnApply: false,
      ),
      EditorMode.template => const DesignTemplatePanel(closeOnApply: false),
      _ => const SizedBox.shrink(),
    };

    if (kIsWeb) {
      return ColoredBox(
        color: WebPalette.of(context).surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Text(
                mode == EditorMode.layer ? '겹침 순서 · ${layers.length}' : title,
                style: TextStyle(
                  color: WebPalette.of(context).ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Divider(height: 1, color: WebPalette.of(context).line),
            Expanded(child: panel),
          ],
        ),
      );
    }

    return _InlineEditorAtelierPanel(
      title: title,
      fillAvailableHeight: fillAvailableHeight,
      onClose: () => setState(() => _currentMode = EditorMode.none),
      child: panel,
    );
  }

  Future<void> _openWebEditorTool(EditorMode initialMode) async {
    if (!mounted || _webToolDialogOpen || _isSaving) return;
    final editorScope = ProviderScope.containerOf(context, listen: false);
    final pageId = ref
        .read(albumEditorViewModelProvider.notifier)
        .currentPage
        ?.id;
    setState(() {
      _webToolDialogOpen = true;
      _currentMode = initialMode;
    });
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: false,
        routeSettings: editorModalRouteSettings(context),
        builder: (_) => UncontrolledProviderScope(
          container: editorScope,
          child: WebEditorToolDialog(
            initialMode: initialMode,
            onModeChanged: (mode) {
              if (mounted) setState(() => _currentMode = mode);
            },
            panelBuilder: (toolContext, mode, close) => Consumer(
              builder: (context, toolRef, _) {
                final state = toolRef.watch(albumEditorViewModelProvider).value;
                final vm = toolRef.read(albumEditorViewModelProvider.notifier);
                if (vm.currentPage?.id != pageId) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('편집할 페이지가 변경됐어요. 창을 닫고 다시 열어주세요.'),
                    ),
                  );
                }
                return switch (mode) {
                  EditorMode.layer => LayerManagerPanel(
                    layers: state?.layers ?? const [],
                    interaction: _interaction,
                    showHandle: false,
                    onLayerSelected: (_) => close(),
                  ),
                  EditorMode.layout => const TemplateSelectionPanel(
                    title: '레이아웃',
                    showHeader: false,
                  ),
                  EditorMode.template => const DesignTemplatePanel(
                    showHeader: false,
                  ),
                  EditorMode.sticker => DecoratePanel(
                    mode: DecorateSheetMode.sticker,
                    onClose: close,
                  ),
                  EditorMode.backgroundColor => DecoratePanel(
                    mode: DecorateSheetMode.backgroundColor,
                    onClose: close,
                  ),
                  _ => const SizedBox.shrink(),
                };
              },
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _webToolDialogOpen = false;
          _currentMode = EditorMode.none;
        });
      }
    }
  }

  void _handleModeChange(EditorMode mode, List<LayerModel> layers) {
    if (_showEditorHint) {
      setState(() => _showEditorHint = false);
    }
    if (mode == EditorMode.none) {
      setState(() => _currentMode = mode);
      return;
    }

    if (mode == EditorMode.text) {
      setState(() => _currentMode = EditorMode.none);
      final vm = ref.read(albumEditorViewModelProvider.notifier);
      TextEditorManager(context, vm).openAndCreateNew();
      return;
    }

    if (kIsWeb) {
      unawaited(_openWebEditorTool(mode));
      return;
    }

    // 가로 모드: 사이드바 인라인 패널 사용
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final viewport = MediaQuery.sizeOf(context);
    if (isLandscape || (viewport.width >= 1100 && viewport.height >= 600)) {
      setState(() => _currentMode = mode);
      return;
    }

    // 세로 모드: 커버 편집과 동일하게 모달 바텀시트 사용
    setState(() => _currentMode = mode);
    final editorScope = ProviderScope.containerOf(context, listen: false);
    final openingVm = ref.read(albumEditorViewModelProvider.notifier);
    final session = openingVm.editSessionIdentity;
    final pageId = openingVm.currentPage?.id;
    final albumId = openingVm.editingAlbumId;
    showModalBottomSheet(
      context: context,
      routeSettings: editorModalRouteSettings(context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final panel = switch (mode) {
          EditorMode.sticker => const DecoratePanel(
            mode: DecorateSheetMode.sticker,
          ),
          EditorMode.backgroundColor => const DecoratePanel(
            mode: DecorateSheetMode.backgroundColor,
          ),
          EditorMode.layer => Consumer(
            builder: (context, sheetRef, _) {
              final state = sheetRef.watch(albumEditorViewModelProvider).value;
              final vm = sheetRef.read(albumEditorViewModelProvider.notifier);
              if (!identical(vm.editSessionIdentity, session) ||
                  vm.currentPage?.id != pageId ||
                  vm.editingAlbumId != albumId) {
                return const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('편집할 페이지가 변경됐어요. 다시 열어주세요.'),
                  ),
                );
              }
              return LayerManagerPanel(
                layers: state?.layers ?? const [],
                interaction: _interaction,
              );
            },
          ),
          EditorMode.layout => const TemplateSelectionPanel(title: '레이아웃'),
          EditorMode.template => const DesignTemplatePanel(closeOnApply: false),
          _ => const SizedBox.shrink(),
        };
        return UncontrolledProviderScope(container: editorScope, child: panel);
      },
    ).then((_) {
      if (mounted) setState(() => _currentMode = EditorMode.none);
    });
  }
}

class _EditorToolPanelReveal extends StatelessWidget {
  const _EditorToolPanelReveal({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: SnapFitMotion.entrance,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: Transform.scale(
              scale: 0.985 + (0.015 * value),
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _InlineEditorAtelierPanel extends StatelessWidget {
  const _InlineEditorAtelierPanel({
    required this.title,
    required this.onClose,
    required this.child,
    this.fillAvailableHeight = false,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final bool fillAvailableHeight;

  @override
  Widget build(BuildContext context) {
    final borderColor = ExperienceFormStyle.line(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('editorAtelierPanel'),
        height: fillAvailableHeight
            ? null
            : MediaQuery.sizeOf(context).height * .50,
        decoration: BoxDecoration(
          color: ExperienceFormStyle.surface(context),
          borderRadius: BorderRadius.circular(SnapFitRadius.lg),
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SnapFitRadius.lg),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        child is LayerManagerPanel
                            ? '$title · ${(child as LayerManagerPanel).layers.length}'
                            : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExperienceFormStyle.text(
                          context,
                          13,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '편집 도구 닫기',
                      onPressed: onClose,
                      icon: Transform.rotate(
                        angle: math.pi / 4,
                        child: const ExperienceIcon('Plus', size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: borderColor.withValues(alpha: 0.78),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: SnapFitMotion.fast,
                  switchInCurve: SnapFitMotion.entrance,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(key: ValueKey(title), child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
