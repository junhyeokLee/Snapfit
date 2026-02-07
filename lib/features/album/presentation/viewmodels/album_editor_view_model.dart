import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/api/album_provider.dart';
import '../../data/api/storage_service.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/album_page.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/cover_theme.dart';
import '../../../../core/constants/page_templates.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/layer_export_mapper.dart';
import '../../domain/repositories/album_repository.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../../service/album_editor_service.dart';
import 'album_view_model.dart';
import 'cover_view_model.dart';

part 'album_editor_view_model.freezed.dart';
part 'album_editor_view_model.g.dart';

/// 갤러리 + 편집 상태 (MVVM)
@freezed
abstract class AlbumEditorState with _$AlbumEditorState {
  const factory AlbumEditorState({
    @Default([]) List<AssetEntity> files,
    @Default([]) List<AssetPathEntity> albums,
    AssetPathEntity? currentAlbum,

    /// 현재 페이지의 레이어들(UI가 바로 그릴 데이터)
    @Default([]) List<LayerModel> layers,

    @Default(
      CoverSize(
        name: '세로형',
        ratio: 6 / 8,
        realSize: Size(14.5, 19.4),
      ),
    )
    CoverSize selectedCover,

    @Default(CoverTheme.classic) CoverTheme selectedTheme,

    /// 에디터 커버 캔버스 크기 (레이어 좌표 기준). 썸네일/스프레드 배치용.
    Size? coverCanvasSize,
  }) = _AlbumEditorState;
}

@Riverpod(keepAlive: true)
class AlbumEditorViewModel extends _$AlbumEditorViewModel {
  late final AlbumEditorService _service;
  late final GalleryRepository _gallery;
  late final StorageService _storage;
  late final AlbumRepository _albumRepository;

  final List<AssetEntity> _files = [];
  final List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;

  CoverSize _cover = coverSizes.first;
  CoverTheme _selectedTheme = CoverTheme.classic;

  // 페이지 구조
  final List<AlbumPage> _pages = [];
  int _currentPageIndex = 0;

  /// 홈에서 편집으로 열었을 때의 앨범 ID (저장 시 update 호출용)
  int? _editingAlbumId;
  String? _pendingCoverLayersJson;
  /// 편집 진입 시 앨범의 커버 이미지 URL (saveFullAlbum 시 updateAlbum에 전달)
  String? _initialCoverImageUrl;
  String? _initialCoverThumbnailUrl;

  static const _pageSize = 80;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;

  // ===== Selected getters =====
  CoverSize get selectedCover => _cover;
  CoverTheme get selectedTheme => _selectedTheme;

  @override
  FutureOr<AlbumEditorState> build() async {
    _service = ref.read(albumEditorServiceProvider);
    _gallery = ref.read(galleryRepositoryProvider);
    _storage = ref.read(storageServiceProvider);
    _albumRepository = ref.read(albumRepositoryProvider);

    // 초기 표지 페이지 생성
    if (_pages.isEmpty) {
      _pages.add(_service.createPage(index: 0, isCover: true));
    }

    return AlbumEditorState(
      files: List.of(_files),
      albums: List.of(_albums),
      currentAlbum: _currentAlbum,
      layers: List.of(currentPage?.layers ?? const []),
      selectedCover: _cover,
      selectedTheme: _selectedTheme,
      coverCanvasSize: null,
    );
  }

