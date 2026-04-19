import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/snapfit_image.dart';
import '../../domain/entities/layer.dart';
import '../viewmodels/album_editor_view_model.dart';
import 'layer_interaction_manager.dart';
part 'layer_builder_sticker_decorations.dart';
part 'layer_builder_decoration_presets.dart';
part 'layer_builder_style_sizing.dart';
part 'layer_builder_frame_switch.dart';
part 'layer_builder_frame_polaroid.dart';
part 'layer_builder_frame_paper_cards.dart';
part 'layer_builder_frame_effects.dart';
part 'layer_builder_text_styles.dart';
part 'layer_builder_text_rendering.dart';
part 'layer_builder_image_rendering.dart';
part 'layer_builder_painters.dart';

/// Decorate 스티커 탭(추천/전체보기)의 미리보기와
/// 실제 캔버스 적용 렌더링을 동일하게 맞추는 공용 위젯.
///
/// `style`은 `LayerModel.imageBackground`에 들어가는 sticker 키를 사용합니다.
class DecoStickerVisual extends StatelessWidget {
  final String style;
  final double width;
  final double height;

  const DecoStickerVisual({
    super.key,
    required this.style,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return LayerBuilder.buildStickerDecoration(
      style: style,
      width: width,
      height: height,
    );
  }
}

/// 이미지/텍스트 레이어의 렌더링과 기본 사이즈 계산 전담
class LayerBuilder {
  final LayerInteractionManager interaction;
  final Size Function() getCoverSize;

  LayerBuilder(this.interaction, this.getCoverSize);

  /// sticker 계열 decoration을 실제 적용과 동일하게 렌더링하는 공용 빌더.
  /// (DecorateStickerTab 미리보기에서 사용)
  static Widget buildStickerDecoration({
    required String style,
    required double width,
    required double height,
  }) {
    final layer = LayerModel(
      id: 'deco_preview_$style',
      type: LayerType.decoration,
      position: Offset.zero,
      width: width,
      height: height,
      imageBackground: style,
      opacity: 1,
      zIndex: 0,
    );
    return _buildStickerDecoration(layer) ?? const SizedBox.shrink();
  }

  /// 스타일별 가로 패딩 합(좌+우) — 텍스트 레이아웃 시 콘텐츠 너비 계산용
  static double _styleHorizontalPadding(String type) =>
      _styleHorizontalPaddingImpl(type);

  /// 찢어진 메모지(아래 톱니) step/amp – 키에 따라 일반(8, 2.5), 거친(12, 4), 부드러운(5, 1.2)
  static (double, double) _tornEdgeParams(String key) =>
      _tornEdgeParamsImpl(key);

  /// 찢어진 테이프 키 → 단색 테이프 키 (tapeTorn*/tapeTornSolid* → tapeSolid*)
  static String? _tapeTornToSolidKey(String? key) =>
      _tapeTornToSolidKeyImpl(key);

  Size _calculateStyleSize(
    String type,
    LayerModel layer,
    TextPainter painter,
  ) => _calculateStyleSizeImpl(type, layer, painter);

  /// 템플릿 적용 시 템플릿 비율 슬롯에 사진이 꽉 차게 cover, 자유 비율이면 cover
  static BoxFit _imageFitForLayer(LayerModel layer) =>
      _imageFitForLayerImpl(layer);

  /// 사진 위치 조정용 imageOffset(픽셀)을 Image alignment(-1.0~1.0)로 변환
  static Alignment _imageAlignmentForLayer(LayerModel layer) =>
      _imageAlignmentForLayerImpl(layer);

  /// 이미지 레이어 빌드
  Widget buildImage(LayerModel layer, {bool isCover = false}) =>
      _buildImageImpl(this, layer, isCover: isCover);

  /// 빈 이미지 슬롯(플레이스홀더) – 템플릿 적용 후 사진을 넣을 자리
  Widget _buildImagePlaceholder(LayerModel layer) =>
      _buildImagePlaceholderImpl(this, layer);
  Widget _buildFramedImage(LayerModel layer, Widget image) {
    return _buildFramedImageImpl(this, layer, image);
  }

  Widget _fitFramedContent(LayerModel layer, Widget child) {
    return _fitFramedContentImpl(layer, child);
  }

