import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A physical photo mount with a live, replaceable [child].
///
/// Supply bounded width and height, as with AtelierEditionFrame. Geometry and
/// detail widths scale with the shorter side, including at print resolution.
/// Unknown style IDs use the vow mount without changing the public style ID.
class AtelierSignatureFrame extends StatelessWidget {
  const AtelierSignatureFrame({
    super.key,
    required this.style,
    required this.child,
  });

  final String style;
  final Widget child;

  /// Insets in the coordinate space of the complete frame.
  ///
  /// Inset content retains at least 77% of each frame dimension. Pocket
  /// overlaps leave the central 76% of the photo unobscured.
  static EdgeInsets insets(String style, Size size) =>
      _signatureInsets(_signatureStyle(style), size);

  /// The exterior silhouette, including transparent ticket or film cutouts.
  static Path outer(String style, Size size) =>
      _signatureOuter(_signatureStyle(style), size);

  /// The photo opening in local coordinates of the *inset content size*.
  static Path aperture(String style, Size size) =>
      _signatureAperture(_signatureStyle(style), size);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (!_signatureHasArea(size)) return const SizedBox.shrink();
      final kind = _signatureStyle(style);
      return ClipPath(
        clipper: _SignatureClipper(kind, exterior: true),
        child: CustomPaint(
          painter: _SignaturePainter(kind, foreground: false),
          foregroundPainter: _SignaturePainter(kind, foreground: true),
          child: Padding(
            padding: _signatureInsets(kind, size),
            child: ClipPath(
              clipper: _SignatureClipper(kind, exterior: false),
              child: SizedBox.expand(child: child),
            ),
          ),
        ),
      );
    },
  );
}

enum _SignatureStyle { vow, rail, herbarium, orbit, kitchen, cinema, trail }

_SignatureStyle _signatureStyle(String style) => switch (style) {
  'signatureVowPocket' => _SignatureStyle.vow,
  'signatureRailWallet' => _SignatureStyle.rail,
  'signatureHerbariumSleeve' => _SignatureStyle.herbarium,
  'signatureOrbitQuilt' => _SignatureStyle.orbit,
  'signatureKitchenFold' => _SignatureStyle.kitchen,
  'signatureCinemaGate' => _SignatureStyle.cinema,
  'signatureTrailPocket' => _SignatureStyle.trail,
  _ => _SignatureStyle.vow,
};

bool _signatureHasArea(Size size) =>
    size.width.isFinite && size.height.isFinite && !size.isEmpty;

EdgeInsets _signatureInsets(_SignatureStyle style, Size size) {
  if (!_signatureHasArea(size)) return EdgeInsets.zero;
  final u = math.min(size.width, size.height);
  return switch (style) {
    _SignatureStyle.vow => EdgeInsets.fromLTRB(
      u * .072,
      u * .070,
      u * .072,
      u * .120,
    ),
    _SignatureStyle.rail => EdgeInsets.fromLTRB(
      u * .075,
      u * .075,
      u * .145,
      u * .120,
    ),
    _SignatureStyle.herbarium => EdgeInsets.fromLTRB(
      u * .080,
      u * .115,
      u * .080,
      u * .115,
    ),
    _SignatureStyle.orbit => EdgeInsets.fromLTRB(
      u * .097,
      u * .097,
      u * .097,
      u * .110,
    ),
    _SignatureStyle.kitchen => EdgeInsets.fromLTRB(
      u * .106,
      u * .090,
      u * .106,
      u * .120,
    ),
    _SignatureStyle.cinema => EdgeInsets.fromLTRB(
      u * .105,
      u * .075,
      u * .105,
      u * .135,
    ),
    _SignatureStyle.trail => EdgeInsets.fromLTRB(
      u * .085,
      u * .085,
      u * .085,
      u * .125,
    ),
  };
}

Path _signatureAperture(_SignatureStyle style, Size size) {
  if (!_signatureHasArea(size)) return Path();
  final u = math.min(size.width, size.height);
  final radius = switch (style) {
    _SignatureStyle.orbit => .018,
    _SignatureStyle.cinema => .004,
    _SignatureStyle.rail || _SignatureStyle.kitchen => .006,
    _ => .009,
  };
  return _signatureRoundedRect(Offset.zero & size, u * radius);
}