  /// 신규 생성(+ 진입)용: 기존 편집/갤러리 상태를 모두 버리고 "빈 커버"로 초기화
  /// - 갤러리(앨범/사진) 로딩은 하지 않는다 (요구사항: 불러오는거 X)
  void resetForCreate({CoverSize? initialCover, CoverTheme? initialTheme}) {
    _editingAlbumId = null;
    _pendingCoverLayersJson = null;
    _initialCoverImageUrl = null;
    _initialCoverThumbnailUrl = null;

    _cover = initialCover ?? coverSizes.firstWhere(
      (s) => s.name == '세로형',
      orElse: () => coverSizes.first,
    );
    _selectedTheme = initialTheme ?? CoverTheme.classic;

    _pages.clear();
    _pages.add(_service.createPage(index: 0, isCover: true));
    _currentPageIndex = 0;

    // 갤러리 상태도 비워서 "빈 레이아웃" 느낌을 유지 (사진 선택 시 그때 로딩)
    _files.clear();
    _albums.clear();
    _currentAlbum = null;
    _page = 0;
    _hasMore = true;
    _loading = false;

    // Cover VM도 동기화 (화면 선택기/테마 즉시 반영)
    ref.read(coverViewModelProvider.notifier).selectCover(_cover);
    ref.read(coverViewModelProvider.notifier).updateTheme(_selectedTheme);

    final prev = state.value ?? const AlbumEditorState();
    state = AsyncData(prev.copyWith(coverCanvasSize: null));
    _emit();
  }

  /// 사진 선택 바텀시트 등을 열기 전에 갤러리 데이터가 비어있으면 1회 로딩
  Future<void> ensureGalleryLoaded() async {
    if (_albums.isNotEmpty && _currentAlbum != null) return;
    await fetchInitialData();
  }

  /// 초기 데이터
  Future<void> fetchInitialData() async {
    final ok = await _gallery.requestPermission();
    if (!ok) {
      state = const AsyncError('갤러리 접근 권한이 필요합니다.', StackTrace.empty);
      return;
    }

    final list = await _gallery.loadAlbums();
    _albums
      ..clear()
      ..addAll(list);

    if (_albums.isEmpty) {
      state = const AsyncError('이미지 앨범이 없습니다.', StackTrace.empty);
      return;
    }

    await selectAlbum(_albums.first);
  }

  /// 앨범 선택
  Future<void> selectAlbum(AssetPathEntity album) async {
    _currentAlbum = album;
    _files.clear();
    _page = 0;
    _hasMore = true;
    await loadMore();
  }

  /// 홈에서 선택한 앨범을 "편집 준비" 상태로 세팅
  /// - 실제 레이어 복원은 EditCover에서 실제 커버 캔버스 크기(_coverSize)가 잡힌 뒤 수행해야
  ///   위치/스케일이 정확히 맞는다.
  Future<void> prepareAlbumForEdit(Album album) async {
    _editingAlbumId = album.id > 0 ? album.id : null;

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

    // 테마 복원 (서버에서 coverTheme 반환 시)
    final themeStr = effective.coverTheme;
    if (themeStr != null && themeStr.isNotEmpty) {
      try {
        // 과거 값 호환: abstract1이 "abstract"로 저장된 경우가 있었음
        final normalized = themeStr == 'abstract' ? 'abstract1' : themeStr;
        final theme = CoverTheme.values.firstWhere((t) => t.label == normalized);
        _selectedTheme = theme;
        ref.read(coverViewModelProvider.notifier).updateTheme(theme);
      } catch (_) {
        // 알 수 없는 테마 문자열이면 기본값 유지
      }
    }

    // 레이어 JSON은 실제 canvasSize가 정해진 다음에 복원
    _pendingCoverLayersJson =
        effective.coverLayersJson.isEmpty ? '{"layers":[]}' : effective.coverLayersJson;
    _initialCoverImageUrl = effective.coverImageUrl;
    _initialCoverThumbnailUrl = effective.coverThumbnailUrl;

    // 이전 편집 상태 초기화: 페이지/커버 캔버스 정보 리셋
    _pages.clear();
    _pages.add(_service.createPage(index: 0, isCover: true));
    _currentPageIndex = 0;

    // coverCanvasSize 도 초기화해서, 다음 화면(커버/스프레드)에서
    // loadPendingEditAlbumIfNeeded 가 새 앨범 기준으로 다시 한 번만 동작하도록 한다.
    final prev = state.value ?? const AlbumEditorState();
    state = AsyncData(prev.copyWith(coverCanvasSize: null));

    // 커버 사이즈/테마만 먼저 반영(선택기/레이아웃 동기화)
    _emit();
  }

