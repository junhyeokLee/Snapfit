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
    
    /// 내지 캔버스 크기 (3:4 비율)
    Size? innerCanvasSize,

    /// 백그라운드에서 앨범 생성(업로드) 중인지 여부
    @Default(false) bool isCreatingInBackground,

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
  String? _pendingCoverLayersJson;
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
    _cover = initialCover ?? coverSizes.firstWhere(
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

  /// 사진 선택 바텀시트 등을 열기 전에 갤러리 데이터가 비어있으면 1회 로딩
  /// 홈에서 선택한 앨범을 "편집 준비" 상태로 세팅
  /// - 실제 레이어 복원은 EditCover에서 실제 커버 캔버스 크기(_coverSize)가 잡힌 뒤 수행해야
  ///   위치/스케일이 정확히 맞는다.
  /// - waitForCreation: true일 경우 앨범 생성 완료를 비동기로 기다림
  Future<void> prepareAlbumForEdit(Album album, {bool waitForCreation = false}) async {
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
        final updatedAlbum = await ref.read(albumRepositoryProvider).fetchAlbum(album.id.toString());
        await _loadAlbumForEdit(updatedAlbum);
      } else {
        state = const AsyncError('앨범 생성 확인 시간이 초과되었습니다.', StackTrace.empty);
      }
      return;
    }

    // 일반 편집 모드
    await _loadAlbumForEdit(album);
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
        final theme = CoverTheme.values.firstWhere((t) => t.label == normalized);
        _selectedTheme = theme;
      } catch (_) {
        // 알 수 없는 테마 문자열이면 기본값 유지
      }
    }

    // coverViewModelProvider에 커버 사이즈와 테마 동기화
    ref.read(coverViewModelProvider.notifier).selectCover(_cover);
    ref.read(coverViewModelProvider.notifier).updateTheme(_selectedTheme);

    // 레이어 JSON은 실제 canvasSize가 정해진 다음에 복원
    _pendingCoverLayersJson =
        effective.coverLayersJson.isEmpty ? '{"layers":[]}' : effective.coverLayersJson;
    _editingAlbumId = album.id > 0 ? album.id : null;
    _initialCoverImageUrl = album.coverImageUrl;
    _initialCoverThumbnailUrl = album.coverThumbnailUrl;
    _initialAlbumTitle = album.title; // 앨범 제목 저장

    // 이전 편집 상태 초기화: 페이지/커버 캔버스 정보 리셋
    _clearAllHistory();
    _pages.clear();
    _pages.add(_service.createPage(index: 0, isCover: true));

    // Step1에서 선택한 페이지 수(targetPages)만큼 빈 내지 페이지 미리 생성
    // targetPages가 0이면 기본 1페이지
    final targetPageCount = album.targetPages > 0 ? album.targetPages : 1;
    for (int i = 1; i <= targetPageCount; i++) {
      _pages.add(_service.createPage(index: i));
    }
    debugPrint('[_loadAlbumForEdit] Pre-created $targetPageCount inner page(s) from targetPages=${album.targetPages}');

    _currentPageIndex = 0;

    // coverCanvasSize 도 초기화해서, 다음 화면(커버/스프레드)에서
    // loadPendingEditAlbumIfNeeded 가 새 앨범 기준으로 다시 한 번만 동작하도록 한다.
    final prev = state.value ?? const AlbumEditorState();
    state = AsyncData(prev.copyWith(
      coverCanvasSize: null,
      selectedCover: _cover,
      selectedTheme: _selectedTheme,
      isCreatingInBackground: false, // 로딩 해제
    ));

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

    // [10단계 Fix] 커버는 이제 항상 kCoverReferenceWidth(500px) 기준으로 복원합니다.
    // 실측 canvasSize에 의한 리스케일링은 UI 단에서 Transform.scale로 처리합니다.
    final double ratio = _cover.ratio > 0 ? _cover.ratio : 1.0;
    final effectiveSize = Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
    
    debugPrint('[loadPendingEditAlbumIfNeeded] Restoring COVER layers with REFERENCE size: $effectiveSize');
    loadAlbum({'coverLayersJson': pendingJson}, effectiveSize);
    
    // UI 동기화용 실측 사이즈만 업데이트 (리스케일링은 발생하지 않음)
    _lastCoverCanvasSize = canvasSize != Size.zero ? canvasSize : effectiveSize;
    state = AsyncData(state.value!.copyWith(coverCanvasSize: _lastCoverCanvasSize));
  }

  /// 서버에서 불러온 앨범 데이터를 편집기에 로드
  /// coverLayersJson이 "pages" 배열 형식이면 커버+내지 모두 복원, 아니면 기존 형식(cover만) 복원
  /// [canvasSize]: 커버용 캔버스 크기. 내지 페이지는 300x400 고정(페이지 에디터와 동일)
  void loadAlbum(Map<String, dynamic> albumData, Size canvasSize) {
    if (canvasSize == Size.zero) return;
    _clearAllHistory();

    // [10단계 Fix] 커버는 항상 500xH, 내지는 300xH 참조 사이즈를 베이스로 로드합니다.
    final coverAspect = _cover.ratio > 0 ? _cover.ratio : 1.0;
    final coverRefSize = Size(kCoverReferenceWidth, kCoverReferenceWidth / coverAspect);
    
    _lastCoverCanvasSize = canvasSize; // 실제 UI용 캔버스 크기만 기록
    _lastInnerCanvasSize = _innerPageCanvasSize;
    
    final String raw = albumData['coverLayersJson'] as String? ?? '{}';
    final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>? ?? {};

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
        final page = _service.createPage(index: index, isCover: isCover, backgroundColor: backgroundColor);
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
          canvasSize: coverRefSize,
          isCover: true,
        );
      }).toList();
      final coverPage = _service.createPage(index: 0, isCover: true);
      coverPage.layers.addAll(loadedLayers);
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
    final List<LayerModel> currentLayers = overrideLayers ?? List.of(state.value?.layers ?? []);
    final albumVm = ref.read(albumViewModelProvider.notifier);
    final themeLabel = _selectedTheme.label;

    try {
      int? createdAlbumId;
      
      if (_editingAlbumId != null) {
        createdAlbumId = _editingAlbumId;
      } else {
        // 신규 생성 모드: 메타데이터만으로 ID 먼저 발급
        final tempJson = jsonEncode({
          'layers': currentLayers.map((l) => LayerExportMapper.toJson(l, canvasSize: canvasSize, isCover: true)).toList()
        });

        await albumVm.createAlbum(
          ratio: _cover.ratio.toString(),
          title: title ?? '',
          targetPages: targetPages ?? 0,
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

      // [STEP 2] 후(後) 업로드: 서비스로 이관
      if (createdAlbumId != null) {
        _persistence.performBackgroundUpload(
          albumId: createdAlbumId,
          canvasSize: canvasSize,
          currentLayers: currentLayers,
          coverImageBytes: coverImageBytes,
          themeLabel: themeLabel,
          title: title ?? '',
          coverRatio: _cover.ratio,
        );
      }
      return createdAlbumId;

    } catch (e) {
      debugPrint('Save Album Error: $e');
      return null;
    }
  }

  /// 이미지 레이어 추가 (현재 페이지)
  /// [templateKey]: null/"free"면 원본 비율, "1:1", "4:3" 등이면 해당 템플릿으로 슬롯 생성(사진 contain)
  Future<void> addImage(AssetEntity asset, Size canvasSize, {String? templateKey}) async {
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
    _recordUndo();
    final currentPage = _pages[_currentPageIndex];
    _service.updateLayer(page: currentPage, updated: updated);
    _emit();
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
        debugPrint('[setCoverCanvasSize] Initial INNER size set to $size (No Scaling)');
      }
      return;
    }

    // [10단계 Fix] 커버 역시 내지와 마찬가지로 리스케일링을 수행하지 않습니다.
    // 모든 좌표는 500xH 논리 좌표계에 고정되며, UI 스케일링만 적용됩니다.
    if (isCover) {
      debugPrint('[setCoverCanvasSize] COVER canvas size updated to $size (No Rescaling)');
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
      isCover: false,
    ));
    _currentPageIndex = nextIndex;
    _emit();
  }

  /// 앨범 전체(모든 페이지)를 서버에 저장
  Future<bool> saveFullAlbum({Uint8List? coverImageBytes}) async {
    state = const AsyncLoading(); // 로딩 상태 시작

    try {
      // 1. 모든 페이지를 병렬로 순회하며 이미지 레이어 업로드 및 로컬 상태 반영
      // [PERFORMANCE] 순차 처리(for문) -> 병렬 처리(Future.wait)로 변경하여 속도 개선
      await Future.wait(_pages.map((page) async {
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
      }));

      // 1.1 커버 이미지 업로드 (전달된 경우)
      UploadedUrls? coverUploaded;
      if (coverImageBytes != null) {
        coverUploaded = await _storage.uploadCoverVariants(coverImageBytes);
      }

      // 2. 전체 앨범 JSON 생성 후 서버에 저장 (편집 중인 앨범인 경우)
    final albumVm = ref.read(albumViewModelProvider.notifier);
    final stateVal = state.value;
    final canvasSize = (stateVal != null && stateVal.coverCanvasSize != null && stateVal.coverCanvasSize != Size.zero) 
        ? stateVal.coverCanvasSize 
        : (_lastCoverCanvasSize != Size.zero 
            ? _lastCoverCanvasSize 
            : Size(358.0, 358.0 / _cover.ratio));
    
    print('[saveFullAlbum] Using canvas size for export: ${canvasSize!.width.toStringAsFixed(1)} x ${canvasSize.height.toStringAsFixed(1)}');
    final fullJson = exportFullAlbumLayersJson(canvasSize);
    final themeLabel = _selectedTheme.label;

      if (_editingAlbumId != null) {
        // 커버 이미지 URL: 전달된 업로드 결과가 있으면 우선 사용
        String coverImg = coverUploaded?.previewGsPath ?? coverUploaded?.previewUrl ?? _initialCoverImageUrl ?? _initialCoverThumbnailUrl ?? '';
        String coverThumb = coverUploaded?.previewGsPath ?? coverUploaded?.previewUrl ?? _initialCoverThumbnailUrl ?? _initialCoverImageUrl ?? '';
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
          title: _initialAlbumTitle ?? '', // 앨범 제목 유지
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
        _initialAlbumTitle = null; // 초기화
      }

      _hasUnsavedChanges = false;
      _emit();
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false; // 실패 반환
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
    final updated = old.copyWith(asset: asset);

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
          canvasSize: _coverReferenceSize,
          isCover: true,
        ),
      ).toList(),
    });
  }

  /// 페이지 에디터(PageEditorScreen)의 내지 캔버스 크기 - 300x400 고정
  // [Fix] 내지 캔버스 크기를 커버 비율에 맞춰 동적으로 계산 (일관성 확보)
  Size get _innerPageCanvasSize {
    final ratio = _cover.ratio > 0 ? _cover.ratio : (3 / 4);
    // 너비 300을 기준으로 비율에 맞는 높이 계산 (예: 1:1이면 300x300, 3:4면 300x400)
    return Size(300.0, 300.0 / ratio);
  }

  /// [10단계] 커버 논리 고정 좌표계 크기 (500xH)
  Size get _coverReferenceSize {
    final ratio = _cover.ratio > 0 ? _cover.ratio : 1.0;
    return Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
  }

  /// 현재 페이지의 레이어 리스트 전체 교체 (순서 변경 등)
  void updatePageLayers(List<LayerModel> newLayers, {bool recordHistory = true}) {
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
    if (newIndex > currentPage.layers.length) newIndex = currentPage.layers.length;
    
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
      final canvasSize = page.isCover ? _coverReferenceSize : _innerPageCanvasSize;
      return {
        'index': page.pageIndex,
        'isCover': page.isCover,
        if (page.backgroundColor != null) 'backgroundColor': page.backgroundColor,
        'layers': page.layers
            .map((l) => LayerExportMapper.toJson(l, canvasSize: canvasSize, isCover: page.isCover))
            .toList(),
      };
    }).toList();
    return jsonEncode({'pages': pagesJson});
  }
}