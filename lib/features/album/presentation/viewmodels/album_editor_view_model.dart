import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/api/album_provider.dart';
import '../../data/api/storage_service.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/album_page.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/design_templates.dart';
import '../../../../core/constants/cover_theme.dart';
import '../../../../core/constants/page_templates.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/layer_export_mapper.dart';
import 'gallery_notifier.dart';
import 'cover_view_model.dart';
import 'album_view_model.dart';
import '../../domain/repositories/album_repository.dart';
import '../../service/album_persistence_service.dart';
import '../../service/album_editor_service.dart'; // Restore import

part 'album_editor_view_model.freezed.dart';
part 'album_editor_view_model.g.dart';

/// 갤러리 + 편집 상태 (MVVM)
@freezed
abstract class AlbumEditorState with _$AlbumEditorState {
  const factory AlbumEditorState({
    /// 현재 페이지의 레이어들(UI가 바로 그릴 데이터)
    @Default([]) List<LayerModel> layers,

    @Default(CoverSize(name: '세로형', ratio: 6 / 8, realSize: Size(14.5, 19.4)))
    CoverSize selectedCover,

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

@Riverpod(keepAlive: true)
class AlbumEditorViewModel extends _$AlbumEditorViewModel {
  late final AlbumEditorService _service;
  late final AlbumPersistenceService _persistence;
  late final StorageService _storage;
  late final AlbumRepository _albumRepository;

  final List<AlbumPage> _pages = [];
  int _currentPageIndex = 0;
  int? _editingAlbumId;
  int _targetPagesHint = 0;
  String? _pendingCoverLayersJson;
  List<List<LayerModel>>? _pendingTemplatePagesAfterLoad;
  String? _initialCoverImageUrl;
  String? _initialCoverThumbnailUrl;
  String? _initialAlbumTitle;

  CoverTheme _selectedTheme = CoverTheme.classic;
  CoverSize _cover = coverSizes.first;

  /// [Rescale Fix] 커버와 내지의 마지막 캔버스 크기를 별도로 관리하여 왜곡 방지
  Size _lastCoverCanvasSize = Size.zero;
  Size _lastInnerCanvasSize = Size.zero;

  // ===== Undo / Redo (현재 페이지 기준) =====
  static const int _maxHistory = 30;
  final Map<int, List<AlbumPage>> _undoByPage = {};
  final Map<int, List<AlbumPage>> _redoByPage = {};
  bool _historyLocked = false; // undo/redo 적용 중 기록 방지
  bool _hasUnsavedChanges = false;
  static const int _saveNetworkRetryCount = 3;

  // ===== Selected getters =====
  CoverSize get selectedCover => _cover;
  CoverTheme get selectedTheme => _selectedTheme;

  // Expose the album being edited (if any)
  Album? get album => _editingAlbumId != null
      ? Album(
          id: _editingAlbumId!,
          title: _initialAlbumTitle ?? '제목 없음',
          coverImageUrl: _initialCoverImageUrl ?? '',
          coverThumbnailUrl: _initialCoverThumbnailUrl ?? '',
          createdAt: DateTime.now().toIso8601String(), // Dummy string
        )
      : null;

  @override
  FutureOr<AlbumEditorState> build() async {
    _service = ref.read(albumEditorServiceProvider);
    _persistence = ref.read(albumPersistenceServiceProvider);
    _storage = ref.read(storageServiceProvider);
    _albumRepository = ref.read(albumRepositoryProvider);

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
    int targetPages = 1,
  }) {
    _clearAllHistory();
    _pages.clear();
    _cover =
        initialCover ??
        coverSizes.firstWhere(
          (s) => s.name == '세로형',
          orElse: () => coverSizes.first,
        );
    _selectedTheme = initialTheme ?? CoverTheme.classic;
    _pages.add(_service.createPage(index: 0, isCover: true));

    // Step1에서 선택한 페이지 수(targetPages)만큼 빈 내지 페이지 미리 생성
    final targetPageCount = targetPages > 0 ? targetPages : 1;
    for (int i = 1; i <= targetPageCount; i++) {
      _pages.add(_service.createPage(index: i));
    }

    _currentPageIndex = 0;
    _editingAlbumId = null;
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

  /// 스토어 로컬 템플릿(홈 피처드 등)을 에디터 페이지로 직접 시작
  /// - 서버 앨범 생성 없이 임시 편집 세션으로 진입
  void startLocalTemplateAlbum({
    required String albumTitle,
    required List<List<LayerModel>> pages,
    CoverSize? initialCover,
  }) {
    final chosenCover =
        initialCover ??
        coverSizes.firstWhere(
          (s) => s.name == '세로형',
          orElse: () => coverSizes.first,
        );

    _clearAllHistory();
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

    _currentPageIndex = 0;
    _editingAlbumId = null;
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
  }) {
    if (sourceLayers.isEmpty) return const [];
    final bounds = _templateBounds(sourceLayers);
    final looksNormalized =
        bounds.width <= 2.5 && bounds.height <= 2.5 && bounds.left >= -1.0;

    // 이미 타깃 캔버스와 거의 같으면 재스케일하지 않는다.
    if (!looksNormalized &&
        (bounds.width - targetCanvas.width).abs() <= 1.0 &&
        (bounds.height - targetCanvas.height).abs() <= 1.0) {
      return sourceLayers.map((l) => l.copyWith()).toList(growable: false);
    }

    final sourceCanvas = looksNormalized
        ? _normalizedTemplateCanvasFor(targetCanvas)
        : _estimateTemplateSourceCanvas(sourceLayers);
    final sourceOrigin = looksNormalized
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

    return sourceLayers.map((layer) {
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
      );
    }).toList(growable: false);
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
  }) {
    if (templatePages.isEmpty || _pages.isEmpty) return;

    final start = keepCurrentCover ? 1 : 0;
    final srcStart = keepCurrentCover ? 1 : 0;
    var dstIndex = start;

    for (int srcIndex = srcStart; srcIndex < templatePages.length; srcIndex++) {
      final isCover = dstIndex == 0;
      while (_pages.length <= dstIndex) {
        _pages.add(_service.createPage(index: _pages.length, isCover: false));
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

    _currentPageIndex = _currentPageIndex.clamp(0, _pages.length - 1);
    _emit();
  }

  /// 생성 플로우 Step2에서 템플릿 예시 커버를 미리 보여줄 때 사용
  void applyTemplateCoverPreview(List<LayerModel> coverLayers) {
    if (_pages.isEmpty || coverLayers.isEmpty) return;
    final mapped = _remapTemplatePageLayers(
      sourceLayers: coverLayers,
      targetCanvas: _coverReferenceSize,
    );
    final normalized = _normalizeLayersForEditing(
      mapped,
      _coverReferenceSize,
      preserveLayout: true,
    );
    final cover = _pages.first;
    cover.layers
      ..clear()
      ..addAll(normalized);
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

      if (success) {
        // 폴링 성공 시 앨범 로드
        final updatedAlbum = await ref
            .read(albumRepositoryProvider)
            .fetchAlbum(album.id.toString());
        await _loadAlbumForEdit(updatedAlbum);
        final pendingPages = _pendingTemplatePagesAfterLoad;
        if (pendingPages != null && pendingPages.isNotEmpty) {
          applyTemplatePagesToCurrentAlbum(
            pendingPages,
            keepCurrentCover: false,
          );
          // 템플릿 페이지를 메모리에 주입한 이후에는,
          // 생성 직후 서버의 coverLayersJson(구형/부분 데이터)로 다시 복원되면
          // 내지 템플릿이 덮어써질 수 있으므로 pending 복원을 비활성화한다.
          _pendingCoverLayersJson = null;
        }
        _pendingTemplatePagesAfterLoad = null;
      } else {
        state = const AsyncError('앨범 생성 확인 시간이 초과되었습니다.', StackTrace.empty);
      }
      return;
    }

    // 일반 편집 모드
    await _loadAlbumForEdit(album);
  }

  /// 생성 직후 서버 로드가 끝나면 템플릿 페이지를 자동 적용하기 위한 큐
  void queueTemplatePagesForNextLoad(List<List<LayerModel>> pages) {
    if (pages.isEmpty) return;
    _pendingTemplatePagesAfterLoad = pages;
  }

  /// 앨범 데이터를 로드하여 편집 준비
  Future<void> _loadAlbumForEdit(Album album) async {
    // 목록에서 coverLayersJson이 비어오는 케이스 대비: 상세로 보강
    Album effective = album;
    if (effective.coverLayersJson.isEmpty && effective.id > 0) {
      try {
        effective = await _albumRepository.fetchAlbum(effective.id.toString());
      } catch (_) {
        // 상세 fetch 실패 시에도 편집 화면은 열되, 빈 커버로 표시
      }
    }

    final coverSize = coverSizes.firstWhere(
      (s) => s.ratio.toString() == effective.ratio,
      orElse: () => coverSizes.first,
    );
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
    _initialAlbumTitle = album.title; // 앨범 제목 저장

    // 이전 편집 상태 초기화: 페이지/커버 캔버스 정보 리셋
    _clearAllHistory();
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

    // 앨범 생성 시 _loadAlbumForEdit에서 미리 만들어둔 빈 내지들이 날아가는 것을 방지
    final existingInnerPages = _pages.where((p) => !p.isCover).toList();
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

  /// 앨범 데이터를 백엔드(Spring Boot)에 최종 저장
  /// [coverImageBytes]가 전달되면 에디터 화면을 그대로 캡처한 합성 이미지를
  /// 대표 커버 이미지로 사용한다.
  /// 반환값: 생성된 Album ID (바로 다음 화면으로 이동하기 위함)
  Future<int?> saveAlbumToBackend(
    Size canvasSize, {
    Uint8List? coverImageBytes,
    String? title,
    int? targetPages,
    List<LayerModel>? overrideLayers,
  }) async {
    final List<LayerModel> currentLayers =
        overrideLayers ?? List.of(state.value?.layers ?? []);
    final currentInnerPageCount = math.max(
      1,
      _pages.where((p) => !p.isCover).length,
    );
    final resolvedTargetPages = (() {
      if (targetPages != null && targetPages > 0) return targetPages;
      if (_editingAlbumId != null) return currentInnerPageCount;
      if (_targetPagesHint > 0) return _targetPagesHint;
      return currentInnerPageCount;
    })();
    _targetPagesHint = resolvedTargetPages;
    final albumVm = ref.read(albumViewModelProvider.notifier);
    final themeLabel = _selectedTheme.label;

    try {
      int? createdAlbumId;

      if (_editingAlbumId != null) {
        createdAlbumId = _editingAlbumId;
      } else {
        // 신규 생성 모드: 메타데이터만으로 ID 먼저 발급
        final tempJson = jsonEncode({
          'layers': currentLayers
              .map(
                (l) => LayerExportMapper.toJson(
                  l,
                  canvasSize: canvasSize,
                  isCover: true,
                ),
              )
              .toList(),
        });

        await albumVm.createAlbum(
          ratio: _cover.ratio.toString(),
          title: title ?? '',
          targetPages: resolvedTargetPages,
          coverLayersJson: tempJson,
          coverImageUrl: '',
          coverThumbnailUrl: '',
          coverPreviewUrl: '',
          coverOriginalUrl: '',
          coverTheme: themeLabel,
        );

        final newAlbum = ref.read(albumViewModelProvider).value;
        createdAlbumId = newAlbum?.id;
      }

      // [STEP 2] 후(後) 업로드: 서비스로 이관 (진행률 콜백 포함)
      if (createdAlbumId != null) {
        final uploadFuture = _persistence.performBackgroundUpload(
          albumId: createdAlbumId,
          canvasSize: canvasSize,
          currentLayers: currentLayers,
          coverImageBytes: coverImageBytes,
          themeLabel: themeLabel,
          title: title ?? '',
          coverRatio: _cover.ratio,
          targetPages: resolvedTargetPages,
          swallowErrors: _editingAlbumId == null,
          onProgress: (completed, total) {
            final prev = state.value;
            if (prev == null || total == 0) return;
            final progress = (completed / total).clamp(0.0, 1.0);
            state = AsyncData(
              prev.copyWith(backgroundUploadProgress: progress),
            );
          },
        );
        // 기존 앨범 수정은 "저장 완료" 시점에 실제 반영되도록 완료까지 대기
        if (_editingAlbumId != null) {
          await uploadFuture;
        }
      }
      return createdAlbumId;
    } catch (e) {
      debugPrint('Save Album Error: $e');
      return null;
    }
  }

  /// 이미지 레이어 추가 (현재 페이지)
  /// [templateKey]: null/"free"면 원본 비율, "1:1", "4:3" 등이면 해당 템플릿으로 슬롯 생성(사진 contain)
  Future<void> addImage(
    AssetEntity asset,
    Size canvasSize, {
    String? templateKey,
  }) async {
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    await _service.addImageLayer(
      page: currentPage,
      asset: asset,
      canvasSize: canvasSize,
      templateKey: templateKey,
    );
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
    final double width = (canvasSize.width * 0.54).clamp(150.0, 320.0);
    final double height = (width * 0.84).clamp(120.0, 280.0);

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

    currentPage.layers.add(layer);
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
    final width = base.clamp(22.0, canvasSize.width * 0.36);
    final height = (base * 0.9).clamp(20.0, canvasSize.height * 0.3);
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
      final old = currentPage.layers.where((l) => l.id == updated.id).firstOrNull;
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
    final currentW =
        layer.width.isFinite && layer.width > 1 ? layer.width : 1.0;
    final naturalPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: layer.textAlign ?? TextAlign.center,
      maxLines: null,
    )..layout(minWidth: 0, maxWidth: 100000);

    // 렌더러의 기본 텍스트 패딩과 맞춰 clipping을 방지한다.
    const hPad = 36.0;
    const vPad = 32.0;
    final maxCanvasTextW = math.max(24.0, canvas.width - 8.0);
    final naturalRequiredW = (naturalPainter.width + hPad)
        .clamp(24.0, maxCanvasTextW)
        .toDouble();
    final nextW = math.max(layer.width, naturalRequiredW);

    final fittedPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: layer.textAlign ?? TextAlign.center,
      maxLines: null,
    )..layout(minWidth: 0, maxWidth: nextW);
    final requiredH = (fittedPainter.height + vPad).clamp(20.0, 5000.0).toDouble();
    final nextH = math.max(layer.height, requiredH);

    if ((nextW - layer.width).abs() < 0.1 && (nextH - layer.height).abs() < 0.1) {
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
    // AlbumPage.copyWith는 backgroundColor에 null을 넘기면 기존 값을 유지하므로
    // 여기서는 명시적으로 새 인스턴스를 만들어 backgroundColor를 완전히 제거한다.
    _pages[_currentPageIndex] = AlbumPage(
      id: page.id,
      layers: page.layers,
      pageIndex: page.pageIndex,
      isCover: page.isCover,
      backgroundColor: null,
    );
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

  /// 페이지 추가
  void addPage() {
    final nextIndex = _pages.length;
    _pages.add(_service.createPage(index: nextIndex));
    _targetPagesHint = math.max(1, _pages.where((p) => !p.isCover).length);
    _currentPageIndex = nextIndex;
    _emit();
  }

  /// 현재 페이지에 템플릿 적용 (기존 레이어를 템플릿 레이아웃으로 교체)
  void applyTemplateToCurrentPage(PageTemplate template, Size canvasSize) {
    final page = currentPage;
    if (page == null) return;
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
    page.layers
      ..clear()
      ..addAll(normalized);
    _emit();
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
    final normalized = _normalizeLayersForEditing(ready, canvasSize);
    page.layers
      ..clear()
      ..addAll(normalized);
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
        textStyle: scaledStyle,
      );
    }).toList();
  }

  List<LayerModel> _normalizeTemplateLayers(
    List<LayerModel> layers,
    Size canvas,
  ) {
    if (layers.isEmpty || canvas.width <= 0 || canvas.height <= 0) {
      return layers;
    }

    final content = layers.where((l) {
      if (l.type == LayerType.decoration &&
          l.position == Offset.zero &&
          (l.width - canvas.width).abs() <= 0.1 &&
          (l.height - canvas.height).abs() <= 0.1) {
        return false;
      }
      return true;
    }).toList();
    if (content.isEmpty) return layers;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    for (final l in content) {
      minX = math.min(minX, l.position.dx);
      minY = math.min(minY, l.position.dy);
      maxX = math.max(maxX, l.position.dx + l.width);
      maxY = math.max(maxY, l.position.dy + l.height);
    }

    final boundsW = maxX - minX;
    final boundsH = maxY - minY;
    if (boundsW <= 0 || boundsH <= 0) return layers;

    final inset = math.min(canvas.width, canvas.height) * 0.01;
    final targetW = canvas.width - (inset * 2);
    final targetH = canvas.height - (inset * 2);
    final scale = math.min(1.0, math.min(targetW / boundsW, targetH / boundsH));

    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    final tx = canvas.width / 2 - cx;
    final ty = canvas.height / 2 - cy;

    return layers.map((l) {
      if (l.type == LayerType.decoration &&
          l.position == Offset.zero &&
          (l.width - canvas.width).abs() <= 0.1 &&
          (l.height - canvas.height).abs() <= 0.1) {
        return l;
      }

      final center = Offset(
        l.position.dx + l.width / 2,
        l.position.dy + l.height / 2,
      );
      final movedCenter = Offset(center.dx + tx, center.dy + ty);
      final canvasCenter = Offset(canvas.width / 2, canvas.height / 2);
      final scaledCenter =
          canvasCenter + ((movedCenter - canvasCenter) * scale);
      final w = l.width * scale;
      final h = l.height * scale;
      final x = scaledCenter.dx - w / 2;
      final y = scaledCenter.dy - h / 2;
      final style = l.textStyle;
      final scaledStyle = style?.copyWith(
        fontSize: style.fontSize == null ? null : style.fontSize! * scale,
        letterSpacing: style.letterSpacing == null
            ? null
            : style.letterSpacing! * scale,
      );

      final clampedX = x.clamp(inset, canvas.width - w - inset).toDouble();
      final clampedY = y.clamp(inset, canvas.height - h - inset).toDouble();

      return l.copyWith(
        position: Offset(clampedX, clampedY),
        width: w,
        height: h,
        textStyle: scaledStyle,
      );
    }).toList();
  }

  bool _isFullCanvasBackgroundCandidate(LayerModel layer, Size canvas) {
    if (layer.type != LayerType.decoration && layer.type != LayerType.image) {
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

  List<LayerModel> _normalizeLayersForEditing(
    List<LayerModel> layers,
    Size canvas,
    {bool preserveLayout = false}
  ) {
    if (layers.isEmpty) return layers;

    if (preserveLayout) {
      return layers.map((layer) {
        var w = layer.width;
        var h = layer.height;
        var x = layer.position.dx;
        var y = layer.position.dy;
        if (!w.isFinite || w <= 0) w = 8;
        if (!h.isFinite || h <= 0) h = 8;
        if (!x.isFinite) x = 0;
        if (!y.isFinite) y = 0;
        return layer.copyWith(position: Offset(x, y), width: w, height: h);
      }).toList(growable: false);
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
  void addPageFromTemplate(PageTemplate template, Size canvasSize) {
    final nextIndex = _pages.length;
    _pages.add(
      _service.createPageFromTemplate(
        template: template,
        index: nextIndex,
        canvasSize: canvasSize,
        isCover: false,
      ),
    );
    _targetPagesHint = math.max(1, _pages.where((p) => !p.isCover).length);
    _currentPageIndex = nextIndex;
    _emit();
  }

  /// 앨범 전체(모든 페이지)를 서버에 저장
  Future<bool> saveFullAlbum({Uint8List? coverImageBytes}) async {
    state = const AsyncLoading(); // 로딩 상태 시작

    try {
      // 1. 모든 페이지를 병렬로 순회하며 이미지 레이어 업로드 및 로컬 상태 반영
      // [PERFORMANCE] 순차 처리(for문) -> 병렬 처리(Future.wait)로 변경하여 속도 개선
      await Future.wait(
        _pages.map((page) async {
          final updatedLayers = await Future.wait(
            page.layers.map((layer) async {
              if (layer.type == LayerType.image &&
                  (layer.previewUrl == null && layer.imageUrl == null) &&
                  layer.asset != null) {
                final uploaded = await _storage.uploadImageVariants(
                  layer.asset!,
                );
                final preview = uploaded.previewGsPath ?? uploaded.previewUrl;
                final original =
                    uploaded.originalGsPath ?? uploaded.originalUrl;
                if (preview == null && original == null) {
                  throw StateError('이미지 업로드에 실패했습니다. (layerId=${layer.id})');
                }
                return layer.copyWith(
                  previewUrl: preview,
                  originalUrl: original,
                  imageUrl: preview, // 하위 호환 미러링
                );
              }
              return layer;
            }),
          );
          page.layers
            ..clear()
            ..addAll(updatedLayers);
        }),
      );

      // 1.1 커버 이미지 업로드 (전달된 경우)
      UploadedUrls? coverUploaded;
      if (coverImageBytes != null) {
        coverUploaded = await _storage.uploadCoverVariants(coverImageBytes);
      }

      // 2. 전체 앨범 JSON 생성 후 서버에 저장 (편집 중인 앨범인 경우)
      final albumVm = ref.read(albumViewModelProvider.notifier);
      final stateVal = state.value;
      final canvasSize =
          (stateVal != null &&
              stateVal.coverCanvasSize != null &&
              stateVal.coverCanvasSize != Size.zero)
          ? stateVal.coverCanvasSize
          : (_lastCoverCanvasSize != Size.zero
                ? _lastCoverCanvasSize
                : Size(358.0, 358.0 / _cover.ratio));

      AppLogger.debug(
        '[saveFullAlbum] Using canvas size for export: ${canvasSize!.width.toStringAsFixed(1)} x ${canvasSize.height.toStringAsFixed(1)}',
      );
      final fullJson = exportFullAlbumLayersJson(canvasSize);
      final themeLabel = _selectedTheme.label;
      final resolvedTargetPages = math.max(
        1,
        _pages.where((p) => !p.isCover).length,
      );
      _targetPagesHint = resolvedTargetPages;

      if (_editingAlbumId != null) {
        // 커버 URL 우선순위:
        // 1) 현재 저장에서 새로 업로드한 커버 캡처
        // 2) 현재 커버 페이지의 첫 이미지 레이어 URL (방금 편집한 결과)
        // 3) 기존 커버 URL
        final uploadedCoverUrl =
            coverUploaded?.previewGsPath ?? coverUploaded?.previewUrl;
        String? coverFromLayer;
        if (_pages.isNotEmpty) {
          final coverPage = _pages.first;
          for (final layer in coverPage.layers) {
            if (layer.type == LayerType.image) {
              final url =
                  layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
              if (url != null && url.isNotEmpty) {
                coverFromLayer = url;
                break;
              }
            }
          }
        }

        final coverImg =
            uploadedCoverUrl ??
            coverFromLayer ??
            _initialCoverImageUrl ??
            _initialCoverThumbnailUrl ??
            '';
        final coverThumb =
            uploadedCoverUrl ??
            coverFromLayer ??
            _initialCoverThumbnailUrl ??
            _initialCoverImageUrl ??
            '';
        await _runWithRetry(() async {
          await albumVm.updateAlbum(
            albumId: _editingAlbumId!,
            ratio: _cover.ratio.toString(),
            title: _initialAlbumTitle ?? '', // 앨범 제목 유지
            targetPages: resolvedTargetPages,
            coverLayersJson: fullJson,
            coverImageUrl: coverImg,
            coverThumbnailUrl: coverThumb,
            coverPreviewUrl: coverImg.isNotEmpty ? coverImg : null,
            coverOriginalUrl: null,
            coverTheme: themeLabel,
          );
        }, maxAttempts: _saveNetworkRetryCount);
        if (coverImg.isNotEmpty) {
          _initialCoverImageUrl = coverImg;
        }
        if (coverThumb.isNotEmpty) {
          _initialCoverThumbnailUrl = coverThumb;
        }
        // 편집 세션은 유지 (연속 저장/추가 수정 대응)
      }

      // 백그라운드 업로드 진행률 초기화
      final prev = state.value ?? const AlbumEditorState();
      state = AsyncData(prev.copyWith(backgroundUploadProgress: 0.0));

      _hasUnsavedChanges = false;
      _emit();
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false; // 실패 반환
    }
  }

  Future<T> _runWithRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    StackTrace? lastStack;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        final canRetry = _isRetriableError(e) && attempt < maxAttempts;
        if (!canRetry) {
          rethrow;
        }
        final delayMs = 250 * attempt;
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  bool _isRetriableError(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode ?? 0;
          return code >= 500 && code < 600;
        default:
          return false;
      }
    }
    return false;
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
  void removeLastPage() {
    if (_pages.length > 1) {
      _pages.removeLast();
      if (_currentPageIndex >= _pages.length) {
        _currentPageIndex = _pages.length - 1;
      }
      _emit();
    }
  }

  /// 커버 테마 변경
  void updateTheme(CoverTheme theme) {
    if (_selectedTheme == theme) return;
    _selectedTheme = theme;
    _emit();
  }

  /// 슬롯 레이어에 이미지 적용
  Future<void> updateSlotImage(String layerId, AssetEntity asset) async {
    final page = _pages[_currentPageIndex];
    final idx = page.layers.indexWhere((l) => l.id == layerId);
    if (idx == -1) return;

    _recordUndo();
    final old = page.layers[idx];
    // 템플릿 등 기존 URL이 있는 슬롯에 새 사진을 교체할 때
    // 이전 URL을 반드시 비워야 저장 시 새 업로드 결과로 치환된다.
    // (LayerModel.copyWith는 nullable 필드를 null로 명시 설정할 수 없어 새 객체로 교체)
    final updated = LayerModel(
      id: old.id,
      type: old.type,
      position: old.position,
      asset: asset,
      text: old.text,
      textStyle: old.textStyle,
      textStyleType: old.textStyleType,
      bubbleColor: old.bubbleColor,
      scale: old.scale,
      rotation: old.rotation,
      textAlign: old.textAlign,
      width: old.width,
      height: old.height,
      textBackground: old.textBackground,
      imageBackground: old.imageBackground,
      imageTemplate: old.imageTemplate,
      frameBaseWidth: old.frameBaseWidth,
      frameBaseHeight: old.frameBaseHeight,
      frameBasePosition: old.frameBasePosition,
      imageOffset: old.imageOffset,
      previewUrl: null,
      imageUrl: null,
      originalUrl: null,
      opacity: old.opacity,
      zIndex: old.zIndex,
    );

    page.layers[idx] = updated;
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
    if (_historyLocked) return;
    if (_pages.isEmpty) return;
    final page = _pages[_currentPageIndex];

    final snapshot = _clonePage(page);
    final undoStack = _undoByPage.putIfAbsent(_currentPageIndex, () => []);

    // 너무 잦은 중복 기록 방지(간단 비교)
    if (undoStack.isNotEmpty && _pageEquals(undoStack.last, snapshot)) {
      return;
    }

    undoStack.add(snapshot);
    _hasUnsavedChanges = true;
    if (undoStack.length > _maxHistory) {
      undoStack.removeAt(0);
    }
    _redoByPage[_currentPageIndex]?.clear();
  }

  AlbumPage _clonePage(AlbumPage page) {
    return page.copyWith(
      layers: page.layers.map((l) => l.copyWith()).toList(growable: true),
    );
  }

  bool _pageEquals(AlbumPage a, AlbumPage b) {
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
      return jsonEncode({'layers': []});
    }

    final coverPage = _pages.first;

    return jsonEncode({
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
  String exportFullAlbumLayersJson(Size? coverCanvasSize) {
    // [10단계] 커버와 내지 모두 고정 참조 사이즈를 사용해 내보냅니다.
    final pagesJson = _pages.map((page) {
      final canvasSize = page.isCover
          ? _coverReferenceSize
          : _innerPageCanvasSize;
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
    return jsonEncode({'pages': pagesJson});
  }
}
