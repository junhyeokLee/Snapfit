import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../data/gallery/browser_photo_asset.dart';
import '../../../domain/entities/album_photo_fill_draft.dart';
import '../../../domain/entities/layer.dart';
import '../../providers/album_edit_session_provider.dart';
import '../../controllers/editor_canvas_coordinates.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../create_flow/template_photo_fill_step.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';

class EditorPhotoFillResult {
  EditorPhotoFillResult({
    required List<List<LayerModel>> pages,
    required List<AssetEntity> pendingPhotos,
    required this.selectedPhoto,
    required this.pageIndex,
  }) : pages = [for (final page in pages) List<LayerModel>.of(page)],
       pendingPhotos = List<AssetEntity>.of(pendingPhotos);

  final List<List<LayerModel>> pages;
  final List<AssetEntity> pendingPhotos;
  final AssetEntity? selectedPhoto;
  final int pageIndex;
}

/// 사진을 채우는 동안 원래 앨범을 바꾸지 않고, 적용한 결과만 돌려준다.
class EditorPhotoFillScreen extends ConsumerStatefulWidget {
  const EditorPhotoFillScreen({
    super.key,
    required this.draft,
    this.initialSession,
  });

  final AlbumPhotoFillDraft draft;
  final TemplatePhotoFillSession? initialSession;

  @override
  ConsumerState<EditorPhotoFillScreen> createState() =>
      _EditorPhotoFillScreenState();
}

class _EditorPhotoFillScreenState extends ConsumerState<EditorPhotoFillScreen> {
  late final AlbumEditorViewModel _vm;
  late final TemplatePhotoFillSession _session;
  late final ValueNotifier<List<List<LayerModel>>> _pages;
  late final List<Color?> _pageBackgroundColors;
  final _toolsNavigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _vm = ref.read(albumEditorViewModelProvider.notifier);
    _pageBackgroundColors = List<Color?>.unmodifiable([
      for (final page in _vm.pages)
        page.backgroundColor == null ? null : Color(page.backgroundColor!),
    ]);
    _pages = ValueNotifier([
      for (final page in widget.draft.pages) List<LayerModel>.of(page),
    ]);
    final initial = widget.initialSession;
    _session = TemplatePhotoFillSession()
      ..page = initial?.page ?? widget.draft.pageIndex;
    _session.pendingPhotos.addAll(
      initial?.pendingPhotos.where(
            (photo) =>
                photo is! BrowserPhotoAsset ||
                photo.ownerId == widget.draft.ownerId,
          ) ??
          const <AssetEntity>[],
    );
    _session.selectedPhoto =
        _session.pendingPhotos
            .where((photo) => photo.id == initial?.selectedPhoto?.id)
            .firstOrNull ??
        _session.pendingPhotos.firstOrNull;
  }

  bool _current() =>
      mounted &&
      identical(ref.read(albumEditorViewModelProvider.notifier), _vm) &&
      _vm.isPhotoFillCurrent(widget.draft);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<bool> _handleBack() async {
    final navigator = _toolsNavigator.currentState;
    if (navigator != null && navigator.canPop()) {
      await navigator.maybePop();
      return false;
    }
    return true;
  }

  void _apply() {
    if (!_current()) return;
    Navigator.of(context).pop(
      EditorPhotoFillResult(
        pages: _pages.value,
        pendingPhotos: _session.pendingPhotos,
        selectedPhoto: _session.selectedPhoto,
        pageIndex: _session.page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(albumEditorViewModelProvider);
    ref.watch(albumCurrentSessionOwnerProvider);
    ref.watch(albumEditSyncStatusProvider);
    final current = _current();
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        key: const ValueKey('editor-photo-fill-workspace'),
        backgroundColor: AlbumStageStyle.top(context),
        appBar: AppBar(
          backgroundColor: AlbumStageStyle.top(context),
          surfaceTintColor: Colors.transparent,
          title: Text(
            '사진 여러 장 넣기',
            style: ExperienceFormStyle.text(
              context,
              16,
              weight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            key: const ValueKey('editor-photo-fill-cancel'),
            tooltip: '사진 도구 닫기',
            onPressed: () => Navigator.of(context).pop(),
            icon: const ExperienceIcon('X'),
          ),
        ),
        body: current
            ? KeyedSubtree(
                key: const ValueKey('editor-photo-fill-owned-navigation'),
                child: HeroControllerScope.none(
                  child: Navigator(
                    key: _toolsNavigator,
                    onGenerateRoute: (_) => snapFitRoute<void>(page: ValueListenableBuilder<List<List<LayerModel>>>(
                            valueListenable: _pages,
                            builder: (context, pages, _) =>
                                TemplatePhotoFillStep(
                                  pages: pages,
                                  pageBackgroundColors: _pageBackgroundColors,
                                  cover: widget.draft.cover,
                                  canvasSize: editorReferenceCanvasSize(
                                    widget.draft.cover,
                                  ),
                                  session: _session,
                                  preserveTypography: true,
                                  enableAutoFill: true,
                                  continueLabel: '편집기에 적용',
                                  currentOwner: () =>
                                      _current() ? widget.draft.ownerId : null,
                                  onChanged: (pages) {
                                    if (_current()) {
                                      _pages.value = [
                                        for (final page in pages)
                                          List<LayerModel>.of(page),
                                      ];
                                    }
                                  },
                                  onContinue: _apply,
                                ),
                          )),
                  ),
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '앨범이나 계정이 변경됐어요. 사진 도구를 닫고 다시 열어주세요.',
                        textAlign: TextAlign.center,
                        style: ExperienceFormStyle.text(context, 14),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
