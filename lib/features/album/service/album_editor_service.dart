import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/models/album_page.dart';
import '../data/models/layer.dart';

/// 앨범 편집 + 갤러리 로딩 도메인 서비스
///
/// - 갤러리 권한 / 앨범 / 이미지 로딩
/// - 페이지 생성
/// - 레이어 생성 / 수정 / 삭제
class AlbumEditorService {
  const AlbumEditorService();

  /// 갤러리 접근 권한 요청
  Future<bool> requestPermission() async {
    final perm = await PhotoManager.requestPermissionExtend();
    return perm.isAuth;
  }

  /// 기기 내 이미지 앨범 목록 로드
  Future<List<AssetPathEntity>> loadAlbums() {
    return PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: false,
    );
  }

  /// 선택한 앨범에서 페이징으로 이미지 로드
  Future<List<AssetEntity>> loadImagesPaged(
    AssetPathEntity album,
    int page,
    int size,
  ) {
    return album.getAssetListPaged(page: page, size: size);
  }

  /// 페이지 생성 (표지/내지 공통)
  AlbumPage createPage({
    required int index,
    bool isCover = false,
  }) {
    return AlbumPage(
      id: isCover ? 'cover_page' : 'page_$index',
      isCover: isCover,
      pageIndex: index,
      layers: [],
    );
  }

  /// 이미지 레이어 생성 (단일 레이어 인스턴스만 생성)
  LayerModel createImageLayer(AssetEntity asset) {
    return LayerModel(
      id: asset.id,
      type: LayerType.image,
      position: const Offset(40, 40),
      asset: asset,
    );
  }

  /// 텍스트 레이어 생성 (텍스트 크기 기반 중앙 정렬 포함)
  LayerModel createTextLayer({
    required String text,
    required TextStyle style,
    required TextStyleType mode,
    required Size canvasSize,
    TextAlign textAlign = TextAlign.center,
    Color? color,
  }) {
    // 실제 텍스트 사이즈 측정 (멀티라인 포함)
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: canvasSize.width);

    final size = tp.size;
    final center = Offset(
      (canvasSize.width - size.width) / 2,
      (canvasSize.height - size.height) / 2,
    );

    return LayerModel(
      id: UniqueKey().toString(),
      type: LayerType.text,
      position: center,
      text: text,
      textStyle: style,
      textStyleType: mode,
      bubbleColor: color,
      textAlign: textAlign,
    );
  }

  /// 페이지에 이미지 레이어 추가
  ///
  /// 같은 asset.id 를 가진 이미지 레이어가 이미 있으면 추가하지 않는다.
  AlbumPage addImageLayer({
    required AlbumPage page,
    required AssetEntity asset,
  }) {
    if (page.layers.any(
      (l) => l.type == LayerType.image && l.id == asset.id,
    )) {
      return page;
    }

    final newLayer = createImageLayer(asset);
    page.layers.add(newLayer);
    return page;
  }

  /// 페이지에 텍스트 레이어 추가
  AlbumPage addTextLayer({
    required AlbumPage page,
    required String text,
    required TextStyle style,
    required TextStyleType mode,
    required Size canvasSize,
    TextAlign textAlign = TextAlign.center,
    Color? color,
  }) {
    final newLayer = createTextLayer(
      text: text,
      style: style,
      mode: mode,
      canvasSize: canvasSize,
      textAlign: textAlign,
      color: color,
    );
    page.layers.add(newLayer);
    return page;
  }

  /// 레이어 전체 속성 업데이트
  AlbumPage updateLayer({
    required AlbumPage page,
    required LayerModel updated,
  }) {
    final idx = page.layers.indexWhere((l) => l.id == updated.id);
    if (idx == -1) return page;

    final oldLayer = page.layers[idx];
    page.layers[idx] = oldLayer.copyWith(
      text: updated.text ?? oldLayer.text,
      textStyle: updated.textStyle ?? oldLayer.textStyle,
      textStyleType: updated.textStyleType ?? oldLayer.textStyleType,
      bubbleColor: updated.bubbleColor ?? oldLayer.bubbleColor,
      position: updated.position ?? oldLayer.position,
      scale: updated.scale ?? oldLayer.scale,
      rotation: updated.rotation ?? oldLayer.rotation,
      textAlign: updated.textAlign ?? oldLayer.textAlign,
    );
    return page;
  }

  /// 텍스트 스타일(배경 키) 변경
  AlbumPage updateTextStyle({
    required AlbumPage page,
    required String id,
    required String styleKey,
  }) {
    final idx = page.layers.indexWhere((l) => l.id == id);
    if (idx == -1) return page;

    final old = page.layers[idx];
    page.layers[idx] = old.copyWith(
      textBackground: styleKey,
    );
    return page;
  }

  /// 이미지 프레임 스타일 변경
  AlbumPage updateImageFrame({
    required AlbumPage page,
    required String id,
    required String frameKey,
  }) {
    final idx = page.layers.indexWhere((l) => l.id == id);
    if (idx == -1) return page;

    final old = page.layers[idx];
    page.layers[idx] = old.copyWith(
      imageBackground: frameKey,
    );
    return page;
  }

  /// 마지막 레이어 제거
  AlbumPage removeLast({
    required AlbumPage page,
  }) {
    if (page.layers.isNotEmpty) {
      page.layers.removeLast();
    }
    return page;
  }

  /// 모든 레이어 제거
  AlbumPage clearAll({
    required AlbumPage page,
  }) {
    page.layers.clear();
    return page;
  }

  /// 특정 레이어 ID 삭제
  AlbumPage removeLayerById({
    required AlbumPage page,
    required String id,
  }) {
    final idx = page.layers.indexWhere((l) => l.id == id);
    if (idx != -1) {
      page.layers.removeAt(idx);
    }
    return page;
  }
}
