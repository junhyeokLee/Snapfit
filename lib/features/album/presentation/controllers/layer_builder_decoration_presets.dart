part of 'layer_builder.dart';

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
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFAED1F3), Color(0xFFBFD9F6)],
                ),
              ),
            ),
          ),
          Positioned(
            left: -layer.width * 0.08,
            bottom: -layer.height * 0.03,
            child: Container(
              width: layer.width * 0.42,
              height: layer.height * 0.22,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.24),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            right: -layer.width * 0.1,
            bottom: layer.height * 0.08,
            child: Container(
              width: layer.width * 0.5,
              height: layer.height * 0.26,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _PaperNoisePainter(opacity: 0.04)),
          ),
        ],
      ),
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
  final Gradient? gradient;
  switch (layer.imageBackground) {
    case 'paperBeige':
      color = const Color(0xFFE9E0CF);
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF1E8D7), Color(0xFFE5DCC9)],
      );
      break;
    case 'paperBrown':
    case 'paperBrownLined':
      color = const Color(0xFFD2B295);
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFDCC3A8), Color(0xFFC6A585)],
      );
      break;
    case 'paperBrownPlain':
      color = const Color(0xFFCDB08E);
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD6BA99), Color(0xFFC19F7C)],
      );
      break;
    case 'paperYellow':
      color = const Color(0xFFF6E18E);
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF0DE89), Color(0xFFE8D476)],
      );
      break;
    case 'paperPink':
      color = const Color(0xFFF1C5B4);
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF3D0C3), Color(0xFFE7B6A4)],
      );
      break;
    case 'paperWarm':
      color = const Color(0xFFF4EBDD);
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF6EDE0), Color(0xFFECDDCB)],
      );
      break;
    case 'paperWhite':
      color = const Color(0xFFF7F7F3);
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFAFAF7), Color(0xFFF0F0EC)],
      );
      break;
    case 'paperGray':
      color = const Color(0xFFEDEDED);
      gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF1F1F1), Color(0xFFE3E3E3)],
      );
      break;
    default:
      color = Colors.white;
      gradient = null;
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
          child: Container(
            decoration: BoxDecoration(color: color, gradient: gradient),
          ),
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
