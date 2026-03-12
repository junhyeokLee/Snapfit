import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/snapfit_image.dart';
import '../../domain/entities/layer.dart';
import 'layer_interaction_manager.dart';

/// 이미지/텍스트 레이어의 렌더링과 기본 사이즈 계산 전담
class LayerBuilder {
  final LayerInteractionManager interaction;
  final Size Function() getCoverSize;

  LayerBuilder(this.interaction, this.getCoverSize);

  /// 스타일별 가로 패딩 합(좌+우) — 텍스트 레이아웃 시 콘텐츠 너비 계산용
  static double _styleHorizontalPadding(String type) {
    switch (type) {
      case "round":
      case "roundGray":
      case "roundPink":
      case "roundBlue":
      case "roundMint":
      case "roundLavender":
      case "roundOrange":
      case "roundGreen":
      case "roundCream":
      case "roundNavy":
      case "roundRose":
      case "roundCoral":
      case "roundBeige":
      case "roundTeal":
      case "roundLemon":
      case "square":
      case "squareGray":
      case "squarePink":
      case "squareBlue":
      case "squareMint":
      case "squareLavender":
      case "squareOrange":
      case "squareGreen":
      case "squareCream":
      case "squareNavy":
      case "squareRose":
      case "squareCoral":
      case "squareBeige":
      case "squareTeal":
      case "squareLemon":
      case "roundSoft":
      case "roundSoftGray":
      case "roundSoftPink":
      case "roundSoftBlue":
      case "roundSoftMint":
      case "roundSoftLavender":
      case "roundSoftOrange":
      case "roundSoftGreen":
      case "roundSoftCream":
      case "roundSoftNavy":
      case "roundSoftRose":
      case "roundSoftCoral":
      case "roundSoftBeige":
      case "roundSoftTeal":
      case "roundSoftLemon":
      case "softPill2":
      case "softPill2Gray":
      case "softPill2Pink":
      case "softPill2Blue":
      case "softPill2Mint":
      case "softPill2Lavender":
      case "softPill2Orange":
      case "softPill2Green":
      case "softPill2Cream":
      case "softPill2Navy":
      case "softPill2Rose":
      case "softPill2Coral":
      case "softPill2Beige":
      case "softPill2Teal":
      case "softPill2Lemon":
        return 28;
      case "label":
      case "labelGray":
      case "labelPink":
      case "labelBlue":
      case "labelMint":
      case "labelLavender":
      case "labelOrange":
      case "labelGreen":
      case "labelWhite":
      case "labelCream":
        return 28;
      case "tag":
      case "tagGray":
      case "tagPink":
      case "tagBlue":
      case "tagMint":
      case "tagLavender":
      case "tagOrange":
      case "tagGreen":
      case "tagRed":
        return 24;
      case "labelSolid":
      case "labelSolidGray":
      case "labelSolidPink":
      case "labelSolidBlue":
      case "labelSolidMint":
      case "labelSolidRed":
      case "labelSolidGreen":
      case "labelSolidOrange":
      case "labelSolidLavender":
      case "labelSolidCream":
      case "labelGold":
      case "labelNeon":
      case "labelRose":
        return 32;
      case "labelOutline":
        return 28;
      case "bubble":
      case "bubbleGray":
      case "bubblePink":
      case "bubbleBlue":
      case "bubbleMint":
      case "bubbleLavender":
      case "bubbleOrange":
      case "bubbleGreen":
      case "bubbleCream":
      case "bubbleNavy":
      case "bubbleRose":
      case "bubbleCoral":
      case "bubbleBeige":
      case "bubbleTeal":
      case "bubbleLemon":
      case "bubbleCenter":
      case "bubbleCenterGray":
      case "bubbleCenterPink":
      case "bubbleCenterBlue":
      case "bubbleCenterMint":
      case "bubbleCenterLavender":
      case "bubbleCenterOrange":
      case "bubbleCenterGreen":
      case "bubbleCenterCream":
      case "bubbleCenterNavy":
      case "bubbleCenterRose":
      case "bubbleCenterCoral":
      case "bubbleCenterBeige":
      case "bubbleCenterTeal":
      case "bubbleCenterLemon":
      case "bubbleRight":
      case "bubbleRightGray":
      case "bubbleRightPink":
      case "bubbleRightBlue":
      case "bubbleRightMint":
      case "bubbleRightLavender":
      case "bubbleRightOrange":
      case "bubbleRightGreen":
      case "bubbleRightCream":
      case "bubbleRightNavy":
      case "bubbleRightRose":
      case "bubbleRightCoral":
      case "bubbleRightBeige":
      case "bubbleRightTeal":
      case "bubbleRightLemon":
      case "bubbleSquare":
      case "bubbleSquareGray":
      case "bubbleSquarePink":
      case "bubbleSquareBlue":
      case "bubbleSquareMint":
      case "bubbleSquareLavender":
      case "bubbleSquareOrange":
      case "bubbleSquareGreen":
      case "bubbleSquareCream":
      case "bubbleSquareNavy":
      case "bubbleSquareRose":
      case "bubbleSquareCoral":
      case "bubbleSquareBeige":
      case "bubbleSquareTeal":
      case "bubbleSquareLemon":
      case "bubbleSquareCenter":
      case "bubbleSquareCenterGray":
      case "bubbleSquareCenterPink":
      case "bubbleSquareCenterBlue":
      case "bubbleSquareCenterMint":
      case "bubbleSquareCenterLavender":
      case "bubbleSquareCenterOrange":
      case "bubbleSquareCenterGreen":
      case "bubbleSquareCenterCream":
      case "bubbleSquareCenterNavy":
      case "bubbleSquareCenterRose":
      case "bubbleSquareCenterCoral":
      case "bubbleSquareCenterBeige":
      case "bubbleSquareCenterTeal":
      case "bubbleSquareCenterLemon":
      case "bubbleSquareRight":
      case "bubbleSquareRightGray":
      case "bubbleSquareRightPink":
      case "bubbleSquareRightBlue":
      case "bubbleSquareRightMint":
      case "bubbleSquareRightLavender":
      case "bubbleSquareRightOrange":
      case "bubbleSquareRightGreen":
      case "bubbleSquareRightCream":
      case "bubbleSquareRightNavy":
      case "bubbleSquareRightRose":
      case "bubbleSquareRightCoral":
      case "bubbleSquareRightBeige":
      case "bubbleSquareRightTeal":
      case "bubbleSquareRightLemon":
        return 36;
      case "note":
      case "noteBlue":
      case "notePink":
      case "noteMint":
      case "noteLavender":
      case "noteOrange":
      case "noteGray":
      case "noteBeige":
      case "noteTorn":
      case "noteTornGray":
      case "noteTornPink":
      case "noteTornBlue":
      case "noteTornMint":
      case "noteTornLavender":
      case "noteTornOrange":
      case "noteTornCream":
      case "noteTornBeige":
      case "noteTornYellow":
      case "noteTornGold":
      case "noteTornRough":
      case "noteTornRoughGray":
      case "noteTornRoughPink":
      case "noteTornRoughBlue":
      case "noteTornRoughMint":
      case "noteTornRoughLavender":
      case "noteTornRoughOrange":
      case "noteTornRoughCream":
      case "noteTornRoughBeige":
      case "noteTornRoughYellow":
      case "noteTornRoughGold":
      case "noteTornSoft":
      case "noteTornSoftGray":
      case "noteTornSoftPink":
      case "noteTornSoftBlue":
      case "noteTornSoftMint":
      case "noteTornSoftLavender":
      case "noteTornSoftOrange":
      case "noteTornSoftCream":
      case "noteTornSoftBeige":
      case "noteTornSoftYellow":
      case "noteTornSoftGold":
      case "noteGrid":
      case "noteGridBlue":
      case "noteGridPink":
      case "noteGridMint":
      case "noteGridLavender":
      case "noteGridOrange":
      case "noteGridGray":
      case "noteGold":
      case "noteCream":
        return 36;
      case "tape":
      case "tapeYellow":
      case "tapePink":
      case "tapeMint":
      case "tapeLavender":
      case "tapeGray":
      case "tapeTorn":
      case "tapeTornGray":
      case "tapeTornPink":
      case "tapeTornMint":
      case "tapeTornLavender":
      case "tapeTornYellow":
      case "tapeTornRough":
      case "tapeTornRoughGray":
      case "tapeTornRoughPink":
      case "tapeTornRoughMint":
      case "tapeTornRoughLavender":
      case "tapeTornRoughYellow":
      case "tapeTornSoft":
      case "tapeTornSoftGray":
      case "tapeTornSoftPink":
      case "tapeTornSoftMint":
      case "tapeTornSoftLavender":
      case "tapeTornSoftYellow":
      case "tapeTornSolid":
      case "tapeTornSolidGray":
      case "tapeTornSolidPink":
      case "tapeTornSolidBlue":
      case "tapeTornSolidMint":
      case "tapeTornSolidLavender":
      case "tapeTornSolidOrange":
      case "tapeTornSolidGreen":
      case "tapeDots":
      case "tapeDotsPink":
      case "tapeDotsMint":
      case "tapeDotsLavender":
      case "tapeDotsOrange":
      case "tapeDotsGray":
      case "tapeKraft":
      case "tapeGold":
      case "tapeSolidWhite":
      case "tapeSolidGray":
      case "tapeSolidPink":
      case "tapeSolidBlue":
      case "tapeSolidMint":
      case "tapeSolidLavender":
      case "tapeSolidOrange":
      case "tapeSolidGreen":
      case "tapeDouble":
      case "tapeDoublePink":
      case "tapeDoubleMint":
      case "tapeDoubleBlue":
      case "tapeDoubleLavender":
      case "tapeDoubleGray":
        return 36;
      case "calligraphy":
      case "highlightYellow":
      case "highlightGreen":
      case "highlightPink":
      case "stampRed":
      case "stampBlue":
      case "quote":
      case "chalkboard":
      case "caption":
        return 32;
      case "noteGrid":
        return 36;
      case "sticker":
        return 32;
      default:
        return 24;
    }
  }

  /// 기본 텍스트와 동일한 레이아웃(maxWidth)을 쓰므로, 스타일은 텍스트 영역 + 패딩만 넉넉히 줌. 세로는 line height·다음줄까지 여유 확보.
  static const double _styleVerticalSafety = 20.0;
  /// 기본은 좌우 패딩 4씩이라 콘텐츠 폭이 textSize.width+12. 스타일도 같은 콘텐츠 폭 쓰도록 가로 여유.
  static const double _styleHorizontalExtra = 12.0;

  /// 찢어진 메모지(아래 톱니) step/amp – 키에 따라 일반(8, 2.5), 거친(12, 4), 부드러운(5, 1.2)
  static (double, double) _tornEdgeParams(String key) {
    if (key.contains('Rough')) return (12.0, 4.0);
    if (key.contains('Soft')) return (5.0, 1.2);
    return (8.0, 2.5);
  }

  /// 찢어진 테이프 키 → 단색 테이프 키 (tapeTorn*/tapeTornSolid* → tapeSolid*)
  static String? _tapeTornToSolidKey(String? key) {
    if (key == null) return 'tapeSolidWhite';
    final k = key
        .replaceFirst('tapeTornRough', 'tapeTorn')
        .replaceFirst('tapeTornSoft', 'tapeTorn');
    if (k.startsWith('tapeTornSolid')) {
      final resolved = k.replaceFirst('tapeTornSolid', 'tapeSolid');
      return resolved.isEmpty ? 'tapeSolidWhite' : (resolved == 'tapeSolid' ? 'tapeSolidWhite' : resolved);
    }
    switch (k) {
      case 'tapeTorn': return 'tapeSolidWhite';
      case 'tapeTornGray': return 'tapeSolidGray';
      case 'tapeTornPink': return 'tapeSolidPink';
      case 'tapeTornMint': return 'tapeSolidMint';
      case 'tapeTornLavender': return 'tapeSolidLavender';
      case 'tapeTornYellow': return 'tapeSolidOrange';
      default: return 'tapeSolidWhite';
    }
  }

