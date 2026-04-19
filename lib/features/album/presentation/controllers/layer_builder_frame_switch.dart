part of 'layer_builder.dart';

Widget _buildFramedImageImpl(
  LayerBuilder builder,
  LayerModel layer,
  Widget image,
) {
  Widget framed;
  switch (layer.imageBackground) {
    case "circle":
      framed = builder._frameCircle(image);
      break;
    case "archSoft":
      framed = builder._frameArchSoft(image);
      break;
    case "archOval":
      framed = builder._frameArchOval(image);
      break;
    case "round":
      framed = builder._frameRound(image);
      break;
    case "circleRing":
      framed = builder._frameCircleRing(image);
      break;
    case "heartFrame":
      framed = builder._frameHeart(image);
      break;
    case "rounded28":
      framed = builder._frameRounded28(image);
      break;
    case "polaroid":
      framed = builder._framePolaroid(image);
      break;
    case "polaroidClassic":
      framed = builder._framePolaroidClassic(image);
      break;
    case "polaroidWide":
      framed = builder._framePolaroidWide(image);
      break;
    case "polaroidFilm":
      framed = builder._framePolaroidFilm(image);
      break;
    case "softGlow":
      framed = builder._frameSoftGlow(image);
      break;
    case "sticker":
      framed = builder._frameSticker(image);
      break;
    case "vintage":
      framed = builder._frameVintage(image);
      break;
    case "film":
      framed = builder._frameFilm(image);
      break;
    case "filmSquare":
      framed = builder._frameFilmSquare(image);
      break;
    case "photoCard":
      framed = builder._framePhotoCard(image);
      break;
    case "paperTapeCard":
      framed = builder._framePaperTapeCard(image);
      break;
    case "posterPolaroid":
      framed = builder._framePosterPolaroid(image);
      break;
    case "collageTile":
      framed = builder._frameCollageTile(image);
      break;
    case "tornPaperCard":
      framed = builder._frameTornPaperCard(image);
      break;
    case "paperClipCard":
      framed = builder._framePaperClipCard(image);
      break;
    case "ribbonPolaroid":
      framed = builder._frameRibbonPolaroid(image);
      break;
    case "roughPolaroid":
      framed = builder._frameRoughPolaroid(image);
      break;
    case "maskingTapeFrame":
      framed = builder._frameMaskingTape(image);
      break;
    case "softPaperCard":
      framed = builder._frameSoftPaperCard(image);
      break;
    case "sketch":
      framed = builder._frameSketch(image);
      break;
    case "win95":
      framed = builder._frameWin95(image);
      break;
    case "pixel8":
      framed = builder._framePixel8(image);
      break;
    case "vhs":
      framed = builder._frameVhs(image);
      break;
    case "neon":
      framed = builder._frameNeon(image);
      break;
    case "crayon":
      framed = builder._frameCrayon(image);
      break;
    case "notebook":
      framed = builder._frameNotebook(image);
      break;
    case "tapeClip":
      framed = builder._frameTapeClip(image);
      break;
    case "comicBubble":
      framed = builder._frameComicBubble(image);
      break;
    case "thinDoubleLine":
      framed = builder._frameThinDoubleLine(image);
      break;
    case "offsetColorBlock":
      framed = builder._frameOffsetColorBlock(image);
      break;
    case "floatingGlass":
      framed = builder._frameFloatingGlass(image);
      break;
    case "gradientEdge":
      framed = builder._frameGradientEdge(image);
      break;
    case "tornNotebook":
      framed = builder._frameTornNotebook(image);
      break;
    case "oldNewspaper":
      framed = builder._frameOldNewspaper(image);
      break;
    case "postalStamp":
      framed = builder._framePostalStamp(image);
      break;
    case "kraftPaper":
      framed = builder._frameKraftPaper(image);
      break;
    case "goldFrame":
      framed = builder._frameGoldFrame(image);
      break;
    case "ticketStub":
      framed = builder._frameTicketStub(image);
      break;
    case "blob":
      framed = builder._frameBlob(image);
      break;
    case "pinkSplatter":
      framed = builder._framePinkSplatter(image);
      break;
    case "toxicGlow":
      framed = builder._frameToxicGlow(image);
      break;
    case "stencilBlock":
      framed = builder._frameStencilBlock(image);
      break;
    case "midnightDrip":
      framed = builder._frameMidnightDrip(image);
      break;
    case "vaporStreet":
      framed = builder._frameVaporStreet(image);
      break;
    default:
      framed = image;
  }
  return _fitFramedContentImpl(layer, framed);
}

Widget _fitFramedContentImpl(LayerModel layer, Widget child) {
  final bg = (layer.imageBackground ?? '').trim().toLowerCase();
  if (bg.isEmpty || bg == 'none' || bg == 'free') {
    return SizedBox.expand(child: child);
  }
  return LayoutBuilder(
    builder: (context, constraints) {
      final maxW = constraints.maxWidth;
      final maxH = constraints.maxHeight;
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: maxW > 0 ? maxW : layer.width,
            height: maxH > 0 ? maxH : layer.height,
            child: child,
          ),
        ),
      );
    },
  );
}