Path _signatureRoundedRect(Rect rect, double radius) =>
    Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

Path _signaturePolygon(List<Offset> points) => Path()..addPolygon(points, true);

Path _signatureOuter(_SignatureStyle style, Size size) {
  if (!_signatureHasArea(size)) return Path();
  final w = size.width, h = size.height;
  final u = math.min(w, h);
  switch (style) {
    case _SignatureStyle.rail:
      final k = u * .014, stub = w - u * .074, notch = u * .017;
      final body = Path()
        ..fillType = PathFillType.evenOdd
        ..moveTo(k, 0)
        ..lineTo(stub - notch, 0)
        ..quadraticBezierTo(stub, notch * 1.8, stub + notch, 0)
        ..lineTo(w - k, 0)
        ..quadraticBezierTo(w, 0, w, k)
        ..lineTo(w, h - k)
        ..quadraticBezierTo(w, h, w - k, h)
        ..lineTo(stub + notch, h)
        ..quadraticBezierTo(stub, h - notch * 1.8, stub - notch, h)
        ..lineTo(k, h)
        ..quadraticBezierTo(0, h, 0, h - k)
        ..lineTo(0, k)
        ..quadraticBezierTo(0, 0, k, 0)
        ..close();
      _signatureRailHoles(size, (hole) => body.addOval(hole));
      return body;
    case _SignatureStyle.herbarium:
      final k = u * .014, top = u * .039;
      final tabLeft = w - u * .300, tabRight = w - u * .095;
      return Path()
        ..moveTo(k, top)
        ..lineTo(tabLeft - k, top)
        ..quadraticBezierTo(tabLeft, top, tabLeft, top - k)
        ..lineTo(tabLeft, k)
        ..quadraticBezierTo(tabLeft, 0, tabLeft + k, 0)
        ..lineTo(tabRight - k, 0)
        ..quadraticBezierTo(tabRight, 0, tabRight, k)
        ..lineTo(tabRight, top - k)
        ..quadraticBezierTo(tabRight, top, tabRight + k, top)
        ..lineTo(w - k, top)
        ..quadraticBezierTo(w, top, w, top + k)
        ..lineTo(w, h - k)
        ..quadraticBezierTo(w, h, w - k, h)
        ..lineTo(k, h)
        ..quadraticBezierTo(0, h, 0, h - k)
        ..lineTo(0, top + k)
        ..quadraticBezierTo(0, top, k, top)
        ..close();
    case _SignatureStyle.orbit:
      return _signatureScallops(size);
    case _SignatureStyle.kitchen:
      final k = u * .012, fold = u * .065;
      return Path()
        ..moveTo(k, 0)
        ..lineTo(w - fold, 0)
        ..lineTo(w, fold)
        ..lineTo(w, h - k)
        ..quadraticBezierTo(w, h, w - k, h)
        ..lineTo(k, h)
        ..quadraticBezierTo(0, h, 0, h - k)
        ..lineTo(0, k)
        ..quadraticBezierTo(0, 0, k, 0)
        ..close();
    case _SignatureStyle.cinema:
      final k = u * .022;
      final body = _signaturePolygon([
        Offset(k, 0),
        Offset(w - k, 0),
        Offset(w, k),
        Offset(w, h - k),
        Offset(w - k, h),
        Offset(k, h),
        Offset(0, h - k),
        Offset(0, k),
      ])..fillType = PathFillType.evenOdd;
      _signatureFilmHoles(size, (hole) {
        body.addRRect(RRect.fromRectAndRadius(hole, Radius.circular(u * .003)));
      });
      return body;
    case _SignatureStyle.vow:
      return _signatureRoundedRect(Offset.zero & size, u * .012);
    case _SignatureStyle.trail:
      return _signatureRoundedRect(Offset.zero & size, u * .026);
  }
}