  Widget _buildDecoration(LayerModel layer) {
    final sticker = _buildStickerDecoration(layer);
    if (sticker != null) return sticker;
    final explicit = _buildExplicitDecoration(layer);
    if (explicit != null) return explicit;
    final preset = _buildPresetDecoration(layer);
    if (preset != null) return preset;

    return _buildPaperTextureDecoration(layer);
  }

  /// 기본 원형 – 바텀시트 디자인대로 원형
  Widget _frameCircle(Widget image) => _frameCircleImpl(image);

  /// 소프트 아치 – 웨딩 에디토리얼용 아치형 프레임
  Widget _frameArchSoft(Widget image) => _frameArchSoftImpl(image);

  /// 캡슐형 아치/오벌 – SAVE THE DATE 피그마 정합용
  Widget _frameArchOval(Widget image) => _frameArchOvalImpl(image);

  /// 원형 링 카드 – SAVE THE DATE 피그마 정합용
  Widget _frameCircleRing(Widget image) => _frameCircleRingImpl(image);

  /// 하트 이미지 프레임 – 기념일 템플릿용
  Widget _frameHeart(Widget image) => _frameHeartImpl(image);

  /// 피그마 원본의 28px rounded image clip
  Widget _frameRounded28(Widget image) => _frameRounded28Impl(image);

  /// 소프트 라운드 – 바텀시트와 동일: 카드 없이 18px 둥글게
  Widget _frameRound(Widget image) => _frameRoundImpl(image);

  /// 공통: 폴라로이드 하단 가로선 (클래식/카드 동일)
  static Widget _polaroidBottomLine() => _polaroidBottomLineImpl();

  /// 클래식 폴라로이드 – 세로로 길고 가로는 더 좁은 카드 (좌우·위 20, 아래 80 여백)
  Widget _framePolaroid(Widget image) => _framePolaroidImpl(image);

  /// 카드 폴라로이드 – 세로로 길고 가로는 더 좁은 카드 (좌우·위 20, 아래 80 여백)
  Widget _framePolaroidClassic(Widget image) =>
      _framePolaroidClassicImpl(image);

  /// 와이드 폴라로이드 – 바텀시트와 동일: 흰색 6r, 패딩 2/6/2/14, 사진 3r
  Widget _framePolaroidWide(Widget image) => _framePolaroidWideImpl(image);

  /// 폴라로이드 필름 – 검은 카드 + 폴라로이드 비율
  Widget _framePolaroidFilm(Widget image) => _framePolaroidFilmImpl(image);

  Widget _framePhotoCard(Widget image) => _framePhotoCardImpl(image);

  Widget _framePaperTapeCard(Widget image) => _framePaperTapeCardImpl(image);

  Widget _framePosterPolaroid(Widget image) => _framePosterPolaroidImpl(image);

  Widget _frameCollageTile(Widget image) => _frameCollageTileImpl(image);

  Widget _frameTornPaperCard(Widget image) => _frameTornPaperCardImpl(image);

  Widget _framePaperClipCard(Widget image) => _framePaperClipCardImpl(image);

  Widget _frameRibbonPolaroid(Widget image) => _frameRibbonPolaroidImpl(image);

  Widget _frameRoughPolaroid(Widget image) => _frameRoughPolaroidImpl(image);

  Widget _frameMaskingTape(Widget image) => _frameMaskingTapeImpl(image);

  Widget _frameSoftPaperCard(Widget image) => _frameSoftPaperCardImpl(image);

  /// 소프트 글로우 – 바텀시트와 동일: 그라데이션 FFF5FB→E9F4FF, 24r, 패딩 10, 사진 20r
  Widget _frameSoftGlow(Widget image) => _frameSoftGlowImpl(image);

  /// 아티스틱 브러쉬 – 바텀시트와 동일: 흰색 24r/E0E4F2 2, 내부 F7F8FF 20r/D0D7F0 1.4
  Widget _frameVintage(Widget image) => _frameVintageImpl(image);

  /// 스케치 – 바텀시트와 동일: 투명 4r, black87 1.5, 패딩 4, 사진 2r
  Widget _frameSketch(Widget image) => _frameSketchImpl(image);

