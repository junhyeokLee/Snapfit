part of 'layer_builder.dart';

Widget _framePhotoCardImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final s = constraints.biggest.shortestSide;
      final pad = (s * 0.052).clamp(3.0, 10.0);
      final radius = (s * 0.012).clamp(1.0, 3.0);
      return Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: (s * 0.05).clamp(2.0, 7.0),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular((radius * 0.7).clamp(0.8, 2.0)),
          child: SizedBox.expand(child: image),
        ),
      );
    },
  );
}

Widget _framePaperTapeCardImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final s = constraints.biggest.shortestSide;
      final padLR = (s * 0.038).clamp(4.0, 14.0);
      final padTop = (s * 0.042).clamp(4.0, 14.0);
      final padBottom = (s * 0.064).clamp(6.0, 20.0);
      final tapeW = (s * 0.32).clamp(30.0, 84.0);
      final tapeH = (s * 0.08).clamp(8.0, 18.0);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: _RoughEdgePaperClipper(),
              child: Container(
                padding: EdgeInsets.fromLTRB(padLR, padTop, padLR, padBottom),
                decoration: BoxDecoration(
                  color: const Color(0xFFBC9067),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: (s * 0.07).clamp(3.0, 10.0),
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PaperNoisePainter(opacity: 0.07),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: SizedBox.expand(child: image),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -tapeH * 0.5,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: -0.09,
                child: Container(
                  width: tapeW,
                  height: tapeH,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0C79F).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: CustomPaint(
                    painter: _TapeDotsPainter(
                      baseColor: Colors.transparent,
                      dotColor: const Color(0xFFC9AF85).withOpacity(0.35),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget _framePosterPolaroidImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final s = size.shortestSide;
      final h = size.height;
      final padLR = (s * 0.06).clamp(6.0, 16.0);
      final padTop = (h * 0.05).clamp(5.0, 14.0);
      var padBottom = (h * 0.20).clamp(14.0, 42.0);
      final maxBottom = (h - padTop - 24).clamp(8.0, 48.0);
      if (padBottom > maxBottom) padBottom = maxBottom;
      return Container(
        padding: EdgeInsets.fromLTRB(padLR, padTop, padLR, padBottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: (s * 0.09).clamp(4.0, 12.0),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: SizedBox.expand(child: image),
        ),
      );
    },
  );
}

Widget _frameCollageTileImpl(Widget image) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(1),
    child: SizedBox.expand(child: image),
  );
}

Widget _frameTornPaperCardImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.14),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ClipPath(
      clipper: _TornPaperClipper(),
      child: Stack(
        children: [
          Container(
            color: const Color(0xFFFFFBF2),
            child: CustomPaint(painter: _PaperNoisePainter(opacity: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: SizedBox.expand(child: image),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TornBottomEdgeShadowPainter(
                  color: const Color(0xFFB49D7E),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _framePaperClipCardImpl(Widget image) {
  final clipWidget = SizedBox(
    width: 22,
    height: 28,
    child: CustomPaint(
      painter: _PaperClipPainter(color: const Color(0xFF9AA6B1)),
    ),
  );
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipPath(
            clipper: _TornPaperClipper(),
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFFFFFBF2),
                  child: CustomPaint(
                    painter: _PaperNoisePainter(opacity: 0.09),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: SizedBox.expand(child: image),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _TornBottomEdgeShadowPainter(
                        color: const Color(0xFFB49D7E),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(top: -12, right: 8, child: clipWidget),
    ],
  );
}

Widget _frameRibbonPolaroidImpl(Widget image) {
  const ribbon = SizedBox(
    width: 26,
    height: 24,
    child: CustomPaint(
      painter: _RibbonStickerPainter(
        color: Color(0xFF6E89CE),
        shadeColor: Color(0xFF506EB8),
      ),
    ),
  );
  return Stack(
    clipBehavior: Clip.hardEdge,
    children: [
      Positioned.fill(child: _framePolaroidClassicImpl(image)),
      const Positioned(top: 2, right: 2, child: ribbon),
    ],
  );
}

Widget _frameRoughPolaroidImpl(Widget image) {
  return ClipPath(
    clipper: _RoughEdgePaperClipper(),
    child: Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: SizedBox.expand(child: image),
      ),
    ),
  );
}

Widget _frameMaskingTapeImpl(Widget image) {
  return Stack(
    clipBehavior: Clip.hardEdge,
    children: [
      Positioned.fill(
        child: Container(
          color: const Color(0xFFFDFBF5),
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox.expand(child: image),
          ),
        ),
      ),
      Positioned(
        top: 1,
        left: 12,
        right: 12,
        child: Container(
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFFE4D2A6).withOpacity(0.9),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      Positioned(
        bottom: 1,
        left: 16,
        right: 18,
        child: Container(
          height: 9,
          decoration: BoxDecoration(
            color: const Color(0xFFE4D2A6).withOpacity(0.82),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    ],
  );
}

Widget _frameSoftPaperCardImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF4EBDD),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: const Color(0xFFDDCDB9), width: 1.1),
    ),
    padding: const EdgeInsets.all(7),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox.expand(child: image),
    ),
  );
}

Widget _frameArchSoftImpl(Widget image) {
  return ClipPath(
    clipper: _ArchFrameClipper(),
    child: SizedBox.expand(child: image),
  );
}

Widget _frameArchOvalImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final radius =
          (constraints.biggest.shortestSide * 0.41).clamp(120.0, 320.0);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox.expand(child: image),
      );
    },
  );
}

Widget _frameTicketStubImpl(Widget image) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF243B53),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F0E6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.expand(child: image),
            ),
          ),
        ),
      ),
      const Positioned(left: -8, top: 44, child: _TicketStubNotch()),
      const Positioned(right: -8, top: 44, child: _TicketStubNotch()),
      const Positioned(left: -8, bottom: 30, child: _TicketStubNotch()),
      const Positioned(right: -8, bottom: 30, child: _TicketStubNotch()),
    ],
  );
}

class _ArchFrameClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final archBottom = size.height * 0.32;
    final midX = size.width * 0.5;
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, archBottom)
      ..quadraticBezierTo(midX, 0, size.width, archBottom)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TicketStubNotch extends StatelessWidget {
  const _TicketStubNotch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F0E6),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF243B53), width: 1.2),
      ),
    );
  }
}
