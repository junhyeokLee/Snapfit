part of 'layer_builder.dart';

Widget _frameCircleImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final side = size.shortestSide;

      return Center(
        child: SizedBox(
          width: side,
          height: side,
          child: ClipOval(child: SizedBox.expand(child: image)),
        ),
      );
    },
  );
}

Widget _frameCircleRingImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final side = size.shortestSide;
      final ringPadding = (side * 0.054).clamp(10.0, 42.0);
      final borderWidth = (side * 0.0027).clamp(1.0, 2.0);

      return Center(
        child: SizedBox(
          width: side,
          height: side,
          child: Container(
            padding: EdgeInsets.all(ringPadding),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFC9D2DA),
                width: borderWidth,
              ),
            ),
            child: ClipOval(child: SizedBox.expand(child: image)),
          ),
        ),
      );
    },
  );
}

Widget _frameHeartImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final side = size.shortestSide;
      final shadowBlur = (side * 0.06).clamp(4.0, 12.0);
      return Center(
        child: SizedBox(
          width: side,
          height: side * 0.93,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Transform.translate(
                  offset: const Offset(0, 3),
                  child: Opacity(
                    opacity: 0.12,
                    child: ClipPath(
                      clipper: _HeartClipper(),
                      child: Container(color: Colors.black),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipPath(
                  clipper: _HeartClipper(),
                  child: SizedBox.expand(child: image),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _frameRoundImpl(Widget image) {
  return ClipRRect(borderRadius: BorderRadius.circular(18), child: image);
}

Widget _frameRounded28Impl(Widget image) {
  return ClipRRect(borderRadius: BorderRadius.circular(28), child: image);
}

Widget _polaroidBottomLineImpl() {
  return Container(
    height: 3,
    width: 48,
    decoration: BoxDecoration(
      color: const Color(0xFFD0D3DC),
      borderRadius: BorderRadius.circular(999),
    ),
  );
}

Widget _framePolaroidImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final s = size.shortestSide;
      final h = size.height;
      final padLR = (s * 0.05).clamp(4.0, 14.0);
      final padTop = (h * 0.07).clamp(4.0, 18.0);
      var padBottom = (h * 0.17).clamp(8.0, 34.0);
      final maxBottom = (h - padTop - 24).clamp(6.0, 42.0);
      if (padBottom > maxBottom) padBottom = maxBottom;
      final radius = (s * 0.04).clamp(5.0, 10.0);
      return Center(
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            padding: EdgeInsets.fromLTRB(padLR, padTop, padLR, padBottom),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
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
              borderRadius: BorderRadius.circular((radius * 0.65)),
              child: SizedBox.expand(child: image),
            ),
          ),
        ),
      );
    },
  );
}

Widget _framePolaroidClassicImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final s = size.shortestSide;
      final h = size.height;
      final padLR = (s * 0.05).clamp(4.0, 12.0);
      final padTop = (h * 0.07).clamp(4.0, 16.0);
      var padBottom = (h * 0.16).clamp(8.0, 30.0);
      final maxBottom = (h - padTop - 24).clamp(6.0, 38.0);
      if (padBottom > maxBottom) padBottom = maxBottom;
      final radius = (s * 0.045).clamp(6.0, 12.0);
      return Center(
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            padding: EdgeInsets.fromLTRB(padLR, padTop, padLR, padBottom),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEF5),
              borderRadius: BorderRadius.circular(radius),
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
              borderRadius: BorderRadius.circular((radius * 0.60)),
              child: SizedBox.expand(child: image),
            ),
          ),
        ),
      );
    },
  );
}

Widget _framePolaroidWideImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final s = constraints.biggest.shortestSide;
      final padLR = (s * 0.045).clamp(4.0, 10.0);
      final padTop = (s * 0.06).clamp(5.0, 12.0);
      final padBottom = (s * 0.14).clamp(10.0, 24.0);
      return Container(
        padding: EdgeInsets.fromLTRB(padLR, padTop, padLR, padBottom),
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
    },
  );
}

Widget _framePolaroidFilmImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final s = constraints.biggest.shortestSide;
      final padLR = (s * 0.07).clamp(6.0, 18.0);
      final padTop = (s * 0.12).clamp(8.0, 28.0);
      final padBottom = (s * 0.24).clamp(14.0, 54.0);
      final radius = (s * 0.04).clamp(5.0, 10.0);
      return Center(
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            padding: EdgeInsets.fromLTRB(padLR, padTop, padLR, padBottom),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(radius),
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
              borderRadius: BorderRadius.circular((radius * 0.65)),
              child: SizedBox.expand(child: image),
            ),
          ),
        ),
      );
    },
  );
}