Path _signatureScallops(Size size) {
  final w = size.width, h = size.height;
  final u = math.min(w, h), d = u * .016, corner = u * .033;
  final nx = (w / u * 10).round().clamp(8, 32);
  final ny = (h / u * 10).round().clamp(8, 32);
  final dx = (w - corner * 2) / nx, dy = (h - corner * 2) / ny;
  final path = Path()..moveTo(corner, d);
  for (var i = 0; i < nx; i++) {
    final x = corner + i * dx;
    path.quadraticBezierTo(x + dx * .5, 0, x + dx, d);
  }
  path.quadraticBezierTo(w - d, d, w - d, corner);
  for (var i = 0; i < ny; i++) {
    final y = corner + i * dy;
    path.quadraticBezierTo(w, y + dy * .5, w - d, y + dy);
  }
  path.quadraticBezierTo(w - d, h - d, w - corner, h - d);
  for (var i = 0; i < nx; i++) {
    final x = w - corner - i * dx;
    path.quadraticBezierTo(x - dx * .5, h, x - dx, h - d);
  }
  path.quadraticBezierTo(d, h - d, d, h - corner);
  for (var i = 0; i < ny; i++) {
    final y = h - corner - i * dy;
    path.quadraticBezierTo(0, y - dy * .5, d, y - dy);
  }
  return path
    ..quadraticBezierTo(d, d, corner, d)
    ..close();
}

void _signatureRailHoles(Size size, void Function(Rect) visit) {
  final u = math.min(size.width, size.height);
  final span = size.height - u * .112;
  final count = (span / (u * .033)).round().clamp(8, 48);
  for (var i = 0; i < count; i++) {
    visit(
      Rect.fromCircle(
        center: Offset(
          size.width - u * .074,
          u * .056 + span * i / (count - 1),
        ),
        radius: u * .0032,
      ),
    );
  }
}

void _signatureFilmHoles(Size size, void Function(Rect) visit) {
  final u = math.min(size.width, size.height);
  final span = size.height - u * .245;
  final count = (span / (u * .062)).round().clamp(6, 36);
  for (var i = 0; i < count; i++) {
    final y = u * .085 + span * i / (count - 1);
    for (final x in [u * .035, size.width - u * .035]) {
      visit(
        Rect.fromCenter(
          center: Offset(x, y),
          width: u * .021,
          height: u * .028,
        ),
      );
    }
  }
}

class _SignatureClipper extends CustomClipper<Path> {
  const _SignatureClipper(this.style, {required this.exterior});

  final _SignatureStyle style;
  final bool exterior;

  @override
  Path getClip(Size size) =>
      exterior ? _signatureOuter(style, size) : _signatureAperture(style, size);

  @override
  bool shouldReclip(_SignatureClipper oldClipper) =>
      oldClipper.style != style || oldClipper.exterior != exterior;
}

class _SignatureGeometry {
  _SignatureGeometry(this.style, this.size)
    : u = math.min(size.width, size.height),
      bounds = Offset.zero & size {
    photo = _signatureInsets(style, size).deflateRect(bounds);
    opening = _signatureAperture(style, photo.size).shift(photo.topLeft);
    silhouette = _signatureOuter(style, size);
  }

  final _SignatureStyle style;
  final Size size;
  final double u;
  final Rect bounds;
  late final Rect photo;
  late final Path opening;
  late final Path silhouette;

  double get w => size.width;
  double get h => size.height;
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.style, {required this.foreground});

  final _SignatureStyle style;
  final bool foreground;

  @override
  void paint(Canvas canvas, Size size) {
    if (!_signatureHasArea(size)) return;
    final g = _SignatureGeometry(style, size);
    final surface = _SignatureSurface(canvas, g);
    canvas.save();
    canvas.clipPath(g.silhouette);
    if (foreground) {
      // Clip twice: overlapping protected regions must not cancel with evenOdd.
      // This protects both the photo's center and the frame's central 60%.
      canvas.clipPath(
        _outside(
          g.bounds,
          Path()..addRect(
            Rect.fromCenter(
              center: g.photo.center,
              width: g.photo.width * .76,
              height: g.photo.height * .76,
            ),
          ),
        ),
      );
      canvas.clipPath(
        _outside(
          g.bounds,
          Path()..addRect(
            Rect.fromCenter(
              center: g.bounds.center,
              width: g.w * .60,
              height: g.h * .60,
            ),
          ),
        ),
      );
      surface.stroke(g.opening, const Color(0x20292C29), .0035);
      switch (style) {
        case _SignatureStyle.vow:
          surface.vowFront();
        case _SignatureStyle.rail:
          surface.railFront();
        case _SignatureStyle.herbarium:
          surface.herbariumFront();
        case _SignatureStyle.orbit:
          surface.orbitFront();
        case _SignatureStyle.kitchen:
          surface.kitchenFront();
        case _SignatureStyle.cinema:
          surface.cinemaFront();
        case _SignatureStyle.trail:
          surface.trailFront();
      }
    } else {
      // No opaque backing beneath the child, including a transparent child.
      canvas.clipPath(_outside(g.bounds, g.opening));
      switch (style) {
        case _SignatureStyle.vow:
          surface.vowBack();
        case _SignatureStyle.rail:
          surface.railBack();
        case _SignatureStyle.herbarium:
          surface.herbariumBack();
        case _SignatureStyle.orbit:
          surface.orbitBack();
        case _SignatureStyle.kitchen:
          surface.kitchenBack();
        case _SignatureStyle.cinema:
          surface.cinemaBack();
        case _SignatureStyle.trail:
          surface.trailBack();
      }
      surface.grain();
    }
    canvas.restore();
  }

  static Path _outside(Rect bounds, Path hole) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(bounds)
    ..addPath(hole, Offset.zero);

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.foreground != foreground;
}

