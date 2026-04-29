part of 'layer_builder.dart';

Color? _parseHexColor(String? raw) {
  if (raw == null) return null;
  var value = raw.trim();
  if (value.isEmpty) return null;
  if (!value.startsWith('#')) value = '#$value';
  final hex = value.substring(1);
  if (hex.length == 6) {
    return Color(int.parse('FF$hex', radix: 16));
  }
  if (hex.length == 8) {
    return Color(int.parse(hex, radix: 16));
  }
  return null;
}

Widget? _buildExplicitDecoration(LayerModel layer) {
  final fill = _parseHexColor(layer.decorationFillColor);
  final border = _parseHexColor(layer.decorationBorderColor);
  final radiusRaw = layer.decorationCornerRadius;
  final borderWidthRaw = layer.decorationBorderWidth;

  if (fill == null &&
      border == null &&
      radiusRaw == null &&
      borderWidthRaw == null) {
    return null;
  }

  final radius = radiusRaw == null
      ? 0.0
      : (radiusRaw <= 1.0
            ? radiusRaw * math.min(layer.width, layer.height)
            : radiusRaw);
  final borderWidth = borderWidthRaw == null
      ? 1.0
      : (borderWidthRaw <= 1.0 ? borderWidthRaw * layer.width : borderWidthRaw);

  return SizedBox(
    width: layer.width,
    height: layer.height,
    child: Container(
      decoration: BoxDecoration(
        color: fill ?? Colors.transparent,
        borderRadius: radius > 0 ? BorderRadius.circular(radius) : null,
        border: border != null
            ? Border.all(color: border, width: borderWidth)
            : null,
      ),
    ),
  );
}

