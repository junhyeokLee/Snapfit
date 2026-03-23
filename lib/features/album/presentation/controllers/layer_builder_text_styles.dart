part of 'layer_builder.dart';

Color _roundStyleBackgroundColor(String? key) {
  switch (key) {
    case 'roundGray':
      return SnapFitStylePalette.gray;
    case 'roundPink':
      return SnapFitStylePalette.pink;
    case 'roundBlue':
      return SnapFitStylePalette.blue;
    case 'roundMint':
      return SnapFitStylePalette.mint;
    case 'roundLavender':
      return SnapFitStylePalette.lavender;
    case 'roundOrange':
      return SnapFitStylePalette.orange;
    case 'roundGreen':
      return SnapFitStylePalette.green;
    case 'roundCream':
      return SnapFitStylePalette.cream;
    case 'roundNavy':
      return SnapFitStylePalette.navy;
    case 'roundRose':
      return SnapFitStylePalette.rose;
    case 'roundCoral':
      return SnapFitStylePalette.coral;
    case 'roundBeige':
      return SnapFitStylePalette.beige;
    case 'roundTeal':
      return SnapFitStylePalette.teal;
    case 'roundLemon':
      return SnapFitStylePalette.lemon;
    default:
      return SnapFitStylePalette.white;
  }
}

/// 라운드 – pill (색상 선택 가능)
Widget _buildRoundStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
  final bg = _roundStyleBackgroundColor(layer.textBackground);
  final borderColor = bg == Colors.white
      ? const Color(0xFFE8EAED)
      : _darken(bg, 0.08);
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

Color _darken(Color c, double amount) {
  return Color.fromARGB(
    c.alpha,
    (c.red * (1 - amount)).round().clamp(0, 255),
    (c.green * (1 - amount)).round().clamp(0, 255),
    (c.blue * (1 - amount)).round().clamp(0, 255),
  );
}

/// 사각형 계열 배경색 (팔레트 통일, 10색)
Color _squareStyleBackgroundColor(String? key) {
  switch (key) {
    case 'squareGray':
      return SnapFitStylePalette.gray;
    case 'squarePink':
      return SnapFitStylePalette.pink;
    case 'squareBlue':
      return SnapFitStylePalette.blue;
    case 'squareMint':
      return SnapFitStylePalette.mint;
    case 'squareLavender':
      return SnapFitStylePalette.lavender;
    case 'squareOrange':
      return SnapFitStylePalette.orange;
    case 'squareGreen':
      return SnapFitStylePalette.green;
    case 'squareCream':
      return SnapFitStylePalette.cream;
    case 'squareNavy':
      return SnapFitStylePalette.navy;
    case 'squareRose':
      return SnapFitStylePalette.rose;
    case 'squareCoral':
      return SnapFitStylePalette.coral;
    case 'squareBeige':
      return SnapFitStylePalette.beige;
    case 'squareTeal':
      return SnapFitStylePalette.teal;
    case 'squareLemon':
      return SnapFitStylePalette.lemon;
    default:
      return SnapFitStylePalette.white;
  }
}

/// 기본 – 사각형 (색상 선택 가능)
Widget _buildSquareStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
  final bg = _squareStyleBackgroundColor(layer.textBackground);
  final borderColor = bg == Colors.white
      ? const Color(0xFFE0E4EC)
      : _darken(bg, 0.08);
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
Color _roundSoftStyleBackgroundColor(String? key) {
  switch (key) {
    case 'roundSoftGray':
      return SnapFitStylePalette.gray;
    case 'roundSoftPink':
      return SnapFitStylePalette.pink;
    case 'roundSoftBlue':
      return SnapFitStylePalette.blue;
    case 'roundSoftMint':
      return SnapFitStylePalette.mint;
    case 'roundSoftLavender':
      return SnapFitStylePalette.lavender;
    case 'roundSoftOrange':
      return SnapFitStylePalette.orange;
    case 'roundSoftGreen':
      return SnapFitStylePalette.green;
    case 'roundSoftCream':
      return SnapFitStylePalette.cream;
    case 'roundSoftNavy':
      return SnapFitStylePalette.navy;
    case 'roundSoftRose':
      return SnapFitStylePalette.rose;
    case 'roundSoftCoral':
      return SnapFitStylePalette.coral;
    case 'roundSoftBeige':
      return SnapFitStylePalette.beige;
    case 'roundSoftTeal':
      return SnapFitStylePalette.teal;
    case 'roundSoftLemon':
      return SnapFitStylePalette.lemon;
    default:
      return SnapFitStylePalette.white;
  }
}