  Size _calculateStyleSize(String type, LayerModel layer, TextPainter painter) {
    final textSize = painter.size;
    final hPad = _styleHorizontalPadding(type);
    final totalWidth = textSize.width + hPad + _styleHorizontalExtra;

    switch (type) {
      case "round":
      case "roundGray":
      case "roundPink":
      case "roundBlue":
      case "roundMint":
      case "roundLavender":
      case "roundOrange":
      case "roundGreen":
      case "roundCream":
      case "roundNavy":
      case "roundRose":
      case "roundCoral":
      case "roundBeige":
      case "roundTeal":
      case "roundLemon":
      case "square":
      case "squareGray":
      case "squarePink":
      case "squareBlue":
      case "squareMint":
      case "squareLavender":
      case "squareOrange":
      case "squareGreen":
      case "squareCream":
      case "squareNavy":
      case "squareRose":
      case "squareCoral":
      case "squareBeige":
      case "squareTeal":
      case "squareLemon":
      case "roundSoft":
      case "roundSoftGray":
      case "roundSoftPink":
      case "roundSoftBlue":
      case "roundSoftMint":
      case "roundSoftLavender":
      case "roundSoftOrange":
      case "roundSoftGreen":
      case "roundSoftCream":
      case "roundSoftNavy":
      case "roundSoftRose":
      case "roundSoftCoral":
      case "roundSoftBeige":
      case "roundSoftTeal":
      case "roundSoftLemon":
      case "softPill2":
      case "softPill2Gray":
      case "softPill2Pink":
      case "softPill2Blue":
      case "softPill2Mint":
      case "softPill2Lavender":
      case "softPill2Orange":
      case "softPill2Green":
      case "softPill2Cream":
      case "softPill2Navy":
      case "softPill2Rose":
      case "softPill2Coral":
      case "softPill2Beige":
      case "softPill2Teal":
      case "softPill2Lemon":
        return Size(totalWidth, textSize.height + 16 + _styleVerticalSafety);
      // 중앙 찢어진 스크래치 레이아웃 (고정 크기)
      case "tag":
      case "tagGray":
      case "tagPink":
      case "tagBlue":
      case "tagMint":
      case "tagLavender":
      case "tagOrange":
      case "tagGreen":
      case "tagRed":
      case "label":
      case "labelGray":
      case "labelPink":
      case "labelBlue":
      case "labelMint":
      case "labelLavender":
      case "labelOrange":
      case "labelGreen":
      case "labelWhite":
      case "labelCream":
        return Size(totalWidth, textSize.height + 12 + _styleVerticalSafety);
      case "labelSolid":
      case "labelSolidGray":
      case "labelSolidPink":
      case "labelSolidBlue":
      case "labelSolidMint":
      case "labelSolidRed":
      case "labelSolidGreen":
      case "labelSolidOrange":
      case "labelSolidLavender":
      case "labelSolidCream":
      case "labelOutline":
      case "labelGold":
      case "labelNeon":
      case "labelRose":
        return Size(totalWidth, textSize.height + 16 + _styleVerticalSafety);
      case "bubble":
      case "bubbleGray":
      case "bubblePink":
      case "bubbleBlue":
      case "bubbleMint":
      case "bubbleLavender":
      case "bubbleOrange":
      case "bubbleGreen":
      case "bubbleCream":
      case "bubbleNavy":
      case "bubbleRose":
      case "bubbleCoral":
      case "bubbleBeige":
      case "bubbleTeal":
      case "bubbleLemon":
      case "bubbleCenter":
      case "bubbleCenterGray":
      case "bubbleCenterPink":
      case "bubbleCenterBlue":
      case "bubbleCenterMint":
      case "bubbleCenterLavender":
      case "bubbleCenterOrange":
      case "bubbleCenterGreen":
      case "bubbleCenterCream":
      case "bubbleCenterNavy":
      case "bubbleCenterRose":
      case "bubbleCenterCoral":
      case "bubbleCenterBeige":
      case "bubbleCenterTeal":
      case "bubbleCenterLemon":
      case "bubbleRight":
      case "bubbleRightGray":
      case "bubbleRightPink":
      case "bubbleRightBlue":
      case "bubbleRightMint":
      case "bubbleRightLavender":
      case "bubbleRightOrange":
      case "bubbleRightGreen":
      case "bubbleRightCream":
      case "bubbleRightNavy":
      case "bubbleRightRose":
      case "bubbleRightCoral":
      case "bubbleRightBeige":
      case "bubbleRightTeal":
      case "bubbleRightLemon":
      case "bubbleSquare":
      case "bubbleSquareGray":
      case "bubbleSquarePink":
      case "bubbleSquareBlue":
      case "bubbleSquareMint":
      case "bubbleSquareLavender":
      case "bubbleSquareOrange":
      case "bubbleSquareGreen":
      case "bubbleSquareCream":
      case "bubbleSquareNavy":
      case "bubbleSquareRose":
      case "bubbleSquareCoral":
      case "bubbleSquareBeige":
      case "bubbleSquareTeal":
      case "bubbleSquareLemon":
      case "bubbleSquareCenter":
      case "bubbleSquareCenterGray":
      case "bubbleSquareCenterPink":
      case "bubbleSquareCenterBlue":
      case "bubbleSquareCenterMint":
      case "bubbleSquareCenterLavender":
      case "bubbleSquareCenterOrange":
      case "bubbleSquareCenterGreen":
      case "bubbleSquareCenterCream":
      case "bubbleSquareCenterNavy":
      case "bubbleSquareCenterRose":
      case "bubbleSquareCenterCoral":
      case "bubbleSquareCenterBeige":
      case "bubbleSquareCenterTeal":
      case "bubbleSquareCenterLemon":
      case "bubbleSquareRight":
      case "bubbleSquareRightGray":
      case "bubbleSquareRightPink":
      case "bubbleSquareRightBlue":
      case "bubbleSquareRightMint":
      case "bubbleSquareRightLavender":
      case "bubbleSquareRightOrange":
      case "bubbleSquareRightGreen":
      case "bubbleSquareRightCream":
      case "bubbleSquareRightNavy":
      case "bubbleSquareRightRose":
        return Size(totalWidth, textSize.height + 32 + _styleVerticalSafety);
      case "note":
      case "noteBlue":
      case "notePink":
      case "noteMint":
      case "noteLavender":
      case "noteOrange":
      case "noteGray":
      case "noteBeige":
      case "noteTorn":
      case "noteTornGray":
      case "noteTornPink":
      case "noteTornBlue":
      case "noteTornMint":
      case "noteTornLavender":
      case "noteTornOrange":
      case "noteTornCream":
      case "noteTornBeige":
      case "noteTornYellow":
      case "noteTornGold":
      case "noteTornRough":
      case "noteTornRoughGray":
      case "noteTornRoughPink":
      case "noteTornRoughBlue":
      case "noteTornRoughMint":
      case "noteTornRoughLavender":
      case "noteTornRoughOrange":
      case "noteTornRoughCream":
      case "noteTornRoughBeige":
      case "noteTornRoughYellow":
      case "noteTornRoughGold":
      case "noteTornSoft":
      case "noteTornSoftGray":
      case "noteTornSoftPink":
      case "noteTornSoftBlue":
      case "noteTornSoftMint":
      case "noteTornSoftLavender":
      case "noteTornSoftOrange":
      case "noteTornSoftCream":
      case "noteTornSoftBeige":
      case "noteTornSoftYellow":
      case "noteTornSoftGold":
      case "noteGrid":
      case "noteGridBlue":
      case "noteGridPink":
      case "noteGridMint":
      case "noteGridLavender":
      case "noteGridOrange":
      case "noteGridGray":
        return Size(
          (totalWidth / 12).ceil() * 12.0,
          ((textSize.height + 24) / 12).ceil() * 12.0,
        );
      case "noteGold":
      case "noteCream":
        return Size(totalWidth, textSize.height + 32);
      case "tape":
      case "tapeYellow":
      case "tapePink":
      case "tapeMint":
      case "tapeLavender":
      case "tapeGray":
      case "tapeTorn":
      case "tapeTornGray":
      case "tapeTornPink":
      case "tapeTornMint":
      case "tapeTornLavender":
      case "tapeTornYellow":
      case "tapeTornRough":
      case "tapeTornRoughGray":
      case "tapeTornRoughPink":
      case "tapeTornRoughMint":
      case "tapeTornRoughLavender":
      case "tapeTornRoughYellow":
      case "tapeTornSoft":
      case "tapeTornSoftGray":
      case "tapeTornSoftPink":
      case "tapeTornSoftMint":
      case "tapeTornSoftLavender":
      case "tapeTornSoftYellow":
      case "tapeTornSolid":
      case "tapeTornSolidGray":
      case "tapeTornSolidPink":
      case "tapeTornSolidBlue":
      case "tapeTornSolidMint":
      case "tapeTornSolidLavender":
      case "tapeTornSolidOrange":
      case "tapeTornSolidGreen":
      case "tapeDots":
      case "tapeDotsPink":
      case "tapeDotsMint":
      case "tapeDotsLavender":
      case "tapeDotsOrange":
      case "tapeDotsGray":
      case "tapeKraft":
      case "tapeGold":
      case "tapeSolidWhite":
      case "tapeSolidGray":
      case "tapeSolidPink":
      case "tapeSolidBlue":
      case "tapeSolidMint":
      case "tapeSolidLavender":
      case "tapeSolidOrange":
      case "tapeSolidGreen":
      case "tapeDouble":
      case "tapeDoublePink":
      case "tapeDoubleMint":
      case "tapeDoubleBlue":
      case "tapeDoubleLavender":
      case "tapeDoubleGray":
        return Size(totalWidth, textSize.height + 0 + _styleVerticalSafety);
      case "calligraphy":
      case "highlightYellow":
      case "highlightGreen":
      case "highlightPink":
      case "stampRed":
      case "stampBlue":
      case "quote":
      case "chalkboard":
      case "caption":
        return Size(totalWidth, textSize.height + 16 + _styleVerticalSafety);
      case "sticker":
        return Size(totalWidth, textSize.height + 20 + _styleVerticalSafety);
      default:
        return Size(textSize.width + 20, textSize.height + 10);
    }
  }

  /// 템플릿 적용 시 템플릿 비율 슬롯에 사진이 꽉 차게 cover, 자유 비율이면 cover
  static BoxFit _imageFitForLayer(LayerModel layer) {
    // 템플릿이 있든 없든 모두 cover로 꽉 차게 표시
    return BoxFit.cover;
  }

