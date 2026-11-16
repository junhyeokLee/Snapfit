import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../data/api/album_provider.dart';
import '../../data/api/storage_service.dart';
import '../../data/gallery/browser_photo_asset.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/album_photo_fill_draft.dart';
import '../../domain/entities/album_source_template.dart';
import '../../domain/entities/album_edit_failure.dart';
import '../../data/dto/request/create_album_request.dart';
import '../../domain/entities/album_page.dart';
import '../../domain/entities/album_creation_draft.dart';
import '../../domain/entities/album_creation_attempt.dart';
import '../../domain/entities/album_save_progress.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/album_page_policy.dart';
import '../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../core/templates/studio_word_art_catalog.dart';
import '../../../../core/constants/design_templates.dart';
import '../../../../core/constants/cover_theme.dart';
import '../../../../core/constants/page_templates.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/layer_export_mapper.dart';
import 'cover_view_model.dart';
import 'album_view_model.dart';
import '../providers/album_edit_session_provider.dart';
import '../../domain/repositories/album_repository.dart';
import '../../service/album_persistence_service.dart';
import '../../service/album_editor_service.dart'; // Restore import

part 'album_editor_view_model.freezed.dart';
part 'album_editor_view_model.g.dart';

class _AlbumSaveAttempt {
  const _AlbumSaveAttempt({
    required this.albumId,
    required this.actor,
    required this.expectedUpdatedAt,
    required this.requestId,
    required this.request,
  });

  final int albumId;
  final String actor;
  final String expectedUpdatedAt;
  final String requestId;
  final CreateAlbumRequest request;
}

class _AlbumPhotoFillSnapshot {
  _AlbumPhotoFillSnapshot(AlbumEditorViewModel editor)
    : pages = [
        for (final page in editor._pages)
          page.copyWith(layers: List<LayerModel>.unmodifiable(page.layers)),
      ],
      sourceAlbum = editor._sourceAlbum,
      productKey = editor._sourceTemplateProductKey,
      theme = editor._selectedTheme,
      coverCanvas = editor._lastCoverCanvasSize,
      innerCanvas = editor._lastInnerCanvasSize,
      targetPages = editor._targetPagesHint,
      title = editor._initialAlbumTitle;

  final List<AlbumPage> pages;
  final Album? sourceAlbum;
  final String? productKey, title;
  final CoverTheme theme;
  final Size coverCanvas, innerCanvas;
  final int targetPages;
}

/// 갤러리 + 편집 상태 (MVVM)
@freezed
abstract class AlbumEditorState with _$AlbumEditorState {
  const factory AlbumEditorState({
    /// 현재 페이지의 레이어들(UI가 바로 그릴 데이터)
    @Default([]) List<LayerModel> layers,

    @Default(defaultCoverSize) CoverSize selectedCover,

    @Default(CoverTheme.classic) CoverTheme selectedTheme,

    /// 에디터 커버 캔버스 크기 (레이어 좌표 기준). 썸네일/스프레드 배치용.
    Size? coverCanvasSize,

    /// 내지 캔버스 크기 (3:4 비율)
    Size? innerCanvasSize,

    /// 백그라운드에서 앨범 생성(업로드) 중인지 여부
    @Default(false) bool isCreatingInBackground,

    /// 백그라운드 이미지 업로드 진행률 (0.0 ~ 1.0)
    @Default(0.0) double backgroundUploadProgress,

    /// 되돌리기/다시하기 가능 여부 (현재 페이지 기준)
    @Default(false) bool canUndo,
    @Default(false) bool canRedo,
  }) = _AlbumEditorState;
}

class AlbumEditCheckpoint {
  const AlbumEditCheckpoint._({
    required this.albumId,
    required this.pages,
    required this.undo,
    required this.redo,
    required this.pageIndex,
    required this.cover,
    required this.theme,
    required this.hasChanges,
    required this.coverCanvas,
    required this.innerCanvas,
    required this.editorState,
    required this.sourceAlbum,
    required this.sessionIdentity,
    required this.actor,
    required this.sourceTemplateProductKey,
  });

  final int? albumId;
  final List<AlbumPage> pages;
  final Map<int, List<AlbumPage>> undo;
  final Map<int, List<AlbumPage>> redo;
  final int pageIndex;
  final CoverSize cover;
  final CoverTheme theme;
  final bool hasChanges;
  final Size coverCanvas;
  final Size innerCanvas;
  final AlbumEditorState? editorState;
  final Album? sourceAlbum;
  final Object sessionIdentity;
  final String? actor;
  final String? sourceTemplateProductKey;
}

@Riverpod(keepAlive: true)
class AlbumEditorViewModel extends _$AlbumEditorViewModel {
  static const pageLimitMessage =
      '앨범 내지는 최대 80쪽까지 사용할 수 있어요. 페이지를 줄인 뒤 다시 적용해주세요.';
  late final AlbumEditorService _service;
  late final AlbumPersistenceService _persistence;
  late final StorageService _storage;
  late final AlbumRepository _albumRepository;

  final List<AlbumPage> _pages = [];
  final _photoFillSnapshots = Expando<_AlbumPhotoFillSnapshot>('photo-fill');
  Object _editSessionIdentity = Object();

  /// Page IDs are reused in new drafts. Transient editor tools must also match
  /// this identity before applying a result to the current editing session.
  Object get editSessionIdentity => _editSessionIdentity;
  int _currentPageIndex = 0;
  int? _editingAlbumId;
  Album? _sourceAlbum;
  String? _editingActor;
  _AlbumSaveAttempt? _pendingSaveAttempt;
  AlbumCreationAttempt? _pendingCreationAttempt;
  String? _creationDraftOwner, _creationDraftId;
  Future<void> Function(AlbumCreationAttempt)? _persistCreationAttempt;
  Object? _activeSaveIdentity;
  bool _disposed = false;
  bool _checkingRemote = false;
  final Set<String> _uncommittedUploads = {};
  late final AlbumEditorOwnerReader _readOwner;
  int _targetPagesHint = 0;
  String? _pendingCoverLayersJson;
  List<List<LayerModel>>? _pendingTemplatePagesAfterLoad;
  String? _initialCoverImageUrl;
  String? _initialCoverThumbnailUrl;
  String? _initialAlbumTitle;
  String? _sourceTemplateProductKey;
  String? _pendingTemplateProductKeyAfterLoad;

  CoverTheme _selectedTheme = CoverTheme.classic;
  CoverSize _cover = defaultCoverSize;

  /// [Rescale Fix] 커버와 내지의 마지막 캔버스 크기를 별도로 관리하여 왜곡 방지
  Size _lastCoverCanvasSize = Size.zero;
  Size _lastInnerCanvasSize = Size.zero;

  // ===== Undo / Redo (현재 페이지 기준) =====
  static const int _maxHistory = 30;
  final _singlePageCanvases = Expando<Size>('local-single-page-canvas');
  Object? _singlePageDraftSession;
  bool get _isSinglePageDraft =>
      _singlePageDraftSession != null &&
      identical(_singlePageDraftSession, _editSessionIdentity) &&
      _editingAlbumId == null &&
      _pages.length == 1 &&
      _pages.single.id == 'local-single-page';
  final Map<int, List<AlbumPage>> _undoByPage = {};
  final Map<int, List<AlbumPage>> _redoByPage = {};
  bool _historyLocked = false; // undo/redo 적용 중 기록 방지
  bool _hasUnsavedChanges = false;
  Object? _lastSaveError;
  bool _isSaving = false;

  bool get hasUnsavedChanges => _hasUnsavedChanges;
  Object? get lastSaveError => _lastSaveError;

  /// Bind only after resetting a new editor. A restored command is immutable,
  /// while the visible document can keep changing before a safe retry.
  void bindCreationDraft({
    required String ownerId,
    required String draftId,
    AlbumCreationAttempt? attempt,
    required Future<void> Function(AlbumCreationAttempt) persist,
  }) {
    if (ownerId.isEmpty ||
        draftId.isEmpty ||
        attempt != null &&
            (attempt.ownerId != ownerId || attempt.draftId != draftId)) {
      throw const AlbumEditSessionChanged();
    }
    _creationDraftOwner = ownerId;
    _creationDraftId = draftId;
    _pendingCreationAttempt = attempt;
    _persistCreationAttempt = persist;
  }

  AlbumEditCheckpoint captureEditCheckpoint() => AlbumEditCheckpoint._(
    albumId: _editingAlbumId,
    pages: _pages.map(_clonePage).toList(),
    undo: _copyHistory(_undoByPage),
    redo: _copyHistory(_redoByPage),
    pageIndex: _currentPageIndex,
    cover: _cover,
    theme: _selectedTheme,
    hasChanges: _hasUnsavedChanges,
    coverCanvas: _lastCoverCanvasSize,
    innerCanvas: _lastInnerCanvasSize,
    editorState: state.value,
    sourceAlbum: _sourceAlbum,
    sessionIdentity: _editSessionIdentity,
    actor: _editingActor,
    sourceTemplateProductKey: _sourceTemplateProductKey,
  );

  AlbumCreationEditorCheckpoint captureCreationEditorCheckpoint() =>
      AlbumCreationEditorCheckpoint(
        pages: _pages,
        pageIndex: _currentPageIndex,
        coverCanvas: _lastCoverCanvasSize == Size.zero
            ? _coverReferenceSize
            : _lastCoverCanvasSize,
        innerCanvas: _lastInnerCanvasSize == Size.zero
            ? _innerPageCanvasSize
            : _lastInnerCanvasSize,
        theme: _selectedTheme,
        sourceUpdatedAt: _sourceAlbum?.updatedAt,
        sourceOwnerId: _sourceAlbum?.userId,
        sourceMemberRole: _sourceAlbum?.memberRole,
        sourceTemplateProductKey: _sourceTemplateProductKey,
      );

  Map<int, List<AlbumPage>> _copyHistory(Map<int, List<AlbumPage>> history) => {
    for (final entry in history.entries)
      entry.key: entry.value.map(_clonePage).toList(),
  };

  void restoreEditCheckpoint(AlbumEditCheckpoint checkpoint) {
    if (_isSaving ||
        checkpoint.albumId != _editingAlbumId ||
        !identical(checkpoint.sessionIdentity, _editSessionIdentity) ||
        checkpoint.actor != _editingActor ||
        checkpoint.actor != _readOwner())
      return;
    final accessRevoked = editingAccessRevoked;
    _beginSession(checkpoint.sourceAlbum);
    _sourceTemplateProductKey = checkpoint.sourceTemplateProductKey;
    if (accessRevoked && _editingAlbumId != null) {
      _sourceAlbum = _sourceAlbum?.copyWith(memberRole: 'VIEWER');
      _syncStatus(AlbumEditSyncKind.accessRevoked);
    }
    _pages
      ..clear()
      ..addAll(checkpoint.pages.map(_clonePage));
    _undoByPage
      ..clear()
      ..addAll(_copyHistory(checkpoint.undo));
    _redoByPage
      ..clear()
      ..addAll(_copyHistory(checkpoint.redo));
    _currentPageIndex = checkpoint.pageIndex;
    _cover = checkpoint.cover;
    _selectedTheme = checkpoint.theme;
    _hasUnsavedChanges = checkpoint.hasChanges;
    _lastCoverCanvasSize = checkpoint.coverCanvas;
    _lastInnerCanvasSize = checkpoint.innerCanvas;
    _targetPagesHint = innerPageCount;
    state = AsyncData(checkpoint.editorState ?? const AlbumEditorState());
    ref.read(coverViewModelProvider.notifier).selectCover(_cover);
    ref.read(coverViewModelProvider.notifier).updateTheme(_selectedTheme);
    _emit();
  }

  // ===== Selected getters =====
  CoverSize get selectedCover => _cover;
  CoverTheme get selectedTheme => _selectedTheme;

  // Expose the album being edited (if any)
  Album? get album => _sourceAlbum;

  bool get editingAllowed =>
      (_sourceAlbum?.allowsEditing ?? _editingAlbumId == null) &&
      syncKind != AlbumEditSyncKind.accessRevoked;

  AlbumEditSyncKind get syncKind {
    final status = ref.read(albumEditSyncStatusProvider);
    return status.albumId == _editingAlbumId
        ? status.kind
        : AlbumEditSyncKind.current;
  }

  bool get hasRemoteChanges => syncKind == AlbumEditSyncKind.remoteChanged;

  /// Expose existing conflict recovery without accepting any newer revision or
  /// replacing the local creation document with server content.
  void showCreatedAlbumConflict() {
    if (_editingAlbumId == null || _editingActor != _readOwner()) return;
    _lastSaveError = const AlbumRevisionConflict();
    _hasUnsavedChanges = true;
    _syncStatus(AlbumEditSyncKind.remoteChanged);
    _emit();
  }

  bool get editingAccessRevoked => !editingAllowed;

  /// 별도 화면에서 선택한 사진은 명시적으로 적용하기 전까지 원본과 격리한다.
  AlbumPhotoFillDraft? beginPhotoFill() {
    if (_disposed || _isSaving || _pages.isEmpty) return null;
    final owner = _readOwner();
    if (owner == null ||
        owner.trim().isEmpty ||
        owner != _editingActor ||
        !editingAllowed ||
        _pendingCoverLayersJson != null ||
        _pendingTemplatePagesAfterLoad != null) {
      return null;
    }
    final draft = AlbumPhotoFillDraft(
      pages: [for (final page in _pages) page.layers],
      cover: _cover,
      pageIndex: _currentPageIndex,
      ownerId: owner,
      sessionIdentity: _editSessionIdentity,
      albumId: _editingAlbumId,
    );
    // 작업본의 가변 목록을 원본 비교 기준으로 사용하지 않는다.
    _photoFillSnapshots[draft] = _AlbumPhotoFillSnapshot(this);
    return draft;
  }

  bool isPhotoFillCurrent(AlbumPhotoFillDraft draft) {
    if (_disposed ||
        _isSaving ||
        !identical(draft.sessionIdentity, _editSessionIdentity) ||
        draft.albumId != _editingAlbumId ||
        draft.ownerId != _editingActor ||
        draft.ownerId != _readOwner() ||
        !editingAllowed) {
      return false;
    }
    final original = _photoFillSnapshots[draft];
    if (original == null ||
        draft.cover.name != _cover.name ||
        draft.cover.ratio != _cover.ratio ||
        draft.cover.realSize != _cover.realSize ||
        draft.cover.productId != _cover.productId ||
        original.sourceAlbum != _sourceAlbum ||
        original.productKey != _sourceTemplateProductKey ||
        original.theme != _selectedTheme ||
        original.coverCanvas != _lastCoverCanvasSize ||
        original.innerCanvas != _lastInnerCanvasSize ||
        original.targetPages != _targetPagesHint ||
        original.title != _initialAlbumTitle ||
        original.pages.length != _pages.length ||
        _pendingCoverLayersJson != null ||
        _pendingTemplatePagesAfterLoad != null) {
      return false;
    }
    for (var page = 0; page < _pages.length; page++) {
      final before = original.pages[page];
      final current = _pages[page];
      if (before.id != current.id ||
          before.pageIndex != current.pageIndex ||
          before.isCover != current.isCover ||
          before.backgroundColor != current.backgroundColor ||
          before.layers.length != current.layers.length) {
        return false;
      }
      for (var layer = 0; layer < before.layers.length; layer++) {
        if (!identical(before.layers[layer], current.layers[layer]))
          return false;
      }
    }
    return true;
  }