/// 기본 – 소프트 필 (색상 선택 가능, 그림자 적용)
Widget _buildRoundSoftStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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
Color _softPill2StyleBackgroundColor(String? key) {
  switch (key) {
    case 'softPill2Gray':
      return SnapFitStylePalette.gray;
    case 'softPill2Pink':
      return SnapFitStylePalette.pink;
    case 'softPill2Blue':
      return SnapFitStylePalette.blue;
    case 'softPill2Mint':
      return SnapFitStylePalette.mint;
    case 'softPill2Lavender':
      return SnapFitStylePalette.lavender;
    case 'softPill2Orange':
      return SnapFitStylePalette.orange;
    case 'softPill2Green':
      return SnapFitStylePalette.green;
    case 'softPill2Cream':
      return SnapFitStylePalette.cream;
    case 'softPill2Navy':
      return SnapFitStylePalette.navy;
    case 'softPill2Rose':
      return SnapFitStylePalette.rose;
    case 'softPill2Coral':
      return SnapFitStylePalette.coral;
    case 'softPill2Beige':
      return SnapFitStylePalette.beige;
    case 'softPill2Teal':
      return SnapFitStylePalette.teal;
    case 'softPill2Lemon':
      return SnapFitStylePalette.lemon;
    default:
      return SnapFitStylePalette.white;
  }
}