Widget? _buildPresetDecoration(LayerModel layer) {
  if (layer.imageBackground == 'notebookPunchPage') {
    return Stack(
      children: [
        Container(
          width: layer.width,
          height: layer.height,
          color: const Color(0xFFF8F8F6),
          child: CustomPaint(painter: _PaperNoisePainter(opacity: 0.055)),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: layer.width * 0.105,
          child: Container(color: const Color(0xFFEFEFEB)),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  15,
                  (_) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 1.2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: layer.width * 0.12,
          top: 0,
          bottom: 0,
          width: 1,
          child: Container(color: const Color(0xFFE6E6E1)),
        ),
      ],
    );
  }

  if (layer.imageBackground == 'ivoryGridPaper') {
    return SizedBox(
      width: layer.width,
      height: layer.height,
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFFF3EEE0))),
          Positioned.fill(
            child: CustomPaint(
              painter: _GridLinePainter(
                color: const Color(0xFFE0D7C5),
                step: 18.0,
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _PaperNoisePainter(opacity: 0.05)),
          ),
        ],
      ),
    );
  }

  if (layer.imageBackground == 'cloudSkyBlue') {
    return SizedBox(
      width: layer.width,
      height: layer.height,
      child: Container(color: const Color(0xFFDCE7EF)),
    );
  }

  if (layer.imageBackground == 'deepNavy') {
    return SizedBox(
      width: layer.width,
      height: layer.height,
      child: Container(color: const Color(0xFF24374A)),
    );
  }

  if (layer.imageBackground == 'minimalGray') {
    return SizedBox(
      width: layer.width,
      height: layer.height,
      child: Container(color: const Color(0xFFD8DEE6)),
    );
  }

  if (layer.imageBackground == 'darkVignette') {
    return Container(
      width: layer.width,
      height: layer.height,
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0.08, -0.10),
          radius: 1.05,
          colors: [Color(0xFF4A5E8D), Color(0xFF2E2C3E), Color(0xFF0C0C10)],
          stops: [0.0, 0.48, 1.0],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFCB6F2B).withOpacity(0.28),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55],
          ),
        ),
      ),
    );
  }

  if (layer.imageBackground == 'saveDateHeroGradient') {
    return Container(
      width: layer.width,
      height: layer.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF6B92B3), Color(0xFFA98276)],
        ),
      ),
    );
  }
  if (layer.imageBackground == 'saveDateTopTint') {
    return Container(
      width: layer.width,
      height: layer.height,
      color: const Color(0x338EC5E8),
    );
  }
  if (layer.imageBackground == 'saveDateBottomTint') {
    return Container(
      width: layer.width,
      height: layer.height,
      color: const Color(0x2EE8A580),
    );
  }
  if (layer.imageBackground == 'saveDateHaze') {
    return Container(
      width: layer.width,
      height: layer.height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(220),
      ),
    );
  }

  if (layer.imageBackground == 'chipPill' ||
      layer.imageBackground == 'chipPillDark') {
    return Container(
      width: layer.width,
      height: layer.height,
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withOpacity(0.42),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
  if (layer.imageBackground == 'chipPillLight') {
    return Container(
      width: layer.width,
      height: layer.height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  if (layer.imageBackground == 'blossomPinkDust') {
    return SizedBox(
      width: layer.width,
      height: layer.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF294B2),
                    Color(0xFFE07EA0),
                    Color(0xFFD56F95),
                  ],
                  stops: [0.0, 0.58, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _PaperNoisePainter(opacity: 0.08)),
          ),
        ],
      ),
    );
  }

  if (layer.imageBackground == 'dreamyNightSky') {
    return SizedBox(
      width: layer.width,
      height: layer.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1D235A),
                    Color(0xFF20266A),
                    Color(0xFF11153A),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _PaperNoisePainter(opacity: 0.07)),
          ),
        ],
      ),
    );
  }

  if (layer.imageBackground == 'softSkyBloom') {
    return SizedBox(
      width: layer.width,
      height: layer.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF8CB8E8),
                    Color(0xFF8BB6E4),
                    Color(0xFFA8C9EC),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -layer.width * 0.10,
            bottom: -layer.height * 0.06,
            child: Container(
              width: layer.width * 0.56,
              height: layer.height * 0.24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.24),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            right: -layer.width * 0.12,
            bottom: layer.height * 0.08,
            child: Container(
              width: layer.width * 0.54,
              height: layer.height * 0.22,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  return null;
}

Widget _buildPaperTextureDecoration(LayerModel layer) {
  final Color color;
  switch (layer.imageBackground) {
    case 'paperBeige':
      color = const Color(0xFFE9DDCB);
      break;
    case 'paperBrown':
    case 'paperBrownLined':
      color = const Color(0xFFD8C7B5);
      break;
    case 'paperBrownPlain':
      color = const Color(0xFFCDB08E);
      break;
    case 'paperYellow':
      color = const Color(0xFFF6E6B0);
      break;
    case 'paperPink':
      color = const Color(0xFFF1DDE2);
      break;
    case 'paperWarm':
      color = const Color(0xFFF1E6D8);
      break;
    case 'paperWhiteWarm':
      color = const Color(0xFFF7F1E8);
      break;
    case 'paperWhite':
      color = const Color(0xFFFFFFFF);
      break;
    case 'paperGray':
      color = const Color(0xFFE9EDF2);
      break;
    default:
      color = Colors.white;
  }

  final bool linedBrown =
      layer.imageBackground == 'paperBrown' ||
      layer.imageBackground == 'paperBrownLined';
  final bool texturedPaper =
      layer.imageBackground == 'paperWhite' ||
      layer.imageBackground == 'paperWarm' ||
      layer.imageBackground == 'paperBeige' ||
      layer.imageBackground == 'paperYellow' ||
      layer.imageBackground == 'paperBrownPlain' ||
      linedBrown;

  return SizedBox(
    width: layer.width,
    height: layer.height,
    child: Stack(
      children: [
        Positioned.fill(
          child: Container(decoration: BoxDecoration(color: color)),
        ),
        if (texturedPaper)
          Positioned.fill(
            child: CustomPaint(
              painter: _PaperNoisePainter(opacity: linedBrown ? 0.06 : 0.05),
            ),
          ),
        if (linedBrown)
          Positioned.fill(
            child: CustomPaint(
              painter: _HorizontalRulePainter(
                color: const Color(0xFFB8936E).withOpacity(0.28),
                gap: 18,
                stroke: 0.8,
              ),
            ),
          ),
      ],
    ),
  );
}