  /// 이미지 레이어 빌드
  Widget buildImage(LayerModel layer, {bool isCover = false}) {
    // 편집 중인 레이어면 숨김
    if (_isEditing(layer)) return const SizedBox.shrink();

    final fit = _imageFitForLayer(layer);

    if (layer.asset != null) {
      // 아직 업로드 전: 로컬 AssetEntity로 표시
      return interaction.buildInteractiveLayer(
        layer: layer,
        baseWidth: layer.width,
        baseHeight: layer.height,
        isCover: isCover,
        child: Opacity(
          opacity: layer.opacity,
          child: _buildFramedImage(
            layer,
            Image(
              image: AssetEntityImageProvider(layer.asset!),
              fit: fit,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      );
    }

    final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
    if (url == null || url.isEmpty) {
      return interaction.buildInteractiveLayer(
        layer: layer,
        baseWidth: layer.width,
        baseHeight: layer.height,
        isCover: isCover,
        child: Opacity(
          opacity: layer.opacity,
          child: _buildImagePlaceholder(layer),
        ),
      );
    }

    // 앱 번들 에셋 기반 스티커(예: asset:assets/sticker/scrap1.png)
    if (url.startsWith('asset:')) {
      final assetPath = url.substring('asset:'.length);
      return interaction.buildInteractiveLayer(
        layer: layer,
        baseWidth: layer.width,
        baseHeight: layer.height,
        isCover: isCover,
        child: Opacity(
          opacity: layer.opacity,
          child: _buildFramedImage(
            layer,
            Image.asset(
              assetPath,
              // 찢김 스크랩 스티커는 이미지 전체가 보이도록 contain 사용
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      );
    }

    return interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: layer.width,
      baseHeight: layer.height,
      isCover: isCover,
      child: Opacity(
        opacity: layer.opacity,
        child: _buildFramedImage(
          layer,
          SnapfitImage(
            key: ValueKey(layer.id), // Stable key to prevent reloading
            urlOrGs: url, 
            fit: fit,
          ),
        ),
      ),
    );
  }

  /// 빈 이미지 슬롯(플레이스홀더) – 템플릿 적용 후 사진을 넣을 자리
  Widget _buildImagePlaceholder(LayerModel layer) {
    final placeholder = Container(
      width: layer.width,
      height: layer.height,
      decoration: BoxDecoration(
        color: const Color(0xFFEBEBEB),
        borderRadius: BorderRadius.zero,
      ),
      child: Center(
        child: Icon(
          Icons.add_a_photo,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
    return _buildFramedImage(layer, placeholder);
  }

  /// 이미지 프레임 적용 스위치
  Widget _buildFramedImage(LayerModel layer, Widget image) {
    switch (layer.imageBackground) {
      case "circle":
        return _frameCircle(image);
      case "round":
        return _frameRound(image);
      case "polaroid":
        return _framePolaroid(image);
      case "polaroidClassic":
        return _framePolaroidClassic(image);
      case "polaroidWide":
        return _framePolaroidWide(image);
      case "polaroidFilm":
        return _framePolaroidFilm(image);
      case "softGlow":
        return _frameSoftGlow(image);
      case "sticker":
        return _frameSticker(image);
      case "vintage":
        return _frameVintage(image);
      case "film":
        return _frameFilm(image);
      case "sketch":
        return _frameSketch(image);
      case "win95":
        return _frameWin95(image);
      case "pixel8":
        return _framePixel8(image);
      case "vhs":
        return _frameVhs(image);
      case "neon":
        return _frameNeon(image);
      case "crayon":
        return _frameCrayon(image);
      case "notebook":
        return _frameNotebook(image);
      case "tapeClip":
        return _frameTapeClip(image);
      case "comicBubble":
        return _frameComicBubble(image);
      case "thinDoubleLine":
        return _frameThinDoubleLine(image);
      case "offsetColorBlock":
        return _frameOffsetColorBlock(image);
      case "floatingGlass":
        return _frameFloatingGlass(image);
      case "gradientEdge":
        return _frameGradientEdge(image);
      case "tornNotebook":
        return _frameTornNotebook(image);
      case "oldNewspaper":
        return _frameOldNewspaper(image);
      case "postalStamp":
        return _framePostalStamp(image);
      case "kraftPaper":
        return _frameKraftPaper(image);
      case "goldFrame":
        return _frameGoldFrame(image);
      case "pinkSplatter":
        return _framePinkSplatter(image);
      case "toxicGlow":
        return _frameToxicGlow(image);
      case "stencilBlock":
        return _frameStencilBlock(image);
      case "midnightDrip":
        return _frameMidnightDrip(image);
      case "vaporStreet":
        return _frameVaporStreet(image);
      default:
        return image;
    }
  }

  /// 기본 원형 – 바텀시트 디자인대로 원형
  Widget _frameCircle(Widget image) {
    return ClipOval(
      child: FittedBox(fit: BoxFit.cover, child: image),
    );
  }

  /// 소프트 라운드 – 바텀시트와 동일: 카드 없이 18px 둥글게
  Widget _frameRound(Widget image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: image,
    );
  }

  /// 공통: 폴라로이드 하단 가로선 (클래식/카드 동일)
  static Widget _polaroidBottomLine() {
    return Container(
      height: 3,
      width: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFD0D3DC),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  /// 클래식 폴라로이드 – 세로로 길고 가로는 더 좁은 카드 (좌우·위 20, 아래 80 여백)
  Widget _framePolaroid(Widget image) {
    return Center(
      child: AspectRatio(
        // 세로가 더 긴 폴라로이드 카드 비율 (width : height)
        aspectRatio: 3 / 4,
        child: Container(
          // 좌우/위는 동일, 아래는 더 넉넉하게
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 80),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E3EC), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox.expand(child: image),
          ),
        ),
      ),
    );
  }

  /// 카드 폴라로이드 – 세로로 길고 가로는 더 좁은 카드 (좌우·위 20, 아래 80 여백)
  Widget _framePolaroidClassic(Widget image) {
    return Center(
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          // 좌우/위는 동일, 아래는 더 넉넉하게
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 80),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E4D8), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox.expand(child: image),
          ),
        ),
      ),
    );
  }

