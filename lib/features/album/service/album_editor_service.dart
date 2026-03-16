import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../../core/constants/cover_size.dart';

import '../../../core/constants/image_templates.dart';
import '../../../core/constants/page_templates.dart';
import '../domain/entities/album_page.dart';
import '../domain/entities/layer.dart';

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
    int? backgroundColor,
  }) {
    return AlbumPage(
      id: isCover ? 'cover_page' : 'page_$index',
      isCover: isCover,
      pageIndex: index,
      layers: [],
      backgroundColor: backgroundColor,
    );
  }

  /// 템플릿으로 페이지 생성 (스크랩북 스타일 레이아웃)
  /// [canvasSize]: 페이지 캔버스 크기 (비율 슬롯을 픽셀 좌표로 변환할 때 사용)
  /// [isCover]: 커버 템플릿인지 여부 (스파인 여백 등 처리용, 현재는 좌표계만 공유)
  AlbumPage createPageFromTemplate({
    required PageTemplate template,
    required int index,
    required Size canvasSize,
    bool isCover = false,
  }) {
    final page = createPage(index: index, isCover: isCover);
    final w = canvasSize.width;
    final h = canvasSize.height;

    for (final slot in template.slots) {
      final pos = Offset(slot.left * w, slot.top * h);
      final slotW = slot.width * w;
      final slotH = slot.height * h;
      final id = '${template.id}_slot_${page.layers.length}_${UniqueKey()}';

      if (slot.type == 'image') {
        page.layers.add(LayerModel(
          id: id,
          type: LayerType.image,
          position: pos,
          width: slotW,
          height: slotH,
          rotation: slot.rotation,
          imageBackground: slot.imageBackground,
          imageTemplate: slot.imageTemplate ?? 'free',
          asset: null,
        ));
      } else if (slot.type == 'text') {
        page.layers.add(LayerModel(
          id: id,
          type: LayerType.text,
          position: pos,
          width: slotW,
          height: slotH,
          rotation: slot.rotation,
          text: slot.defaultText ?? '',
          textStyle: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          textStyleType: TextStyleType.none,
          textBackground: slot.textBackground,
        ));
      }
    }
    return page;
  }

  /// 이미지 레이어 생성 (단일 레이어 인스턴스만 생성)
  /// [templateKey]: "free" 또는 null이면 원본 사진 비율, "1:1", "4:3" 등이면 해당 비율로 슬롯 생성(사진은 contain으로 짤리지 않게)
  Future<LayerModel> createImageLayer({
    required AssetEntity asset,
    required Size canvasSize,
    String? templateKey,
    bool isCover = false,
  }) async {
    final maxW = canvasSize.width * 0.8;
    final maxH = canvasSize.height * 0.8;

    final slotAspect = aspectForTemplateKey(templateKey);
    double width;
    double height;

    if (slotAspect == null) {
      // 자유: 원본 사진 비율 유지
      // 일부 기기(특히 Android)에서는 세로 사진이 EXIF orientation(90/270)으로 저장되어
      // width/height 값은 가로 기준이지만 실제 표시 방향은 세로인 경우가 있다.
      // 이 경우 orientation 값을 참고하여 가로/세로를 보정해준다.
      double w = asset.width.toDouble();
      double h = asset.height.toDouble();
      try {
        final ori = asset.orientation;
        if (ori == 90 || ori == 270) {
          final tmp = w;
          w = h;
          h = tmp;
        }
      } catch (_) {
        // orientation 프로퍼티가 없거나 접근 실패 시, 그대로 진행 (기존 동작 유지)
      }

      final aspect = w / h;
      if (aspect >= maxW / maxH) {
        width = maxW;
        height = width / aspect;
      } else {
        height = maxH;
        width = height * aspect;
      }
    } else {
      // 템플릿 비율로 슬롯 크기 결정 (캔버스 80% 안에 들어가게)
      if (slotAspect >= maxW / maxH) {
        width = maxW;
        height = width / slotAspect;
      } else {
        height = maxH;
        width = height * slotAspect;
      }
    }

    // [Spine fix] 커버인 경우 Spine(14px)을 고려한 시각적 중앙 정렬
    final double centerX;
    if (isCover) {
      // (SpineWidth + (전체너비 - SpineWidth - LayerWidth) / 2)
      centerX = kCoverSpineWidth + (canvasSize.width - kCoverSpineWidth - width) / 2;
    } else {
      centerX = (canvasSize.width - width) / 2;
    }

    final pos = Offset(
      centerX,
      (canvasSize.height - height) / 2,
    );

    return LayerModel(
      id: asset.id,
      type: LayerType.image,
      position: pos,
      width: width,
      height: height,
      asset: asset,
      imageTemplate: templateKey ?? 'free',
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
    double? initialWidth,
    double? initialHeight,
    bool isCover = false, // Added isCover parameter
  }) {
    // ✅ layer_builder와 정확히 동일한 렌더 기준 (+55 padding)
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(); // ✅ maxWidth 제거 → 텍스트 길이에 따라 width / height 자동 증가

    final double safeWidth = initialWidth ?? (tp.width + 55);

    // ✅ TextPainter 전체 높이를 그대로 사용 (모든 줄/줄간 간격 포함)
    // flutter LineMetrics에는 leading 프로퍼티가 없으므로 computeLineMetrics로 직접 합산할 필요 없이
    // tp.height로 전체 텍스트 높이를 사용하는 것이 가장 안전합니다.
    final double verticalPadding = 80; // 위/아래 여유 공간
    final double safeHeight = initialHeight ?? (tp.height + verticalPadding);

    // ✅ 텍스트 실폭 기준 중앙 정렬 보정
    final double textWidth = tp.width - 4;

    // safeWidth 안에서 실제 텍스트가 차지하지 않는 좌우 여백의 절반
    final double textBiasX = (safeWidth - textWidth) / 2;

    // 커버 중앙에 '텍스트 자체의 중심'이 오도록 보정
    // [Spine fix] 텍스트 시각적 중앙 정렬
    final double centerX;
    
    // (1) safeWidth 박스 자체를 캔버스 중앙(혹은 Spine 제외 중앙)에 배치할 X 좌표
    if (isCover) {
      centerX = kCoverSpineWidth + (canvasSize.width - kCoverSpineWidth - safeWidth) / 2;
    } else {
      centerX = (canvasSize.width - safeWidth) / 2;
    }

    // (2) 텍스트 내부의 실제 글자 중심이 박스 중심과 일치하도록 bias 역보정
    final pos = Offset(
      centerX - textBiasX,
      (canvasSize.height - safeHeight) / 2,
    );

    return LayerModel(
      id: UniqueKey().toString(),
      type: LayerType.text,
      position: pos,
      width: safeWidth,
      height: safeHeight,
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
  /// [templateKey]: null/"free"면 원본 비율, "1:1", "4:3" 등이면 해당 템플릿 비율로 슬롯 생성(사진 contain)
  Future<AlbumPage> addImageLayer({
    required AlbumPage page,
    required AssetEntity asset,
    required Size canvasSize,
    String? templateKey,
  }) async {

    // 같은 이미지 이미 있으면 패스
    if (page.layers.any(
          (l) => l.type == LayerType.image && l.id == asset.id,
    )) {
      return page;
    }

    final newLayer = await createImageLayer(
      asset: asset,
      canvasSize: canvasSize,
      templateKey: templateKey,
      isCover: page.isCover,
    );

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
    double? initialWidth,
    double? initialHeight,
  }) {
    final newLayer = createTextLayer(
      text: text,
      style: style,
      mode: mode,
      canvasSize: canvasSize,
      textAlign: textAlign,
      color: color,
      initialWidth: initialWidth,
      initialHeight: initialHeight,
      isCover: page.isCover,
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
      textStyleType: updated.textStyleType,
      bubbleColor: updated.bubbleColor ?? oldLayer.bubbleColor,
      position: updated.position ?? oldLayer.position,
      scale: updated.scale ?? oldLayer.scale,
      rotation: updated.rotation ?? oldLayer.rotation,
      textAlign: updated.textAlign ?? oldLayer.textAlign,
      opacity: updated.opacity,
      // [Fix] 이미지 변경 반영을 위해 asset 및 URL 관련 필드 추가
      asset: updated.asset,
      imageUrl: updated.imageUrl,
      previewUrl: updated.previewUrl,
      originalUrl: updated.originalUrl,
      imageBackground: updated.imageBackground ?? oldLayer.imageBackground,
      textBackground: updated.textBackground ?? oldLayer.textBackground,
      imageOffset: updated.imageOffset ?? oldLayer.imageOffset,
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

    // 1) 프레임 해제(기본)일 때: 프레임 적용 전에 저장해 둔 기본 크기/위치로 복원
    if (frameKey.isEmpty || frameKey == '') {
      if (old.frameBaseWidth != null &&
          old.frameBaseHeight != null &&
          old.frameBasePosition != null) {
        page.layers[idx] = old.copyWith(
          imageBackground: '',
          width: old.frameBaseWidth,
          height: old.frameBaseHeight,
          position: old.frameBasePosition,
          frameBaseWidth: null,
          frameBaseHeight: null,
          frameBasePosition: null,
        );
      } else {
        // 베이스 정보가 없으면 단순히 프레임 키만 제거
        page.layers[idx] = old.copyWith(imageBackground: '');
      }
      return page;
    }

    // 2) 프레임 적용 시: 최초 한 번만 "기본 상태"를 저장해 두고,
    //    폴라로이드 계열에 대해서만 고정 비율로 레이어 박스를 재조정한다.
    final baseWidth = old.frameBaseWidth ?? old.width;
    final baseHeight = old.frameBaseHeight ?? old.height;
    final basePosition = old.frameBasePosition ?? old.position;

    var updated = old.copyWith(
      imageBackground: frameKey,
      frameBaseWidth: baseWidth,
      frameBaseHeight: baseHeight,
      frameBasePosition: basePosition,
    );

    double? targetAspect; // width / height
    switch (frameKey) {
      case 'polaroid':
      case 'polaroidClassic':
      case 'polaroidFilm':
        targetAspect = 3 / 4;
        break;
      case 'polaroidWide':
        targetAspect = 16 / 9;
        break;
      default:
        // 폴라로이드 외 나머지 프레임들도 모두
        // 세로형 카드(3:4) 비율로 고정해서, 사진 비율에 따라
        // 프레임 크기가 달라지지 않도록 맞춘다.
        targetAspect = 3 / 4;
    }

    if (targetAspect != null && baseHeight > 0 && baseWidth > 0) {
      final scale = old.scale;
      final center = Offset(
        basePosition.dx + (baseWidth * scale) / 2,
        basePosition.dy + (baseHeight * scale) / 2,
      );

      // 폴라로이드 카드 크기: "기본 상태"의 세로 길이를 그대로 쓰고,
      // 너비만 프레임 비율에 맞춰 조정 → 사진 비율과 무관하게 일정한 카드 높이 유지
      final newHeight = baseHeight;
      final newWidth = newHeight * targetAspect;

      final newPosition = Offset(
        center.dx - (newWidth * scale) / 2,
        center.dy - (newHeight * scale) / 2,
      );

      updated = updated.copyWith(
        width: newWidth,
        height: newHeight,
        position: newPosition,
      );
    }

    page.layers[idx] = updated;
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
