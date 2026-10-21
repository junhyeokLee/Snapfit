import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../shared/widgets/editor_modal_scope.dart';
import '../../data/album_creation_draft_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/album_save_progress.dart';
import '../../domain/entities/album_creation_draft.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart' show SnapFitRadius;
import '../../../../core/constants/cover_size.dart';
import '../../../../shared/widgets/album_stage_style.dart';
import '../../../../core/utils/screen_logger.dart';
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
                      color: Colors.black.withOpacity(
                        (0.16 * (1 - t) + 0.045 * settlePulse).clamp(0.0, 0.18),
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
  });

  final bool returnToPreviousOnSave;
  final String? creationDraftId;
  final String? creationDraftOwner;

  @override
  ConsumerState<PageEditorScreen> createState() => _PageEditorScreenState();
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

  // 저장 진행률 상태
  bool _isSaving = false;
  AlbumSaveProgress _saveStatus = const AlbumSaveProgress(
    AlbumSavePhase.preparing,
  );
  AlbumEditCheckpoint? _entryCheckpoint;
  bool _exitPromptOpen = false;
  Timer? _editorHintTimer;
  int? _lastSyncedPageIndex;
  int? _initialSelectionPageIndex;
  String? _pendingInitialSelectedLayerId;
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _editorHintTimer?.cancel();
    _interaction.dispose();
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
      final maxIdx = vm.pages.length - 1;
      final pageIndex = idx.clamp(0, maxIdx > 0 ? maxIdx : 0);
      vm.goToPage(pageIndex);
      _initialSelectionPageIndex = pageIndex;
      _pendingInitialSelectedLayerId = idx == pageIndex
          ? widget.initialSelectedLayerId
          : null;
      setState(() {});
      if (widget.initialMaterialKey != null) {
        unawaited(_insertInitialMaterial(widget.initialMaterialKey!));
      }
    });
  }

  void _selectInitialPhotoIfReady() {
    final id = _pendingInitialSelectedLayerId;
    final targetPage = _initialSelectionPageIndex;
    if (id == null || targetPage == null) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (_lastSyncedPageIndex != targetPage ||
        vm.currentPageIndex != targetPage) {
      return;
    }
    _pendingInitialSelectedLayerId = null;
    _initialSelectionPageIndex = null;
    final photo = vm.currentPage?.layers
        .where((layer) => layer.id == id && layer.type == LayerType.image)
        .firstOrNull;
    if (photo != null) _interaction.setSelectedLayer(photo.id);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 소재를 넣었어요. 저장하면 앨범에 반영돼요.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('소재를 넣지 못했어요. 편집 도구에서 다시 선택해 주세요.')),
        );
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        _hasCreationDraft &&
        _entryCheckpoint != null &&
        !_isSaving &&
        !_exitPromptOpen) {
      unawaited(_saveCreationEditorDraft(notify: false));
    }
  }

  Future<bool> _saveCreationEditorDraft({
    bool notify = true,
    AlbumEditCheckpoint? checkpoint,
  }) {
    final owner = widget.creationDraftOwner;
    final draftId = widget.creationDraftId;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final albumId = checkpoint?.albumId ?? vm.editingAlbumId;
    final cover = checkpoint?.cover ?? vm.selectedCover;
    if (owner == null ||
        draftId == null ||
        albumId == null ||
        ref.read(authViewModelProvider).asData?.value?.id != owner) {
      if (notify && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인한 계정을 확인해 주세요. 편집 내용은 유지돼요.')),
        );
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
          );
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
          if (mounted &&
              ref.read(authViewModelProvider).asData?.value?.id != owner) {
            throw StateError('Draft account changed');
          }
          return draft.withEditorCheckpoint(draftCheckpoint, cover: cover);
        });
        if (!written) throw StateError('Linked draft no longer exists');
        if (mounted) {
          _lastDraftSavedAt = DateTime.now();
          ref.invalidate(albumCreationDraftProvider);
          if (notify)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('이 기기에 임시 저장했어요. 홈에서 이어 만들 수 있어요.')),
            );
        }
        return true;
      } catch (_) {
        if (mounted) {
          _draftWriteFailed = true;
          if (notify)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('임시 저장하지 못했어요. 편집 내용은 유지돼요. 다시 시도해 주세요.'),
              ),
            );
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
    if (_isSaving || (kIsWeb && _interaction.isInteractingNow)) return;

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
        await _saveCreationEditorDraft(notify: false);
        if (!mounted) return;
      }

      // 2. 서버 저장
      Uint8List? coverCapture;
      try {
        coverCapture = await _coverEditorKey.currentState?.captureCoverBytes();
      } catch (e) {
        debugPrint('Failed to capture cover in Screen: $e');
      }

      final isSuccess = await vm.saveFullAlbum(
        coverImageBytes: coverCapture,
        onProgress: (value) {
          if (mounted) setState(() => _saveStatus = value);
        },
      );
      if (!isSuccess) {
        throw vm.lastSaveError ?? StateError('앨범 저장에 실패했습니다.');
      }

      if (context.mounted && isSuccess) {
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
        if (!mounted) return;
        // 3. 홈 화면 갱신 및 이동
        // Refresh when observed, without holding navigation on a network request.
        ref.invalidate(homeViewModelProvider);

        // popUntil 이전에 캡처해야 한다. popUntil 이후 context는 deactivated 상태가
        // 되어 SnackBar 애니메이션 완료 시점에 ancestor 조회가 실패한다.
        final messenger = ScaffoldMessenger.of(context);
        if (widget.returnToPreviousOnSave && Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
        messenger.showSnackBar(SnackBar(content: Text(savedMessage)));
      }
    } catch (e) {
      if (e is StorageQuotaExceededException && context.mounted) {
        setState(() => _isSaving = false);
        await _showQuotaExceededSheet(context);
        return;
      }
      if (context.mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(albumSaveErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          '페이지 삭제',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        content: Text(
          vm.deleteCurrentPageDescription,
          style: TextStyle(
            fontSize: 14.sp,
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
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final state = asyncState.value;
    final canUndo = state?.canUndo ?? false;
    final canRedo = state?.canRedo ?? false;
    final viewport = MediaQuery.sizeOf(context);
    final desktopWorkspace = viewport.width >= 1100 && viewport.height >= 600;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('빈 내지 $addedPages쪽을 추가했어요.')));
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
        ),
      );
    }

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
                        icon: const Icon(Icons.undo, size: 21),
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
                        icon: const Icon(Icons.redo, size: 21),
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
                          '레이어',
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
              tool('레이어', Icons.layers_outlined, EditorMode.layer),
              tool('레이아웃', Icons.dashboard_outlined, EditorMode.layout),
              tool('템플릿', Icons.grid_view_outlined, EditorMode.template),
              tool('꾸미기', Icons.interests_outlined, EditorMode.sticker),
              tool('배경', Icons.palette_outlined, EditorMode.backgroundColor),
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

    return WebUnsavedWorkGuard(
      hasUnsavedChanges: () =>
          ref.read(albumEditorViewModelProvider.notifier).hasUnsavedChanges,
      child: EditorKeyboardShortcuts(
        enabled:
            !_isSaving &&
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
                          : '$currentPageIndex쪽',
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
                          label: Text(desktopWorkspace ? '앨범 저장' : '저장'),
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
                                  if (_interaction.selectedLayerId != null)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        8,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 110,
                                        ),
                                        child: SingleChildScrollView(
                                          child: buildLayerActions(),
                                        ),
                                      ),
                                    ),
                                  buildBottomMenu(),
                                ],
                              );
                            },
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
                            bottom: 80.h,
                            left: 16.w,
                            right: 16.w,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color: SnapFitColors.overlayStrongOf(context),
                                borderRadius: BorderRadius.circular(999.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 14.r,
                                    height: 14.r,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: state!.backgroundUploadProgress,
                                      color: const Color(0xFF8F6846),
                                      backgroundColor: Colors.white24,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    '사진 업로드 중... ${(state.backgroundUploadProgress * 100).toInt()}%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
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
  }

  Widget _buildWorkspaceFrame(BuildContext context, {required Widget child}) {
    // The album itself should be the visual object, matching Home/Reader.
    // Avoid a separate oversized editor card behind it.
    return Center(child: child);
  }

  Widget _buildEditorHint(BuildContext context, {required bool isCover}) {
    return Positioned(
      top: 104.h,
      left: 20.w,
      right: 20.w,
      child: IgnorePointer(
        child: SnapFitFadeIn(
          delay: const Duration(milliseconds: 220),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context).withOpacity(0.94),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1E1CB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.touch_app_outlined,
                    size: 18.sp,
                    color: const Color(0xFF8F6846),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    isCover
                        ? '표지 사진·제목·레이어를 그대로 편집할 수 있어요.'
                        : '사진·레이아웃·템플릿·스티커·배경을 아래에서 바로 조정해요.',
                    style: TextStyle(
                      color: SnapFitColors.textSecondaryOf(context),
                      fontSize: 12.sp,
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
    if (_isSaving || _exitPromptOpen) return false;
    if (!vm.hasUnsavedChanges) return true;

    _exitPromptOpen = true;
    try {
      final result = await showDialog<String>(
        context: context,
        useRootNavigator: false,
        routeSettings: editorModalRouteSettings(context),
        builder: (ctx) {
          return AlertDialog(
            scrollable: _hasCreationDraft,
            title: Text(_hasCreationDraft ? '편집을 마칠까요?' : '변경 내용을 저장할까요?'),
            content: Text(
              _hasCreationDraft
                  ? '임시 저장은 이 기기에 남아요.\n앨범에는 저장 후 반영돼요.'
                  : '나가기 전에 편집한 내용을 저장하시겠어요?',
            ),
            actions: _hasCreationDraft
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
      if (!mounted) return false;

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
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('임시 저장을 정리하지 못했어요. 편집 내용은 유지돼요.')),
            );
          return false;
        }
        if (!mounted) return false;
        if (checkpoint != null) vm.restoreEditCheckpoint(checkpoint);
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
      EditorMode.layer => '레이어',
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
                mode == EditorMode.layer ? '레이어 · ${layers.length}' : title,
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
          EditorMode.layer => LayerManagerPanel(
            layers: layers,
            interaction: _interaction,
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
                color: borderColor.withOpacity(0.78),
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
