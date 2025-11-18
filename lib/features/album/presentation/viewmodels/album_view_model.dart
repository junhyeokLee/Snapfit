import 'dart:async';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/rendering.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/album.dart';
import '../../domain/entities/album_page.dart';
import '../../domain/entities/cover_size.dart';
import '../../domain/entities/cover_theme.dart';
import '../../domain/entities/layer.dart';
part 'album_view_model.g.dart';
part 'album_view_model.freezed.dart';

/// 갤러리 상태 (MVVM)
@freezed
abstract class AlbumState with _$AlbumState {
  const factory AlbumState({
    @Default([]) List<AssetEntity> files,
    @Default([]) List<AssetPathEntity> albums,
    AssetPathEntity? currentAlbum,
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
  }) = _AlbumState;
}

@Riverpod(keepAlive: true)
class AlbumViewModel extends _$AlbumViewModel {
  final List<AssetEntity> _files = [];
  final List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  CoverSize _cover = coverSizes.first;
  CoverTheme _selectedTheme = CoverTheme.classic;

  // ===== Selected getters =====
  CoverSize get selectedCover => _cover;
  CoverTheme get selectedTheme => _selectedTheme;

  // 페이지 구조 추가
  final List<AlbumPage> _pages = [];
  int _currentPageIndex = 0;

  static const _pageSize = 80;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;

  @override
  FutureOr<AlbumState> build() async {
    await fetchInitialData();

    // 초기 표지 페이지 생성
    if (_pages.isEmpty) {
      _pages.add(AlbumPage(
        id: 'cover_page',
        isCover: true,
        pageIndex: 0,
        layers: [],
      ));
    }

    return AlbumState(
      files: List.of(_files),
      albums: List.of(_albums),
      currentAlbum: _currentAlbum,
      layers: List.of(currentPage!.layers),
      selectedCover: _cover,
      selectedTheme: _selectedTheme,
    );
  }