  /// 편집 모드 여부 (저장 성공 시 홈으로 pop할지, 스프레드로 push할지 판단용)
  bool get isEditingExistingAlbum => _editingAlbumId != null;

  /// 현재 편집 중인 앨범 ID (Hero 태그 등에서 사용)
  int? get editingAlbumId => _editingAlbumId;

  /// EditCover에서 실제 커버 캔버스 크기가 잡힌 뒤 1회만 레이어 복원
  void loadPendingEditAlbumIfNeeded(Size canvasSize) {
    final json = _pendingCoverLayersJson;
    if (json == null) return;
    if (canvasSize == Size.zero) return;
    _pendingCoverLayersJson = null;
    loadAlbum({'coverLayersJson': json}, canvasSize);
    setCoverCanvasSize(canvasSize);
  }

  /// 서버에서 불러온 앨범 데이터를 편집기에 로드
  /// coverLayersJson이 "pages" 배열 형식이면 커버+내지 모두 복원, 아니면 기존 형식(cover만) 복원
  /// [canvasSize]: 커버용 캔버스 크기. 내지 페이지는 300x400 고정(페이지 에디터와 동일)
  void loadAlbum(Map<String, dynamic> albumData, Size canvasSize) {
    if (canvasSize == Size.zero) return;

    final String raw = albumData['coverLayersJson'] as String? ?? '{}';
    final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>? ?? {};

    _pages.clear();

    // 새 형식: { "pages": [ { "index", "isCover", "layers" }, ... ] }
    final List<dynamic>? pagesList = data['pages'] as List<dynamic>?;
    if (pagesList != null && pagesList.isNotEmpty) {
      for (final p in pagesList) {
        final map = p as Map<String, dynamic>;
        final index = (map['index'] as num?)?.toInt() ?? _pages.length;
        final isCover = map['isCover'] as bool? ?? (index == 0);
        final layerList = (map['layers'] as List<dynamic>?) ?? [];
        // 커버는 canvasSize, 내지는 300x400 (페이지 에디터와 동일)
        final pageCanvasSize = isCover ? canvasSize : _innerPageCanvasSize;
        final loadedLayers = layerList.map((l) {
          return LayerExportMapper.fromJson(
            l as Map<String, dynamic>,
            canvasSize: pageCanvasSize,
          );
        }).toList();
        final page = _service.createPage(index: index, isCover: isCover);
        page.layers.addAll(loadedLayers);
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
          canvasSize: canvasSize,
        );
      }).toList();
      final coverPage = _service.createPage(index: 0, isCover: true);
      coverPage.layers.addAll(loadedLayers);
      _pages.add(coverPage);
    }

    _emit();
  }

  /// 앨범 데이터를 백엔드(Spring Boot)에 최종 저장
  /// [coverImageBytes]가 전달되면 에디터 화면을 그대로 캡처한 합성 이미지를
  /// 대표 커버 이미지로 사용한다.
  Future<void> saveAlbumToBackend(
    Size canvasSize, {
    Uint8List? coverImageBytes,
  }) async {
    final List<LayerModel> currentLayers = List.of(state.value?.layers ?? []);

    try {
      // 1. 이미지 레이어 최적화 업로드 (이미 URL이 있는 경우는 건너뜀)
      final updatedLayers = await Future.wait(currentLayers.map((layer) async {
        // 이미지 타입이고, 아직 업로드되지 않았으며(previewUrl/imageUrl null), 로컬 파일(asset)이 있는 경우만 업로드
        if (layer.type == LayerType.image &&
            (layer.previewUrl == null && layer.imageUrl == null && layer.originalUrl == null) &&
            layer.asset != null) {
          final uploaded = await _storage.uploadImageVariants(layer.asset!);
          final preview = uploaded.previewGsPath ?? uploaded.previewUrl;
          final original = uploaded.originalGsPath ?? uploaded.originalUrl;
          if (preview != null || original != null) {
            return layer.copyWith(
              previewUrl: preview,
              originalUrl: original,
              imageUrl: preview, // 하위 호환 미러링
            );
          }
        }
        return layer;
      }));

      // 2. 서버 저장용 JSON 문자열 생성 (상대 좌표 비율로 변환)
      final json = jsonEncode({
        'layers': updatedLayers.map((l) => LayerExportMapper.toJson(l, canvasSize: canvasSize)).toList()
      });

      // 3. 대표 이미지(커버) URL 결정
      String? coverPreviewUrl;
      String? coverOriginalUrl;

      // 3-1. 캡처된 합성 이미지가 있으면 우선 사용
      if (coverImageBytes != null) {
        final uploaded = await _storage.uploadCoverVariants(coverImageBytes);
        coverPreviewUrl = uploaded.previewGsPath ?? uploaded.previewUrl;
        coverOriginalUrl = uploaded.originalGsPath ?? uploaded.originalUrl;
      }

      // 3-2. 없으면 여전히 첫 번째 이미지 레이어 활용
      coverPreviewUrl ??= updatedLayers
          .firstWhere(
            (l) => l.type == LayerType.image && (l.previewUrl ?? l.imageUrl) != null,
            orElse: () => updatedLayers.first,
          )
          .previewUrl ?? updatedLayers
          .firstWhere(
            (l) => l.type == LayerType.image && (l.previewUrl ?? l.imageUrl) != null,
            orElse: () => updatedLayers.first,
          )
          .imageUrl;

      // 4. 백엔드 API 호출 (편집 시 update, 신규 시 create)
      final albumVm = ref.read(albumViewModelProvider.notifier);
      final themeLabel = _selectedTheme.label;
      if (_editingAlbumId != null) {
        await albumVm.updateAlbum(
          albumId: _editingAlbumId!,
          ratio: _cover.ratio.toString(),
          coverLayersJson: json,
          // 하위 호환: coverImageUrl/coverThumbnailUrl에 preview 미러링
          coverImageUrl: coverPreviewUrl ?? '',
          coverThumbnailUrl: coverPreviewUrl ?? '',
          coverPreviewUrl: coverPreviewUrl,
          coverOriginalUrl: coverOriginalUrl,
          coverTheme: themeLabel,
        );
        _editingAlbumId = null;
      } else {
        await albumVm.createAlbum(
          ratio: _cover.ratio.toString(),
          coverLayersJson: json,
          coverImageUrl: coverPreviewUrl ?? '',
          coverThumbnailUrl: coverPreviewUrl ?? '',
          coverPreviewUrl: coverPreviewUrl,
          coverOriginalUrl: coverOriginalUrl,
          coverTheme: themeLabel,
        );
      }

      _emit();

    } catch (e) {
      // 에러 발생 시 처리 (예: 스낵바 표시 등)
      debugPrint("Save Album Error: $e");
    }
  }

  /// 이미지 페이징
  Future<void> loadMore() async {
    if (_loading || !_hasMore || _currentAlbum == null) return;
    _loading = true;

    try {
      final page = await _gallery.loadImagesPaged(_currentAlbum!, _page, _pageSize);
      _files.addAll(page);
      _hasMore = page.length == _pageSize;
      _page++;
      _emit();
    } finally {
      _loading = false;
    }
  }

  /// 이미지 레이어 추가 (현재 페이지)
  /// [templateKey]: null/"free"면 원본 비율, "1:1", "4:3" 등이면 해당 템플릿으로 슬롯 생성(사진 contain)
  Future<void> addImage(AssetEntity asset, Size canvasSize, {String? templateKey}) async {
    final currentPage = _pages[_currentPageIndex];
    await _service.addImageLayer(
      page: currentPage,
      asset: asset,
      canvasSize: canvasSize,
      templateKey: templateKey,
    );
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
    final currentPage = _pages[_currentPageIndex];

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
    );

    _emit();
  }

  /// 레이어 업데이트
  void updateLayer(LayerModel updated) {
    final currentPage = _pages[_currentPageIndex];
    _service.updateLayer(page: currentPage, updated: updated);
    _emit();
  }

  /// 텍스트 스타일 변경
  void updateTextStyle(String id, String styleKey) {
    final currentPage = _pages[_currentPageIndex];
    _service.updateTextStyle(page: currentPage, id: id, styleKey: styleKey);
    _emit();
  }

  /// 이미지 프레임 스타일 변경
  void updateImageFrame(String id, String frameKey) {
    final currentPage = _pages[_currentPageIndex];
    _service.updateImageFrame(page: currentPage, id: id, frameKey: frameKey);
    _emit();
  }

  /// 커버 선택
  void selectCover(CoverSize cover) {
    _cover = cover;
    _emit();
  }

  /// 에디터 커버 캔버스 크기 설정 (썸네일/스프레드 배치용)
  void setCoverCanvasSize(Size? size) {
    final prev = state.value;
    if (prev == null) return;
    state = AsyncData(prev.copyWith(coverCanvasSize: size));
  }

  /// 페이지 추가
  void addPage() {
    final nextIndex = _pages.length;
    _pages.add(_service.createPage(index: nextIndex));
    _currentPageIndex = nextIndex;
    _emit();
  }

  /// 현재 페이지에 템플릿 적용 (기존 레이어를 템플릿 레이아웃으로 교체)
  void applyTemplateToCurrentPage(PageTemplate template, Size canvasSize) {
    final page = currentPage;
    if (page == null) return;
    final fromTemplate = _service.createPageFromTemplate(
      template: template,
      index: _currentPageIndex,
      canvasSize: canvasSize,
    );
    page.layers
      ..clear()
      ..addAll(fromTemplate.layers);
    _emit();
  }

  /// 템플릿으로 새 페이지 추가 후 해당 페이지로 이동
  void addPageFromTemplate(PageTemplate template, Size canvasSize) {
    final nextIndex = _pages.length;
    _pages.add(_service.createPageFromTemplate(
      template: template,
      index: nextIndex,
      canvasSize: canvasSize,
    ));
    _currentPageIndex = nextIndex;
    _emit();
  }

  /// 앨범 전체(모든 페이지)를 서버에 저장
  Future<void> saveFullAlbum() async {
    state = const AsyncLoading(); // 로딩 상태 시작

    try {
      // 1. 모든 페이지를 순회하며 이미지 레이어 업로드 및 로컬 상태 반영
      for (var page in _pages) {
        final updatedLayers = await Future.wait(
          page.layers.map((layer) async {
            if (layer.type == LayerType.image &&
                (layer.previewUrl == null && layer.imageUrl == null) &&
                layer.asset != null) {
              final uploaded = await _storage.uploadImageVariants(layer.asset!);
              final preview = uploaded.previewUrl;
              final original = uploaded.originalUrl;
              if (preview != null || original != null) {
                return layer.copyWith(
                  previewUrl: preview,
                  originalUrl: original,
                  imageUrl: preview, // 하위 호환 미러링
                );
              }
            }
            return layer;
          }),
        );
        page.layers
          ..clear()
          ..addAll(updatedLayers);
      }

      // 2. 전체 앨범 JSON 생성 후 서버에 저장 (편집 중인 앨범인 경우)
      final albumVm = ref.read(albumViewModelProvider.notifier);
      final canvasSize = state.value?.coverCanvasSize ??
          Size(358.0, 358.0 / _cover.ratio);
      final fullJson = exportFullAlbumLayersJson(canvasSize);
      final themeLabel = _selectedTheme.label;

      if (_editingAlbumId != null) {
        // 커버 이미지 URL: 기존 값이 없으면 커버 페이지 첫 이미지 레이어에서 추출 (빈 문자열로 덮어쓰지 않음)
        String coverImg = _initialCoverImageUrl ?? _initialCoverThumbnailUrl ?? '';
        String coverThumb = _initialCoverThumbnailUrl ?? _initialCoverImageUrl ?? '';
        if (coverImg.isEmpty && _pages.isNotEmpty) {
          final coverPage = _pages.first;
          for (final layer in coverPage.layers) {
            if (layer.type == LayerType.image) {
              final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
              if (url != null && url.isNotEmpty) {
                coverImg = url;
                coverThumb = url;
                break;
              }
            }
          }
        }
        await albumVm.updateAlbum(
          albumId: _editingAlbumId!,
          ratio: _cover.ratio.toString(),
          coverLayersJson: fullJson,
          coverImageUrl: coverImg,
          coverThumbnailUrl: coverThumb,
          coverPreviewUrl: coverImg.isNotEmpty ? coverImg : null,
          coverOriginalUrl: null,
          coverTheme: themeLabel,
        );
        _editingAlbumId = null;
        _initialCoverImageUrl = null;
        _initialCoverThumbnailUrl = null;
      }

      _emit();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
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
    final currentPage = _pages[_currentPageIndex];
    _service.removeLast(page: currentPage);
    _emit();
  }

  /// 마지막 페이지(내지) 제거 – 저장 없이 뒤로갈 때 사용
  void removeLastPage() {
    if (_pages.length <= 1) return; // 커버만 있으면 제거 안 함
    _pages.removeLast();
    _currentPageIndex = (_pages.length - 1).clamp(0, _pages.length - 1);
    _emit();
  }

  /// 전체 초기화
  void clearAll() {
    final currentPage = _pages[_currentPageIndex];
    _service.clearAll(page: currentPage);
    _emit();
  }

  /// 특정 레이어 ID로 삭제
  void removeLayerById(String id) {
    final currentPage = _pages[_currentPageIndex];
    _service.removeLayerById(page: currentPage, id: id);
    _emit();
  }

  /// 선택 해제(뷰 단 관리여도 호출 가능하도록)
  void clearSelectedLayer() {
    _emit();
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

    final old = page.layers[idx];
    final updated = old.copyWith(asset: asset);

    page.layers[idx] = updated;
    _emit();
  }

  /// emit (현재 페이지 반영)
  void _emit() {
    final prev = state.value ?? const AlbumEditorState();
    final currentLayers = currentPage?.layers ?? [];

    state = AsyncData(
      prev.copyWith(
        files: List.of(_files),
        albums: List.of(_albums),
        currentAlbum: _currentAlbum,
        layers: List.of(currentLayers),
        selectedCover: _cover,
        selectedTheme: _selectedTheme,
        coverCanvasSize: prev.coverCanvasSize,
      ),
    );
  }

  // ===== getters =====
  List<LayerModel> get layers => List.unmodifiable(currentPage?.layers ?? const []);
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
      'layers': coverPage.layers.map(
            (layer) => LayerExportMapper.toJson(
          layer,
          canvasSize: canvasSize,
        ),
      ).toList(),
    });
  }

  /// 페이지 에디터(PageEditorScreen)의 내지 캔버스 크기 - 300x400 고정
  static const Size _innerPageCanvasSize = Size(300, 400);

  /// 커버 + 모든 내지 페이지 레이어를 서버 저장용 JSON 문자열로 변환
  /// 형식: { "pages": [ { "index": 0, "isCover": true, "layers": [...] }, ... ] }
  /// 커버는 coverCanvasSize, 내지는 300x400 (페이지 에디터와 동일)
  String exportFullAlbumLayersJson(Size? coverCanvasSize) {
    final coverSize = coverCanvasSize ??
        Size(358.0, 358.0 / _cover.ratio);
    final pagesJson = _pages.map((page) {
      final canvasSize = page.isCover ? coverSize : _innerPageCanvasSize;
      return {
        'index': page.pageIndex,
        'isCover': page.isCover,
        'layers': page.layers
            .map((l) => LayerExportMapper.toJson(l, canvasSize: canvasSize))
            .toList(),
      };
    }).toList();
    return jsonEncode({'pages': pagesJson});
  }
}