  /// 스티커 프레임 – 바텀시트와 동일: 흰색 10r, 검정 2, 패딩 4, 사진 6r
  Widget _frameSticker(Widget image) => _frameStickerImpl(image);

  /// 빈티지 필름 스트립 – 폴라로이드와 비슷한 세로 카드 비율
  Widget _frameFilm(Widget image) => _frameFilmImpl(image);

  /// 정사각 필름 프레임 (포스터 느낌)
  Widget _frameFilmSquare(Widget image) => _frameFilmSquareImpl(image);

  /// Win95 창 느낌 프레임
  Widget _frameWin95(Widget image) => _frameWin95Impl(image);

  Widget _win95Button({double size = 12}) => _win95ButtonImpl(size: size);

  /// 픽셀 8-bit 프레임
  Widget _framePixel8(Widget image) => _framePixel8Impl(image);

  /// VHS 프레임
  Widget _frameVhs(Widget image) => _frameVhsImpl(image);

  /// 네온 프레임
  Widget _frameNeon(Widget image) => _frameNeonImpl(image);

  /// 크레용 프레임
  Widget _frameCrayon(Widget image) => _frameCrayonImpl(image);

  /// 노트북 메모 프레임
  Widget _frameNotebook(Widget image) => _frameNotebookImpl(image);

  Widget _notebookMarginDots() => _notebookMarginDotsImpl();

  /// 테이프 + 클립 포토 카드
  Widget _frameTapeClip(Widget image) => _frameTapeClipImpl(image);

  /// 코믹 말풍선 프레임
  Widget _frameComicBubble(Widget image) => _frameComicBubbleImpl(image);

  /// 얇은 더블라인 프레임
  Widget _frameThinDoubleLine(Widget image) => _frameThinDoubleLineImpl(image);

  /// 오프셋 컬러 블록 프레임
  Widget _frameOffsetColorBlock(Widget image) =>
      _frameOffsetColorBlockImpl(image);

  /// 플로팅 글래스 프레임
  Widget _frameFloatingGlass(Widget image) => _frameFloatingGlassImpl(image);

  /// 그라디언트 엣지 프레임
  Widget _frameGradientEdge(Widget image) => _frameGradientEdgeImpl(image);

  /// 찢어진 노트 프레임
  Widget _frameTornNotebook(Widget image) => _frameTornNotebookImpl(image);

  /// 올드 뉴스페이퍼 프레임
  Widget _frameOldNewspaper(Widget image) => _frameOldNewspaperImpl(image);

  /// 우표 프레임
  Widget _framePostalStamp(Widget image) => _framePostalStampImpl(image);

  /// 크래프트 종이 프레임
  Widget _frameKraftPaper(Widget image) => _frameKraftPaperImpl(image);

  /// 골드 프레임
  Widget _frameGoldFrame(Widget image) => _frameGoldFrameImpl(image);

  /// RSVP 티켓형 프레임
  Widget _frameTicketStub(Widget image) => _frameTicketStubImpl(image);

  /// 블롭 프레임
  Widget _frameBlob(Widget image) => _frameBlobImpl(image);

  /// 핑크 스플래터
  Widget _framePinkSplatter(Widget image) => _framePinkSplatterImpl(image);

  /// 톡식 글로우
  Widget _frameToxicGlow(Widget image) => _frameToxicGlowImpl(image);

  /// 스텐실 블록
  Widget _frameStencilBlock(Widget image) => _frameStencilBlockImpl(image);

  /// 미드나잇 드립
  Widget _frameMidnightDrip(Widget image) => _frameMidnightDripImpl(image);

  /// 베이퍼 스트리트
  Widget _frameVaporStreet(Widget image) => _frameVaporStreetImpl(image);

  /// 텍스트 레이어 빌드
  Widget buildText(LayerModel layer, {bool isCover = false}) =>
      _buildTextImpl(this, layer, isCover: isCover);
  bool _isEditing(LayerModel layer) {
    return interaction.selectedLayerId == layer.id
        ? false
        : false; // 현재 편집 중 레이어 숨김은 interaction에서 editing id로 제어 가능
  }

  // ImageInfo 프리패치가 필요해지면 여기에 precacheImage 등을 추가한다.
}