  /// 초기 데이터
  Future<void> fetchInitialData() async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      state = const AsyncError('갤러리 접근 권한이 필요합니다.', StackTrace.empty);
      return;
    }

    final list = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: false,
    );

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
      final page = await _currentAlbum!.getAssetListPaged(page: _page, size: _pageSize);
      _files.addAll(page);
      _hasMore = page.length == _pageSize;
      _page++;
      _emit();
    } finally {
      _loading = false;
    }
  }

  /// 이미지 레이어 추가 (현재 페이지)
  void addImage(AssetEntity asset) {
    final currentPage = _pages[_currentPageIndex];
    if (currentPage.layers.any((l) => l.type == LayerType.image && l.id == asset.id)) return;

    final newLayer = LayerModel(
      id: asset.id,
      type: LayerType.image,
      position: const Offset(40, 40),
      asset: asset,
      // textStyleMode not needed for image
    );
    currentPage.layers.add(newLayer);
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

    // 실제 텍스트 사이즈 측정 (멀티라인 포함)
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: canvasSize.width * 1);

    final textSize = tp.size; // 실제 텍스트 크기
    final center = Offset(
      (canvasSize.width - textSize.width) / 2,
      (canvasSize.height - textSize.height) / 2,
    );

    final newLayer = LayerModel(
      id: UniqueKey().toString(),
      type: LayerType.text,
      position: center, // 텍스트 크기 기반 중앙 정렬
      text: text,
      textStyle: style,
      textStyleType: mode,
      bubbleColor: color,
      textAlign: textAlign,
    );

    currentPage.layers.add(newLayer);
    _emit();
  }

  /// 레이어 업데이트
  void updateLayer(LayerModel updated) {
    final currentPage = _pages[_currentPageIndex];
    final idx = currentPage.layers.indexWhere((l) => l.id == updated.id);
    if (idx != -1) {
      final oldLayer = currentPage.layers[idx];
      currentPage.layers[idx] = oldLayer.copyWith(
        text: updated.text ?? oldLayer.text,
        textStyle: updated.textStyle ?? oldLayer.textStyle,
        textStyleType: updated.textStyleType ?? oldLayer.textStyleType,
        bubbleColor: updated.bubbleColor ?? oldLayer.bubbleColor,
        position: updated.position ?? oldLayer.position,
        scale: updated.scale ?? oldLayer.scale,
        rotation: updated.rotation ?? oldLayer.rotation,
        textAlign: updated.textAlign ?? oldLayer.textAlign,
      );
      _emit();
    }
  }

  /// 텍스트 스타일 변경
  void updateTextStyle(String id, String styleKey) {
    final currentPage = _pages[_currentPageIndex];
    final idx = currentPage.layers.indexWhere((l) => l.id == id);
    if (idx != -1) {
      final old = currentPage.layers[idx];
      currentPage.layers[idx] = old.copyWith(
        textBackground: styleKey,
      );
      _emit();
    }
  }

  /// 이미지 프레임 스타일 변경
  void updateImageFrame(String id, String frameKey) {
    final currentPage = _pages[_currentPageIndex];
    final idx = currentPage.layers.indexWhere((l) => l.id == id);
    if (idx != -1) {
      final old = currentPage.layers[idx];
      currentPage.layers[idx] = old.copyWith(
        imageBackground: frameKey,
      );
      _emit();
    }
  }

  /// 커버 선택 (+ 선택적으로 Variant 지정)
  void selectCover(
    CoverSize cover) {
    _cover = cover;
    _emit();
  }

  /// 페이지 추가
  void addPage() {
    final nextIndex = _pages.length;
    _pages.add(
      AlbumPage(
        id: 'page_$nextIndex',
        isCover: false,
        pageIndex: nextIndex,
        layers: [],
      ),
    );
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
    if (currentPage.layers.isNotEmpty) {
      currentPage.layers.removeLast();
      _emit();
    }
  }

  ///  전체 초기화
  void clearAll() {
    _pages[_currentPageIndex].layers.clear();
    _emit();
  }

  /// 앨범 전체 내보내기 (저장)
  Album exportDesign() {
    return Album(
      albumId: UniqueKey().toString(),
      title: '나의 앨범',
      coverSize: _cover,
      pages: _pages,
      createdAt: DateTime.now(),
    );
  }

  /// 특정 레이어 ID로 삭제 (현재 페이지 기준)
  void removeLayerById(String id) {
    final currentPage = _pages[_currentPageIndex];
    final idx = currentPage.layers.indexWhere((l) => l.id == id);
    if (idx != -1) {
      currentPage.layers.removeAt(idx);
      _emit();
    }
  }

  /// 선택 해제 (UI에서만 쓰이는 경우라도 호출 가능하도록 준비)
  void clearSelectedLayer() {
    // 현재는 선택 상태를 View 단에서 관리하지만,
    // 호출 에러 방지를 위해 빈 메서드로 구현.
    _emit();
  }

  /// 커버 테마 변경
  void updateTheme(CoverTheme theme) {
    if (_selectedTheme == theme) return; // 동일 테마면 무시
    _selectedTheme = theme;
    _emit();
  }

  /// emit (현재 페이지 반영)
  void _emit() {
    final prev = state.value ?? const AlbumState();
    final currentLayers = currentPage?.layers ?? [];

    state = AsyncData(prev.copyWith(
      files: List.of(_files),
      albums: List.of(_albums),
      currentAlbum: _currentAlbum,
      layers: List.of(currentLayers),
      selectedCover: _cover,
      selectedTheme: _selectedTheme,
    ));
  }


  // getter
  List<LayerModel> get layers => List.unmodifiable(currentPage!.layers);
  List<AlbumPage> get pages => List.unmodifiable(_pages);
  // AlbumPage get currentPage => _pages[_currentPageIndex];
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
}