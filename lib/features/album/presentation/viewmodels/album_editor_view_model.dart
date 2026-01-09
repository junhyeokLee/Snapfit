import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/album_page.dart';
import '../../../../core/constatns/cover_size.dart';
import '../../../../core/constatns/cover_theme.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/layer_export_mapper.dart';
import '../../data/repositories/gallery_repositoryImpl.dart';
import '../../service/album_editor_service.dart';
import '../controllers/layer_interaction_manager.dart';

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
  }) = _AlbumEditorState;
}

@Riverpod(keepAlive: true)
class AlbumEditorViewModel extends _$AlbumEditorViewModel {
  late final AlbumEditorService _service = AlbumEditorService();
  late final GalleryRepositoryImpl _gallery = GalleryRepositoryImpl();

  final List<AssetEntity> _files = [];
  final List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;

  CoverSize _cover = coverSizes.first;
  CoverTheme _selectedTheme = CoverTheme.classic;

  // 페이지 구조
  final List<AlbumPage> _pages = [];
  int _currentPageIndex = 0;

  static const _pageSize = 80;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;

  // ===== Selected getters =====
  CoverSize get selectedCover => _cover;
  CoverTheme get selectedTheme => _selectedTheme;

  @override
  FutureOr<AlbumEditorState> build() async {
    await fetchInitialData();

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
    );
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
  Future<void> addImage(AssetEntity asset, Size canvasSize) async {
    final currentPage = _pages[_currentPageIndex];
    await _service.addImageLayer(
      page: currentPage,
      asset: asset,
      canvasSize: canvasSize,
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

  /// 페이지 추가
  void addPage() {
    final nextIndex = _pages.length;
    _pages.add(_service.createPage(index: nextIndex));
    _currentPageIndex = nextIndex;
    _emit();
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
}