/// All strokes use material-space units, never device pixels or image filters.
class _SignatureSurface {
  const _SignatureSurface(this.c, this.g);

  final Canvas c;
  final _SignatureGeometry g;

  double get u => g.u;
  double get w => g.w;
  double get h => g.h;
  Rect get r => g.photo;

  void fill(Path path, Color color) => c.drawPath(path, Paint()..color = color);

  void stroke(Path path, Color color, [double width = .0015]) => c.drawPath(
    path,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * width
      ..strokeJoin = StrokeJoin.round,
  );

  void line(Offset a, Offset b, Color color, [double width = .0015]) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = u * width
          ..strokeCap = StrokeCap.round,
      );

  Path rounded(Rect rect, [double radius = .008]) =>
      _signatureRoundedRect(rect, u * radius);

  void base(Color color) => c.drawRect(g.bounds, Paint()..color = color);

  void layer(Path path, Color color, {double lift = .003}) {
    // Two narrow contact shadows give paper thickness without a blurred layer.
    fill(path.shift(Offset(0, u * lift * 1.6)), const Color(0x0B222924));
    fill(path.shift(Offset(0, u * lift)), const Color(0x14222924));
    fill(path, color);
    stroke(path, const Color(0x24707568), .0011);
  }

  void mat(Color color, {double lip = .019, double radius = .009}) {
    layer(rounded(r.inflate(u * lip), radius), color);
    stroke(g.opening, const Color(0x42585D55), .0032);
    line(
      r.bottomLeft + Offset(u * .012, u * .002),
      r.bottomRight + Offset(-u * .012, u * .002),
      const Color(0x99FFFFFF),
      .002,
    );
  }

  void grain() {
    final dark = Path(), light = Path();
    // Fixed integer sequences keep grain stable across thumbnail/export sizes.
    for (var i = 0; i < 180; i++) {
      final x = ((i * 73 + 19) % 257) / 257 * w;
      final y = ((i * 151 + 61) % 263) / 263 * h;
      final length = u * (.0025 + (i % 5) * .0012);
      final path = i.isEven ? dark : light;
      path
        ..moveTo(x, y)
        ..lineTo(x + length, y + u * .0008);
    }
    stroke(dark, const Color(0x10464A40), .0007);
    stroke(light, const Color(0x32FFFFFF), .0008);
  }

  void weave(Color color) {
    final nx = (w / (u * .019)).ceil().clamp(8, 64);
    final ny = (h / (u * .019)).ceil().clamp(8, 64);
    final warp = Path(), weft = Path();
    for (var i = 1; i < nx; i++) {
      final x = w * i / nx;
      warp
        ..moveTo(x, 0)
        ..lineTo(x, h);
    }
    for (var i = 1; i < ny; i++) {
      final y = h * i / ny;
      weft
        ..moveTo(0, y)
        ..lineTo(w, y);
    }
    stroke(warp, color, .0008);
    stroke(weft, const Color(0x33FFFFFF), .0011);
  }

  void gingham(Path clip) {
    c.save();
    c.clipPath(clip);
    final nx = (w / (u * .047)).ceil().clamp(6, 56);
    final ny = (h / (u * .047)).ceil().clamp(6, 56);
    final dx = w / nx, dy = h / ny;
    final paint = Paint()..color = const Color(0x35637F60);
    for (var i = 0; i < nx; i++) {
      c.drawRect(Rect.fromLTWH(i * dx, 0, dx * .45, h), paint);
    }
    for (var i = 0; i < ny; i++) {
      c.drawRect(Rect.fromLTWH(0, i * dy, w, dy * .45), paint);
    }
    c.restore();
  }

  void stitches(
    Offset a,
    Offset b,
    Color color, {
    double pitch = .030,
    double width = .0017,
  }) {
    final delta = b - a;
    final count = (delta.distance / (u * pitch)).round().clamp(1, 64);
    final thread = Path();
    for (var i = 0; i < count; i++) {
      final start = (i + .16) / count, end = (i + .60) / count;
      final p = a + delta * start, q = a + delta * end;
      thread
        ..moveTo(p.dx, p.dy)
        ..lineTo(q.dx, q.dy);
    }
    stroke(thread.shift(Offset(0, u * .0011)), const Color(0x28505A50), .0026);
    stroke(thread, color, width);
  }

  void perimeterStitches(Rect rect, Color color, {double pitch = .030}) {
    final trim = u * .018;
    stitches(
      rect.topLeft + Offset(trim, 0),
      rect.topRight - Offset(trim, 0),
      color,
      pitch: pitch,
    );
    stitches(
      rect.topRight + Offset(0, trim),
      rect.bottomRight - Offset(0, trim),
      color,
      pitch: pitch,
    );
    stitches(
      rect.bottomLeft + Offset(trim, 0),
      rect.bottomRight - Offset(trim, 0),
      color,
      pitch: pitch,
    );
    stitches(
      rect.topLeft + Offset(0, trim),
      rect.bottomLeft - Offset(0, trim),
      color,
      pitch: pitch,
    );
  }

  void cornerSlots(Color stock, Color cut, {double reach = .047}) {
    for (var i = 0; i < 4; i++) {
      final right = i.isOdd, bottom = i >= 2;
      final corner = Offset(
        right ? r.right : r.left,
        bottom ? r.bottom : r.top,
      );
      final sx = right ? -1.0 : 1.0, sy = bottom ? -1.0 : 1.0;
      Offset p(double x, double y) => corner + Offset(x * u * sx, y * u * sy);
      final a = p(-.010, reach), b = p(reach, -.010);
      layer(_signaturePolygon([p(-.010, -.010), b, a]), stock, lift: .0017);
      line(a, b, cut, .0020);
      line(
        a + Offset(u * .001 * sx, u * .002 * sy),
        b + Offset(u * .001 * sx, u * .002 * sy),
        const Color(0xA6FFFEF5),
        .0012,
      );
    }
  }

  void vowBack() {
    base(const Color(0xFFDDDCD2));
    layer(rounded(g.bounds.deflate(u * .012), .010), const Color(0xFFF3F0E7));
    stroke(rounded(r.inflate(u * .043)), const Color(0xB5AF9662), .0012);
    stroke(rounded(r.inflate(u * .035)), const Color(0xD336485C), .0018);
    mat(const Color(0xFFFCF9F0), lip: .020);
  }

  void vowFront() {
    cornerSlots(const Color(0xFFF3F0E5), const Color(0x7A555D57));
    final a = Offset(r.right - u * .075, h - u * .014);
    final b = Offset(w - u * .018, r.bottom - u * .065);
    final tip = Offset(w - u * .018, h - u * .014);
    layer(_signaturePolygon([a, b, tip]), const Color(0x9AEFF1E7));
    line(a, b, const Color(0x466E7A70), .0014);
    final fold = _signaturePolygon([
      b,
      b + Offset(-u * .027, u * .050),
      Offset(w - u * .018, r.bottom + u * .006),
    ]);
    fill(fold, const Color(0xB8FAFAEF));
    line(b, b + Offset(-u * .027, u * .050), const Color(0x666F7A70), .0011);
  }

  void railBack() {
    base(const Color(0xFF829BAA));
    layer(
      rounded(Rect.fromLTRB(u * .018, u * .019, w - u * .090, h - u * .018)),
      const Color(0xFFC6D2D5),
    );
    fill(
      rounded(
        Rect.fromLTRB(w - u * .061, u * .035, w - u * .014, h - u * .035),
      ),
      const Color(0xFF91A8B4),
    );
    final x = w - u * .074;
    line(
      Offset(x - u * .009, u * .036),
      Offset(x - u * .009, h - u * .036),
      const Color(0x58708690),
    );
    line(
      Offset(x + u * .008, u * .036),
      Offset(x + u * .008, h - u * .036),
      const Color(0x70E8EBE5),
    );
    _signatureRailHoles(g.size, (hole) {
      stroke(
        Path()..addOval(hole.inflate(u * .0007)),
        const Color(0x58708489),
        .0010,
      );
    });
    mat(const Color(0xFFECECE2), lip: .020, radius: .006);
    line(
      Offset(u * .033, u * .031),
      Offset(w - u * .110, u * .031),
      const Color(0x65708691),
    );
  }

  void railFront() {
    final a = Offset(u * .020, r.bottom - u * .025);
    final b = Offset(w - u * .092, r.bottom + u * .052);
    final flap = _signaturePolygon([
      a,
      b,
      Offset(b.dx, h - u * .017),
      Offset(a.dx, h - u * .017),
    ]);
    layer(flap, const Color(0xFFA6BBC4), lift: .004);
    line(a, b, const Color(0x8A617D8A), .0020);
    line(
      a + Offset(0, u * .004),
      b + Offset(0, u * .004),
      const Color(0x8AE1E8E5),
      .0013,
    );
    fill(
      _signaturePolygon([
        b,
        b + Offset(-u * .045, u * .020),
        b + Offset(0, u * .039),
      ]),
      const Color(0xFFC8D5D8),
    );
    line(
      Offset(u * .033, h - u * .031),
      Offset(w - u * .106, h - u * .031),
      const Color(0x7D647F8C),
      .0012,
    );
  }

  void herbariumBack() {
    base(const Color(0xFFA7B59E));
    layer(
      rounded(Rect.fromLTRB(u * .016, u * .054, w - u * .016, h - u * .016)),
      const Color(0xFFCAD2BF),
    );
    line(
      Offset(w - u * .286, u * .039),
      Offset(w - u * .109, u * .039),
      const Color(0x685D745A),
      .0014,
    );
    line(
      Offset(w - u * .277, u * .013),
      Offset(w - u * .119, u * .013),
      const Color(0x6BE8EDDD),
      .0012,
    );
    for (final x in [u * .035, w - u * .035]) {
      line(
        Offset(x, u * .073),
        Offset(x, h - u * .031),
        const Color(0x556B8063),
      );
      line(
        Offset(x + u * .003, u * .073),
        Offset(x + u * .003, h - u * .031),
        const Color(0x80F1F3E6),
        .0010,
      );
    }
    mat(const Color(0xFFEDEEE1), lip: .019);
  }

  void herbariumFront() {
    cornerSlots(const Color(0xFFD3DAC6), const Color(0x7965795E), reach: .040);
    final a = Offset(u * .024, r.bottom - u * .028);
    final b = Offset(w - u * .024, r.bottom - u * .035);
    final edge = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(w * .36, a.dy + u * .013, w * .70, b.dy + u * .012, b.dx, b.dy);
    final glassine = Path.from(edge)
      ..lineTo(b.dx, h - u * .017)
      ..lineTo(a.dx, h - u * .017)
      ..close();
    layer(glassine, const Color(0x99F0F2E4), lift: .002);
    stroke(edge, const Color(0x4A657C62), .0016);
    stroke(edge.shift(Offset(0, u * .003)), const Color(0x85FEFFF1), .0012);
    line(
      Offset(u * .025, h - u * .026),
      Offset(w - u * .025, h - u * .026),
      const Color(0x4E7F9075),
      .0010,
    );
  }

  void orbitBack() {
    base(const Color(0xFFDCE8EB));
    final edge = u * .020;
    final binding = _signatureScallops(
      Size(w - edge * 2, h - edge * 2),
    ).shift(Offset(edge, edge));
    stroke(binding, const Color(0x9AB4C8CE), .0040);
    final corners = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    final exterior = [
      Offset(u * .028, u * .028),
      Offset(w - u * .028, u * .028),
      Offset(w - u * .028, h - u * .028),
      Offset(u * .028, h - u * .028),
    ];
    const panels = [
      Color(0xFFE6EEF0),
      Color(0xFFD7E3E7),
      Color(0xFFDCE8E9),
      Color(0xFFE1EBE9),
    ];
    for (var i = 0; i < 4; i++) {
      final next = (i + 1) % 4;
      fill(
        _signaturePolygon([
          exterior[i],
          exterior[next],
          corners[next],
          corners[i],
        ]),
        panels[i],
      );
      line(exterior[i], corners[i], const Color(0x3D829BA2), .0018);
    }
    weave(const Color(0x12718A91));
    mat(const Color(0xFFF2F4EC), lip: .017, radius: .020);
  }

  void orbitFront() {
    perimeterStitches(
      g.bounds.deflate(u * .041),
      const Color(0xB67B959D),
      pitch: .038,
    );
    final corners = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    for (var i = 0; i < 4; i++) {
      final sx = i == 1 || i == 2 ? 1.0 : -1.0;
      final sy = i >= 2 ? 1.0 : -1.0;
      stitches(
        corners[i] + Offset(sx * u * .028, sy * u * .028),
        corners[i] + Offset(sx * u * .050, sy * u * .050),
        const Color(0xBF849EA5),
        pitch: .013,
        width: .0014,
      );
    }
  }

  void kitchenBack() {
    base(const Color(0xFFD8E1CE));
    gingham(g.silhouette);
    final left = _signaturePolygon([
      Offset(u * .014, u * .032),
      Offset(u * .073, u * .057),
      Offset(r.left - u * .020, h * .48),
      Offset(u * .069, h - u * .028),
      Offset(u * .014, h - u * .014),
    ]);
    final right = _signaturePolygon([
      Offset(w - u * .014, u * .073),
      Offset(w - u * .074, u * .093),
      Offset(r.right + u * .020, h * .50),
      Offset(w - u * .067, h - u * .027),
      Offset(w - u * .014, h - u * .014),
    ]);
    for (final flap in [left, right]) {
      layer(flap, const Color(0xFFC4D2B8));
      gingham(flap);
    }
    mat(const Color(0xFFF4F0DE), lip: .022, radius: .007);
    stroke(rounded(r.inflate(u * .028), .008), const Color(0x625A7553), .0011);
  }

  void kitchenFront() {
    final a = Offset(u * .022, r.bottom + u * .014);
    final b = Offset(w * .55, r.bottom - u * .026);
    final d = Offset(w - u * .022, r.bottom + u * .025);
    final flap = _signaturePolygon([
      a,
      b,
      d,
      Offset(d.dx, h - u * .016),
      Offset(a.dx, h - u * .016),
    ]);
    layer(flap, const Color(0xFFC1D0B5), lift: .004);
    gingham(flap);
    stroke(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(d.dx, d.dy),
      const Color(0x8069805D),
      .0017,
    );
    final fold = u * .065;
    final turn = _signaturePolygon([
      Offset(w - fold, 0),
      Offset(w - fold, fold),
      Offset(w, fold),
    ]);
    layer(turn, const Color(0xFFF0EDD9), lift: .0025);
    line(
      Offset(w - fold, 0),
      Offset(w - fold, fold),
      const Color(0x76849770),
      .0012,
    );
    line(
      Offset(w - fold, fold),
      Offset(w, fold),
      const Color(0x8A718565),
      .0017,
    );
  }

  void cinemaBack() {
    base(const Color(0xFF303537));
    fill(
      rounded(Rect.fromLTRB(u * .011, u * .021, u * .069, h - u * .020), .004),
      const Color(0xFF653F49),
    );
    fill(
      rounded(
        Rect.fromLTRB(w - u * .068, u * .021, w - u * .011, h - u * .020),
        .004,
      ),
      const Color(0xFF503D45),
    );
    _signatureFilmHoles(g.size, (hole) {
      stroke(
        rounded(hole.inflate(u * .001), .003),
        const Color(0x847C7770),
        .0013,
      );
    });
    layer(rounded(r.inflate(u * .025), .005), const Color(0xFF9E9990));
    mat(const Color(0xFF474B4A), lip: .016, radius: .005);
    stroke(rounded(r.inflate(u * .019), .005), const Color(0x8CB5AB94), .0010);
    line(
      Offset(u * .081, u * .027),
      Offset(w - u * .081, u * .027),
      const Color(0x769D8B7B),
      .0012,
    );
  }

  void cinemaFront() {
    final a = Offset(u * .078, r.bottom - u * .019);
    final b = Offset(w - u * .078, r.bottom + u * .046);
    layer(
      _signaturePolygon([
        a,
        b,
        Offset(b.dx, h - u * .020),
        Offset(a.dx, h - u * .020),
      ]),
      const Color(0xFF704651),
      lift: .003,
    );
    line(a, b, const Color(0x9E322F33), .0020);
    line(
      a + Offset(0, u * .004),
      b + Offset(0, u * .004),
      const Color(0x7AA58688),
      .0010,
    );
    fill(
      rounded(
        Rect.fromLTRB(u * .090, h - u * .043, w - u * .091, h - u * .027),
        .002,
      ),
      const Color(0xFFB9AE9B),
    );
    final x = w - u * .091;
    final margin = _signaturePolygon([
      Offset(x, u * .044),
      Offset(w - u * .057, u * .063),
      Offset(w - u * .057, h - u * .026),
      Offset(x, h - u * .043),
    ]);
    layer(margin, const Color(0xFFD4CCBA), lift: .002);
    line(
      Offset(x + u * .009, u * .058),
      Offset(x + u * .009, h - u * .052),
      const Color(0x6D918475),
      .0010,
    );
    final fold = _signaturePolygon([
      Offset(x, h - u * .130),
      Offset(w - u * .057, h - u * .108),
      Offset(x, h - u * .062),
    ]);
    layer(fold, const Color(0xFFA99B8B), lift: .0015);
    line(
      Offset(x, h - u * .130),
      Offset(w - u * .057, h - u * .108),
      const Color(0x997E6A62),
      .0012,
    );
  }

  void trailBack() {
    base(const Color(0xFFA9A7BD));
    layer(
      rounded(g.bounds.deflate(u * .013), .018),
      const Color(0xFFC2BCD0),
      lift: .002,
    );
    weave(const Color(0x24676A7F));
    layer(
      rounded(Rect.fromLTRB(u * .026, u * .028, w - u * .026, u * .057), .004),
      const Color(0xFF617B69),
      lift: .0015,
    );
    layer(
      rounded(
        Rect.fromLTRB(r.right + u * .028, u * .079, w - u * .026, h - u * .096),
        .005,
      ),
      const Color(0xFF718574),
      lift: .0015,
    );
    mat(const Color(0xFFE8E9DD), lip: .019);
  }

  void trailFront() {
    perimeterStitches(
      g.bounds.deflate(u * .032),
      const Color(0xCBEDEBDA),
      pitch: .029,
    );
    final a = Offset(u * .020, r.bottom + u * .024);
    final b = Offset(w - u * .020, r.bottom - u * .033);
    final flap = _signaturePolygon([
      a,
      b,
      Offset(b.dx, h - u * .020),
      Offset(a.dx, h - u * .020),
    ]);
    layer(flap, const Color(0xFF536F5F), lift: .004);
    c.save();
    c.clipPath(flap);
    weave(const Color(0x26333F36));
    c.restore();
    line(a, b, const Color(0x9B344D40), .0020);
    stitches(
      a + Offset(0, u * .013),
      b + Offset(0, u * .013),
      const Color(0xC7D7DCC6),
      pitch: .028,
    );
    stitches(
      Offset(u * .032, h - u * .033),
      Offset(w - u * .032, h - u * .033),
      const Color(0xA2D0D7C0),
    );
    final turn = _signaturePolygon([
      b,
      b + Offset(-u * .046, u * .033),
      b + Offset(0, u * .057),
    ]);
    layer(turn, const Color(0xFFB7B1C7), lift: .0015);
    line(b, b + Offset(-u * .046, u * .033), const Color(0x8A697A68), .0012);
  }
}