/// 기본 – 소프트 필2 (사각형, 라운드 없음, 그림자)
Widget _buildSoftPill2Style(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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

({Color bg, Color text}) _labelOvalColors(String? key) {
  switch (key) {
    case 'labelGray':
      return (bg: SnapFitStylePalette.labelGray, text: const Color(0xFF616161));
    case 'labelPink':
      return (bg: SnapFitStylePalette.labelPink, text: const Color(0xFFAD1457));
    case 'labelBlue':
      return (bg: SnapFitStylePalette.labelBlue, text: const Color(0xFF1565C0));
    case 'labelMint':
      return (bg: SnapFitStylePalette.labelMint, text: const Color(0xFF00695C));
    case 'labelLavender':
      return (
        bg: SnapFitStylePalette.labelLavender,
        text: const Color(0xFF5E35B1),
      );
    case 'labelOrange':
      return (
        bg: SnapFitStylePalette.labelOrange,
        text: const Color(0xFFE65100),
      );
    case 'labelGreen':
      return (
        bg: SnapFitStylePalette.labelGreen,
        text: const Color(0xFF2E7D32),
      );
    case 'labelWhite':
      return (
        bg: SnapFitStylePalette.labelWhite,
        text: const Color(0xFF424242),
      );
    case 'labelCream':
      return (
        bg: SnapFitStylePalette.labelCream,
        text: const Color(0xFF5D4037),
      );
    default:
      return (
        bg: SnapFitColors.accent.withOpacity(0.25),
        text: SnapFitColors.accent,
      );
  }
}

/// 라벨 – 타원형 (색상 선택 가능)
Widget _buildLabelOvalStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
  final colors = _labelOvalColors(layer.textBackground);
  final style = effectiveStyle.copyWith(
    fontWeight: FontWeight.w600,
    color: colors.text,
  );
  return IntrinsicWidth(
    child: IntrinsicHeight(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(999),
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

Color _tagBorderColor(String? key) {
  switch (key) {
    case 'tagGray':
      return SnapFitStylePalette.tagGray;
    case 'tagPink':
      return SnapFitStylePalette.tagPink;
    case 'tagBlue':
      return SnapFitStylePalette.tagBlue;
    case 'tagMint':
      return SnapFitStylePalette.tagMint;
    case 'tagLavender':
      return SnapFitStylePalette.tagLavender;
    case 'tagOrange':
      return SnapFitStylePalette.tagOrange;
    case 'tagGreen':
      return SnapFitStylePalette.tagGreen;
    case 'tagRed':
      return const Color(0xFFE57373);
    default:
      return const Color(0xFFB0B0B0);
  }
}

/// 태그 – 점선 테두리 (색상 선택 가능)
Widget _buildTagStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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
              child: Text(
                layer.text ?? "",
                style: style,
                textAlign: layer.textAlign ?? TextAlign.center,
              ),
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

({Color bg, Color text}) _labelSolidColors(String? key) {
  switch (key) {
    case 'labelSolidGray':
      return (bg: const Color(0xFF616161), text: Colors.white);
    case 'labelSolidPink':
      return (bg: const Color(0xFFAD1457), text: Colors.white);
    case 'labelSolidBlue':
      return (bg: const Color(0xFF1565C0), text: Colors.white);
    case 'labelSolidMint':
      return (bg: const Color(0xFF00695C), text: Colors.white);
    case 'labelSolidRed':
      return (bg: const Color(0xFFC62828), text: Colors.white);
    case 'labelSolidGreen':
      return (bg: const Color(0xFF2E7D32), text: Colors.white);
    case 'labelSolidOrange':
      return (bg: const Color(0xFFE65100), text: Colors.white);
    case 'labelSolidLavender':
      return (bg: const Color(0xFF5E35B1), text: Colors.white);
    case 'labelSolidCream':
      return (bg: const Color(0xFFF5F0E6), text: const Color(0xFF5D4037));
    default:
      return (bg: const Color(0xFF1E3A5F), text: Colors.white);
  }
}

/// 라벨 – 진한 채움 (색상 선택 가능)
Widget _buildLabelSolidStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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

/// 라벨 – 아웃라인만 (TODAY 스타일)
Widget _buildLabelOutlineStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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

/// 라벨 – 골드 프리미엄
Widget _buildLabelGoldStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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

/// 라벨 – 네온 아웃라인
Widget _buildLabelNeonStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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

/// 라벨 – 로즈 (로즈골드/핑크 채움)
Widget _buildLabelRoseStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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
            colors: [const Color(0xFFF8BBD9), const Color(0xFFF48FB1)],
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

/// 말풍선 채움 색상 (팔레트 통일, 10색)
Color _bubbleFillColor(String? key) {
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

Widget _buildBubbleStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
  final baseStyle = effectiveStyle;
  final style = baseStyle.copyWith(fontWeight: FontWeight.w500, height: 1.2);
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
  final isSquare =
      baseKey == 'bubbleSquare' ||
      baseKey == 'bubbleSquareCenter' ||
      baseKey == 'bubbleSquareRight';
  final tailPosition = isSquare
      ? (baseKey == 'bubbleSquare'
            ? 0.0
            : baseKey == 'bubbleSquareRight'
            ? 1.0
            : 0.5)
      : (baseKey == 'bubbleCenter'
            ? 0.5
            : baseKey == 'bubbleRight'
            ? 0.72
            : 0.28);
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

Color _noteStyleBackgroundColor(String? key) {
  final k = (key ?? '')
      .replaceFirst('noteTornRough', 'noteTorn')
      .replaceFirst('noteTornSoft', 'noteTorn');
  switch (k) {
    case "noteBlue":
      return const Color(0xFFE8F0FF);
    case "notePink":
      return const Color(0xFFFFEFF4);
    case "noteMint":
      return const Color(0xFFE0F7F0);
    case "noteLavender":
      return const Color(0xFFF3E8FF);
    case "noteOrange":
      return const Color(0xFFFFF0E0);
    case "noteGray":
      return const Color(0xFFF0F0F0);
    case "noteBeige":
      return const Color(0xFFF5F0E8);
    case "noteGold":
      return const Color(0xFFFFF8E1);
    case "noteCream":
      return const Color(0xFFFFFBF0);
    case "noteTornGray":
      return const Color(0xFFF0F0F0);
    case "noteTornPink":
      return const Color(0xFFFFEFF4);
    case "noteTornBlue":
      return const Color(0xFFE8F0FF);
    case "noteTornMint":
      return const Color(0xFFE0F7F0);
    case "noteTornLavender":
      return const Color(0xFFF3E8FF);
    case "noteTornOrange":
      return const Color(0xFFFFF0E0);
    case "noteTornCream":
      return const Color(0xFFFFFBF0);
    case "noteTornBeige":
      return const Color(0xFFF5F0E8);
    case "noteTornYellow":
      return const Color(0xFFFFF9C4);
    case "noteTornGold":
      return const Color(0xFFFFF8E1);
    case "note":
    case "noteTorn":
    default:
      return const Color(0xFFFFF9C4);
  }
}

String? _normalizeTornTapeKey(String? key) {
  if (key == null) return null;
  return key
      .replaceFirst('tapeTornRough', 'tapeTorn')
      .replaceFirst('tapeTornSoft', 'tapeTorn');
}

/// 메모지 – 찢어짐 없음, 스티커노트 느낌, 여러 색상 (테두리 없음)
Widget _buildNoteStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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
Widget _buildNoteTornStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
  final style = effectiveStyle.copyWith(height: 1.25);
  final background = _noteStyleBackgroundColor(layer.textBackground);
  final (step, amp) = _tornEdgeParamsImpl(layer.textBackground ?? 'noteTorn');
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
Widget _buildTapeTornStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
  final style = effectiveStyle.copyWith(fontWeight: FontWeight.w500);
  final bg = layer.textBackground ?? 'tapeTornSolid';
  final solidKey = _tapeTornToSolidKeyImpl(bg);
  final colors = _tapeSolidColors(solidKey);
  final (step, amp) = _tornEdgeParamsImpl(bg);
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
Widget _buildTapeTornSolidStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
  return _buildTapeTornStyle(layer, painter, effectiveStyle);
}

Widget _buildCalligraphyStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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

Widget _buildStickerStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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
Widget _buildHighlightStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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
  final style = effectiveStyle.copyWith(
    color: textColor,
    fontWeight: FontWeight.w700,
  );
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
Widget _buildStampStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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
          border: Border.all(
            color: isRed ? const Color(0xFFE53935) : const Color(0xFF1976D2),
            width: 1.5,
          ),
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
Widget _buildQuoteStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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
Widget _buildChalkboardStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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
Widget _buildCaptionStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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

({Color bg, Color grid}) _noteGridColors(String? key) {
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
Widget _buildNoteGridStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
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
              padding: const EdgeInsets.symmetric(
                horizontal: padH,
                vertical: padV,
              ),
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
({Color base, Color dot}) _tapeDotsColors(String? key) {
  switch (key) {
    case 'tapeDotsPink':
      return (
        base: SnapFitStylePalette.labelPink,
        dot: SnapFitStylePalette.tagPink,
      );
    case 'tapeDotsMint':
      return (base: SnapFitStylePalette.mint, dot: SnapFitStylePalette.tagMint);
    case 'tapeDotsLavender':
      return (
        base: SnapFitStylePalette.lavender,
        dot: SnapFitStylePalette.tagLavender,
      );
    case 'tapeDotsOrange':
      return (
        base: SnapFitStylePalette.orange,
        dot: SnapFitStylePalette.tagOrange,
      );
    case 'tapeDotsGray':
      return (
        base: SnapFitStylePalette.stripeGrayBase,
        dot: SnapFitStylePalette.stripeGrayStripe,
      );
    default:
      return (base: const Color(0xFFFFE0B2), dot: const Color(0xFFFFCC80));
  }
}

/// 이중 스트라이프 테이프용 base/stripe 색상 (6색 통일)
({Color base, Color stripe}) _tapeDoubleColors(String? key) {
  switch (key) {
    case 'tapeDoublePink':
      return (base: SnapFitStylePalette.pink, stripe: const Color(0xFFFFCDD2));
    case 'tapeDoubleMint':
      return (base: SnapFitStylePalette.mint, stripe: const Color(0xFFA7FFEB));
    case 'tapeDoubleBlue':
      return (base: const Color(0xFFE3F2FD), stripe: const Color(0xFF90CAF9));
    case 'tapeDoubleLavender':
      return (
        base: SnapFitStylePalette.lavender,
        stripe: const Color(0xFFB39DDB),
      );
    case 'tapeDoubleGray':
      return (
        base: SnapFitStylePalette.stripeGrayBase,
        stripe: SnapFitStylePalette.stripeGrayStripe,
      );
    default:
      return (base: const Color(0xFFE3F2FD), stripe: const Color(0xFF90CAF9));
  }
}

/// 단색 테이프 (크래프트·골드 통일 + 기본 색상)
({Color bg, Color text}) _tapeSolidColors(String? key) {
  switch (key) {
    case 'tapeKraft':
      return (bg: const Color(0xFFD7CCC8), text: const Color(0xFF5D4037));
    case 'tapeGold':
      return (bg: const Color(0xFFE8D4A8), text: const Color(0xFF5D4037));
    case 'tapeSolidWhite':
      return (bg: const Color(0xFFFAFAFA), text: const Color(0xFF424242));
    case 'tapeSolidGray':
      return (bg: const Color(0xFFE0E0E0), text: const Color(0xFF424242));
    case 'tapeSolidPink':
      return (bg: const Color(0xFFFFCDD2), text: const Color(0xFFAD1457));
    case 'tapeSolidBlue':
      return (bg: const Color(0xFFBBDEFB), text: const Color(0xFF1565C0));
    case 'tapeSolidMint':
      return (bg: const Color(0xFFB2DFDB), text: const Color(0xFF00695C));
    case 'tapeSolidLavender':
      return (bg: const Color(0xFFD1C4E9), text: const Color(0xFF5E35B1));
    case 'tapeSolidOrange':
      return (bg: const Color(0xFFFFE0B2), text: const Color(0xFFE65100));
    case 'tapeSolidGreen':
      return (bg: const Color(0xFFC8E6C9), text: const Color(0xFF2E7D32));
    default:
      return (bg: const Color(0xFFD7CCC8), text: const Color(0xFF5D4037));
  }
}

/// 스트라이프 테이프용 base/stripe 색상 (팔레트 통일)
({Color base, Color stripe}) _stripeTapeColors(String key) {
  switch (key) {
    case 'tape':
      return (
        base: SnapFitStylePalette.stripeSkyBase,
        stripe: SnapFitStylePalette.stripeSkyStripe,
      );
    case 'tapeYellow':
      return (
        base: SnapFitStylePalette.stripeYellowBase,
        stripe: SnapFitStylePalette.stripeYellowStripe,
      );
    case 'tapePink':
      return (
        base: SnapFitStylePalette.stripePinkBase,
        stripe: SnapFitStylePalette.stripePinkStripe,
      );
    case 'tapeMint':
      return (
        base: SnapFitStylePalette.stripeMintBase,
        stripe: SnapFitStylePalette.stripeMintStripe,
      );
    case 'tapeLavender':
      return (
        base: SnapFitStylePalette.stripeLavenderBase,
        stripe: SnapFitStylePalette.stripeLavenderStripe,
      );
    case 'tapeGray':
      return (
        base: SnapFitStylePalette.stripeGrayBase,
        stripe: SnapFitStylePalette.stripeGrayStripe,
      );
    default:
      return (
        base: SnapFitStylePalette.stripeSkyBase,
        stripe: SnapFitStylePalette.stripeSkyStripe,
      );
  }
}

Widget _buildTapeStyle(
  LayerModel layer,
  TextPainter painter,
  TextStyle effectiveStyle,
) {
  final style = effectiveStyle.copyWith(fontWeight: FontWeight.w500);
  final bg = layer.textBackground ?? 'tape';

  // 스트라이프 디자인 통일: tape, tapeYellow, tapePink, tapeMint, tapeLavender, tapeGray
  const stripeKeys = [
    'tape',
    'tapeYellow',
    'tapePink',
    'tapeMint',
    'tapeLavender',
    'tapeGray',
  ];
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

  const dotsKeys = [
    'tapeDots',
    'tapeDotsPink',
    'tapeDotsMint',
    'tapeDotsLavender',
    'tapeDotsOrange',
    'tapeDotsGray',
  ];
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
              padding: const EdgeInsets.symmetric(
                horizontal: padH,
                vertical: padV,
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
      ),
    );
  }

  const solidTapeKeys = [
    'tapeKraft',
    'tapeGold',
    'tapeSolidWhite',
    'tapeSolidGray',
    'tapeSolidPink',
    'tapeSolidBlue',
    'tapeSolidMint',
    'tapeSolidLavender',
    'tapeSolidOrange',
    'tapeSolidGreen',
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

  const doubleKeys = [
    'tapeDouble',
    'tapeDoublePink',
    'tapeDoubleMint',
    'tapeDoubleBlue',
    'tapeDoubleLavender',
    'tapeDoubleGray',
  ];
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