  /// 모든 반환값을 먼저 검증한 뒤 변경된 페이지의 기존 히스토리에만 기록한다.
  bool applyPhotoFill(AlbumPhotoFillDraft draft, List<List<LayerModel>> pages) {
    if (!isPhotoFillCurrent(draft) || pages.length != _pages.length)
      return false;
    final replacements = <int, List<LayerModel>>{};
    for (var page = 0; page < _pages.length; page++) {
      final current = _pages[page].layers;
      final staged = pages[page];
      if (current.length != staged.length) return false;
      final next = List<LayerModel>.of(current);
      var changed = false;
      for (var layer = 0; layer < current.length; layer++) {
        final before = current[layer];
        final after = staged[layer];
        if (!_photoFillStructureMatches(before, after)) return false;
        final asset = after.asset;
        if (asset is BrowserPhotoAsset && asset.ownerId != draft.ownerId) {
          return false;
        }
        final samePhoto =
            _photoFillSourceMatches(before, after) &&
            before.imageOffset == after.imageOffset &&
            before.imageZoom == after.imageZoom;
        if (before.type != LayerType.image) {
          if (!samePhoto ||
              before.isTemplateContent != after.isTemplateContent) {
            return false;
          }
          continue;
        }
        if (!after.imageZoom.isFinite ||
            after.imageZoom <= 0 ||
            after.imageOffset != null &&
                (!after.imageOffset!.dx.isFinite ||
                    !after.imageOffset!.dy.isFinite) ||
            before.isTemplateContent != after.isTemplateContent &&
                (after.isTemplateContent != false ||
                    _photoFillSourceMatches(before, after))) {
          return false;
        }
        // 사진 도구는 원격 URL을 새로 만들지 않고 기존 원본을 유지/제거한다.
        if (after.imageUrl != null && after.imageUrl != before.imageUrl ||
            after.originalUrl != null &&
                after.originalUrl != before.originalUrl ||
            after.previewUrl != null && after.previewUrl != before.previewUrl) {
          return false;
        }
        if (!samePhoto || before.isTemplateContent != after.isTemplateContent) {
          next[layer] = after;
          changed = true;
        }
      }
      if (changed) replacements[page] = next;
    }
    for (final entry in replacements.entries) {
      _recordPageUndo(entry.key, skipDuplicate: false);
      _pages[entry.key] = _pages[entry.key].copyWith(layers: entry.value);
    }
    if (replacements.isNotEmpty) _emit();
    return true;
  }

  bool _photoFillSourceMatches(LayerModel a, LayerModel b) =>
      identical(a.asset, b.asset) &&
      a.imageUrl == b.imageUrl &&
      a.originalUrl == b.originalUrl &&
      a.previewUrl == b.previewUrl;

  bool _photoFillStructureMatches(LayerModel a, LayerModel b) =>
      a.id == b.id &&
      a.type == b.type &&
      a.position == b.position &&
      a.text == b.text &&
      a.textStyle == b.textStyle &&
      a.textStyleType == b.textStyleType &&
      a.bubbleColor == b.bubbleColor &&
      a.scale == b.scale &&
      a.rotation == b.rotation &&
      a.textAlign == b.textAlign &&
      a.width == b.width &&
      a.height == b.height &&
      a.canvasClip == b.canvasClip &&
      a.textBackground == b.textBackground &&
      a.textFillMode == b.textFillMode &&
      a.textFillImageUrl == b.textFillImageUrl &&
      a.imageBackground == b.imageBackground &&
      a.imageTemplate == b.imageTemplate &&
      a.decorationFillColor == b.decorationFillColor &&
      a.decorationBorderColor == b.decorationBorderColor &&
      a.decorationBorderWidth == b.decorationBorderWidth &&
      a.decorationCornerRadius == b.decorationCornerRadius &&
      a.frameBaseWidth == b.frameBaseWidth &&
      a.frameBaseHeight == b.frameBaseHeight &&
      a.frameBasePosition == b.frameBasePosition &&
      a.opacity == b.opacity &&
      a.zIndex == b.zIndex;

  /// Foreground checks detect remote saves/revocation without replacing local
  /// layers. They are advisory; the server CAS remains the write authority.
  Future<void> checkRemoteAlbum() async {
    final id = _editingAlbumId;
    if (id == null ||
        _isSaving ||
        _checkingRemote ||
        _pendingSaveAttempt != null)
      return;
    final session = _editSessionIdentity;
    final actor = _readOwner();
    if (actor == null || actor != _editingActor) return;
    bool current() =>
        !_disposed &&
        identical(session, _editSessionIdentity) &&
        _editingAlbumId == id &&
        _readOwner() == actor;
    _checkingRemote = true;
    try {
      final fresh = await _albumRepository.fetchAlbum('$id');
      if (!current()) return;
      if (!fresh.allowsEditing) {
        _syncStatus(AlbumEditSyncKind.accessRevoked);
      } else if (_sourceAlbum?.updatedAt != fresh.updatedAt) {
        _syncStatus(AlbumEditSyncKind.remoteChanged);
      } else {
        _syncStatus(AlbumEditSyncKind.current);
      }
      _sourceAlbum = _sourceAlbum?.copyWith(memberRole: fresh.memberRole);
    } on AlbumEditAccessRevoked {
      if (current()) _syncStatus(AlbumEditSyncKind.accessRevoked);
    } catch (_) {
      if (current() && syncKind != AlbumEditSyncKind.accessRevoked) {
        _syncStatus(AlbumEditSyncKind.offline);
      }
    } finally {
      _checkingRemote = false;
    }
  }

  /// Only an explicit discard confirmation may call this; polling never does.
  Future<bool> reloadAlbumDiscardingLocalChanges() async {
    final id = _editingAlbumId;
    if (id == null || _isSaving) return false;
    final actor = _readOwner();
    final session = _editSessionIdentity;
    try {
      final fresh = await _albumRepository.fetchAlbum('$id');
      if (_disposed ||
          !identical(session, _editSessionIdentity) ||
          actor == null ||
          actor != _readOwner())
        return false;
      if (!fresh.allowsEditing) throw const AlbumEditAccessRevoked();
      final pageIndex = _currentPageIndex;
      await _loadAlbumForEdit(fresh);
      if (_disposed || actor != _readOwner() || _editingAlbumId != id)
        return false;
      loadPendingEditAlbumIfNeeded(_coverReferenceSize);
      _currentPageIndex = pageIndex.clamp(0, math.max(0, _pages.length - 1));
      _emit();
      return true;
    } catch (error) {
      if (!_disposed && actor == _readOwner()) {
        _lastSaveError = error;
        if (error is AlbumEditAccessRevoked)
          _syncStatus(AlbumEditSyncKind.accessRevoked);
      }
      return false;
    }
  }

  void _syncStatus(AlbumEditSyncKind kind) => ref
      .read(albumEditSyncStatusProvider.notifier)
      .update(_editingAlbumId, kind);

  void _beginSession(Album? source) {
    // Only clean files whose payload was never submitted. An unanswered save
    // may still commit, so its uploads must not be deleted speculatively.
    if (_pendingSaveAttempt == null &&
        _editingActor != null &&
        _readOwner() == _editingActor &&
        _uncommittedUploads.isNotEmpty) {
      unawaited(
        _storage.removeUnreferencedAlbumUploads(
          Set.of(_uncommittedUploads),
          expectedOwner: _editingActor!,
        ),
      );
    }
    _uncommittedUploads.clear();
    _editSessionIdentity = Object();
    _sourceAlbum = source;
    _sourceTemplateProductKey = source?.sourceTemplateProductKey;
    _editingActor = _readOwner();
    _pendingSaveAttempt = null;
    _activeSaveIdentity = null;
    _isSaving = false;
    _syncStatus(AlbumEditSyncKind.current);
  }

  void _trackUpload(UploadedUrls uploaded, String actor, bool current) {
    final markers =
        [
              uploaded.originalGsPath,
              uploaded.previewGsPath,
              uploaded.originalUrl,
              uploaded.previewUrl,
            ]
            .whereType<String>()
            .where((value) => value.startsWith('supabase://album-assets/'))
            .toSet();
    if (markers.isEmpty || _readOwner() != actor) return;
    if (current) {
      _uncommittedUploads.addAll(markers);
    } else {
      unawaited(
        _storage.removeUnreferencedAlbumUploads(markers, expectedOwner: actor),
      );
    }
  }

  @override
  FutureOr<AlbumEditorState> build() async {
    _service = ref.read(albumEditorServiceProvider);
    _persistence = ref.read(albumPersistenceServiceProvider);
    _storage = ref.read(storageServiceProvider);
    _albumRepository = ref.read(albumRepositoryProvider);
    _readOwner = ref.read(albumEditorOwnerReaderProvider);
    ref.onDispose(() {
      if (_pendingSaveAttempt == null &&
          _editingActor != null &&
          _readOwner() == _editingActor &&
          _uncommittedUploads.isNotEmpty) {
        unawaited(
          _storage.removeUnreferencedAlbumUploads(
            Set.of(_uncommittedUploads),
            expectedOwner: _editingActor!,
          ),
        );
      }
      _disposed = true;
      _editSessionIdentity = Object();
    });
    ref.listen(albumEditorOwnerChangesProvider, (_, next) {
      if (!next.hasValue ||
          _editingActor == null ||
          next.value == _editingActor)
        return;
      resetForCreate();
    });

    // 초기 표지 페이지 생성
    if (_pages.isEmpty) {
      _pages.add(_service.createPage(index: 0, isCover: true));
    }

    return AlbumEditorState(
      layers: List.of(currentPage?.layers ?? const []),
      selectedCover: _cover,
      selectedTheme: _selectedTheme,
      coverCanvasSize: null,
    );
  }

  /// 신규 생성(+ 진입)용: 기존 편집/갤러리 상태를 모두 버리고 "빈 커버"로 초기화
  /// - 갤러리(앨범/사진) 로딩은 하지 않는다 (요구사항: 불러오는거 X)
  void resetForCreate({
    CoverSize? initialCover,
    CoverTheme? initialTheme,
    int targetPages = AlbumPagePolicy.minInnerPages,
    String? sourceTemplateProductKey,
  }) {
    _pendingCreationAttempt = null;
    _creationDraftOwner = null;
    _creationDraftId = null;
    _persistCreationAttempt = null;
    _clearAllHistory();
    _editSessionIdentity = Object();
    _pages.clear();
    _cover = newAlbumCoverSize(initialCover);
    _selectedTheme = initialTheme ?? CoverTheme.classic;
    _pages.add(_service.createPage(index: 0, isCover: true));

    // Step1에서 선택한 페이지 수(targetPages)만큼 빈 내지 페이지 미리 생성
    final targetPageCount = AlbumPagePolicy.normalize(targetPages);
    for (int i = 1; i <= targetPageCount; i++) {
      _pages.add(_service.createPage(index: i));
    }

    _currentPageIndex = 0;
    _editingAlbumId = null;
    _beginSession(null);
    _sourceTemplateProductKey = normalizeAlbumSourceTemplateProductKey(
      sourceTemplateProductKey,
    );
    _pendingTemplateProductKeyAfterLoad = null;
    _pendingCoverLayersJson = null;
    _initialCoverImageUrl = null;
    _initialCoverThumbnailUrl = null;
    _initialAlbumTitle = null;
    _targetPagesHint = targetPageCount;

    // [Rescale Fix] 새 앨범 생성 시 트래커 초기화
    _lastCoverCanvasSize = Size.zero;
    _lastInnerCanvasSize = _innerPageCanvasSize; // (300, 400) canonical

    // Cover VM도 동기화 (화면 선택기/테마 즉시 반영)
    ref.read(coverViewModelProvider.notifier).selectCover(_cover);
    ref.read(coverViewModelProvider.notifier).updateTheme(_selectedTheme);

    final prev = state.value ?? const AlbumEditorState();
    state = AsyncData(prev.copyWith(coverCanvasSize: null));
    _emit();
  }

  /// Seeds one local page in an isolated provider scope. This creates no album,
  /// uploads nothing, and never participates in a durable album save session.
  /// Hosts must override this notifier and its cover/sync providers together.
  void startSinglePageDraft({
    required List<LayerModel> layers,
    required Size canvasSize,
    int? backgroundColor,
  }) {
    if (!canvasSize.width.isFinite ||
        !canvasSize.height.isFinite ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0) {
      throw ArgumentError.value(canvasSize, 'canvasSize');
    }
    _clearAllHistory();
    _pages
      ..clear()
      ..add(
        AlbumPage(
          id: 'local-single-page',
          layers: List.of(layers),
          pageIndex: 0,
          backgroundColor: backgroundColor,
        ),
      );
    _cover = CoverSize(
      name: '한 장의 기록',
      ratio: canvasSize.width / canvasSize.height,
      realSize: Size(10 * canvasSize.width / canvasSize.height, 10),
    );
    _selectedTheme = CoverTheme.classic;
    _currentPageIndex = 0;
    _editingAlbumId = null;
    _beginSession(null);
    _singlePageDraftSession = _editSessionIdentity;
    _singlePageCanvases[_pages.single] = canvasSize;
    _pendingCreationAttempt = null;
    _creationDraftOwner = null;
    _creationDraftId = null;
    _persistCreationAttempt = null;
    _pendingCoverLayersJson = null;
    _pendingTemplatePagesAfterLoad = null;
    _pendingTemplateProductKeyAfterLoad = null;
    _targetPagesHint = 0;
    _initialCoverImageUrl = null;
    _initialCoverThumbnailUrl = null;
    _initialAlbumTitle = null;
    _lastCoverCanvasSize = canvasSize;
    _lastInnerCanvasSize = canvasSize;
    _hasUnsavedChanges = false;
    ref.read(coverViewModelProvider.notifier).selectCover(_cover);
    ref.read(coverViewModelProvider.notifier).updateTheme(_selectedTheme);
    final previous = state.value ?? const AlbumEditorState();
    state = AsyncData(
      previous.copyWith(
        coverCanvasSize: canvasSize,
        innerCanvasSize: canvasSize,
      ),
    );
    _emit();
  }