  /// 와이드 폴라로이드 – 바텀시트와 동일: 흰색 6r, 패딩 2/6/2/14, 사진 3r
  Widget _framePolaroidWide(Widget image) {
    return Container(
      // 와이드 샷 – 좌우/위는 적당히, 아래는 조금 더 여유
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withOpacity(0.35), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: image,
        ),
      ),
    );
  }

  /// 폴라로이드 필름 – 검은 카드 + 폴라로이드 비율
  Widget _framePolaroidFilm(Widget image) {
    return Center(
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 80),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white30, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox.expand(child: image),
          ),
        ),
      ),
    );
  }

  /// 소프트 글로우 – 바텀시트와 동일: 그라데이션 FFF5FB→E9F4FF, 24r, 패딩 10, 사진 20r
  Widget _frameSoftGlow(Widget image) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF5FB),
            Color(0xFFE9F4FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: image,
      ),
    );
  }

  /// 아티스틱 브러쉬 – 바텀시트와 동일: 흰색 24r/E0E4F2 2, 내부 F7F8FF 20r/D0D7F0 1.4
  Widget _frameVintage(Widget image) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E4F2), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD0D7F0), width: 1.4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: image,
        ),
      ),
    );
  }

  /// 스케치 – 바텀시트와 동일: 투명 4r, black87 1.5, 패딩 4, 사진 2r
  Widget _frameSketch(Widget image) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black87, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: image,
      ),
    );
  }

  /// 스티커 프레임 – 바텀시트와 동일: 흰색 10r, 검정 2, 패딩 4, 사진 6r
  Widget _frameSticker(Widget image) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: image,
      ),
    );
  }


  /// 빈티지 필름 스트립 – 폴라로이드와 비슷한 세로 카드 비율
  Widget _frameFilm(Widget image) {
    return Center(
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF151B2C),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // 왼쪽 점 4개 (프리뷰와 동일)
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (_) {
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D4556),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 4),
              // 중앙 화면 영역 (사진 + 배경색)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    color: const Color(0xFF1E2433),
                    child: SizedBox.expand(child: image),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 오른쪽 점 4개 (프리뷰와 동일)
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (_) {
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D4556),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 90s 윈도우 프레임
  Widget _frameWin95(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFC0C0C0),
        border: Border.all(color: const Color(0xFF808080), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            color: const Color(0xFF000080),
            child: Row(
              children: [
                Text('image.exe', style: TextStyle(color: Colors.white, fontSize: 11)),
                const Spacer(),
                _win95Button(),
                const SizedBox(width: 2),
                _win95Button(),
                const SizedBox(width: 2),
                _win95Button(),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: ClipRect(
                child: SizedBox.expand(child: image),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _win95Button() {
    return Container(
      width: 14,
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xFFC0C0C0),
        border: Border.all(color: const Color(0xFF808080)),
      ),
    );
  }

  /// 8비트 픽셀 보더
  Widget _framePixel8(Widget image) {
    const cornerColors = [Color(0xFFFFFF00), Color(0xFFFF0000), Color(0xFF0000FF), Color(0xFF00FF00)];
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black54, width: 1),
                  ),
                  child: SizedBox.expand(child: image),
                ),
              ),
            ),
          ),
          Positioned(top: -2, left: -2, child: Container(width: 6, height: 6, color: cornerColors[0])),
          Positioned(top: -2, right: -2, child: Container(width: 6, height: 6, color: cornerColors[1])),
          Positioned(bottom: -2, left: -2, child: Container(width: 6, height: 6, color: cornerColors[2])),
          Positioned(bottom: -2, right: -2, child: Container(width: 6, height: 6, color: cornerColors[3])),
        ],
      ),
    );
  }

  /// VHS 글리치
  Widget _frameVhs(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _VhsScanLinePainter(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('PLAY', style: TextStyle(color: const Color(0xFF00FF00), fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 2),
                    Icon(Icons.play_arrow, color: const Color(0xFF00FF00), size: 12),
                  ],
                ),
                Expanded(
                  child: ClipRect(
                    child: SizedBox.expand(child: image),
                  ),
                ),
                Center(
                  child: Text('SP 00:12:44', style: TextStyle(color: Colors.white70, fontSize: 9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 네온 사이버펑크
  Widget _frameNeon(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF00FFFF), width: 2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00FFFF).withOpacity(0.6), blurRadius: 8, spreadRadius: 0),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              color: Colors.black,
              child: FittedBox(fit: BoxFit.cover, child: image),
            ),
          ),
          Positioned(
            top: 2,
            left: 2,
            child: CustomPaint(
              size: const Size(12, 12),
              painter: _NeonCornerLPainter(),
            ),
          ),
        ],
      ),
    );
  }

  /// 손그림 크레파스
  Widget _frameCrayon(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4CC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8B88A), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }

  /// 수업시간 낙서장
  Widget _frameNotebook(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          _notebookMarginDots(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.pink.shade100, width: 1)),
              ),
              child: FittedBox(fit: BoxFit.cover, child: image),
            ),
          ),
          _notebookMarginDots(),
        ],
      ),
    );
  }

  Widget _notebookMarginDots() {
    return SizedBox(
      width: 8,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (_) => Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: Color(0xFFB0B0B0),
            shape: BoxShape.circle,
          ),
        )),
      ),
    );
  }

  /// 테이프 & 클립
  Widget _frameTapeClip(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E4DC)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 6, right: 6, bottom: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: FittedBox(fit: BoxFit.cover, child: image),
            ),
          ),
          Positioned(top: -4, left: 0, right: 0, child: Center(child: Icon(Icons.attach_file, size: 20, color: const Color(0xFF505050)))),
          Positioned(
            bottom: 4,
            right: 4,
            child: Transform.rotate(
              angle: 0.3,
              child: Container(
                width: 28,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEB3B).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 코믹 말풍선
  Widget _frameComicBubble(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }

  /// 씬 더블 라인
  Widget _frameThinDoubleLine(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE0E4EC), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8ECF0), width: 1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: FittedBox(fit: BoxFit.cover, child: image),
            ),
          ),
        ),
      ),
    );
  }

  /// 오프셋 컬러 블록
  Widget _frameOffsetColorBlock(Widget image) {
    return Container(
      margin: const EdgeInsets.only(right: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: const Border(
          top: BorderSide(color: Colors.black, width: 4),
          left: BorderSide(color: Colors.black, width: 4),
          right: BorderSide(color: Color(0xFFB0D0E8), width: 1),
          bottom: BorderSide(color: Color(0xFFB0D0E8), width: 1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }

  /// 플로팅 글래스
  Widget _frameFloatingGlass(Widget image) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFFA0B0E0).withOpacity(0.25), blurRadius: 16)],
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FittedBox(fit: BoxFit.cover, child: image),
        ),
      ),
    );
  }

  /// 그라데이션 엣지
  Widget _frameGradientEdge(Widget image) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6EB5FF), Color(0xFFB88AFF), Color(0xFFFF9EC5)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: FittedBox(fit: BoxFit.cover, child: image),
        ),
      ),
    );
  }

  /// 찢어진 노트 페이지
  Widget _frameTornNotebook(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }

  /// 오래된 신문 조각
  Widget _frameOldNewspaper(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE0D8C8)),
      ),
      child: Column(
        children: [
          Container(height: 12, color: const Color(0xFFE8E0D4)),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: FittedBox(fit: BoxFit.cover, child: image),
              ),
            ),
          ),
          Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFFD8D0C4)),
          const SizedBox(height: 2),
          Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFFD8D0C4)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// 우표 프레임
  Widget _framePostalStamp(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFC0C0C0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: FittedBox(fit: BoxFit.cover, child: image),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('1924', style: TextStyle(fontSize: 8, color: Color(0xFF707070))),
            ),
          ),
        ],
      ),
    );
  }

  /// 크라프트 종이
  Widget _frameKraftPaper(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFB8956E),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFC9A86C),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: const Color(0xFFA08050), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: FittedBox(fit: BoxFit.cover, child: image),
        ),
      ),
    );
  }

  /// 황금 갤러리
  Widget _frameGoldFrame(Widget image) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFC9A227), width: 10),
        boxShadow: [BoxShadow(color: const Color(0xFF8B6914).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }

  /// 핑크 스플래터
  Widget _framePinkSplatter(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FittedBox(fit: BoxFit.cover, child: image),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: const Color(0xFFFF60A0),
                strokeWidth: 2,
                borderRadius: 8,
                dashWidth: 5,
                dashSpace: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 톡시크 글로우
  Widget _frameToxicGlow(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF39FF14), width: 3),
        boxShadow: [BoxShadow(color: const Color(0xFF39FF14).withOpacity(0.5), blurRadius: 12)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }

  /// 스텐실 블록
  Widget _frameStencilBlock(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD0B898), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }

  /// 미드나잇 드립
  Widget _frameMidnightDrip(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8DC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD8D0C0)),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 14, left: 6, right: 6, bottom: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: FittedBox(fit: BoxFit.cover, child: image),
        ),
      ),
    );
  }

  /// 베이퍼 스트리트
  Widget _frameVaporStreet(Widget image) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC44DFF), width: 3),
        boxShadow: [BoxShadow(color: const Color(0xFFC44DFF).withOpacity(0.35), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(fit: BoxFit.cover, child: image),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF6B9D).withOpacity(0.2),
                    const Color(0xFFC44DFF).withOpacity(0.12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 텍스트 레이어 빌드
  Widget buildText(LayerModel layer, {bool isCover = false}) {
    if (_isEditing(layer)) return const SizedBox.shrink();

    // ✅ 기본 생성 텍스트 최소 폰트 크기 (너무 작게 생성되는 것 방지)
    const double minFontSize = 18;

    final TextStyle baseStyle = layer.textStyle ?? const TextStyle(fontSize: 18);

    // ✅ 실제 적용될 스타일 (최소값 보장)
    final TextStyle effectiveStyle = baseStyle.fontSize != null && baseStyle.fontSize! < minFontSize
        ? baseStyle.copyWith(fontSize: minFontSize)
        : baseStyle;

    final coverSize = getCoverSize();
    final textSpan = TextSpan(text: layer.text ?? "", style: effectiveStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: layer.textAlign ?? TextAlign.center,
    )..layout(minWidth: 0, maxWidth: coverSize.width * 0.8);

    // ───────────────────────────────────────────────
    // 텍스트 스타일(textStyleType) 우선 적용
    // 기존 backgroundMode는 유지하지만 styleType 있을 때는 스타일이 우선한다
    // ───────────────────────────────────────────────
    if (layer.textBackground != null) {
      Widget styled;

      switch (layer.textBackground) {
        case "round":
        case "roundGray":
        case "roundPink":
        case "roundBlue":
        case "roundMint":
        case "roundLavender":
        case "roundOrange":
        case "roundGreen":
        case "roundCream":
        case "roundNavy":
        case "roundRose":
        case "roundCoral":
        case "roundBeige":
        case "roundTeal":
        case "roundLemon":
          styled = _buildRoundStyle(layer, textPainter, effectiveStyle);
          break;
        case "square":
        case "squareGray":
        case "squarePink":
        case "squareBlue":
        case "squareMint":
        case "squareLavender":
        case "squareOrange":
        case "squareGreen":
        case "squareCream":
        case "squareNavy":
        case "squareRose":
        case "squareCoral":
        case "squareBeige":
        case "squareTeal":
        case "squareLemon":
          styled = _buildSquareStyle(layer, textPainter, effectiveStyle);
          break;
        case "roundSoft":
        case "roundSoftGray":
        case "roundSoftPink":
        case "roundSoftBlue":
        case "roundSoftMint":
        case "roundSoftLavender":
        case "roundSoftOrange":
        case "roundSoftGreen":
        case "roundSoftCream":
        case "roundSoftNavy":
        case "roundSoftRose":
        case "roundSoftCoral":
        case "roundSoftBeige":
        case "roundSoftTeal":
        case "roundSoftLemon":
          styled = _buildRoundSoftStyle(layer, textPainter, effectiveStyle);
          break;
        case "softPill2":
        case "softPill2Gray":
        case "softPill2Pink":
        case "softPill2Blue":
        case "softPill2Mint":
        case "softPill2Lavender":
        case "softPill2Orange":
        case "softPill2Green":
        case "softPill2Cream":
        case "softPill2Navy":
        case "softPill2Rose":
        case "softPill2Coral":
        case "softPill2Beige":
        case "softPill2Teal":
        case "softPill2Lemon":
          styled = _buildSoftPill2Style(layer, textPainter, effectiveStyle);
          break;
        case "label":
        case "labelGray":
        case "labelPink":
        case "labelBlue":
        case "labelMint":
        case "labelLavender":
        case "labelOrange":
        case "labelGreen":
        case "labelWhite":
        case "labelCream":
          styled = _buildLabelOvalStyle(layer, textPainter, effectiveStyle);
          break;
        case "tag":
        case "tagGray":
        case "tagPink":
        case "tagBlue":
        case "tagMint":
        case "tagLavender":
        case "tagOrange":
        case "tagGreen":
        case "tagRed":
          styled = _buildTagStyle(layer, textPainter, effectiveStyle);
          break;
        case "labelSolid":
        case "labelSolidGray":
        case "labelSolidPink":
        case "labelSolidBlue":
        case "labelSolidMint":
        case "labelSolidRed":
        case "labelSolidGreen":
        case "labelSolidOrange":
        case "labelSolidLavender":
        case "labelSolidCream":
          styled = _buildLabelSolidStyle(layer, textPainter, effectiveStyle);
          break;
        case "labelOutline":
          styled = _buildLabelOutlineStyle(layer, textPainter, effectiveStyle);
          break;
        case "labelGold":
          styled = _buildLabelGoldStyle(layer, textPainter, effectiveStyle);
          break;
        case "labelNeon":
          styled = _buildLabelNeonStyle(layer, textPainter, effectiveStyle);
          break;
        case "labelRose":
          styled = _buildLabelRoseStyle(layer, textPainter, effectiveStyle);
          break;
        case "bubble":
        case "bubbleGray":
        case "bubblePink":
        case "bubbleBlue":
        case "bubbleMint":
        case "bubbleLavender":
        case "bubbleOrange":
        case "bubbleGreen":
        case "bubbleCream":
        case "bubbleNavy":
        case "bubbleRose":
        case "bubbleCoral":
        case "bubbleBeige":
        case "bubbleTeal":
        case "bubbleLemon":
        case "bubbleCenter":
        case "bubbleCenterGray":
        case "bubbleCenterPink":
        case "bubbleCenterBlue":
        case "bubbleCenterMint":
        case "bubbleCenterLavender":
        case "bubbleCenterOrange":
        case "bubbleCenterGreen":
        case "bubbleCenterCream":
        case "bubbleCenterNavy":
        case "bubbleCenterRose":
        case "bubbleCenterCoral":
        case "bubbleCenterBeige":
        case "bubbleCenterTeal":
        case "bubbleCenterLemon":
        case "bubbleRight":
        case "bubbleRightGray":
        case "bubbleRightPink":
        case "bubbleRightBlue":
        case "bubbleRightMint":
        case "bubbleRightLavender":
        case "bubbleRightOrange":
        case "bubbleRightGreen":
        case "bubbleRightCream":
        case "bubbleRightNavy":
        case "bubbleRightRose":
        case "bubbleRightCoral":
        case "bubbleRightBeige":
        case "bubbleRightTeal":
        case "bubbleRightLemon":
        case "bubbleSquare":
        case "bubbleSquareGray":
        case "bubbleSquarePink":
        case "bubbleSquareBlue":
        case "bubbleSquareMint":
        case "bubbleSquareLavender":
        case "bubbleSquareOrange":
        case "bubbleSquareGreen":
        case "bubbleSquareCream":
        case "bubbleSquareNavy":
        case "bubbleSquareRose":
        case "bubbleSquareCoral":
        case "bubbleSquareBeige":
        case "bubbleSquareTeal":
        case "bubbleSquareLemon":
        case "bubbleSquareCenter":
        case "bubbleSquareCenterGray":
        case "bubbleSquareCenterPink":
        case "bubbleSquareCenterBlue":
        case "bubbleSquareCenterMint":
        case "bubbleSquareCenterLavender":
        case "bubbleSquareCenterOrange":
        case "bubbleSquareCenterGreen":
        case "bubbleSquareCenterCream":
        case "bubbleSquareCenterNavy":
        case "bubbleSquareCenterRose":
        case "bubbleSquareCenterCoral":
        case "bubbleSquareCenterBeige":
        case "bubbleSquareCenterTeal":
        case "bubbleSquareCenterLemon":
        case "bubbleSquareRight":
        case "bubbleSquareRightGray":
        case "bubbleSquareRightPink":
        case "bubbleSquareRightBlue":
        case "bubbleSquareRightMint":
        case "bubbleSquareRightLavender":
        case "bubbleSquareRightOrange":
        case "bubbleSquareRightGreen":
        case "bubbleSquareRightCream":
        case "bubbleSquareRightNavy":
        case "bubbleSquareRightRose":
        case "bubbleSquareRightCoral":
        case "bubbleSquareRightBeige":
        case "bubbleSquareRightTeal":
        case "bubbleSquareRightLemon":
          styled = _buildBubbleStyle(layer, textPainter, effectiveStyle);
          break;
        case "note":
        case "noteBlue":
        case "notePink":
        case "noteMint":
        case "noteLavender":
        case "noteOrange":
        case "noteGray":
        case "noteBeige":
          styled = _buildNoteStyle(layer, textPainter, effectiveStyle);
          break;
        case "noteTorn":
        case "noteTornGray":
        case "noteTornPink":
        case "noteTornBlue":
        case "noteTornMint":
        case "noteTornLavender":
        case "noteTornOrange":
        case "noteTornCream":
        case "noteTornBeige":
        case "noteTornYellow":
        case "noteTornGold":
        case "noteTornRough":
        case "noteTornRoughGray":
        case "noteTornRoughPink":
        case "noteTornRoughBlue":
        case "noteTornRoughMint":
        case "noteTornRoughLavender":
        case "noteTornRoughOrange":
        case "noteTornRoughCream":
        case "noteTornRoughBeige":
        case "noteTornRoughYellow":
        case "noteTornRoughGold":
        case "noteTornSoft":
        case "noteTornSoftGray":
        case "noteTornSoftPink":
        case "noteTornSoftBlue":
        case "noteTornSoftMint":
        case "noteTornSoftLavender":
        case "noteTornSoftOrange":
        case "noteTornSoftCream":
        case "noteTornSoftBeige":
        case "noteTornSoftYellow":
        case "noteTornSoftGold":
          styled = _buildNoteTornStyle(layer, textPainter, effectiveStyle);
          break;
        case "calligraphy":
          styled = _buildCalligraphyStyle(layer, textPainter, effectiveStyle);
          break;
        case "sticker":
          styled = _buildStickerStyle(layer, textPainter, effectiveStyle);
          break;
        case "tape":
        case "tapeYellow":
        case "tapePink":
        case "tapeMint":
        case "tapeLavender":
        case "tapeGray":
        case "tapeDots":
        case "tapeDotsPink":
        case "tapeDotsMint":
        case "tapeDotsLavender":
        case "tapeDotsOrange":
        case "tapeDotsGray":
        case "tapeKraft":
        case "tapeGold":
        case "tapeSolidWhite":
        case "tapeSolidGray":
        case "tapeSolidPink":
        case "tapeSolidBlue":
        case "tapeSolidMint":
        case "tapeSolidLavender":
        case "tapeSolidOrange":
        case "tapeSolidGreen":
        case "tapeDouble":
        case "tapeDoublePink":
        case "tapeDoubleMint":
        case "tapeDoubleBlue":
        case "tapeDoubleLavender":
        case "tapeDoubleGray":
          styled = _buildTapeStyle(layer, textPainter, effectiveStyle);
          break;
        case "tapeTorn":
        case "tapeTornGray":
        case "tapeTornPink":
        case "tapeTornMint":
        case "tapeTornLavender":
        case "tapeTornYellow":
        case "tapeTornRough":
        case "tapeTornRoughGray":
        case "tapeTornRoughPink":
        case "tapeTornRoughMint":
        case "tapeTornRoughLavender":
        case "tapeTornRoughYellow":
        case "tapeTornSoft":
        case "tapeTornSoftGray":
        case "tapeTornSoftPink":
        case "tapeTornSoftMint":
        case "tapeTornSoftLavender":
        case "tapeTornSoftYellow":
        case "tapeTornSolid":
        case "tapeTornSolidGray":
        case "tapeTornSolidPink":
        case "tapeTornSolidBlue":
        case "tapeTornSolidMint":
        case "tapeTornSolidLavender":
        case "tapeTornSolidOrange":
        case "tapeTornSolidGreen":
          styled = _buildTapeTornStyle(layer, textPainter, effectiveStyle);
          break;
        case "highlightYellow":
        case "highlightGreen":
        case "highlightPink":
          styled = _buildHighlightStyle(layer, textPainter, effectiveStyle);
          break;
        case "stampRed":
        case "stampBlue":
          styled = _buildStampStyle(layer, textPainter, effectiveStyle);
          break;
        case "quote":
          styled = _buildQuoteStyle(layer, textPainter, effectiveStyle);
          break;
        case "chalkboard":
          styled = _buildChalkboardStyle(layer, textPainter, effectiveStyle);
          break;
        case "caption":
          styled = _buildCaptionStyle(layer, textPainter, effectiveStyle);
          break;
        case "noteGrid":
        case "noteGridBlue":
        case "noteGridPink":
        case "noteGridMint":
        case "noteGridLavender":
        case "noteGridOrange":
        case "noteGridGray":
          styled = _buildNoteGridStyle(layer, textPainter, effectiveStyle);
          break;
        case "noteGold":
        case "noteCream":
          styled = _buildNoteStyle(layer, textPainter, effectiveStyle);
          break;
        default:
          styled = Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              layer.text ?? "",
              style: effectiveStyle,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          );
          break;
      }

      // ✅ style 텍스트도 하단 여유 보정
      final Size styleSize = _calculateStyleSize(layer.textBackground!, layer, textPainter);
      final isNoteGrid = layer.textBackground == 'noteGrid';
      final realSize = Size(
        styleSize.width,
        styleSize.height + (isNoteGrid ? 0 : 12),
      );
      interaction.setBaseSize(layer.id, realSize);

      return interaction.buildInteractiveLayer(
        layer: layer,
        baseWidth: realSize.width,
        baseHeight: realSize.height,
        isCover: isCover,
        child: Opacity(
          opacity: layer.opacity,
          child: styled,
        ),
      );
    }

    // 배경 모드 처리
    Widget content;

    content = Padding(
      // ✅ descender(y, g 등) 안전 여유 확보
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Text(
        layer.text ?? "",
        style: effectiveStyle,
        textAlign: layer.textAlign ?? TextAlign.center,
      ),
    );

    // ✅ 아래 잘림 방지를 위해 baseHeight를 실측보다 크게 확보
    final realSize = Size(
      textPainter.size.width + 55,
      textPainter.size.height + 55,
    );
    interaction.setBaseSize(layer.id, realSize);

    return interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: realSize.width,
      baseHeight: realSize.height,
      isCover: isCover,
      child: Opacity(
        opacity: layer.opacity,
        child: content,
      ),
    );
  }

  bool _isEditing(LayerModel layer) {
    return interaction.selectedLayerId == layer.id
        ? false
        : false; // 현재 편집 중 레이어 숨김은 interaction에서 editing id로 제어 가능
  }

  // ImageInfo 프리패치가 필요해지면 여기에 precacheImage 등을 추가한다.

  /// 라운드 계열 배경색 (팔레트 통일, 연한+진한 10색)
  static Color _roundStyleBackgroundColor(String? key) {
    switch (key) {
      case 'roundGray': return SnapFitStylePalette.gray;
      case 'roundPink': return SnapFitStylePalette.pink;
      case 'roundBlue': return SnapFitStylePalette.blue;
      case 'roundMint': return SnapFitStylePalette.mint;
      case 'roundLavender': return SnapFitStylePalette.lavender;
      case 'roundOrange': return SnapFitStylePalette.orange;
      case 'roundGreen': return SnapFitStylePalette.green;
      case 'roundCream': return SnapFitStylePalette.cream;
      case 'roundNavy': return SnapFitStylePalette.navy;
      case 'roundRose': return SnapFitStylePalette.rose;
      case 'roundCoral': return SnapFitStylePalette.coral;
      case 'roundBeige': return SnapFitStylePalette.beige;
      case 'roundTeal': return SnapFitStylePalette.teal;
      case 'roundLemon': return SnapFitStylePalette.lemon;
      default: return SnapFitStylePalette.white;
    }
  }

  /// 라운드 – pill (색상 선택 가능)
  Widget _buildRoundStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final bg = _roundStyleBackgroundColor(layer.textBackground);
    final borderColor = bg == Colors.white ? const Color(0xFFE8EAED) : _darken(bg, 0.08);
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: effectiveStyle,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  static Color _darken(Color c, double amount) {
    return Color.fromARGB(
      c.alpha,
      (c.red * (1 - amount)).round().clamp(0, 255),
      (c.green * (1 - amount)).round().clamp(0, 255),
      (c.blue * (1 - amount)).round().clamp(0, 255),
    );
  }

  /// 사각형 계열 배경색 (팔레트 통일, 10색)
  static Color _squareStyleBackgroundColor(String? key) {
    switch (key) {
      case 'squareGray': return SnapFitStylePalette.gray;
      case 'squarePink': return SnapFitStylePalette.pink;
      case 'squareBlue': return SnapFitStylePalette.blue;
      case 'squareMint': return SnapFitStylePalette.mint;
      case 'squareLavender': return SnapFitStylePalette.lavender;
      case 'squareOrange': return SnapFitStylePalette.orange;
      case 'squareGreen': return SnapFitStylePalette.green;
      case 'squareCream': return SnapFitStylePalette.cream;
      case 'squareNavy': return SnapFitStylePalette.navy;
      case 'squareRose': return SnapFitStylePalette.rose;
      case 'squareCoral': return SnapFitStylePalette.coral;
      case 'squareBeige': return SnapFitStylePalette.beige;
      case 'squareTeal': return SnapFitStylePalette.teal;
      case 'squareLemon': return SnapFitStylePalette.lemon;
      default: return SnapFitStylePalette.white;
    }
  }

  /// 기본 – 사각형 (색상 선택 가능)
  Widget _buildSquareStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final bg = _squareStyleBackgroundColor(layer.textBackground);
    final borderColor = bg == Colors.white ? const Color(0xFFE0E4EC) : _darken(bg, 0.08);
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: effectiveStyle,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  /// 소프트 필 계열 배경색 (팔레트 통일, 10색)
  static Color _roundSoftStyleBackgroundColor(String? key) {
    switch (key) {
      case 'roundSoftGray': return SnapFitStylePalette.gray;
      case 'roundSoftPink': return SnapFitStylePalette.pink;
      case 'roundSoftBlue': return SnapFitStylePalette.blue;
      case 'roundSoftMint': return SnapFitStylePalette.mint;
      case 'roundSoftLavender': return SnapFitStylePalette.lavender;
      case 'roundSoftOrange': return SnapFitStylePalette.orange;
      case 'roundSoftGreen': return SnapFitStylePalette.green;
      case 'roundSoftCream': return SnapFitStylePalette.cream;
      case 'roundSoftNavy': return SnapFitStylePalette.navy;
      case 'roundSoftRose': return SnapFitStylePalette.rose;
      case 'roundSoftCoral': return SnapFitStylePalette.coral;
      case 'roundSoftBeige': return SnapFitStylePalette.beige;
      case 'roundSoftTeal': return SnapFitStylePalette.teal;
      case 'roundSoftLemon': return SnapFitStylePalette.lemon;
      default: return SnapFitStylePalette.white;
    }
  }

  /// 기본 – 소프트 필 (색상 선택 가능, 그림자 적용)
  Widget _buildRoundSoftStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final bg = _roundSoftStyleBackgroundColor(layer.textBackground);
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 8,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: effectiveStyle,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  /// 소프트 필2 계열 배경색 (사각형 + 둥근 모서리, 15색)
  static Color _softPill2StyleBackgroundColor(String? key) {
    switch (key) {
      case 'softPill2Gray': return SnapFitStylePalette.gray;
      case 'softPill2Pink': return SnapFitStylePalette.pink;
      case 'softPill2Blue': return SnapFitStylePalette.blue;
      case 'softPill2Mint': return SnapFitStylePalette.mint;
      case 'softPill2Lavender': return SnapFitStylePalette.lavender;
      case 'softPill2Orange': return SnapFitStylePalette.orange;
      case 'softPill2Green': return SnapFitStylePalette.green;
      case 'softPill2Cream': return SnapFitStylePalette.cream;
      case 'softPill2Navy': return SnapFitStylePalette.navy;
      case 'softPill2Rose': return SnapFitStylePalette.rose;
      case 'softPill2Coral': return SnapFitStylePalette.coral;
      case 'softPill2Beige': return SnapFitStylePalette.beige;
      case 'softPill2Teal': return SnapFitStylePalette.teal;
      case 'softPill2Lemon': return SnapFitStylePalette.lemon;
      default: return SnapFitStylePalette.white;
    }
  }

  /// 기본 – 소프트 필2 (사각형, 라운드 없음, 그림자)
  Widget _buildSoftPill2Style(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final bg = _softPill2StyleBackgroundColor(layer.textBackground);
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 8,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: effectiveStyle,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  static ({Color bg, Color text}) _labelOvalColors(String? key) {
    switch (key) {
      case 'labelGray': return (bg: SnapFitStylePalette.labelGray, text: const Color(0xFF616161));
      case 'labelPink': return (bg: SnapFitStylePalette.labelPink, text: const Color(0xFFAD1457));
      case 'labelBlue': return (bg: SnapFitStylePalette.labelBlue, text: const Color(0xFF1565C0));
      case 'labelMint': return (bg: SnapFitStylePalette.labelMint, text: const Color(0xFF00695C));
      case 'labelLavender': return (bg: SnapFitStylePalette.labelLavender, text: const Color(0xFF5E35B1));
      case 'labelOrange': return (bg: SnapFitStylePalette.labelOrange, text: const Color(0xFFE65100));
      case 'labelGreen': return (bg: SnapFitStylePalette.labelGreen, text: const Color(0xFF2E7D32));
      case 'labelWhite': return (bg: SnapFitStylePalette.labelWhite, text: const Color(0xFF424242));
      case 'labelCream': return (bg: SnapFitStylePalette.labelCream, text: const Color(0xFF5D4037));
      default:
        return (bg: SnapFitColors.accent.withOpacity(0.25), text: SnapFitColors.accent);
    }
  }

  /// 라벨 – 타원형 (색상 선택 가능)
  Widget _buildLabelOvalStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final colors = _labelOvalColors(layer.textBackground);
    final style = effectiveStyle.copyWith(fontWeight: FontWeight.w600, color: colors.text);
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(layer.text ?? "", style: style, textAlign: layer.textAlign ?? TextAlign.center),
          ),
        ),
      ),
    );
  }

  static Color _tagBorderColor(String? key) {
    switch (key) {
      case 'tagGray': return SnapFitStylePalette.tagGray;
      case 'tagPink': return SnapFitStylePalette.tagPink;
      case 'tagBlue': return SnapFitStylePalette.tagBlue;
      case 'tagMint': return SnapFitStylePalette.tagMint;
      case 'tagLavender': return SnapFitStylePalette.tagLavender;
      case 'tagOrange': return SnapFitStylePalette.tagOrange;
      case 'tagGreen': return SnapFitStylePalette.tagGreen;
      case 'tagRed': return const Color(0xFFE57373);
      default: return const Color(0xFFB0B0B0);
    }
  }

  /// 태그 – 점선 테두리 (색상 선택 가능)
  Widget _buildTagStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final borderColor = _tagBorderColor(layer.textBackground);
    final style = effectiveStyle.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: borderColor,
    );
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Center(
                child: Text(layer.text ?? "", style: style, textAlign: layer.textAlign ?? TextAlign.center),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: borderColor,
                  strokeWidth: 1.5,
                  borderRadius: 8,
                  dashWidth: 4,
                  dashSpace: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static ({Color bg, Color text}) _labelSolidColors(String? key) {
    switch (key) {
      case 'labelSolidGray': return (bg: const Color(0xFF616161), text: Colors.white);
      case 'labelSolidPink': return (bg: const Color(0xFFAD1457), text: Colors.white);
      case 'labelSolidBlue': return (bg: const Color(0xFF1565C0), text: Colors.white);
      case 'labelSolidMint': return (bg: const Color(0xFF00695C), text: Colors.white);
      case 'labelSolidRed': return (bg: const Color(0xFFC62828), text: Colors.white);
      case 'labelSolidGreen': return (bg: const Color(0xFF2E7D32), text: Colors.white);
      case 'labelSolidOrange': return (bg: const Color(0xFFE65100), text: Colors.white);
      case 'labelSolidLavender': return (bg: const Color(0xFF5E35B1), text: Colors.white);
      case 'labelSolidCream': return (bg: const Color(0xFFF5F0E6), text: const Color(0xFF5D4037));
      default: return (bg: const Color(0xFF1E3A5F), text: Colors.white);
    }
  }

  /// 라벨 – 진한 채움 (색상 선택 가능)
  Widget _buildLabelSolidStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final colors = _labelSolidColors(layer.textBackground);
    final style = effectiveStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: colors.text,
      letterSpacing: 0.5,
    );
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(layer.text ?? "", style: style, textAlign: layer.textAlign ?? TextAlign.center),
          ),
        ),
      ),
    );
  }

  /// 라벨 – 아웃라인만 (TODAY 스타일)
  Widget _buildLabelOutlineStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF607D8B),
    );
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF00C2E0), width: 1.5),
          ),
          child: Center(
            child: Text(layer.text ?? "", style: style, textAlign: layer.textAlign ?? TextAlign.center),
          ),
        ),
      ),
    );
  }

  /// 라벨 – 골드 프리미엄
  Widget _buildLabelGoldStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF5D4037),
      letterSpacing: 0.5,
    );
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF5E6C8),
                const Color(0xFFE8D4A8),
                const Color(0xFFD4B896),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB8860B).withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(layer.text ?? "", style: style, textAlign: layer.textAlign ?? TextAlign.center),
          ),
        ),
      ),
    );
  }

  /// 라벨 – 네온 아웃라인
  Widget _buildLabelNeonStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF00E5FF),
    );
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF00E5FF), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(layer.text ?? "", style: style, textAlign: layer.textAlign ?? TextAlign.center),
          ),
        ),
      ),
    );
  }

  /// 라벨 – 로즈 (로즈골드/핑크 채움)
  Widget _buildLabelRoseStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF880E4F),
      letterSpacing: 0.3,
    );
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF8BBD9),
                const Color(0xFFF48FB1),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFAD1457).withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(layer.text ?? "", style: style, textAlign: layer.textAlign ?? TextAlign.center),
          ),
        ),
      ),
    );
  }

  /// 말풍선 채움 색상 (팔레트 통일, 10색)
  static Color _bubbleFillColor(String? key) {
    if (key == null) return SnapFitStylePalette.white;
    if (key.endsWith('Gray')) return SnapFitStylePalette.gray;
    if (key.endsWith('Pink')) return SnapFitStylePalette.pink;
    if (key.endsWith('Blue')) return SnapFitStylePalette.blue;
    if (key.endsWith('Mint')) return SnapFitStylePalette.mint;
    if (key.endsWith('Lavender')) return SnapFitStylePalette.lavender;
    if (key.endsWith('Orange')) return SnapFitStylePalette.orange;
    if (key.endsWith('Green')) return SnapFitStylePalette.green;
    if (key.endsWith('Cream')) return SnapFitStylePalette.cream;
    if (key.endsWith('Navy')) return SnapFitStylePalette.navy;
    if (key.endsWith('Rose')) return SnapFitStylePalette.rose;
    if (key.endsWith('Coral')) return SnapFitStylePalette.coral;
    if (key.endsWith('Beige')) return SnapFitStylePalette.beige;
    if (key.endsWith('Teal')) return SnapFitStylePalette.teal;
    if (key.endsWith('Lemon')) return SnapFitStylePalette.lemon;
    return SnapFitStylePalette.white;
  }

  Widget _buildBubbleStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    final bg = layer.textBackground ?? '';
    final baseKey = bg
        .replaceAll('Gray', '')
        .replaceAll('Pink', '')
        .replaceAll('Blue', '')
        .replaceAll('Mint', '')
        .replaceAll('Lavender', '')
        .replaceAll('Orange', '')
        .replaceAll('Green', '')
        .replaceAll('Cream', '')
        .replaceAll('Navy', '')
        .replaceAll('Rose', '')
        .replaceAll('Coral', '')
        .replaceAll('Beige', '')
        .replaceAll('Teal', '')
        .replaceAll('Lemon', '');
    final isSquare = baseKey == 'bubbleSquare' || baseKey == 'bubbleSquareCenter' || baseKey == 'bubbleSquareRight';
    final tailPosition = isSquare
        ? (baseKey == 'bubbleSquare' ? 0.0 : baseKey == 'bubbleSquareRight' ? 1.0 : 0.5)
        : (baseKey == 'bubbleCenter' ? 0.5 : baseKey == 'bubbleRight' ? 0.72 : 0.28);
    final fillColor = _bubbleFillColor(bg);
    final borderColor = fillColor == Colors.white
        ? Colors.black.withOpacity(0.22)
        : Color.lerp(fillColor, Colors.black, 0.12) ?? Colors.black26;

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: CustomPaint(
          painter: _BubbleBackgroundPainter(
            fillColor: fillColor,
            borderColor: borderColor,
            tailPosition: tailPosition,
            shapeSquare: isSquare,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
            child: Center(
              child: Text(
                layer.text ?? "",
                style: style,
                textAlign: layer.textAlign ?? TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _noteStyleBackgroundColor(String? key) {
    final k = (key ?? '').replaceFirst('noteTornRough', 'noteTorn').replaceFirst('noteTornSoft', 'noteTorn');
    switch (k) {
      case "noteBlue": return const Color(0xFFE8F0FF);
      case "notePink": return const Color(0xFFFFEFF4);
      case "noteMint": return const Color(0xFFE0F7F0);
      case "noteLavender": return const Color(0xFFF3E8FF);
      case "noteOrange": return const Color(0xFFFFF0E0);
      case "noteGray": return const Color(0xFFF0F0F0);
      case "noteBeige": return const Color(0xFFF5F0E8);
      case "noteGold": return const Color(0xFFFFF8E1);
      case "noteCream": return const Color(0xFFFFFBF0);
      case "noteTornGray": return const Color(0xFFF0F0F0);
      case "noteTornPink": return const Color(0xFFFFEFF4);
      case "noteTornBlue": return const Color(0xFFE8F0FF);
      case "noteTornMint": return const Color(0xFFE0F7F0);
      case "noteTornLavender": return const Color(0xFFF3E8FF);
      case "noteTornOrange": return const Color(0xFFFFF0E0);
      case "noteTornCream": return const Color(0xFFFFFBF0);
      case "noteTornBeige": return const Color(0xFFF5F0E8);
      case "noteTornYellow": return const Color(0xFFFFF9C4);
      case "noteTornGold": return const Color(0xFFFFF8E1);
      case "note":
      case "noteTorn":
      default: return const Color(0xFFFFF9C4);
    }
  }

  static String? _normalizeTornTapeKey(String? key) {
    if (key == null) return null;
    return key.replaceFirst('tapeTornRough', 'tapeTorn').replaceFirst('tapeTornSoft', 'tapeTorn');
  }

  /// 메모지 – 찢어짐 없음, 스티커노트 느낌, 여러 색상 (테두리 없음)
  Widget _buildNoteStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(height: 1.25);
    final background = _noteStyleBackgroundColor(layer.textBackground);
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: style,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  /// 찢어진 메모지 – 아래쪽만 톱니 찢김 (종이 뜯은 느낌, 키에 따라 일반/거친/부드러운)
  Widget _buildNoteTornStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(height: 1.25);
    final background = _noteStyleBackgroundColor(layer.textBackground);
    final (step, amp) = _tornEdgeParams(layer.textBackground ?? 'noteTorn');
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: ClipPath(
          clipper: _TornNoteEdgeClipper(step: step, amp: amp),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                layer.text ?? "",
                style: style,
                textAlign: layer.textAlign ?? TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 찢어진 테이프 – 단색만, 오른쪽만 톱니 찢김 (메모지와 다른 느낌, 키에 따라 일반/거친/부드러운)
  Widget _buildTapeTornStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(fontWeight: FontWeight.w500);
    final bg = layer.textBackground ?? 'tapeTornSolid';
    final solidKey = _tapeTornToSolidKey(bg);
    final colors = _tapeSolidColors(solidKey);
    final (step, amp) = _tornEdgeParams(bg);
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: ClipPath(
          clipper: _TapeTornEdgeClipper(step: step, amp: amp),
          child: Container(
            decoration: BoxDecoration(
              color: colors.bg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Center(
              child: Text(
                layer.text ?? "",
                style: style.copyWith(color: colors.text),
                textAlign: layer.textAlign ?? TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 찢어진 단색 테이프 – 동일 빌더(단색 + 오른쪽 톱니)
  Widget _buildTapeTornSolidStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    return _buildTapeTornStyle(layer, painter, effectiveStyle);
  }


  Widget _buildCalligraphyStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
      height: 1.25,
    );

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.amber.shade700, width: 1),
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: style,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: style,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  /// 포인트 – 형광 하이라이트 (강조 포인트)
  Widget _buildHighlightStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    Color bg;
    Color textColor;
    switch (layer.textBackground) {
      case "highlightGreen":
        bg = const Color(0xFF9CCC65).withOpacity(0.7);
        textColor = const Color(0xFF1B5E20);
        break;
      case "highlightPink":
        bg = const Color(0xFFF48FB1).withOpacity(0.75);
        textColor = const Color(0xFF880E4F);
        break;
      case "highlightYellow":
      default:
        bg = const Color(0xFFFFF59D).withOpacity(0.75);
        textColor = const Color(0xFFF57F17);
        break;
    }
    final style = effectiveStyle.copyWith(color: textColor, fontWeight: FontWeight.w700);
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: textColor.withOpacity(0.2),
                blurRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: style,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  /// 데코 – 스탬프 인상 (테두리 + 그림자로 찍힌 느낌)
  Widget _buildStampStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final isRed = layer.textBackground == 'stampRed';
    final bg = isRed ? const Color(0xFFB71C1C) : const Color(0xFF0D47A1);
    final style = effectiveStyle.copyWith(
      color: const Color(0xFFFFF8E7),
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    );
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isRed ? const Color(0xFFE53935) : const Color(0xFF1976D2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 1,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: style,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  /// 데코 – 인용 프레임 (두꺼운 왼쪽 바 + 이중선 느낌)
  Widget _buildQuoteStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(height: 1.35);
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: SnapFitColors.accent, width: 5),
            ),
            boxShadow: [
              BoxShadow(
                color: SnapFitColors.accent.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: style,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  /// 데코 – 칠판 포인트 (테두리 있는 칠판 틀)
  Widget _buildChalkboardStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(
      color: const Color(0xFFECEFF1),
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF263238),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF546E7A), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: style,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  /// 데코 – 점선 프레임 캡션 (장식 테두리)
  Widget _buildCaptionStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(
      color: const Color(0xFF546E7A),
      height: 1.3,
    );
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  layer.text ?? "",
                  style: style,
                  textAlign: layer.textAlign ?? TextAlign.center,
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: const Color(0xFFB0BEC5),
                    strokeWidth: 1.5,
                    borderRadius: 10,
                    dashWidth: 5,
                    dashSpace: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ({Color bg, Color grid}) _noteGridColors(String? key) {
    switch (key) {
      case 'noteGridBlue':
        return (bg: SnapFitStylePalette.blue, grid: const Color(0xFFBBDEFB));
      case 'noteGridPink':
        return (bg: SnapFitStylePalette.pink, grid: const Color(0xFFFFCDD2));
      case 'noteGridMint':
        return (bg: SnapFitStylePalette.mint, grid: const Color(0xFF80CBC4));
      case 'noteGridLavender':
        return (bg: SnapFitStylePalette.lavender, grid: const Color(0xFFB39DDB));
      case 'noteGridOrange':
        return (bg: SnapFitStylePalette.orange, grid: const Color(0xFFFFCC80));
      case 'noteGridGray':
        return (bg: SnapFitStylePalette.gray, grid: const Color(0xFFBDBDBD));
      default:
        return (bg: const Color(0xFFFFFDE7), grid: const Color(0xFFE8E0B0));
    }
  }

  /// 격자 노트 (색상 선택 가능) – 격자만 전체에 그림, 텍스트는 패딩으로 정렬
  Widget _buildNoteGridStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(height: 1.25);
    final colors = _noteGridColors(layer.textBackground);
    const gridStep = 12.0;
    const padH = 12.0;
    const padV = 12.0;
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.zero,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridLinePainter(color: colors.grid, step: gridStep),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                child: Center(
                  child: Text(
                    layer.text ?? "",
                    style: style,
                    textAlign: layer.textAlign ?? TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 도트 테이프용 base/dot 색상 (팔레트 통일, 6색)
  static ({Color base, Color dot}) _tapeDotsColors(String? key) {
    switch (key) {
      case 'tapeDotsPink':
        return (base: SnapFitStylePalette.labelPink, dot: SnapFitStylePalette.tagPink);
      case 'tapeDotsMint':
        return (base: SnapFitStylePalette.mint, dot: SnapFitStylePalette.tagMint);
      case 'tapeDotsLavender':
        return (base: SnapFitStylePalette.lavender, dot: SnapFitStylePalette.tagLavender);
      case 'tapeDotsOrange':
        return (base: SnapFitStylePalette.orange, dot: SnapFitStylePalette.tagOrange);
      case 'tapeDotsGray':
        return (base: SnapFitStylePalette.stripeGrayBase, dot: SnapFitStylePalette.stripeGrayStripe);
      default:
        return (base: const Color(0xFFFFE0B2), dot: const Color(0xFFFFCC80));
    }
  }

  /// 이중 스트라이프 테이프용 base/stripe 색상 (6색 통일)
  static ({Color base, Color stripe}) _tapeDoubleColors(String? key) {
    switch (key) {
      case 'tapeDoublePink':
        return (base: SnapFitStylePalette.pink, stripe: const Color(0xFFFFCDD2));
      case 'tapeDoubleMint':
        return (base: SnapFitStylePalette.mint, stripe: const Color(0xFFA7FFEB));
      case 'tapeDoubleBlue':
        return (base: const Color(0xFFE3F2FD), stripe: const Color(0xFF90CAF9));
      case 'tapeDoubleLavender':
        return (base: SnapFitStylePalette.lavender, stripe: const Color(0xFFB39DDB));
      case 'tapeDoubleGray':
        return (base: SnapFitStylePalette.stripeGrayBase, stripe: SnapFitStylePalette.stripeGrayStripe);
      default:
        return (base: const Color(0xFFE3F2FD), stripe: const Color(0xFF90CAF9));
    }
  }

  /// 단색 테이프 (크래프트·골드 통일 + 기본 색상)
  static ({Color bg, Color text}) _tapeSolidColors(String? key) {
    switch (key) {
      case 'tapeKraft': return (bg: const Color(0xFFD7CCC8), text: const Color(0xFF5D4037));
      case 'tapeGold': return (bg: const Color(0xFFE8D4A8), text: const Color(0xFF5D4037));
      case 'tapeSolidWhite': return (bg: const Color(0xFFFAFAFA), text: const Color(0xFF424242));
      case 'tapeSolidGray': return (bg: const Color(0xFFE0E0E0), text: const Color(0xFF424242));
      case 'tapeSolidPink': return (bg: const Color(0xFFFFCDD2), text: const Color(0xFFAD1457));
      case 'tapeSolidBlue': return (bg: const Color(0xFFBBDEFB), text: const Color(0xFF1565C0));
      case 'tapeSolidMint': return (bg: const Color(0xFFB2DFDB), text: const Color(0xFF00695C));
      case 'tapeSolidLavender': return (bg: const Color(0xFFD1C4E9), text: const Color(0xFF5E35B1));
      case 'tapeSolidOrange': return (bg: const Color(0xFFFFE0B2), text: const Color(0xFFE65100));
      case 'tapeSolidGreen': return (bg: const Color(0xFFC8E6C9), text: const Color(0xFF2E7D32));
      default: return (bg: const Color(0xFFD7CCC8), text: const Color(0xFF5D4037));
    }
  }

  /// 스트라이프 테이프용 base/stripe 색상 (팔레트 통일)
  static ({Color base, Color stripe}) _stripeTapeColors(String key) {
    switch (key) {
      case 'tape':
        return (base: SnapFitStylePalette.stripeSkyBase, stripe: SnapFitStylePalette.stripeSkyStripe);
      case 'tapeYellow':
        return (base: SnapFitStylePalette.stripeYellowBase, stripe: SnapFitStylePalette.stripeYellowStripe);
      case 'tapePink':
        return (base: SnapFitStylePalette.stripePinkBase, stripe: SnapFitStylePalette.stripePinkStripe);
      case 'tapeMint':
        return (base: SnapFitStylePalette.stripeMintBase, stripe: SnapFitStylePalette.stripeMintStripe);
      case 'tapeLavender':
        return (base: SnapFitStylePalette.stripeLavenderBase, stripe: SnapFitStylePalette.stripeLavenderStripe);
      case 'tapeGray':
        return (base: SnapFitStylePalette.stripeGrayBase, stripe: SnapFitStylePalette.stripeGrayStripe);
      default:
        return (base: SnapFitStylePalette.stripeSkyBase, stripe: SnapFitStylePalette.stripeSkyStripe);
    }
  }

  Widget _buildTapeStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(fontWeight: FontWeight.w500);
    final bg = layer.textBackground ?? 'tape';

    // 스트라이프 디자인 통일: tape, tapeYellow, tapePink, tapeMint, tapeLavender, tapeGray
    const stripeKeys = ['tape', 'tapeYellow', 'tapePink', 'tapeMint', 'tapeLavender', 'tapeGray'];
    if (stripeKeys.contains(bg)) {
      final colors = _stripeTapeColors(bg);
      return IntrinsicWidth(
        child: IntrinsicHeight(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: _TapeStripePainter(
                baseColor: colors.base,
                stripeColor: colors.stripe,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                child: Center(
                  child: Text(
                    layer.text ?? "",
                    style: style,
                    textAlign: layer.textAlign ?? TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    const dotsKeys = ['tapeDots', 'tapeDotsPink', 'tapeDotsMint', 'tapeDotsLavender', 'tapeDotsOrange', 'tapeDotsGray'];
    if (dotsKeys.contains(bg)) {
      final colors = _tapeDotsColors(bg);
      const dotSpacing = 8.0;
      const padH = 16.0;
      const padV = 8.0;
      return IntrinsicWidth(
        child: IntrinsicHeight(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: _TapeDotsPainter(
                baseColor: colors.base,
                dotColor: colors.dot,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                child: Center(
                  child: Text(
                    layer.text ?? "",
                    style: style,
                    textAlign: layer.textAlign ?? TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    const solidTapeKeys = [
      'tapeKraft', 'tapeGold', 'tapeSolidWhite', 'tapeSolidGray', 'tapeSolidPink',
      'tapeSolidBlue', 'tapeSolidMint', 'tapeSolidLavender', 'tapeSolidOrange', 'tapeSolidGreen',
    ];
    if (solidTapeKeys.contains(bg)) {
      final colors = _tapeSolidColors(bg);
      return IntrinsicWidth(
        child: IntrinsicHeight(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                layer.text ?? "",
                style: style.copyWith(color: colors.text),
                textAlign: layer.textAlign ?? TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    const doubleKeys = ['tapeDouble', 'tapeDoublePink', 'tapeDoubleMint', 'tapeDoubleBlue', 'tapeDoubleLavender', 'tapeDoubleGray'];
    if (doubleKeys.contains(bg)) {
      final colors = _tapeDoubleColors(bg);
      return IntrinsicWidth(
        child: IntrinsicHeight(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: _TapeDoubleStripePainter(
                baseColor: colors.base,
                stripeColor: colors.stripe,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                child: Center(
                  child: Text(
                    layer.text ?? "",
                    style: style,
                    textAlign: layer.textAlign ?? TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFFB6E8FF), const Color(0xFFE3F7FF)],
            ),
          ),
          child: Center(
            child: Text(
              layer.text ?? "",
              style: style,
              textAlign: layer.textAlign ?? TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// 점선 테두리 (태그 적용 시 미리보기와 동일)
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
    this.dashWidth = 4,
    this.dashSpace = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final segment = metric.extractPath(
          distance,
          distance + dashWidth,
        );
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 티켓 스텁 – 왼쪽 톱니(원형 터치선) 연출
class _TicketNotchPainter extends CustomPainter {
  final Color color;

  _TicketNotchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const cx = 6.0;
    const r = 2.5;
    final step = size.height / 5;
    for (var i = 1; i <= 4; i++) {
      final y = step * i;
      canvas.drawCircle(Offset(cx, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 리본 – 양끝 비스듬히 잘린 배너 클리퍼
class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const cut = 14.0;
    final path = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 격자 노트 – 가로·세로 그리드 라인 (step 지정 가능)
class _GridLinePainter extends CustomPainter {
  final Color color;
  final double step;

  _GridLinePainter({required this.color, this.step = 12.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 찢어진 메모지 전용 – 아래쪽만 톱니 찢김 (종이 뜯은 느낌)
class _TornNoteEdgeClipper extends CustomClipper<Path> {
  final double step;
  final double amp;

  _TornNoteEdgeClipper({this.step = 8.0, this.amp = 2.5});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    for (var x = size.width - step; x > 0; x -= step) {
      path.lineTo(x + step / 2, size.height - amp);
      path.lineTo(x, size.height);
    }
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) =>
      oldDelegate is _TornNoteEdgeClipper && (oldDelegate.step != step || oldDelegate.amp != amp);
}

/// 찢어진 테이프 전용 – 오른쪽만 톱니 찢김 (메모지 아래 톱니와 다른 느낌)
class _TapeTornEdgeClipper extends CustomClipper<Path> {
  final double step;
  final double amp;

  _TapeTornEdgeClipper({this.step = 8.0, this.amp = 2.5});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    for (var y = step; y < size.height; y += step) {
      path.lineTo(size.width - amp, y - step / 2);
      path.lineTo(size.width, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) =>
      oldDelegate is _TapeTornEdgeClipper && (oldDelegate.step != step || oldDelegate.amp != amp);
}

/// 도트 테이프 – 작은 원 패턴
class _TapeDotsPainter extends CustomPainter {
  final Color baseColor;
  final Color dotColor;

  _TapeDotsPainter({required this.baseColor, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = baseColor);
    final paint = Paint()..color = dotColor;
    const spacing = 8.0;
    const r = 2.0;
    // 여백 일정: 네 면 모두 spacing 이상 비워 두고 그 안쪽에만 도트 그리기 (끝 잘림 방지)
    for (var x = spacing; x <= size.width - spacing; x += spacing) {
      for (var y = spacing; y <= size.height - spacing; y += spacing) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 이중 스트라이프 테이프 (넓은 대각 줄무늬)
class _TapeDoubleStripePainter extends CustomPainter {
  final Color baseColor;
  final Color stripeColor;

  _TapeDoubleStripePainter({required this.baseColor, required this.stripeColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = baseColor);
    const stripeWidth = 12.0;
    var x = -size.height * 2;
    var index = 0;
    while (x < size.width + size.height * 2) {
      final paint = Paint()
        ..color = index.isEven ? stripeColor : baseColor
        ..style = PaintingStyle.fill;
      final path = Path();
      path.moveTo(x, 0);
      path.lineTo(x + stripeWidth, 0);
      path.lineTo(x + stripeWidth + size.height, size.height);
      path.lineTo(x + size.height, size.height);
      path.close();
      canvas.drawPath(path, paint);
      x += stripeWidth;
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 마스킹 테이프 적용 시 대각 스트라이프 (라벨/노트와 구분)
class _TapeStripePainter extends CustomPainter {
  final Color baseColor;
  final Color stripeColor;

  _TapeStripePainter({required this.baseColor, required this.stripeColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = baseColor);
    const stripeWidth = 6.0;
    var x = -size.height * 2;
    var index = 0;
    while (x < size.width + size.height * 2) {
      final paint = Paint()
        ..color = index.isEven ? stripeColor : baseColor
        ..style = PaintingStyle.fill;
      final path = Path();
      path.moveTo(x, 0);
      path.lineTo(x + stripeWidth, 0);
      path.lineTo(x + stripeWidth + size.height, size.height);
      path.lineTo(x + size.height, size.height);
      path.close();
      canvas.drawPath(path, paint);
      x += stripeWidth;
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 말풍선 스타일: 라운드(꼬리 0.2/0.5/0.8) / 사각형(꼬리 0/0.5/1)
class _BubbleBackgroundPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double tailPosition; // 라운드: 0.2 왼 0.5 가운데 0.8 오른 / 사각: 0 왼 0.5 가운데 1 오른
  final bool shapeSquare;

  _BubbleBackgroundPainter({
    required this.fillColor,
    required this.borderColor,
    this.tailPosition = 0.2,
    this.shapeSquare = false,
  });

  static const double _tailWidth = 18.0;
  static const double _tailHeight = 10.0;
  static const double _radius = 16.0;
  /// 꼬리가 가장자리에 붙지 않도록 여백 (자연스러운 느낌)
  static const double _tailMargin = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    // 꼬리가 잘리지 않도록 본체 높이 = 전체 - 꼬리 높이 (그리기는 size 안에 완전히 포함)
    final h = size.height - _tailHeight;

    if (shapeSquare) {
      final tailCenterX = tailPosition <= 0.25
          ? _tailMargin + _tailWidth / 2
          : tailPosition >= 0.75
              ? w - _tailMargin - _tailWidth / 2
              : w / 2;
      final tailLeft = tailCenterX - _tailWidth / 2;
      final tailRight = tailCenterX + _tailWidth / 2;
      _drawSquareBubblePath(path, w, h, tailLeft, tailRight, tailCenterX);
    } else {
      final r = _radius;
      final minX = r + _tailMargin + _tailWidth / 2;
      final maxX = w - r - _tailMargin - _tailWidth / 2;
      // 라운드: 왼쪽(0.28) / 가운데(0.5) / 오른쪽(0.72) — 비율이 아닌 구간으로 명시 적용
      final bool isLeft = tailPosition < 0.4;
      final bool isRight = tailPosition > 0.6;
      final tailCenterX = minX <= maxX
          ? (isLeft ? minX : isRight ? maxX : w / 2)
          : (isLeft ? (r + _tailWidth / 2) : isRight ? (w - r - _tailWidth / 2) : w / 2);
      final tailLeft = tailCenterX - _tailWidth / 2;
      final tailRight = tailCenterX + _tailWidth / 2;
      _drawRoundBubblePath(path, w, h, tailLeft, tailRight, tailCenterX);
    }

    final fill = Paint()..color = fillColor..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  /// 라운드 말풍선: 둥근 사각형 본체 + 하단 평평한 구간에 꼬리 연결 (한 경로, 여백 없음)
  void _drawRoundBubblePath(Path path, double w, double h, double tailLeft, double tailRight, double tailCenterX) {
    final r = _radius;
    path.moveTo(tailLeft, h);
    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));
    path.lineTo(tailRight, h);
    path.lineTo(tailCenterX, h + _tailHeight);
    path.lineTo(tailLeft, h);
    path.close();
  }

  /// 사각형 말풍선: 직사각형 본체 + 꼬리 왼/가운데/오른쪽 (한 경로, 여백 없음)
  void _drawSquareBubblePath(Path path, double w, double h, double tailLeft, double tailRight, double tailCenterX) {
    path.moveTo(tailLeft, h);
    path.lineTo(0, h);
    path.lineTo(0, 0);
    path.lineTo(w, 0);
    path.lineTo(w, h);
    path.lineTo(tailRight, h);
    path.lineTo(tailCenterX, h + _tailHeight);
    path.lineTo(tailLeft, h);
    path.close();
  }

  @override
  bool shouldRepaint(covariant _BubbleBackgroundPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.tailPosition != tailPosition ||
        oldDelegate.shapeSquare != shapeSquare;
  }
}

// 노트 스타일: 아래 찢어진 종이 효과
class _TornPaperClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - 4);

    // 아랫부분 찢어진 효과
    const step = 8.0;
    double x = size.width;
    bool up = true;
    while (x > 0) {
      x -= step;
      final y = size.height - (up ? 0 : 4);
      path.lineTo(x.clamp(0, size.width), y);
      up = !up;
    }

    path.lineTo(0, size.height - 4);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// (중앙 찢김 스크래치용 CustomPainter들은 찢김 스티커 제거에 따라 삭제되었습니다)
// Film strip painter: 양쪽에 4개씩 연한 타공(perforation) — 레퍼런스 빈티지 필름 스트립
class _FilmHolePainterV2 extends CustomPainter {
  static const int holesPerSide = 4;
  static const double holeW = 5.0;
  static const double holeH = 5.0;
  static const Color holeColor = Color(0xFF3D4556);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = holeColor..style = PaintingStyle.fill;
    final leftX = 2.0;
    final rightX = size.width - 2.0 - holeW;
    final totalGap = size.height - (holesPerSide * holeH);
    final gap = holesPerSide > 1 ? totalGap / (holesPerSide + 1) : totalGap / 2;

    for (int i = 0; i < holesPerSide; i++) {
      final y = gap + i * (holeH + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(leftX, y, holeW, holeH),
        const Radius.circular(1),
      );
      canvas.drawRRect(rect, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rightX, y, holeW, holeH),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Sketch frame painter for _frameSketch
class _SketchFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(4, 8);
    path.lineTo(size.width - 4, 4);
    path.lineTo(size.width - 6, size.height - 6);
    path.lineTo(6, size.height - 4);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// VHS 스캔라인
class _VhsScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 네온 코너 L자
class _NeonCornerLPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const r = 6.0;
    canvas.drawPath(Path()
      ..moveTo(0, r)
      ..lineTo(0, 0)
      ..lineTo(r, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}