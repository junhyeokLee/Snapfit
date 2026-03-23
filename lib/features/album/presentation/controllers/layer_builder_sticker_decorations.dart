part of 'layer_builder.dart';

Widget? _buildStickerDecoration(LayerModel layer) {
  if (layer.imageBackground == 'stickerBlueStar') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _StarStickerPainter(
        fillColor: const Color(0xFF2E4FB2),
        points: 7,
        innerFactor: 0.42,
      ),
    );
  }
  if (layer.imageBackground == 'stickerBlueStarSmall') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _StarStickerPainter(
        fillColor: const Color(0xFF385CC8),
        points: 6,
        innerFactor: 0.45,
      ),
    );
  }
  if (layer.imageBackground == 'stickerCatDoodle') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _CatDoodlePainter(color: const Color(0xFF4A4A4A)),
    );
  }
  if (layer.imageBackground == 'stickerFlowerPink') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _FlowerStickerPainter(
        petalColor: const Color(0xFFF1A5B8),
        centerColor: const Color(0xFFF7D5A6),
      ),
    );
  }
  if (layer.imageBackground == 'stickerFlowerCoral') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _FlowerStickerPainter(
        petalColor: const Color(0xFFE77B8C),
        centerColor: const Color(0xFFF4C989),
      ),
    );
  }
  if (layer.imageBackground == 'stickerDaisyWhite') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _FlowerStickerPainter(
        petalColor: const Color(0xFFFDFDFD),
        centerColor: const Color(0xFFF0CA61),
        petalCount: 8,
      ),
    );
  }
  if (layer.imageBackground == 'stickerTapeBeige') {
    return Transform.rotate(
      angle: -0.10,
      child: ClipPath(
        clipper: _TapeTornEdgeClipper(step: 6, amp: 2),
        child: Container(
          width: layer.width,
          height: layer.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE2CDA6).withOpacity(0.94),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
  if (layer.imageBackground == 'stickerTapeDotsBlue') {
    return Transform.rotate(
      angle: -0.08,
      child: ClipPath(
        clipper: _TapeTornEdgeClipper(step: 7, amp: 2),
        child: SizedBox(
          width: layer.width,
          height: layer.height,
          child: CustomPaint(
            painter: _TapeDotsPainter(
              baseColor: const Color(0xFFCFE3FF).withOpacity(0.96),
              dotColor: const Color(0xFF2F5FBF).withOpacity(0.32),
            ),
          ),
        ),
      ),
    );
  }
  if (layer.imageBackground == 'stickerTapeStripePink') {
    return Transform.rotate(
      angle: 0.10,
      child: ClipPath(
        clipper: _TapeTornEdgeClipper(step: 7, amp: 2),
        child: SizedBox(
          width: layer.width,
          height: layer.height,
          child: CustomPaint(
            painter: _TapeStripePainter(
              baseColor: const Color(0xFFFFD3E6).withOpacity(0.96),
              stripeColor: const Color(0xFFE85AA9).withOpacity(0.28),
            ),
          ),
        ),
      ),
    );
  }
  if (layer.imageBackground == 'stickerTicketPaper') {
    return Transform.rotate(
      angle: -0.24,
      child: Container(
        width: layer.width,
        height: layer.height,
        decoration: BoxDecoration(
          color: const Color(0xFFE6D6BE),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFBDAF99), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _TicketNotchPainter(color: const Color(0xFFCEC0AA)),
        ),
      ),
    );
  }
  if (layer.imageBackground == 'stickerTornNoteBeige') {
    return Transform.rotate(
      angle: -0.16,
      child: ClipPath(
        clipper: _TornPaperClipper(),
        child: Container(
          width: layer.width,
          height: layer.height,
          color: const Color(0xFFE6D8C2),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _PaperNoisePainter(opacity: 0.08)),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _TornBottomEdgeShadowPainter(
                    color: const Color(0xFFAA9273),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  child: CustomPaint(
                    painter: _TinyHandwritingPainter(
                      color: const Color(0xFF6D5E4C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  if (layer.imageBackground == 'stickerPaperClip') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _PaperClipPainter(color: const Color(0xFFA5AFB7)),
    );
  }
  if (layer.imageBackground == 'stickerRibbonBlue') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _RibbonStickerPainter(
        color: const Color(0xFF7D95D4),
        shadeColor: const Color(0xFF5E78B9),
      ),
    );
  }
  if (layer.imageBackground == 'stickerHeartRed') {
    return const FittedBox(
      fit: BoxFit.contain,
      child: Text('❤', style: TextStyle(color: Color(0xFFD74A4A))),
    );
  }
  if (layer.imageBackground == 'stickerLeafGreen') {
    return const FittedBox(
      fit: BoxFit.contain,
      child: Text('❧', style: TextStyle(color: Color(0xFF6FA05A))),
    );
  }
  if (layer.imageBackground == 'stickerSparkleBlue') {
    return const FittedBox(
      fit: BoxFit.contain,
      child: Text('✶', style: TextStyle(color: Color(0xFF355ABA))),
    );
  }
  if (layer.imageBackground == 'stickerSparkleGold') {
    return const FittedBox(
      fit: BoxFit.contain,
      child: Text('✶', style: TextStyle(color: Color(0xFFE6B84E))),
    );
  }
  if (layer.imageBackground == 'stickerBowPink') {
    return const FittedBox(
      fit: BoxFit.contain,
      child: Text('🎀', style: TextStyle(color: Color(0xFFD97AAC))),
    );
  }
  if (layer.imageBackground == 'stickerHeartPink') {
    return const FittedBox(
      fit: BoxFit.contain,
      child: Text('❤', style: TextStyle(color: Color(0xFFEC58A2))),
    );
  }
  if (layer.imageBackground == 'stickerScribbleBlue') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _ScribbleStickerPainter(color: const Color(0xFF4A89C8)),
    );
  }
  if (layer.imageBackground == 'stickerBrushPink') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _BrushStrokeStickerPainter(color: const Color(0xFFE85AA9)),
    );
  }
  if (layer.imageBackground == 'stickerBlobGreen') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _BlobStickerPainter(color: const Color(0xFF73BC67)),
    );
  }
  if (layer.imageBackground == 'stickerArrowCoral') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _ArrowDoodlePainter(color: const Color(0xFFF07A63)),
    );
  }
  if (layer.imageBackground == 'stickerStarGold') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _StarStickerPainter(
        fillColor: const Color(0xFFE6B84E),
        points: 6,
        innerFactor: 0.46,
      ),
    );
  }
  if (layer.imageBackground == 'stickerLeafCornerLeft') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _LeafCornerPainter(
        color: const Color(0xFF2F7A2A),
        mirror: false,
      ),
    );
  }
  if (layer.imageBackground == 'stickerLeafCornerRight') {
    return CustomPaint(
      size: Size(layer.width, layer.height),
      painter: _LeafCornerPainter(color: const Color(0xFF2F7A2A), mirror: true),
    );
  }
  if (layer.imageBackground == 'stickerCherryBlossom') {
    return const FittedBox(
      fit: BoxFit.contain,
      child: Text('🌸', style: TextStyle(fontSize: 48)),
    );
  }
  if (layer.imageBackground == 'stickerCloudSoft') {
    return const FittedBox(
      fit: BoxFit.contain,
      child: Text(
        '☁',
        style: TextStyle(color: Color(0xFFF8FBFF), fontSize: 54),
      ),
    );
  }
  if (layer.imageBackground == 'stickerCloverGreen') {
    return const FittedBox(
      fit: BoxFit.contain,
      child: Text(
        '☘',
        style: TextStyle(color: Color(0xFF4C8F4E), fontSize: 44),
      ),
    );
  }
  if (layer.imageBackground == 'stickerInstantCamera') {
    return Container(
      width: layer.width,
      height: layer.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E2DE), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: layer.width * 0.44,
              height: layer.width * 0.44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDCDCD8),
                border: Border.all(color: const Color(0xFFBEBEB8), width: 1.2),
              ),
            ),
          ),
          Positioned(
            right: layer.width * 0.18,
            top: layer.height * 0.18,
            child: Container(
              width: layer.width * 0.09,
              height: layer.width * 0.09,
              decoration: const BoxDecoration(
                color: Color(0xFF9FB7D5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
  if (layer.imageBackground == 'stickerEnvelopeBlue') {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: layer.width,
        height: layer.height,
        color: const Color(0xFFDDEBFA),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: layer.height * 0.62,
              child: CustomPaint(painter: _EnvelopeFlapPainter()),
            ),
            Positioned(
              left: layer.width * 0.14,
              right: layer.width * 0.14,
              top: layer.height * 0.14,
              height: layer.height * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8EDF1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return null;
}

class _EnvelopeFlapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFCCE0F7);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height * 0.62)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