  /// A format change belongs to the isolated moment draft's existing history.
  /// Saved albums and normal album creation never enter this local session.
  bool resizeSinglePageDraft({
    required List<LayerModel> layers,
    required Size canvasSize,
  }) {
    if (!_isSinglePageDraft || _isSaving) return false;
    if (!canvasSize.width.isFinite ||
        !canvasSize.height.isFinite ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0) {
      throw ArgumentError.value(canvasSize, 'canvasSize');
    }
    _recordUndo();
    final page = _pages.single.copyWith(layers: List.of(layers));
    _pages[0] = page;
    _singlePageCanvases[page] = canvasSize;
    _restoreSinglePageCanvas(page);
    _emit();
    return true;
  }

  void _restoreSinglePageCanvas(AlbumPage page) {
    if (!_isSinglePageDraft) return;
    final canvas = _singlePageCanvases[page];
    if (canvas == null) return;
    _cover = CoverSize(
      name: '한 장의 기록',
      ratio: canvas.width / canvas.height,
      realSize: Size(10 * canvas.width / canvas.height, 10),
    );
    _lastCoverCanvasSize = canvas;
    _lastInnerCanvasSize = canvas;
    final previous = state.value ?? const AlbumEditorState();
    state = AsyncData(
      previous.copyWith(coverCanvasSize: canvas, innerCanvasSize: canvas),
    );
    ref.read(coverViewModelProvider.notifier).selectCover(_cover);
  }

  /// 스토어 로컬 템플릿(홈 피처드 등)을 에디터 페이지로 직접 시작
  /// - 서버 앨범 생성 없이 임시 편집 세션으로 진입
  void startLocalTemplateAlbum({
    required String albumTitle,
    required List<List<LayerModel>> pages,
    CoverSize? initialCover,
    Size? templateCanvasSize,
    String? sourceTemplateProductKey,
  }) {
    _checkTemplatePageLimit(pages.length - 1);
    final chosenCover = newAlbumCoverSize(initialCover);

    _clearAllHistory();
    _editSessionIdentity = Object();
    _pages.clear();
    _cover = chosenCover;
    _selectedTheme = CoverTheme.classic;

    final coverCanvas = _coverReferenceSize;
    final innerCanvas = _innerPageCanvasSize;

    if (pages.isEmpty) {
      _pages.add(_service.createPage(index: 0, isCover: true));
      _pages.add(_service.createPage(index: 1));
    } else {
      for (int i = 0; i < pages.length; i++) {
        final isCover = i == 0;
        final source = pages[i];
        final targetCanvas = isCover ? coverCanvas : innerCanvas;
        final mapped = _remapTemplatePageLayers(
          sourceLayers: source,
          targetCanvas: targetCanvas,
          sourceCanvasOverride: templateCanvasSize,
        );
        final page = _service.createPage(index: i, isCover: isCover);
        page.layers
          ..clear()
          ..addAll(mapped);
        _pages.add(page);
      }
      if (_pages.length == 1) {
        _pages.add(_service.createPage(index: 1));
      }
    }

    _padInnerPages(AlbumPagePolicy.minimumForContent(innerPageCount));
    _currentPageIndex = 0;
    _editingAlbumId = null;
    _beginSession(null);
    _sourceTemplateProductKey = normalizeAlbumSourceTemplateProductKey(
      sourceTemplateProductKey,
    );
    _pendingTemplateProductKeyAfterLoad = null;
    _pendingCoverLayersJson = null;
    _initialCoverImageUrl = null;
    _initialCoverThumbnailUrl = null;
    _initialAlbumTitle = albumTitle;
    _targetPagesHint = math.max(1, _pages.length - 1);

    _lastCoverCanvasSize = coverCanvas;
    _lastInnerCanvasSize = innerCanvas;

    ref.read(coverViewModelProvider.notifier).selectCover(_cover);
    ref.read(coverViewModelProvider.notifier).updateTheme(_selectedTheme);

    final prev = state.value ?? const AlbumEditorState();
    state = AsyncData(
      prev.copyWith(coverCanvasSize: coverCanvas, innerCanvasSize: innerCanvas),
    );
    _emit();
  }

  List<LayerModel> _remapTemplatePageLayers({
    required List<LayerModel> sourceLayers,
    required Size targetCanvas,
    Size? sourceCanvasOverride,
  }) {
    if (sourceLayers.isEmpty) return const [];
    final bounds = _templateBounds(sourceLayers);
    final looksNormalized =
        sourceCanvasOverride == null &&
        bounds.width <= 2.5 &&
        bounds.height <= 2.5 &&
        bounds.left >= -1.0;

    // 이미 타깃 캔버스와 거의 같으면 재스케일하지 않는다.
    if (!looksNormalized &&
        sourceCanvasOverride == null &&
        (bounds.width - targetCanvas.width).abs() <= 1.0 &&
        (bounds.height - targetCanvas.height).abs() <= 1.0) {
      return sourceLayers.map((l) => l.copyWith()).toList(growable: false);
    }

    final sourceCanvas =
        sourceCanvasOverride ??
        (looksNormalized
            ? _normalizedTemplateCanvasFor(targetCanvas)
            : _estimateTemplateSourceCanvas(sourceLayers));
    final sourceOrigin = looksNormalized || sourceCanvasOverride != null
        ? Offset.zero
        : _estimateTemplateSourceOrigin(sourceLayers);
    final sx = targetCanvas.width / math.max(1.0, sourceCanvas.width);
    final sy = targetCanvas.height / math.max(1.0, sourceCanvas.height);
    // 핵심: 피그마 원본 비율을 유지하기 위해 축별 스케일 대신 단일 스케일을 사용한다.
    // 이렇게 하면 세로/정사각/가로에서도 레이아웃이 찌그러지지 않고 동일한 아트디렉션을 유지한다.
    final uniformScale = math.min(sx, sy);
    final fittedW = sourceCanvas.width * uniformScale;
    final fittedH = sourceCanvas.height * uniformScale;
    final offsetX = (targetCanvas.width - fittedW) / 2;
    final offsetY = (targetCanvas.height - fittedH) / 2;

    return sourceLayers
        .map((layer) {
          final sourceX = looksNormalized
              ? layer.position.dx * sourceCanvas.width
              : (layer.position.dx - sourceOrigin.dx);
          final sourceY = looksNormalized
              ? layer.position.dy * sourceCanvas.height
              : (layer.position.dy - sourceOrigin.dy);
          final sourceW = looksNormalized
              ? layer.width * sourceCanvas.width
              : layer.width;
          final sourceH = looksNormalized
              ? layer.height * sourceCanvas.height
              : layer.height;

          final nx = (sourceX * uniformScale) + offsetX;
          final ny = (sourceY * uniformScale) + offsetY;
          final nw = sourceW * uniformScale;
          final nh = sourceH * uniformScale;
          final style = layer.textStyle;
          final scaledStyle = style?.copyWith(
            fontSize: style.fontSize == null
                ? null
                : sourceCanvasOverride != null
                ? style.fontSize! * uniformScale
                : (style.fontSize! * uniformScale).clamp(8.0, 220.0).toDouble(),
            letterSpacing: style.letterSpacing == null
                ? null
                : style.letterSpacing! * uniformScale,
          );

          return layer.copyWith(
            position: Offset(nx, ny),
            width: nw,
            height: nh,
            textStyle: scaledStyle,
            decorationCornerRadius:
                sourceCanvasOverride != null &&
                    (layer.decorationCornerRadius ?? 0) > 1
                ? layer.decorationCornerRadius! * uniformScale
                : layer.decorationCornerRadius,
            decorationBorderWidth:
                sourceCanvasOverride != null &&
                    (layer.decorationBorderWidth ?? 0) > 1
                ? layer.decorationBorderWidth! * uniformScale
                : layer.decorationBorderWidth,
          );
        })
        .toList(growable: false);
  }

  Size _normalizedTemplateCanvasFor(Size targetCanvas) {
    final aspect = targetCanvas.width <= 0 || targetCanvas.height <= 0
        ? (3 / 4)
        : (targetCanvas.width / targetCanvas.height);
    const baseW = 1080.0;
    return Size(baseW, baseW / aspect);
  }

  Size _estimateTemplateSourceCanvas(List<LayerModel> layers) {
    if (layers.isEmpty) return const Size(500, 500);
    final bleedCanvas = _estimateFullBleedCanvas(layers);
    if (bleedCanvas != null) return bleedCanvas;
    final b = _templateBounds(layers);
    // Figma 기반 템플릿은 페이지 외곽까지 레이어가 닿지 않는 경우가 잦다.
    // bounds 자체를 캔버스로 쓰면 전체가 확대되어 피그마 대비 커져 보일 수 있어,
    // 흔히 쓰는 디자인 캔버스(1080/1440 등)로 스냅해 원본 비율을 유지한다.
    final right = (b.left + b.width).clamp(1.0, double.infinity);
    final bottom = (b.top + b.height).clamp(1.0, double.infinity);
    final snappedW = _snapTemplateDesignDimension(right);
    final snappedH = _snapTemplateDesignDimension(bottom);
    if (b.left >= -1.0 &&
        b.top >= -1.0 &&
        snappedW > 0 &&
        snappedH > 0 &&
        snappedW >= b.width &&
        snappedH >= b.height) {
      return Size(snappedW, snappedH);
    }
    return Size(
      (b.right - b.left).clamp(1.0, double.infinity),
      (b.bottom - b.top).clamp(1.0, double.infinity),
    );
  }

