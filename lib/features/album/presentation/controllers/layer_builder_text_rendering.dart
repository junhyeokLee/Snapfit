part of 'layer_builder.dart';

Widget _buildTextImpl(
  LayerBuilder builder,
  LayerModel layer, {
  bool isCover = false,
}) {
  if (builder._isEditing(layer)) return const SizedBox.shrink();

  final TextStyle baseStyle = layer.textStyle ?? const TextStyle(fontSize: 18);
  // 커버/페이지 템플릿의 스케일 일관성을 위해 강제 최소 폰트 보정은 적용하지 않는다.
  final TextStyle effectiveStyle = baseStyle;

  final coverSize = builder.getCoverSize();
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
    final Size styleSize = _calculateStyleSizeImpl(
      layer.textBackground!,
      layer,
      textPainter,
    );
    final isNoteGrid = layer.textBackground == 'noteGrid';
    final realSize = Size(
      styleSize.width,
      styleSize.height + (isNoteGrid ? 0 : 12),
    );
    builder.interaction.setBaseSize(layer.id, realSize);

    return builder.interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: realSize.width,
      baseHeight: realSize.height,
      isCover: isCover,
      child: Opacity(opacity: layer.opacity, child: styled),
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
  builder.interaction.setBaseSize(layer.id, realSize);

  return builder.interaction.buildInteractiveLayer(
    layer: layer,
    baseWidth: realSize.width,
    baseHeight: realSize.height,
    isCover: isCover,
    child: Opacity(opacity: layer.opacity, child: content),
  );
}