  Size? _estimateFullBleedCanvas(List<LayerModel> layers) {
    LayerModel? candidate;
    var largestArea = 0.0;
    for (final layer in layers) {
      if (layer.type != LayerType.image) continue;
      if (layer.position.dx < -4 || layer.position.dy < -4) continue;
      final area = layer.width * layer.height;
      if (area <= largestArea) continue;
      candidate = layer;
      largestArea = area;
    }
    if (candidate == null) return null;
    final width = candidate.width;
    final height = candidate.height;
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return null;
    }
    // 풀블리드 이미지가 있으면 bounds보다 이쪽이 실제 디자인 캔버스일 가능성이 높다.
    // 하단 패널/배지 등이 바닥을 살짝 넘는 경우에도 커버가 축소되지 않도록 우선한다.
    if (candidate.position.dx <= 4 &&
        candidate.position.dy <= 4 &&
        width >= 900 &&
        height >= 900) {
      return Size(width, height);
    }
    return null;
  }

  double _snapTemplateDesignDimension(double value) {
    const candidates = <double>[
      500,
      667,
      750,
      1000,
      1080,
      1200,
      1334,
      1440,
      1600,
      1920,
    ];
    if (!value.isFinite || value <= 0) return value;
    for (final c in candidates) {
      if (value <= c && (c - value) <= (c * 0.12)) {
        return c;
      }
    }
    return value;
  }

  Offset _estimateTemplateSourceOrigin(List<LayerModel> layers) {
    if (layers.isEmpty) return Offset.zero;
    final b = _templateBounds(layers);
    if (!b.left.isFinite || !b.top.isFinite) return Offset.zero;
    // 템플릿이 이미 "0,0 기준 디자인 캔버스" 안에서 절대좌표로 정의된 경우에는
    // bounds.left/top 만큼 다시 당겨버리면 피그마가 의도한 여백이 사라진다.
    // 이 경우 원점을 유지해야 비율이 달라져도 페이지 구성이 SAVE THE DATE처럼 안정적으로 보인다.
    final right = (b.left + b.width).clamp(1.0, double.infinity);
    final bottom = (b.top + b.height).clamp(1.0, double.infinity);
    final snappedW = _snapTemplateDesignDimension(right);
    final snappedH = _snapTemplateDesignDimension(bottom);
    final looksAbsoluteOnCanvas =
        b.left >= -1.0 &&
        b.top >= -1.0 &&
        snappedW > 0 &&
        snappedH > 0 &&
        snappedW >= b.width &&
        snappedH >= b.height;
    if (looksAbsoluteOnCanvas) return Offset.zero;
    return Offset(b.left, b.top);
  }

  Rect _templateBounds(List<LayerModel> layers) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    for (final l in layers) {
      minX = math.min(minX, l.position.dx);
      minY = math.min(minY, l.position.dy);
      maxX = math.max(maxX, l.position.dx + l.width);
      maxY = math.max(maxY, l.position.dy + l.height);
    }
    if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
      return const Rect.fromLTWH(0, 0, 500, 500);
    }
    final w = (maxX - minX).clamp(1.0, double.infinity);
    final h = (maxY - minY).clamp(1.0, double.infinity);
    return Rect.fromLTWH(minX, minY, w, h);
  }

  /// 현재 로드된 앨범 페이지에 템플릿 페이지를 덮어쓴다.
  /// - keepCurrentCover=true: 사용자가 만든 커버를 유지하고 내지부터 적용
  void applyTemplatePagesToCurrentAlbum(
    List<List<LayerModel>> templatePages, {
    bool keepCurrentCover = true,
    String? sourceTemplateProductKey,
  }) {
    if (templatePages.isEmpty || _pages.isEmpty) return;
    final requiredPages = AlbumPagePolicy.minimumForContent(
      math.max(innerPageCount, templatePages.length - 1),
    );
    _checkTemplatePageLimit(requiredPages);
    _sourceTemplateProductKey = normalizeAlbumSourceTemplateProductKey(
      sourceTemplateProductKey,
    );

    final start = keepCurrentCover ? 1 : 0;
    final srcStart = keepCurrentCover ? 1 : 0;
    var dstIndex = start;

    for (int srcIndex = srcStart; srcIndex < templatePages.length; srcIndex++) {
      final isCover = dstIndex == 0;
      while (_pages.length <= dstIndex) {
        _pages.add(_newInnerPage());
      }

      final targetCanvas = isCover ? _coverReferenceSize : _innerPageCanvasSize;
      final mapped = _remapTemplatePageLayers(
        sourceLayers: templatePages[srcIndex],
        targetCanvas: targetCanvas,
      );
      final normalized = _normalizeLayersForEditing(
        mapped,
        targetCanvas,
        preserveLayout: true,
      );

      final page = _pages[dstIndex];
      page.layers
        ..clear()
        ..addAll(normalized);
      dstIndex++;
    }

    _padInnerPages(requiredPages);
    _targetPagesHint = innerPageCount;
    _clearAllHistory();
    _hasUnsavedChanges = true;
    _currentPageIndex = _currentPageIndex.clamp(0, _pages.length - 1);
    _emit();
  }

  /// 생성 플로우 Step2에서 템플릿 예시 커버를 미리 보여줄 때 사용
  void applyTemplateCoverPreview(
    List<LayerModel> coverLayers, {
    Size? templateCanvasSize,
  }) {
    if (_pages.isEmpty || coverLayers.isEmpty) return;
    final mapped = _remapTemplatePageLayers(
      sourceLayers: coverLayers,
      targetCanvas: _coverReferenceSize,
      sourceCanvasOverride: templateCanvasSize,
    );
    final extracted = _extractTemplateBackgroundForEditing(
      mapped,
      _coverReferenceSize,
    );
    final normalized = _normalizeLayersForEditing(
      extracted.layers,
      _coverReferenceSize,
      preserveLayout: true,
    );
    final cover = _pages.first;
    _pages[0] = cover.copyWith(
      layers: normalized,
      backgroundColor: extracted.backgroundColor ?? cover.backgroundColor,
    );
    _currentPageIndex = 0;
    _emit();
  }

  /// 사진 선택 바텀시트 등을 열기 전에 갤러리 데이터가 비어있으면 1회 로딩
  /// 홈에서 선택한 앨범을 "편집 준비" 상태로 세팅
  /// - 실제 레이어 복원은 EditCover에서 실제 커버 캔버스 크기(_coverSize)가 잡힌 뒤 수행해야
  ///   위치/스케일이 정확히 맞는다.
  /// - waitForCreation: true일 경우 앨범 생성 완료를 비동기로 기다림
  Future<void> prepareAlbumForEdit(
    Album album, {
    bool waitForCreation = false,
  }) async {
    _editingAlbumId = album.id > 0 ? album.id : null;
    _beginSession(album);
    final session = _editSessionIdentity;
    final actor = _readOwner();
    final requestedRatio = album.ratio;

    // 앨범 생성 대기 모드 (신규 생성 후 폴링)
    if (waitForCreation && album.id > 0) {
      if (state.value == null) {
        state = const AsyncData(AlbumEditorState());
      }

      // 로딩 상태 설정
      final prev = state.value!;
      state = AsyncData(prev.copyWith(isCreatingInBackground: true));

      // 백그라운드 서비스에서 폴링 수행
      final success = await _persistence.pollAlbumCreation(album.id);
      if (_disposed ||
          !identical(session, _editSessionIdentity) ||
          _readOwner() != actor)
        throw const AlbumEditSessionChanged();

      if (success) {
        // 폴링 성공 시 앨범 로드
        var updatedAlbum = await ref
            .read(albumRepositoryProvider)
            .fetchAlbum(album.id.toString());
        if (_disposed ||
            !identical(session, _editSessionIdentity) ||
            _readOwner() != actor)
          throw const AlbumEditSessionChanged();
        final pendingPages = _pendingTemplatePagesAfterLoad;
        final pendingProductKey = _pendingTemplateProductKeyAfterLoad;
        if (requestedRatio.isNotEmpty &&
            pendingPages != null &&
            pendingPages.isNotEmpty) {
          updatedAlbum = updatedAlbum.copyWith(ratio: requestedRatio);
        }
        await _loadAlbumForEdit(updatedAlbum);
        if (pendingPages != null && pendingPages.isNotEmpty) {
          applyTemplatePagesToCurrentAlbum(
            pendingPages,
            keepCurrentCover: false,
            sourceTemplateProductKey: pendingProductKey,
          );
          // 템플릿 페이지를 메모리에 주입한 이후에는,
          // 생성 직후 서버의 coverLayersJson(구형/부분 데이터)로 다시 복원되면
          // 내지 템플릿이 덮어써질 수 있으므로 pending 복원을 비활성화한다.
          _pendingCoverLayersJson = null;
        }
        _pendingTemplatePagesAfterLoad = null;
        _pendingTemplateProductKeyAfterLoad = null;
      } else {
        state = const AsyncError('앨범 생성 확인 시간이 초과되었습니다.', StackTrace.empty);
      }
      return;
    }

    // 일반 편집 모드
    await _loadAlbumForEdit(album);
  }

  /// 생성 직후 서버 로드가 끝나면 템플릿 페이지를 자동 적용하기 위한 큐
  void queueTemplatePagesForNextLoad(
    List<List<LayerModel>> pages, {
    String? sourceTemplateProductKey,
  }) {
    if (pages.isEmpty) return;
    _checkTemplatePageLimit(pages.length - 1);
    _pendingTemplatePagesAfterLoad = pages;
    _pendingTemplateProductKeyAfterLoad =
        normalizeAlbumSourceTemplateProductKey(sourceTemplateProductKey);
  }

  /// 일반 새 앨범 생성 플로우에서도 서버 업로드/대표이미지 폴링을 기다리지 않고,
  /// 이미 로컬에 준비된 빈 커버/내지 페이지 상태로 즉시 편집 화면을 연다.
  ///
  /// 서버 앨범 ID만 확정되면 백그라운드 업로드는 계속 진행되며, 사용자는
  /// `앨범을 펼치는 중이에요` 오버레이에 묶이지 않고 바로 편집을 시작할 수 있다.
  void beginCreatedAlbumForEdit({
    required int albumId,
    required String albumTitle,
    String? sourceTemplateProductKey,
  }) {
    if (albumId <= 0) return;
    final source = _sourceAlbum?.id == albumId
        ? _sourceAlbum
        : ref.read(albumViewModelProvider).asData?.value;
    _editingAlbumId = albumId;
    _beginSession(source?.id == albumId ? source : null);
    _sourceTemplateProductKey =
        normalizeAlbumSourceTemplateProductKey(sourceTemplateProductKey) ??
        _sourceTemplateProductKey;
    _initialAlbumTitle = albumTitle;
    if (_pages.isEmpty) {
      _pages.add(_service.createPage(index: 0, isCover: true));
      final targetPageCount = AlbumPagePolicy.normalize(_targetPagesHint);
      for (int i = 1; i <= targetPageCount; i++) {
        _pages.add(_service.createPage(index: i));
      }
    }
    _currentPageIndex = 0;
    _pendingCoverLayersJson = null;
    final prev = state.value ?? const AlbumEditorState();
    state = AsyncData(prev.copyWith(isCreatingInBackground: false));
    _emit();
  }

  /// 템플릿 생성 플로우에서는 이미 메모리에 완성된 커버/내지 페이지가 있으므로,
  /// 생성 직후 편집 진입을 서버 업로드 폴링에 묶지 않는다.
  ///
  /// 서버 업로드는 백그라운드로 계속 진행하되, 사용자는 즉시 페이지 편집을 열 수 있어야
  /// `앨범을 펼치는 중이에요` 오버레이가 업로드 URL 대기 때문에 무한 유지되지 않는다.
  void beginCreatedTemplateAlbumForEdit({
    required int albumId,
    required String albumTitle,
    required List<List<LayerModel>> pages,
    CoverSize? initialCover,
    Size? templateCanvasSize,
    String? sourceTemplateProductKey,
  }) {
    if (albumId <= 0) return;
    final source = _sourceAlbum?.id == albumId
        ? _sourceAlbum
        : ref.read(albumViewModelProvider).asData?.value;
    startLocalTemplateAlbum(
      albumTitle: albumTitle,
      pages: pages,
      initialCover: initialCover,
      templateCanvasSize: templateCanvasSize,
      sourceTemplateProductKey: sourceTemplateProductKey,
    );
    _editingAlbumId = albumId;
    _beginSession(source?.id == albumId ? source : null);
    _sourceTemplateProductKey =
        normalizeAlbumSourceTemplateProductKey(sourceTemplateProductKey) ??
        _sourceTemplateProductKey;
    final prev = state.value ?? const AlbumEditorState();
    state = AsyncData(prev.copyWith(isCreatingInBackground: false));
    _emit();
  }

  /// Restore an unfinished created album without remapping edited coordinates.
  void restoreCreatedEditorDraft({
    required int albumId,
    required String albumTitle,
    required CoverSize cover,
    required AlbumCreationEditorCheckpoint checkpoint,
    String? sourceTemplateProductKey,
  }) {
    if (albumId <= 0 || checkpoint.pages.isEmpty) return;
    _checkTemplatePageLimit(checkpoint.pages.length - 1);
    _clearAllHistory();
    _editSessionIdentity = Object();
    _pages
      ..clear()
      ..addAll(checkpoint.pages.map(_clonePage));
    _editingAlbumId = albumId;
    _beginSession(
      Album(
        id: albumId,
        title: albumTitle,
        ratio: cover.ratio.toString(),
        updatedAt: checkpoint.sourceUpdatedAt ?? '',
        userId: checkpoint.sourceOwnerId ?? '',
        memberRole: checkpoint.sourceMemberRole ?? 'EDITOR',
      ),
    );
    _initialAlbumTitle = albumTitle;
    _sourceTemplateProductKey = normalizeAlbumSourceTemplateProductKey(
      checkpoint.sourceTemplateProductKey ?? sourceTemplateProductKey,
    );
    _initialCoverImageUrl = null;
    _initialCoverThumbnailUrl = null;
    _pendingCoverLayersJson = null;
    _pendingTemplatePagesAfterLoad = null;
    _cover = cover;
    _selectedTheme = checkpoint.theme;
    _lastCoverCanvasSize = checkpoint.coverCanvas;
    _lastInnerCanvasSize = checkpoint.innerCanvas;
    _targetPagesHint = _pages.length - 1;
    _currentPageIndex = checkpoint.pageIndex.clamp(0, _pages.length - 1);
    _hasUnsavedChanges = true;
    ref.read(coverViewModelProvider.notifier).selectCover(_cover);
    ref.read(coverViewModelProvider.notifier).updateTheme(_selectedTheme);
    state = AsyncData(
      AlbumEditorState(
        coverCanvasSize: _lastCoverCanvasSize,
        innerCanvasSize: _lastInnerCanvasSize,
      ),
    );
    _emit();
  }

  /// 앨범 데이터를 로드하여 편집 준비
  Future<void> _loadAlbumForEdit(Album album) async {
    final session = _editSessionIdentity;
    final actor = _readOwner();
    // 목록에서 coverLayersJson이 비어오는 케이스 대비: 상세로 보강
    Album effective = album;
    if (effective.coverLayersJson.isEmpty && effective.id > 0) {
      try {
        effective = await _albumRepository.fetchAlbum(effective.id.toString());
      } catch (error) {
        // An unavailable document must never become an empty editable document
        // that a later save could use to erase the existing book.
        if (error is AlbumEditAccessRevoked) {
          _syncStatus(AlbumEditSyncKind.accessRevoked);
        }
        rethrow;
      }
    }
    if (_disposed ||
        !identical(session, _editSessionIdentity) ||
        _readOwner() != actor)
      throw const AlbumEditSessionChanged();
    _beginSession(effective);

    final coverSize = effective.physicalCoverSize;
    _cover = coverSize;

    // 테마 초기화 (전 상태 유출 방지)
    _selectedTheme = CoverTheme.classic;

    // 테마 복원 (서버에서 coverTheme 반환 시)
    final themeStr = effective.coverTheme;
    if (themeStr != null && themeStr.isNotEmpty) {
      try {
        // 과거 값 호환: abstract1이 "abstract"로 저장된 경우가 있었음
        final normalized = themeStr == 'abstract' ? 'abstract1' : themeStr;
        final theme = CoverTheme.values.firstWhere(
          (t) => t.label == normalized,
        );
        _selectedTheme = theme;
      } catch (_) {
        // 알 수 없는 테마 문자열이면 기본값 유지
      }
    }

    // coverViewModelProvider에 커버 사이즈와 테마 동기화
    ref.read(coverViewModelProvider.notifier).selectCover(_cover);
    ref.read(coverViewModelProvider.notifier).updateTheme(_selectedTheme);

    // 레이어 JSON은 실제 canvasSize가 정해진 다음에 복원
    _pendingCoverLayersJson = effective.coverLayersJson.isEmpty
        ? '{"layers":[]}'
        : effective.coverLayersJson;
    _editingAlbumId = album.id > 0 ? album.id : null;
    _initialCoverImageUrl = effective.coverImageUrl;
    _initialCoverThumbnailUrl = effective.coverThumbnailUrl;
    _initialAlbumTitle = effective.title;

    // 이전 편집 상태 초기화: 페이지/커버 캔버스 정보 리셋
    _clearAllHistory();
    _editSessionIdentity = Object();
    _pages.clear();
    _pages.add(_service.createPage(index: 0, isCover: true));

    // Step1에서 선택한 페이지 수(targetPages)만큼 빈 내지 페이지 미리 생성
    // targetPages가 0이면 기본 1페이지
    final targetPageCount = album.targetPages > 0 ? album.targetPages : 1;
    _targetPagesHint = targetPageCount;
    for (int i = 1; i <= targetPageCount; i++) {
      _pages.add(_service.createPage(index: i));
    }
    debugPrint(
      '[_loadAlbumForEdit] Pre-created $targetPageCount inner page(s) from targetPages=${album.targetPages}',
    );

    _currentPageIndex = 0;

    // coverCanvasSize 도 초기화해서, 다음 화면(커버/스프레드)에서
    // loadPendingEditAlbumIfNeeded 가 새 앨범 기준으로 다시 한 번만 동작하도록 한다.
    final prev = state.value ?? const AlbumEditorState();
    state = AsyncData(
      prev.copyWith(
        coverCanvasSize: null,
        selectedCover: _cover,
        selectedTheme: _selectedTheme,
        isCreatingInBackground: false, // 로딩 해제
      ),
    );

    // 커버 사이즈/테마만 먼저 반영(선택기/레이아웃 동기화)
    _emit();
  }

  /// 편집 모드 여부 (저장 성공 시 홈으로 pop할지, 스프레드로 push할지 판단용)
  bool get isEditingExistingAlbum => _editingAlbumId != null;

  /// 현재 편집 중인 앨범 ID (Hero 태그 등에서 사용)
  int? get editingAlbumId => _editingAlbumId;

  /// EditCover에서 실제 커버 캔버스 크기가 잡힌 뒤 1회만 레이어 복원
  void loadPendingEditAlbumIfNeeded(Size canvasSize) {
    if (_pendingCoverLayersJson == null) return;

    final String pendingJson = _pendingCoverLayersJson!;
    _pendingCoverLayersJson = null;

    // [Guard] 리더 화면 등에서 이미 커버 레이어가 있는 상태에서,
    // 목록에서 coverLayersJson이 비어 넘어온 케이스(= {"layers":[]} 폴백)가
    // 다시 덮어써서 "빈 커버"로 보이는 문제를 방지한다.
    final bool pendingIsEmptyCoverOnly =
        pendingJson.trim().contains('"layers"') &&
        pendingJson.trim().contains('[]') &&
        !pendingJson.trim().contains('"pages"');
    final bool hasExistingCoverLayers =
        _pages.isNotEmpty &&
        _pages.first.isCover &&
        _pages.first.layers.isNotEmpty;
    if (pendingIsEmptyCoverOnly && hasExistingCoverLayers) {
      return;
    }

    // [10단계 Fix] 커버는 이제 항상 kCoverReferenceWidth(500px) 기준으로 복원합니다.
    // 실측 canvasSize에 의한 리스케일링은 UI 단에서 Transform.scale로 처리합니다.
    final double ratio = _cover.ratio > 0 ? _cover.ratio : 1.0;
    final effectiveSize = Size(
      kCoverReferenceWidth,
      kCoverReferenceWidth / ratio,
    );

    debugPrint(
      '[loadPendingEditAlbumIfNeeded] Restoring COVER layers with REFERENCE size: $effectiveSize',
    );
    loadAlbum({'coverLayersJson': pendingJson}, effectiveSize);

    // UI 동기화용 실측 사이즈만 업데이트 (리스케일링은 발생하지 않음)
    _lastCoverCanvasSize = canvasSize != Size.zero ? canvasSize : effectiveSize;
    state = AsyncData(
      state.value!.copyWith(coverCanvasSize: _lastCoverCanvasSize),
    );
  }

  /// 서버에서 불러온 앨범 데이터를 편집기에 로드
  /// coverLayersJson이 "pages" 배열 형식이면 커버+내지 모두 복원, 아니면 기존 형식(cover만) 복원
  /// [canvasSize]: 커버용 캔버스 크기. 내지 페이지는 300x400 고정(페이지 에디터와 동일)
  void loadAlbum(Map<String, dynamic> albumData, Size canvasSize) {
    if (canvasSize == Size.zero) return;
    _clearAllHistory();

    // [10단계 Fix] 커버는 항상 500xH, 내지는 300xH 참조 사이즈를 베이스로 로드합니다.
    final coverAspect = _cover.ratio > 0 ? _cover.ratio : 1.0;
    final coverRefSize = Size(
      kCoverReferenceWidth,
      kCoverReferenceWidth / coverAspect,
    );

    _lastCoverCanvasSize = canvasSize; // 실제 UI용 캔버스 크기만 기록
    _lastInnerCanvasSize = _innerPageCanvasSize;

    final String raw = albumData['coverLayersJson'] as String? ?? '{}';
    final Map<String, dynamic> data =
        jsonDecode(raw) as Map<String, dynamic>? ?? {};
    _sourceTemplateProductKey = readAlbumSourceTemplateProductKey(data);

    // 앨범 생성 시 _loadAlbumForEdit에서 미리 만들어둔 빈 내지들이 날아가는 것을 방지
    final existingInnerPages = _pages.where((p) => !p.isCover).toList();
    _editSessionIdentity = Object();
    _pages.clear();

    // 새 형식: { "pages": [ { "index", "isCover", "layers" }, ... ] }
    final List<dynamic>? pagesList = data['pages'] as List<dynamic>?;
    if (pagesList != null && pagesList.isNotEmpty) {
      for (final p in pagesList) {
        final map = p as Map<String, dynamic>;
        final index = (map['index'] as num?)?.toInt() ?? _pages.length;
        final isCover = map['isCover'] as bool? ?? (index == 0);
        final layerList = (map['layers'] as List<dynamic>?) ?? [];
        final backgroundColor = (map['backgroundColor'] as num?)?.toInt();
        // [10단계] 커버는 500xH, 내지는 300xH 고정 좌표계 사용
        final pageCanvasSize = isCover ? coverRefSize : _innerPageCanvasSize;
        final loadedLayers = layerList.map((l) {
          return LayerExportMapper.fromJson(
            l as Map<String, dynamic>,
            canvasSize: pageCanvasSize,
            isCover: isCover,
          );
        }).toList();
        final normalizedLayers = _normalizeLayersForEditing(
          loadedLayers,
          pageCanvasSize,
        );
        final page = _service.createPage(
          index: index,
          isCover: isCover,
          backgroundColor: backgroundColor,
        );
        page.layers.addAll(normalizedLayers);
        _pages.add(page);
      }
      // 페이지 순서 보장 (index 기준 정렬)
      _pages.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    } else {
      // 기존 형식: { "layers": [...] } → 커버 페이지만 복원
      final List<dynamic> layerList = data['layers'] ?? [];
      final List<LayerModel> loadedLayers = layerList.map((l) {
        return LayerExportMapper.fromJson(
          l as Map<String, dynamic>,
          canvasSize: coverRefSize,
          isCover: true,
        );
      }).toList();
      final normalizedLayers = _normalizeLayersForEditing(
        loadedLayers,
        coverRefSize,
      );
      final coverPage = _service.createPage(index: 0, isCover: true);
      coverPage.layers.addAll(normalizedLayers);
      _pages.add(coverPage);

      // 구 형식 파일의 경우 내지 데이터가 coverLayersJson에 없으므로,
      // API 조회 등을 통해 이미 확보해둔 빈 내지(기존 메모리 상태)들을 다시 복구해줍니다.
      _pages.addAll(existingInnerPages);
    }

    _emit();
  }

  /// Create a new album, or save all pages when the cover belongs to an existing
  /// album. Cover editing must never replace an existing book with legacy layers.
  Future<int?> saveAlbumToBackend(
    Size canvasSize, {
    Uint8List? coverImageBytes,
    String? title,
    int? targetPages,
    List<LayerModel>? overrideLayers,
  }) async {
    if (_isSaving) return null;
    if (_editingAlbumId != null) {
      final albumId = _editingAlbumId;
      if (overrideLayers != null) updatePageLayers(overrideLayers);
      if (title != null) _initialAlbumTitle = title;
      if (!await saveFullAlbum(coverImageBytes: coverImageBytes)) {
        throw _lastSaveError ?? const AlbumEditSessionChanged();
      }
      return albumId;
    }
    final actor = _readOwner();
    if (actor == null) throw const AlbumEditSessionChanged();
    final session = _editSessionIdentity;
    final saveIdentity = Object();
    _activeSaveIdentity = saveIdentity;
    _isSaving = true;
    bool current() =>
        !_disposed &&
        identical(session, _editSessionIdentity) &&
        identical(saveIdentity, _activeSaveIdentity) &&
        _readOwner() == actor;
    void requireCurrent() {
      if (!current()) throw const AlbumEditSessionChanged();
    }

    final currentLayers =
        (overrideLayers ?? state.value?.layers ?? <LayerModel>[])
            .map((layer) => layer.copyWith())
            .toList();
    final count = AlbumPagePolicy.minimumForContent(
      math.max(
        math.max(1, _pages.where((page) => !page.isCover).length),
        targetPages ?? _targetPagesHint,
      ),
    );
    final cover = _cover;
    final themeLabel = _selectedTheme.label;
    final sourceTemplateProductKey = _sourceTemplateProductKey;
    final albumVm = ref.read(albumViewModelProvider.notifier);
    try {
      requireCurrent();
      _checkTemplatePageLimit(count);
      _padInnerPages(count);
      _targetPagesHint = count;
      final seed = CreateAlbumRequest(
        ratio: cover.ratio.toString(),
        title: title ?? '',
        targetPages: count,
        coverLayersJson: jsonEncode({
          ...albumSourceTemplateMetadata(sourceTemplateProductKey),
          if (cover.printProduct != null) 'printProduct': cover.printProduct,
          'layers': currentLayers
              .map(
                (layer) => LayerExportMapper.toJson(
                  layer,
                  canvasSize: canvasSize,
                  isCover: true,
                ),
              )
              .toList(),
        }),
        coverImageUrl: '',
        coverThumbnailUrl: '',
        coverPreviewUrl: '',
        coverOriginalUrl: '',
        coverTheme: themeLabel,
      );
      final persist = _persistCreationAttempt;
      final draftId = _creationDraftId;
      if (persist == null || draftId == null || _creationDraftOwner != actor) {
        throw const AlbumCreationRecoveryRequired();
      }
      final attempt = _pendingCreationAttempt ??= AlbumCreationAttempt(
        ownerId: actor,
        draftId: draftId,
        requestId: const Uuid().v4(),
        seed: seed,
      );
      if (attempt.ownerId != actor || attempt.draftId != draftId) {
        throw const AlbumEditSessionChanged();
      }
      // A failed durable write must prevent even the first server request.
      // Repeating this step also checkpoints edits made after a lost response.
      await persist(attempt);
      requireCurrent();
      await albumVm.createAlbum(
        requestId: attempt.requestId,
        expectedUserId: actor,
        ratio: attempt.seed.ratio,
        title: attempt.seed.title,
        targetPages: attempt.seed.targetPages,
        coverLayersJson: attempt.seed.coverLayersJson,
        coverImageUrl: attempt.seed.coverImageUrl,
        coverThumbnailUrl: attempt.seed.coverThumbnailUrl,
        coverOriginalUrl: attempt.seed.coverOriginalUrl,
        coverPreviewUrl: attempt.seed.coverPreviewUrl,
        coverTheme: attempt.seed.coverTheme,
      );
      requireCurrent();
      final created = ref.read(albumViewModelProvider).asData?.value;
      if (created == null || created.id <= 0) {
        throw ref.read(albumViewModelProvider).error ??
            StateError('앨범 생성 응답을 확인할 수 없어요.');
      }
      // Retain the known created ID/revision even if uploading fails, so retry
      // saves this album instead of creating another empty album.
      _editingAlbumId = created.id;
      _sourceAlbum = created;
      _editingActor = actor;
      _initialAlbumTitle = title ?? '';
      final requestId = const Uuid().v4();
      final saved = await _persistence.performBackgroundUpload(
        albumId: created.id,
        expectedUpdatedAt: created.updatedAt,
        expectedUserId: actor,
        requestId: requestId,
        canvasSize: canvasSize,
        currentLayers: currentLayers,
        coverImageBytes: coverImageBytes,
        themeLabel: themeLabel,
        title: title ?? '',
        coverRatio: cover.ratio,
        printProduct: cover.printProduct,
        sourceTemplateProductKey: sourceTemplateProductKey,
        targetPages: count,
        swallowErrors: false,
        canContinue: current,
        onUploaded: (uploaded) => _trackUpload(uploaded, actor, current()),
        onPrepared: (request) {
          requireCurrent();
          _pendingSaveAttempt = _AlbumSaveAttempt(
            albumId: created.id,
            actor: actor,
            expectedUpdatedAt: created.updatedAt,
            requestId: requestId,
            request: request,
          );
        },
        onLayerUploaded: (before, after) {
          requireCurrent();
          final page = _pages.firstOrNull;
          if (page != null &&
              after.previewUrl != null &&
              after.originalUrl != null) {
            _retainUploadedLayer(
              page,
              before,
              after.previewUrl!,
              after.originalUrl!,
            );
          }
        },
        onProgress: (completed, total) {
          if (!current() || total == 0) return;
          final previous = state.value;
          if (previous != null)
            state = AsyncData(
              previous.copyWith(
                backgroundUploadProgress: (completed / total).clamp(0.0, 1.0),
              ),
            );
        },
      );
      requireCurrent();
      _sourceAlbum = saved;
      _pendingSaveAttempt = null;
      _uncommittedUploads.clear();
      _initialCoverImageUrl = saved.coverImageUrl;
      _initialCoverThumbnailUrl = saved.coverThumbnailUrl;
      albumVm.acceptSavedAlbum(saved);
      return created.id;
    } finally {
      if (identical(saveIdentity, _activeSaveIdentity)) {
        _activeSaveIdentity = null;
        _isSaving = false;
      }
    }
  }

  /// 이미지 레이어 추가 (현재 페이지)
  /// [templateKey]: null/"free"면 원본 비율, "1:1", "4:3" 등이면 해당 템플릿으로 슬롯 생성(사진 contain)
  Future<void> addImage(
    AssetEntity asset,
    Size canvasSize, {
    String? templateKey,
    String? imageFrameKey,
  }) async {
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    await _service.addImageLayer(
      page: currentPage,
      asset: asset,
      canvasSize: canvasSize,
      templateKey: templateKey,
    );
    if (imageFrameKey != null) {
      final added = currentPage.layers
          .where((layer) => layer.id == asset.id)
          .firstOrNull;
      if (added != null) {
        _service.updateImageFrame(
          page: currentPage,
          id: added.id,
          frameKey: imageFrameKey,
        );
      }
    }
    _emit();
  }

  /// 앱 번들 에셋 스티커 추가 (예: assets/sticker/scrap1.png)
  void addAssetSticker(String assetPath, Size canvasSize) {
    if (_pages.isEmpty) return;
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    final nextZ = _nextZIndex(currentPage);

    // 캔버스 비율에 따라 과도하게 잘리지 않도록 동적 크기 적용
    // (내지/커버 모두 동일 체감 크기 유지)
    final studioSpec = studioDecorationByAsset(assetPath);
    final studioSize = studioSpec?.fittedSize(canvasSize);
    final double width =
        studioSize?.width ?? (canvasSize.width * 0.54).clamp(150.0, 320.0);
    final double height =
        studioSize?.height ?? (width * 0.84).clamp(120.0, 280.0);

    final pos = Offset(
      (canvasSize.width - width) / 2,
      (canvasSize.height - height) / 2,
    );

    final layer = LayerModel(
      id: UniqueKey().toString(),
      type: LayerType.image,
      position: pos,
      width: width,
      height: height,
      imageUrl: 'asset:$assetPath',
      // imageBackground를 지정하지 않아서 추가적인 흰 배경/테두리 없이
      // PNG 자체만 그대로 출력되도록 한다.
      opacity: 1.0,
      zIndex: nextZ,
    );

    // New artwork is not a photo slot and must survive photo replacement.
    currentPage.layers.add(
      studioSpec == null ? layer : layer.copyWith(type: LayerType.sticker),
    );
    _emit();
  }

  /// 벡터/도형 기반 데코 스티커 추가
  void addDecorationSticker(
    String styleKey,
    Size canvasSize, {
    double scale = 1.0,
  }) {
    if (_pages.isEmpty) return;
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    final nextZ = _nextZIndex(currentPage);
    final base = (canvasSize.width * 0.18).clamp(42.0, 120.0) * scale;
    final studioSize = studioDecorationById(
      styleKey,
    )?.fittedSize(canvasSize, scale: scale);
    final width =
        studioSize?.width ?? base.clamp(22.0, canvasSize.width * 0.36);
    final height =
        studioSize?.height ?? (base * 0.9).clamp(20.0, canvasSize.height * 0.3);
    final pos = Offset(
      (canvasSize.width - width) / 2,
      (canvasSize.height - height) / 2,
    );
    final layer = LayerModel(
      id: UniqueKey().toString(),
      type: LayerType.decoration,
      position: pos,
      width: width,
      height: height,
      imageBackground: styleKey,
      opacity: 1.0,
      zIndex: nextZ,
    );
    currentPage.layers.add(layer);
    _emit();
  }

  void addWordArt(StudioWordArt art, Size canvasSize) {
    if (_pages.isEmpty ||
        !canvasSize.width.isFinite ||
        !canvasSize.height.isFinite ||
        canvasSize.isEmpty)
      return;
    final layers = art.buildLayers(canvasSize);
    final page = _pages[_currentPageIndex];
    final nextZ = _nextZIndex(page);
    // One insertion is one undo step, including its paper and lettering.
    _recordUndo();
    page.layers.addAll([
      for (var index = 0; index < layers.length; index++)
        layers[index].copyWith(
          id: UniqueKey().toString(),
          zIndex: nextZ + index,
        ),
    ]);
    _emit();
  }

  /// 텍스트 레이어 추가 (현재 페이지)
  void addTextLayer(
    String text, {
    required TextStyle style,
    required TextStyleType mode,
    Color? color,
    required Size canvasSize,
    TextAlign textAlign = TextAlign.center,
  }) {
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    final nextZ = _nextZIndex(currentPage);

    // ✅ 텍스트 안전 여백 (descender 안전)
    const double horizontalPadding = 16;
    const double verticalPadding = 16;

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: null,
    )..layout();

    final double safeWidth = painter.width + horizontalPadding;
    final double safeHeight = painter.height + verticalPadding;

    _service.addTextLayer(
      page: currentPage,
      text: text,
      style: style,
      mode: mode,
      canvasSize: canvasSize,
      textAlign: textAlign,
      color: color,
      initialWidth: safeWidth,
      initialHeight: safeHeight,
      zIndex: nextZ,
    );

    _emit();
  }

  int _nextZIndex(AlbumPage page) {
    var maxZ = 0;
    for (final layer in page.layers) {
      if (layer.zIndex > maxZ) maxZ = layer.zIndex;
    }
    return maxZ + 1;
  }

  /// 레이어 업데이트
  void updateLayer(LayerModel updated) {
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    var next = updated;
    if (updated.type == LayerType.text) {
      final old = currentPage.layers
          .where((l) => l.id == updated.id)
          .firstOrNull;
      final textAppearanceChanged =
          old == null ||
          old.text != updated.text ||
          old.textStyle != updated.textStyle ||
          old.textAlign != updated.textAlign ||
          old.textBackground != updated.textBackground;
      if (textAppearanceChanged) {
        next = _expandTextLayerToFit(next);
      }
    }
    _service.updateLayer(page: currentPage, updated: next);
    _emit();
  }

  LayerModel _expandTextLayerToFit(LayerModel layer) {
    if (layer.type != LayerType.text) return layer;
    final text = (layer.text ?? '').trim();
    if (text.isEmpty) return layer;

    final style = layer.textStyle ?? const TextStyle(fontSize: 18);
    final isCoverPage = currentPage?.isCover == true;
    final canvas = isCoverPage ? _coverReferenceSize : _innerPageCanvasSize;
    // An authored frame is the document's wrapping width and alignment anchor.
    // Growing it to the unwrapped text width moves right/center-aligned text
    // beyond the page, even when a later edit makes the title shorter. New text
    // already receives its natural initial frame in addTextLayer.
    final hasFrameWidth = layer.width.isFinite && layer.width > 1;
    var nextW = layer.width;
    if (!hasFrameWidth) {
      final naturalPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textAlign: layer.textAlign ?? TextAlign.center,
        maxLines: null,
      )..layout(minWidth: 0, maxWidth: 100000);
      const hPad = 36.0;
      final maxCanvasTextW = math.max(24.0, canvas.width - 8.0);
      nextW = (naturalPainter.width + hPad)
          .clamp(24.0, maxCanvasTextW)
          .toDouble();
    }

    // Retain descender safety while measuring the same wrapping width as the
    // saved-frame renderer. Existing valid height never shrinks during editing.
    const vPad = 32.0;
    final fittedPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: layer.textAlign ?? TextAlign.center,
      maxLines: null,
    )..layout(minWidth: 0, maxWidth: nextW);
    final requiredH = (fittedPainter.height + vPad)
        .clamp(20.0, 5000.0)
        .toDouble();
    final nextH = math.max(layer.height, requiredH);

    if ((nextW - layer.width).abs() < 0.1 &&
        (nextH - layer.height).abs() < 0.1) {
      return layer;
    }
    return layer.copyWith(width: nextW, height: nextH);
  }

  /// 텍스트 스타일 변경
  void updateTextStyle(String id, String styleKey) {
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    _service.updateTextStyle(page: currentPage, id: id, styleKey: styleKey);
    _emit();
  }

  /// 이미지 프레임 스타일 변경
  void updateImageFrame(String id, String frameKey) {
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    _service.updateImageFrame(page: currentPage, id: id, frameKey: frameKey);
    _emit();
  }

  /// 페이지 배경색 변경
  void updatePageBackgroundColor(int color) {
    if (_pages.isEmpty) return;
    _recordUndo();
    final page = _pages[_currentPageIndex];
    final updated = page.copyWith(backgroundColor: color);
    _pages[_currentPageIndex] = updated;
    _emit();
  }

  /// 페이지 배경색 제거 (커버 테마/기본 흰 배경으로 복귀)
  void clearPageBackgroundColor() {
    if (_pages.isEmpty) return;
    _recordUndo();
    final page = _pages[_currentPageIndex];
    _pages[_currentPageIndex] = page.copyWith(backgroundColor: null);
    _emit();
  }

  /// 스티커 추가 (이미지 레이어로 추가, assetPath는 로컬 에셋 경로)
  /// 실제로는 스티커도 LayerType.sticker 등으로 구분하거나
  /// 이미지 레이어의 subtype으로 처리하는 것이 좋으나,
  /// 여기서는 단순화를 위해 AssetEntity 없이 imageUrl/previewUrl에 로컬 경로를 넣어 사용하거나
  /// 별도의 로직을 태운다.
  /// 하지만 현재 LayerModel 구조상 AssetEntity가 없으면 url이 있어야 한다.
  /// 임시로: 스티커는 텍스트 레이어(이모지)로 처리하거나,
  /// 별도 AssetEntity를 생성해야 함.
  /// 우선은 텍스트 이모지로 처리하는 것이 가장 구현이 빠름.
  /// User requested "maintain existing features". If stickers were images, we need image assets.
  /// For now, let's treat stickers as Image Layers with a special flag or just use Text Layer with emoji if assets are missing.
  /// OR, if we assume assets are bundled in app, we need a way to load them.
  /// Let's assume we can add them as Image Layers with `imageUrl` pointing to asset path (requires support in LayerBuilder).
  Future<void> addSticker(String assetPath, Size canvasSize) async {
    // TODO: AssetPath based sticker implementation
    // For now, simple implementation or placeholder
  }

  /// 커버 선택
  void selectCover(CoverSize cover) {
    if (_cover != cover) _hasUnsavedChanges = true;
    _cover = cover;
    _emit();
  }

  /// 에디터 커버 캔버스 크기 설정 (썸네일/스프레드 배치용)
  void setCoverCanvasSize(Size? size, {bool isCover = true}) {
    if (size == null || size == Size.zero) return;

    final prev = state.value;
    if (prev == null) return;

    final oldSize = isCover ? _lastCoverCanvasSize : _lastInnerCanvasSize;

    // [Rescale Fix] 캔버스 크기가 변경되었을 때, 해당 타입의 레이어들만 재조정.
    // [Inner Page Fix] 내지(isCover: false)는 항상 300x400 고정 좌표계를 사용하므로 리스케일링을 하지 않음.
    // UI 단에서 Transform.scale로 대응함.
    if (!isCover) {
      if (oldSize == Size.zero) {
        _lastInnerCanvasSize = size;
        state = AsyncData(prev.copyWith(innerCanvasSize: size));
        debugPrint(
          '[setCoverCanvasSize] Initial INNER size set to $size (No Scaling)',
        );
      }
      return;
    }

    // [10단계 Fix] 커버 역시 내지와 마찬가지로 리스케일링을 수행하지 않습니다.
    // 모든 좌표는 500xH 논리 좌표계에 고정되며, UI 스케일링만 적용됩니다.
    if (isCover) {
      debugPrint(
        '[setCoverCanvasSize] COVER canvas size updated to $size (No Rescaling)',
      );
      _lastCoverCanvasSize = size;
      state = AsyncData(prev.copyWith(coverCanvasSize: size));
      return;
    }

    // 내지 리스케일링 스킵 (기존 유지)
    if (!isCover) {
      _lastInnerCanvasSize = size;
      state = AsyncData(prev.copyWith(innerCanvasSize: size));
    }
  }

  int get innerPageCount => _pages.where((page) => !page.isCover).length;

  bool get canAddPage => innerPageCount < AlbumPagePolicy.maxInnerPages;

  int get pagesToAdd => canAddPage
      ? AlbumPagePolicy.minimumForContent(innerPageCount + 1) - innerPageCount
      : 0;

  String get addPageDescription => canAddPage
      ? '빈 내지 $pagesToAdd쪽 추가 · 표지 별도, 최대 80쪽'
      : '내지는 최대 80쪽까지 추가할 수 있어요';

  void _checkTemplatePageLimit(int count) {
    if (count > AlbumPagePolicy.maxInnerPages) {
      throw StateError(pageLimitMessage);
    }
  }

  // Page IDs identify editing targets independently of their current ordinal.
  // New pages must not alias a retained page or revive a deleted target ID.
  AlbumPage _newInnerPage() => _service
      .createPage(index: _pages.length)
      .copyWith(id: 'page_${const Uuid().v4()}');

  void _padInnerPages(int count) {
    while (innerPageCount < count) {
      _pages.add(_newInnerPage());
    }
  }

  /// 짝수 내지를 유지한다. 기존 홀수 앨범은 한 쪽을 보충한다.
  bool addPage() {
    if (!canAddPage) return false;
    final nextIndex = _pages.length;
    _padInnerPages(innerPageCount + pagesToAdd);
    _targetPagesHint = innerPageCount;
    _currentPageIndex = nextIndex;
    _hasUnsavedChanges = true;
    _emit();
    return true;
  }

  bool get canDeleteCurrentPage {
    if (innerPageCount <= AlbumPagePolicy.minInnerPages) return false;
    if (_currentPageIndex <= 0 || _currentPageIndex >= _pages.length) {
      return false;
    }
    return !_pages[_currentPageIndex].isCover;
  }

  // A styled background is authored content even when it contains no layers.
  int? _blankPartnerForDeletion(int index) {
    if (innerPageCount.isOdd) return null;
    final facing = index.isOdd ? index + 1 : index - 1;
    bool isBlank(int i) =>
        i > 0 &&
        i < _pages.length &&
        i != index &&
        !_pages[i].isCover &&
        _pages[i].layers.isEmpty &&
        _pages[i].backgroundColor == null;
    if (isBlank(facing)) return facing;
    for (var i = _pages.length - 1; i > 0; i--) {
      if (isBlank(i)) return i;
    }
    return null;
  }

  String get deleteCurrentPageDescription {
    if (!canDeleteCurrentPage) return '내지는 최소 20쪽을 유지해야 해요.';
    final partner = _blankPartnerForDeletion(_currentPageIndex);
    if (innerPageCount.isOdd) {
      return '$_currentPageIndex쪽을 삭제하면 내지 ${innerPageCount - 1}쪽이 됩니다. 다른 페이지의 내용은 유지돼요.';
    }
    if (partner != null) {
      return '$_currentPageIndex쪽과 내용이 없는 $partner쪽을 함께 삭제하면 내지 ${innerPageCount - 2}쪽이 됩니다.';
    }
    return '$_currentPageIndex쪽을 삭제하고 맨 뒤에 빈 쪽을 보충해 내지 $innerPageCount쪽을 유지합니다. 다른 페이지의 사진과 글은 삭제하지 않아요.';
  }

  bool deleteCurrentPage() {
    if (!canDeleteCurrentPage) return false;
    return _deleteInnerPage(_currentPageIndex);
  }

  bool _deleteInnerPage(int index) {
    final wasEven = innerPageCount.isEven;
    final partner = _blankPartnerForDeletion(index);
    final selectedPageId = currentPage?.id;
    final removedIndices = [index, if (partner != null) partner]
      ..sort((a, b) => b.compareTo(a));
    for (final removedIndex in removedIndices) {
      _pages.removeAt(removedIndex);
    }
    if (wasEven && partner == null) {
      _pages.add(_newInnerPage());
    }
    for (var i = 0; i < _pages.length; i++) {
      final page = _pages[i];
      _pages[i] = page.copyWith(pageIndex: i, isCover: i == 0);
    }
    _targetPagesHint = innerPageCount;
    final preservedSelection = _pages.indexWhere((p) => p.id == selectedPageId);
    _currentPageIndex = preservedSelection >= 0
        ? preservedSelection
        : (index - 1).clamp(1, _pages.length - 1);
    // Histories use page indices, which changed after removal.
    _clearAllHistory();
    _hasUnsavedChanges = true;
    _emit();
    return true;
  }

  /// 현재 페이지에 템플릿 적용 (기존 레이어를 템플릿 레이아웃으로 교체)
  bool applyTemplateToCurrentPage(PageTemplate template, Size canvasSize) {
    // A layout preview can outlive the permission/session that opened it.
    // Never replace a read-only page or change a document during its save.
    if (_disposed ||
        _isSaving ||
        !editingAllowed ||
        _editingActor != _readOwner()) {
      return false;
    }
    final page = currentPage;
    if (page == null) return false;
    _recordUndo();
    final fromTemplate = _service.createPageFromTemplate(
      template: template,
      index: _currentPageIndex,
      canvasSize: canvasSize,
      isCover: page.isCover,
    );
    final normalized = _normalizeLayersForEditing(
      fromTemplate.layers,
      canvasSize,
    );
    _pages[_currentPageIndex] = page.copyWith(
      layers: normalized,
      backgroundColor: fromTemplate.backgroundColor,
    );
    _emit();
    return true;
  }

  /// 디자인 템플릿(레이어 세트) 적용
  void applyDesignTemplateToCurrentPage(
    DesignTemplate template,
    Size canvasSize,
  ) {
    final page = currentPage;
    if (page == null) return;
    _recordUndo();
    // 템플릿은 항상 커버 기준 논리 캔버스(500xH)에서 생성 후
    // 현재 페이지 캔버스로 동일 비율 스케일해 적용한다.
    final sourceCanvas = _coverReferenceSize;
    final rawLayers = template.buildLayers(sourceCanvas);
    final layers = _scaleTemplateLayers(
      rawLayers,
      from: sourceCanvas,
      to: canvasSize,
    );
    final ready = injectTemplatePreviewImages(
      template,
      layers,
      fillPersistentUrls: true,
    );
    final extracted = _extractTemplateBackgroundForEditing(ready, canvasSize);
    final normalized = _normalizeLayersForEditing(extracted.layers, canvasSize);
    _pages[_currentPageIndex] = page.copyWith(
      layers: [
        for (final layer in normalized) layer.copyWith(isTemplateContent: true),
      ],
      backgroundColor:
          template.backgroundColor?.toARGB32() ??
          extracted.backgroundColor ??
          page.backgroundColor,
    );
    _emit();
  }

  List<LayerModel> _scaleTemplateLayers(
    List<LayerModel> layers, {
    required Size from,
    required Size to,
  }) {
    if (layers.isEmpty || from.width <= 0 || from.height <= 0) return layers;
    final sx = to.width / from.width;
    final sy = to.height / from.height;
    final sText = math.min(sx, sy);

    return layers.map((l) {
      final style = l.textStyle;
      final scaledStyle = style?.copyWith(
        fontSize: style.fontSize == null ? null : style.fontSize! * sText,
        letterSpacing: style.letterSpacing == null
            ? null
            : style.letterSpacing! * sText,
      );
      return l.copyWith(
        position: Offset(l.position.dx * sx, l.position.dy * sy),
        width: l.width * sx,
        height: l.height * sy,
        canvasClip: l.canvasClip == null
            ? null
            : Rect.fromLTWH(
                l.canvasClip!.left * sx,
                l.canvasClip!.top * sy,
                l.canvasClip!.width * sx,
                l.canvasClip!.height * sy,
              ),
        textStyle: scaledStyle,
      );
    }).toList();
  }

  bool _isFullCanvasBackgroundCandidate(LayerModel layer, Size canvas) {
    if (layer.type != LayerType.decoration) {
      return false;
    }
    final nearOrigin =
        layer.position.dx.abs() <= 2.0 && layer.position.dy.abs() <= 2.0;
    if (!nearOrigin) return false;
    final targetW = canvas.width;
    final targetH = canvas.height;
    final nearFull =
        layer.width >= targetW * 0.9 && layer.height >= targetH * 0.9;
    return nearFull;
  }

  ({List<LayerModel> layers, int? backgroundColor})
  _extractTemplateBackgroundForEditing(List<LayerModel> layers, Size canvas) {
    if (layers.isEmpty) {
      return (layers: layers, backgroundColor: null);
    }

    final backgroundCandidates =
        layers
            .where((layer) => _isFullCanvasBackgroundCandidate(layer, canvas))
            .toList(growable: false)
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final backgroundLayer = backgroundCandidates.isEmpty
        ? null
        : backgroundCandidates.first;
    final backgroundColor = backgroundLayer == null
        ? null
        : _resolveTemplateBackgroundColor(backgroundLayer);

    return (layers: layers, backgroundColor: backgroundColor?.toARGB32());
  }

  Color? _resolveTemplateBackgroundColor(LayerModel layer) {
    final fill = _parseHexColor(layer.decorationFillColor);
    if (fill != null) return fill;

    switch (layer.imageBackground) {
      case 'paperWhite':
        return const Color(0xFFFFFFFF);
      case 'paperWhiteWarm':
        return const Color(0xFFF7F1E8);
      case 'paperWarm':
        return const Color(0xFFF1E6D8);
      case 'paperBeige':
        return const Color(0xFFE9DDCB);
      case 'paperYellow':
        return const Color(0xFFF6E6B0);
      case 'paperPink':
        return const Color(0xFFF1DDE2);
      case 'paperGray':
        return const Color(0xFFE9EDF2);
      case 'paperBrown':
      case 'paperBrownLined':
        return const Color(0xFFD8C7B5);
      case 'paperBrownPlain':
        return const Color(0xFFCDB08E);
      case 'skyBlue':
        return const Color(0xFFCDE2F2);
      case 'cloudSkyBlue':
        return const Color(0xFFDCE7EF);
      case 'minimalGray':
        return const Color(0xFFD8DEE6);
      case 'deepNavy':
        return const Color(0xFF24374A);
      case 'darkVignette':
        return const Color(0xFF2E2C3E);
      case 'softSkyBloom':
        return const Color(0xFF8FBCE7);
      case 'blossomPinkDust':
        return const Color(0xFFE688A6);
      case 'dreamyNightSky':
        return const Color(0xFF1D235A);
      case 'saveDateHeroGradient':
        return const Color(0xFF8A8A95);
      case 'notebookPunchPage':
        return const Color(0xFFF7F1E8);
    }

    return null;
  }

  Color? _parseHexColor(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    final hex = normalized.startsWith('#')
        ? normalized.substring(1)
        : normalized;
    if (hex.length != 6 && hex.length != 8) return null;
    final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return value == null ? null : Color(value);
  }

  List<LayerModel> _normalizeLayersForEditing(
    List<LayerModel> layers,
    Size canvas, {
    bool preserveLayout = false,
  }) {
    if (layers.isEmpty) return layers;

    if (preserveLayout) {
      return layers
          .map((layer) {
            var w = layer.width;
            var h = layer.height;
            var x = layer.position.dx;
            var y = layer.position.dy;
            if (!w.isFinite || w <= 0) w = 8;
            if (!h.isFinite || h <= 0) h = 8;
            if (!x.isFinite) x = 0;
            if (!y.isFinite) y = 0;
            return layer.copyWith(position: Offset(x, y), width: w, height: h);
          })
          .toList(growable: false);
    }

    final maxW = math.max(1.0, canvas.width * 2);
    final maxH = math.max(1.0, canvas.height * 2);

    final sanitized = <LayerModel>[];
    for (final layer in layers) {
      var w = layer.width;
      var h = layer.height;
      var x = layer.position.dx;
      var y = layer.position.dy;

      if (!w.isFinite || w <= 0) w = 48;
      if (!h.isFinite || h <= 0) h = 48;
      w = w.clamp(8.0, maxW);
      h = h.clamp(8.0, maxH);

      if (!x.isFinite) x = 0;
      if (!y.isFinite) y = 0;
      x = x.clamp(-w + 8, canvas.width - 8);
      y = y.clamp(-h + 8, canvas.height - 8);

      if (layer.type == LayerType.text) {
        w = w.clamp(36.0, maxW);
        h = h.clamp(24.0, maxH);
      }

      sanitized.add(
        layer.copyWith(position: Offset(x, y), width: w, height: h),
      );
    }

    final backgrounds = sanitized
        .where((l) => _isFullCanvasBackgroundCandidate(l, canvas))
        .toList(growable: false);
    final foregrounds = sanitized
        .where((l) => !_isFullCanvasBackgroundCandidate(l, canvas))
        .toList(growable: false);

    final ordered = <LayerModel>[...backgrounds, ...foregrounds];
    final normalized = <LayerModel>[];
    for (int i = 0; i < ordered.length; i++) {
      normalized.add(ordered[i].copyWith(zIndex: i + 1));
    }
    return normalized;
  }

  /// 템플릿으로 새 페이지 추가 후 해당 페이지로 이동
  bool addPageFromTemplate(PageTemplate template, Size canvasSize) {
    if (!canAddPage) return false;
    final targetCount = innerPageCount + pagesToAdd;
    final nextIndex = _pages.length;
    _pages.add(
      _service.createPageFromTemplate(
        template: template,
        index: nextIndex,
        canvasSize: canvasSize,
        isCover: false,
      ),
    );
    _padInnerPages(targetCount);
    _targetPagesHint = innerPageCount;
    _currentPageIndex = nextIndex;
    _hasUnsavedChanges = true;
    _emit();
    return true;
  }

  /// Save one immutable whole-document snapshot using the loaded server revision.
  /// Other editors' changes are never rebased or merged implicitly.
  Future<bool> saveFullAlbum({
    Uint8List? coverImageBytes,
    ValueChanged<AlbumSaveProgress>? onProgress,
  }) async {
    if (_isSaving) return false;
    final albumId = _editingAlbumId;
    final actor = _readOwner();
    final session = _editSessionIdentity;
    final saveIdentity = Object();
    _activeSaveIdentity = saveIdentity;
    _isSaving = true;
    _lastSaveError = null;
    bool current() =>
        !_disposed &&
        identical(session, _editSessionIdentity) &&
        identical(saveIdentity, _activeSaveIdentity) &&
        _editingAlbumId == albumId &&
        _readOwner() == actor;
    void requireCurrent() {
      if (!current() || actor == null || _editingActor != actor) {
        throw const AlbumEditSessionChanged();
      }
    }

    Future<Album> submit(_AlbumSaveAttempt attempt) async {
      requireCurrent();
      final saved = await _albumRepository.updateAlbum(
        attempt.albumId,
        attempt.request,
        expectedUpdatedAt: attempt.expectedUpdatedAt,
        requestId: attempt.requestId,
        expectedUserId: attempt.actor,
      );
      requireCurrent();
      return saved;
    }

    void accept(Album saved, _AlbumSaveAttempt attempt) {
      requireCurrent();
      _sourceAlbum = saved;
      _initialCoverImageUrl = saved.coverImageUrl;
      _initialCoverThumbnailUrl = saved.coverThumbnailUrl;
      _pendingSaveAttempt = null;
      _uncommittedUploads.clear();
      _hasUnsavedChanges =
          exportFullAlbumLayersJson(null) != attempt.request.coverLayersJson ||
          _selectedTheme.label != attempt.request.coverTheme ||
          _cover.ratio.toString() != attempt.request.ratio ||
          (_initialAlbumTitle ?? '') != attempt.request.title;
      _syncStatus(
        saved.allowsEditing
            ? AlbumEditSyncKind.current
            : AlbumEditSyncKind.accessRevoked,
      );
      ref.read(albumViewModelProvider.notifier).acceptSavedAlbum(saved);
    }

    try {
      requireCurrent();
      if (albumId == null) {
        throw StateError('앨범 정보가 없어 저장할 수 없어요. 앨범을 먼저 만들어주세요.');
      }
      if (!editingAllowed) throw const AlbumEditAccessRevoked();
      // A previous response may have been lost after commit. Resolve exactly
      // that request before preparing a different payload or uploading again.
      final pending = _pendingSaveAttempt;
      if (pending != null) {
        if (pending.albumId != albumId || pending.actor != actor) {
          throw const AlbumEditSessionChanged();
        }
        onProgress?.call(const AlbumSaveProgress(AlbumSavePhase.saving));
        accept(await submit(pending), pending);
        if (!_hasUnsavedChanges) {
          _emit();
          onProgress?.call(const AlbumSaveProgress(AlbumSavePhase.complete));
          return true;
        }
      }
      final source = _sourceAlbum;
      if (source == null || source.updatedAt.isEmpty) {
        throw const AlbumRevisionRequired();
      }
      final pages = _pages.map(_clonePage).toList();
      final cover = _cover;
      final theme = _selectedTheme;
      final sourceTemplateProductKey = _sourceTemplateProductKey;
      final title = _initialAlbumTitle ?? '';
      final jobs = [
        for (var pageIndex = 0; pageIndex < pages.length; pageIndex++)
          for (
            var layerIndex = 0;
            layerIndex < pages[pageIndex].layers.length;
            layerIndex++
          )
            if (_needsPhotoUpload(pages[pageIndex].layers[layerIndex]))
              (page: pageIndex, layer: layerIndex),
      ];
      final uploadCount = jobs.length + (coverImageBytes == null ? 0 : 1);
      var uploadedCount = 0;
      void progress() {
        if (current())
          onProgress?.call(
            AlbumSaveProgress(
              AlbumSavePhase.uploading,
              completed: uploadedCount,
              total: uploadCount,
            ),
          );
      }

      if (uploadCount > 0) progress();
      for (var index = 0; index < jobs.length; index += 4) {
        requireCurrent();
        await Future.wait(
          jobs.skip(index).take(4).map((job) async {
            requireCurrent();
            final page = pages[job.page];
            final layer = page.layers[job.layer];
            final uploaded = await _storage.uploadImageVariants(
              layer.asset!,
              albumId: albumId,
            );
            _trackUpload(uploaded, actor!, current());
            requireCurrent();
            final preview = uploaded.previewGsPath ?? uploaded.previewUrl;
            final original = uploaded.originalGsPath ?? uploaded.originalUrl;
            if (preview?.isNotEmpty != true || original?.isNotEmpty != true) {
              throw StateError('이미지 업로드에 실패했습니다.');
            }
            page.layers[job.layer] = layer.copyWith(
              previewUrl: preview,
              originalUrl: original,
              imageUrl: preview,
            );
            // Retain successful uploads for retry without reverting a newer
            // transform/replacement or resurrecting a deleted page/layer.
            _retainUploadedLayer(page, layer, preview!, original!);
            uploadedCount++;
            progress();
          }),
        );
      }
      requireCurrent();
      UploadedUrls? uploadedCover;
      if (coverImageBytes != null) {
        uploadedCover = await _storage.uploadCoverVariants(
          coverImageBytes,
          albumId: albumId,
        );
        _trackUpload(uploadedCover, actor!, current());
        requireCurrent();
        if ((uploadedCover.previewGsPath ?? uploadedCover.previewUrl)
                    ?.isNotEmpty !=
                true ||
            (uploadedCover.originalGsPath ?? uploadedCover.originalUrl)
                    ?.isNotEmpty !=
                true) {
          throw StateError('표지 이미지 업로드에 실패했습니다.');
        }
        uploadedCount++;
        progress();
      }
      final document = _exportPages(pages, cover, sourceTemplateProductKey);
      String? firstPhoto;
      for (final layer in pages.firstOrNull?.layers ?? <LayerModel>[]) {
        if (layer.type == LayerType.image) {
          firstPhoto = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
          if (firstPhoto?.isNotEmpty == true) break;
        }
      }
      final coverUrl =
          uploadedCover?.previewGsPath ??
          uploadedCover?.previewUrl ??
          firstPhoto ??
          _initialCoverImageUrl ??
          _initialCoverThumbnailUrl ??
          '';
      final attempt = _AlbumSaveAttempt(
        albumId: albumId,
        actor: actor!,
        expectedUpdatedAt: source.updatedAt,
        requestId: const Uuid().v4(),
        request: CreateAlbumRequest(
          ratio: cover.ratio.toString(),
          title: title,
          targetPages: math.max(1, pages.where((page) => !page.isCover).length),
          coverLayersJson: document,
          coverImageUrl: coverUrl,
          coverThumbnailUrl: coverUrl,
          coverPreviewUrl: coverUrl.isEmpty ? null : coverUrl,
          coverOriginalUrl:
              uploadedCover?.originalGsPath ??
              uploadedCover?.originalUrl ??
              source.coverOriginalUrl,
          coverTheme: theme.label,
        ),
      );
      requireCurrent();
      _pendingSaveAttempt = attempt;
      onProgress?.call(const AlbumSaveProgress(AlbumSavePhase.saving));
      accept(await submit(attempt), attempt);
      _emit();
      onProgress?.call(const AlbumSaveProgress(AlbumSavePhase.complete));
      return true;
    } catch (error) {
      if (current()) {
        _lastSaveError = error;
        // These server responses definitively rejected this transaction. Keep
        // local edits/uploads, but resume role/revision checks. Only uncertain
        // transport failures retain the immutable request for commit recovery.
        if (error is AlbumRevisionConflict || error is AlbumEditAccessRevoked) {
          _pendingSaveAttempt = null;
        }
        if (error is AlbumRevisionConflict)
          _syncStatus(AlbumEditSyncKind.remoteChanged);
        if (error is AlbumEditAccessRevoked)
          _syncStatus(AlbumEditSyncKind.accessRevoked);
        _emit();
      }
      return false;
    } finally {
      if (identical(saveIdentity, _activeSaveIdentity)) {
        _activeSaveIdentity = null;
        _isSaving = false;
      }
    }
  }

  bool _needsPhotoUpload(LayerModel layer) =>
      layer.type == LayerType.image &&
      layer.asset != null &&
      layer.previewUrl == null &&
      layer.imageUrl == null &&
      layer.originalUrl == null;

  void _retainUploadedLayer(
    AlbumPage snapshotPage,
    LayerModel original,
    String preview,
    String source,
  ) {
    final page = _pages.where((page) => page.id == snapshotPage.id).firstOrNull;
    if (page == null) return;
    final index = page.layers.indexWhere(
      (layer) =>
          layer.id == original.id &&
          identical(layer.asset, original.asset) &&
          layer.previewUrl == original.previewUrl &&
          layer.originalUrl == original.originalUrl &&
          layer.imageUrl == original.imageUrl,
    );
    if (index < 0) return;
    page.layers[index] = page.layers[index].copyWith(
      previewUrl: preview,
      originalUrl: source,
      imageUrl: preview,
    );
  }

  /// 페이지 전환
  void goToPage(int index) {
    if (index >= 0 && index < _pages.length) {
      _currentPageIndex = index;
      _emit();
    }
  }

  /// 마지막 레이어 제거
  void removeLast() {
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    _service.removeLast(page: currentPage);
    _emit();
  }

  /// 전체 초기화
  void clearAll() {
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    _service.clearAll(page: currentPage);
    _emit();
  }

  /// 특정 레이어 ID로 삭제
  void removeLayerById(String id) {
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    _service.removeLayerById(page: currentPage, id: id);
    _emit();
  }

  /// 선택 해제(뷰 단 관리여도 호출 가능하도록)
  void clearSelectedLayer() {
    _emit();
  }

  /// 커버 페이지가 항상 존재하도록 보장
  void ensureCoverPage() {
    if (_pages.isEmpty || !_pages.first.isCover) {
      _pages.insert(0, _service.createPage(index: 0, isCover: true));
      _currentPageIndex = 0;
      _emit();
    }
  }

  /// 마지막 페이지 제거 (커버 페이지는 제외)
  bool removeLastPage() {
    if (innerPageCount <= AlbumPagePolicy.minInnerPages ||
        _pages.isEmpty ||
        _pages.last.isCover) {
      return false;
    }
    return _deleteInnerPage(_pages.length - 1);
  }

  /// 커버 테마 변경
  void updateTheme(CoverTheme theme) {
    if (_selectedTheme == theme) return;
    _selectedTheme = theme;
    _hasUnsavedChanges = true;
    _emit();
  }

  /// 슬롯 레이어에 이미지 적용
  Future<void> updateSlotImage(
    String layerId,
    AssetEntity asset, {
    String? expectedPageId,
    LayerModel? expectedLayer,
    double imageZoom = 1,
    Offset? imageOffset,
  }) async {
    final page = currentPage;
    if (page == null ||
        _isSaving ||
        (expectedPageId != null && page.id != expectedPageId))
      return;
    final idx = page.layers.indexWhere((l) => l.id == layerId);
    if (idx == -1 || page.layers[idx].type != LayerType.image) return;
    final old = page.layers[idx];
    if (expectedLayer != null && !identical(old, expectedLayer)) return;

    _recordUndo();
    // Commit the new source and crop together, retaining the frame and layout.
    page.layers[idx] = old
        .copyWith(clearImage: true)
        .copyWith(asset: asset, imageZoom: imageZoom, imageOffset: imageOffset);
    _emit();
  }

  bool get _canUndo => (_undoByPage[_currentPageIndex]?.isNotEmpty ?? false);
  bool get _canRedo => (_redoByPage[_currentPageIndex]?.isNotEmpty ?? false);

  void undo() {
    if (_pages.isEmpty) return;
    final undoStack = _undoByPage[_currentPageIndex];
    if (undoStack == null || undoStack.isEmpty) return;

    final currentSnapshot = _clonePage(_pages[_currentPageIndex]);
    final redoStack = _redoByPage.putIfAbsent(_currentPageIndex, () => []);
    redoStack.add(currentSnapshot);

    final prevSnapshot = undoStack.removeLast();
    _historyLocked = true;
    _pages[_currentPageIndex] = _clonePage(prevSnapshot);
    _restoreSinglePageCanvas(_pages[_currentPageIndex]);
    _historyLocked = false;
    _hasUnsavedChanges = _canUndo || _canRedo || _hasUnsavedChanges;
    _emit();
  }

  void redo() {
    if (_pages.isEmpty) return;
    final redoStack = _redoByPage[_currentPageIndex];
    if (redoStack == null || redoStack.isEmpty) return;

    final currentSnapshot = _clonePage(_pages[_currentPageIndex]);
    final undoStack = _undoByPage.putIfAbsent(_currentPageIndex, () => []);
    undoStack.add(currentSnapshot);

    final nextSnapshot = redoStack.removeLast();
    _historyLocked = true;
    _pages[_currentPageIndex] = _clonePage(nextSnapshot);
    _restoreSinglePageCanvas(_pages[_currentPageIndex]);
    _historyLocked = false;
    _hasUnsavedChanges = _canUndo || _canRedo || _hasUnsavedChanges;
    _emit();
  }

  void _clearAllHistory() {
    _undoByPage.clear();
    _redoByPage.clear();
    _hasUnsavedChanges = false;
  }

  void _recordUndo() {
    _recordPageUndo(_currentPageIndex);
  }

  void _recordPageUndo(int pageIndex, {bool skipDuplicate = true}) {
    if (_historyLocked) return;
    if (pageIndex < 0 || pageIndex >= _pages.length) return;
    final page = _pages[pageIndex];

    final snapshot = _clonePage(page);
    final undoStack = _undoByPage.putIfAbsent(pageIndex, () => []);

    // 너무 잦은 중복 기록 방지(간단 비교)
    if (skipDuplicate &&
        undoStack.isNotEmpty &&
        _pageEquals(undoStack.last, snapshot)) {
      return;
    }

    undoStack.add(snapshot);
    _hasUnsavedChanges = true;
    if (undoStack.length > _maxHistory) {
      undoStack.removeAt(0);
    }
    _redoByPage[pageIndex]?.clear();
  }

  AlbumPage _clonePage(AlbumPage page) {
    final clone = page.copyWith(
      layers: page.layers.map((l) => l.copyWith()).toList(growable: true),
    );
    // Snapshot tags take precedence: an undo snapshot must never inherit the
    // current canvas. A normal layer/background edit may replace the current
    // page object, so only that current local page gets the live-size fallback.
    final canvas =
        _singlePageCanvases[page] ??
        (_isSinglePageDraft && identical(page, currentPage)
            ? _lastCoverCanvasSize
            : null);
    if (canvas != null) _singlePageCanvases[clone] = canvas;
    return clone;
  }

  bool _pageEquals(AlbumPage a, AlbumPage b) {
    if (_singlePageCanvases[a] != _singlePageCanvases[b]) return false;
    if (a.backgroundColor != b.backgroundColor) return false;
    if (a.layers.length != b.layers.length) return false;
    for (int i = 0; i < a.layers.length; i++) {
      final la = a.layers[i];
      final lb = b.layers[i];
      if (la.id != lb.id) return false;
      if (la.type != lb.type) return false;
      if (la.position != lb.position) return false;
      if (la.scale != lb.scale) return false;
      if (la.rotation != lb.rotation) return false;
      if (la.opacity != lb.opacity) return false;
      if (la.text != lb.text) return false;
      if ((la.asset?.id) != (lb.asset?.id)) return false;
      if (la.previewUrl != lb.previewUrl) return false;
      if (la.originalUrl != lb.originalUrl) return false;
      if (la.imageUrl != lb.imageUrl) return false;
      if (la.textBackground != lb.textBackground) return false;
      if (la.imageBackground != lb.imageBackground) return false;
      if (la.imageOffset != lb.imageOffset || la.imageZoom != lb.imageZoom)
        return false;
      if (la.width != lb.width || la.height != lb.height) return false;
    }
    return true;
  }

  /// emit (현재 페이지 반영)
  void _emit() {
    final prev = state.value ?? const AlbumEditorState();
    final currentLayers = currentPage?.layers ?? [];

    state = AsyncData(
      prev.copyWith(
        layers: List.of(currentLayers),
        selectedCover: _cover,
        selectedTheme: _selectedTheme,
        coverCanvasSize: prev.coverCanvasSize,
        innerCanvasSize: prev.innerCanvasSize,
        canUndo: _canUndo,
        canRedo: _canRedo,
        isCreatingInBackground: prev.isCreatingInBackground,
      ),
    );
  }

  // ===== getters =====
  List<LayerModel> get layers =>
      List.unmodifiable(currentPage?.layers ?? const []);
  List<AlbumPage> get pages => List.unmodifiable(_pages);
  int get currentPageIndex => _currentPageIndex;

  AlbumPage? get currentPage {
    if (_pages.isEmpty) return null;
    if (_currentPageIndex >= _pages.length) return null;
    return _pages[_currentPageIndex];
  }

  /// 현재 페이지에서 id로 레이어 찾기
  LayerModel? findLayerById(String id) {
    final cp = currentPage;
    if (cp == null) return null;
    try {
      return cp.layers.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 현재 커버(0번 페이지)의 레이어들을 서버 저장용 JSON 문자열로 변환
  /// UI LayerModel → 서버 저장 스키마 변환은 LayerExportMapper 책임
  String exportCoverLayersJson(Size canvasSize) {
    if (_pages.isEmpty) {
      return jsonEncode({
        ...albumSourceTemplateMetadata(_sourceTemplateProductKey),
        if (_cover.printProduct != null) 'printProduct': _cover.printProduct,
        'layers': [],
      });
    }

    final coverPage = _pages.first;

    return jsonEncode({
      ...albumSourceTemplateMetadata(_sourceTemplateProductKey),
      if (_cover.printProduct != null) 'printProduct': _cover.printProduct,
      'layers': coverPage.layers
          .map(
            (layer) => LayerExportMapper.toJson(
              layer,
              canvasSize: _coverReferenceSize,
              isCover: true,
            ),
          )
          .toList(),
    });
  }

  /// 페이지 에디터(PageEditorScreen)의 내지 캔버스 크기 - 300x400 고정
  // [Fix] 내지 캔버스 크기를 커버 비율에 맞춰 동적으로 계산 (일관성 확보)
  Size get _innerPageCanvasSize {
    final ratio = _cover.ratio > 0 ? _cover.ratio : (3 / 4);
    // 페이지도 커버와 동일한 500 기준 좌표계를 사용해 템플릿 체감을 맞춘다.
    return Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
  }

  /// [10단계] 커버 논리 고정 좌표계 크기 (500xH)
  Size get _coverReferenceSize {
    final ratio = _cover.ratio > 0 ? _cover.ratio : 1.0;
    return Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
  }

  /// 현재 페이지의 레이어 리스트 전체 교체 (순서 변경 등)
  void updatePageLayers(
    List<LayerModel> newLayers, {
    bool recordHistory = true,
  }) {
    if (_pages.isEmpty) return;
    final page = _pages[_currentPageIndex];
    if (recordHistory) _recordUndo();

    // Page 객체 불변성 유지하며 레이어 리스트 교체
    final updatedPage = page.copyWith(layers: List.of(newLayers));
    _pages[_currentPageIndex] = updatedPage;
    _emit();
  }

  /// 레이어 순서 변경 (oldIndex -> newIndex)
  void reorderLayer(int oldIndex, int newIndex) {
    if (_pages.isEmpty) return;
    final currentPage = _pages[_currentPageIndex];

    // 범위 체크
    if (oldIndex < 0 || oldIndex >= currentPage.layers.length) return;
    // newIndex는 list length까지 가능 (insert 시) 하지만 reorderable list view 로직 고려
    // ReorderableListView는 old < new 일 때 newIndex -= 1을 이미 처리해서 보내주기도 하지만
    // 여기서는 단순히 removeAt -> insert 로직을 따른다.
    // 범위 조정
    if (newIndex > currentPage.layers.length)
      newIndex = currentPage.layers.length;

    final layers = List<LayerModel>.from(currentPage.layers);
    final item = layers.removeAt(oldIndex);
    layers.insert(newIndex, item);

    updatePageLayers(layers);
  }

  /// 커버 + 모든 내지 페이지 레이어를 서버 저장용 JSON 문자열로 변환
  /// 형식: { "pages": [ { "index": 0, "isCover": true, "layers": [...] }, ... ] }
  /// 커버는 coverCanvasSize, 내지는 300x400 (페이지 에디터와 동일)
  String exportFullAlbumLayersJson(Size? coverCanvasSize) =>
      _exportPages(_pages, _cover, _sourceTemplateProductKey);

  String _exportPages(
    List<AlbumPage> pages,
    CoverSize cover,
    String? sourceTemplateProductKey,
  ) {
    // [10단계] 커버와 내지 모두 고정 참조 사이즈를 사용해 내보냅니다.
    final pagesJson = pages.map((page) {
      final ratio = cover.ratio > 0 ? cover.ratio : 1.0;
      final canvasSize = Size(
        kCoverReferenceWidth,
        kCoverReferenceWidth / ratio,
      );
      return {
        'index': page.pageIndex,
        'isCover': page.isCover,
        if (page.backgroundColor != null)
          'backgroundColor': page.backgroundColor,
        'layers': page.layers
            .map(
              (l) => LayerExportMapper.toJson(
                l,
                canvasSize: canvasSize,
                isCover: page.isCover,
              ),
            )
            .toList(),
      };
    }).toList();
    return jsonEncode({
      ...albumSourceTemplateMetadata(sourceTemplateProductKey),
      if (cover.printProduct != null) 'printProduct': cover.printProduct,
      'pages': pagesJson,
    });
  }
}
