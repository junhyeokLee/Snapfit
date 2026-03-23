part of 'layer_builder.dart';

/// 소프트 글로우 – 바텀시트와 동일: 그라데이션 FFF5FB→E9F4FF, 24r, 패딩 10, 사진 20r
Widget _frameSoftGlowImpl(Widget image) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF5FB), Color(0xFFE9F4FF)],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(20), child: image),
  );
}

/// 아티스틱 브러쉬 – 바텀시트와 동일: 흰색 24r/E0E4F2 2, 내부 F7F8FF 20r/D0D7F0 1.4
Widget _frameVintageImpl(Widget image) {
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
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: image),
    ),
  );
}

/// 스케치 – 바텀시트와 동일: 투명 4r, black87 1.5, 패딩 4, 사진 2r
Widget _frameSketchImpl(Widget image) {
  return Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.black87, width: 1.5),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(2), child: image),
  );
}

/// 스티커 프레임 – 바텀시트와 동일: 흰색 10r, 검정 2, 패딩 4, 사진 6r
Widget _frameStickerImpl(Widget image) {
  return Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.black, width: 2),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(6), child: image),
  );
}

/// 빈티지 필름 스트립 – 폴라로이드와 비슷한 세로 카드 비율
Widget _frameFilmImpl(Widget image) {
  return Center(
    child: AspectRatio(
      aspectRatio: 3 / 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final outerPadX = (w * 0.06).clamp(2.0, 6.0);
          final outerPadY = (h * 0.06).clamp(2.0, 8.0);
          final sideW = (w * 0.08).clamp(3.0, 10.0);
          final gap = (w * 0.03).clamp(1.0, 4.0);
          final dotSize = (math.min(w, h) * 0.04).clamp(1.5, 4.5);

          Widget sideDots() {
            return SizedBox(
              width: sideW,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (_) {
                  return Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D4556),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
            );
          }

          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: outerPadX,
              vertical: outerPadY,
            ),
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
                sideDots(),
                SizedBox(width: gap),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      color: const Color(0xFF1E2433),
                      child: SizedBox.expand(child: image),
                    ),
                  ),
                ),
                SizedBox(width: gap),
                sideDots(),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// 정사각 필름 프레임 (포스터 느낌)
Widget _frameFilmSquareImpl(Widget image) {
  return Center(
    child: AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;
          final pad = (h * 0.04).clamp(4.0, 8.0);
          final sideGap = (w * 0.02).clamp(3.0, 7.0);
          final dotSize = (h * 0.045).clamp(2.8, 5.5);
          final dotCount = (h / (dotSize * 2.3)).floor().clamp(4, 9);

          Widget sprocketColumn() {
            return SizedBox(
              width: dotSize + 1.0,
              child: LayoutBuilder(
                builder: (context, c) {
                  final safeH = c.maxHeight.isFinite ? c.maxHeight : h;
                  final count = dotCount.clamp(3, 9);
                  final travel = (safeH - dotSize).clamp(0.0, double.infinity);
                  return Stack(
                    children: [
                      for (int i = 0; i < count; i++)
                        Positioned(
                          left: 0,
                          top: count == 1
                              ? (safeH - dotSize) / 2
                              : (travel * i) / (count - 1),
                          child: Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8E3D8),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          }

          return Container(
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad),
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                sprocketColumn(),
                SizedBox(width: sideGap),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      color: const Color(0xFF1A1A1A),
                      child: SizedBox.expand(child: image),
                    ),
                  ),
                ),
                SizedBox(width: sideGap),
                sprocketColumn(),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// 90s 윈도우 프레임
Widget _frameWin95Impl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final barH = math.min((h * 0.32).clamp(6.0, 22.0), h * 0.55);
      final showTitle = w >= 92;
      final showButtons = w >= 64;
      final btnSize = (barH - 5).clamp(7.0, 12.0);
      final sidePad = w < 80 ? 3.0 : 6.0;

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFC0C0C0),
          border: Border.all(color: const Color(0xFF808080), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              height: barH,
              padding: EdgeInsets.symmetric(horizontal: sidePad),
              color: const Color(0xFF000080),
              child: Row(
                children: [
                  if (showTitle)
                    Expanded(
                      child: Text(
                        'image.exe',
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: (barH * 0.45).clamp(7.0, 11.0),
                        ),
                      ),
                    ),
                  if (showButtons) ...[
                    _win95ButtonImpl(size: btnSize),
                    SizedBox(width: (btnSize * 0.12).clamp(1.0, 2.0)),
                    _win95ButtonImpl(size: btnSize),
                    SizedBox(width: (btnSize * 0.12).clamp(1.0, 2.0)),
                    _win95ButtonImpl(size: btnSize),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: ClipRect(child: SizedBox.expand(child: image)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _win95ButtonImpl({double size = 12}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFC0C0C0),
      border: Border.all(color: const Color(0xFF808080)),
    ),
  );
}

/// 8비트 픽셀 보더
Widget _framePixel8Impl(Widget image) {
  const cornerColors = [
    Color(0xFFFFFF00),
    Color(0xFFFF0000),
    Color(0xFF0000FF),
    Color(0xFF00FF00),
  ];
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
        Positioned(
          top: -2,
          left: -2,
          child: Container(width: 6, height: 6, color: cornerColors[0]),
        ),
        Positioned(
          top: -2,
          right: -2,
          child: Container(width: 6, height: 6, color: cornerColors[1]),
        ),
        Positioned(
          bottom: -2,
          left: -2,
          child: Container(width: 6, height: 6, color: cornerColors[2]),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(width: 6, height: 6, color: cornerColors[3]),
        ),
      ],
    ),
  );
}

/// VHS 글리치
Widget _frameVhsImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final pad = (w * 0.05).clamp(2.0, 6.0);
      final topH = (h * 0.14).clamp(10.0, 16.0);
      final showTop = h >= 34 && w >= 48;
      final showBottom = h >= 40 && w >= 60;
      final playFont = (topH * 0.55).clamp(6.0, 10.0);
      final bottomFont = (h * 0.09).clamp(6.0, 9.0);

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _VhsScanLinePainter())),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showTop)
                    SizedBox(
                      height: topH,
                      child: Row(
                        children: [
                          Text(
                            'PLAY',
                            style: TextStyle(
                              color: const Color(0xFF00FF00),
                              fontSize: playFont,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: (playFont * 0.2).clamp(1.0, 2.0)),
                          Icon(
                            Icons.play_arrow,
                            color: const Color(0xFF00FF00),
                            size: (playFont * 1.2).clamp(7.0, 12.0),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ClipRect(child: SizedBox.expand(child: image)),
                  ),
                  if (showBottom)
                    Center(
                      child: Text(
                        'SP 00:12:44',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: bottomFont,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// 네온 사이버펑크
Widget _frameNeonImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: const Color(0xFF00FFFF), width: 2),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF00FFFF).withOpacity(0.6),
          blurRadius: 8,
          spreadRadius: 0,
        ),
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
Widget _frameCrayonImpl(Widget image) {
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
Widget _frameNotebookImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Row(
      children: [
        _notebookMarginDotsImpl(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.pink.shade100, width: 1),
              ),
            ),
            child: FittedBox(fit: BoxFit.cover, child: image),
          ),
        ),
        _notebookMarginDotsImpl(),
      ],
    ),
  );
}

Widget _notebookMarginDotsImpl() {
  return SizedBox(
    width: 8,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        6,
        (_) => Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: Color(0xFFB0B0B0),
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}

/// 테이프 & 클립
Widget _frameTapeClipImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF8F6F0),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE8E4DC)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
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
        Positioned(
          top: -4,
          left: 0,
          right: 0,
          child: Center(
            child: Icon(
              Icons.attach_file,
              size: 20,
              color: const Color(0xFF505050),
            ),
          ),
        ),
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
Widget _frameComicBubbleImpl(Widget image) {
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
Widget _frameThinDoubleLineImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
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
Widget _frameOffsetColorBlockImpl(Widget image) {
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
Widget _frameFloatingGlassImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFA0B0E0).withOpacity(0.25),
          blurRadius: 16,
        ),
      ],
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
Widget _frameGradientEdgeImpl(Widget image) {
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
Widget _frameTornNotebookImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBF0),
      boxShadow: [
        BoxShadow(
          color: Colors.brown.withOpacity(0.1),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(10, 10, 8, 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: FittedBox(fit: BoxFit.cover, child: image),
    ),
  );
}

/// 오래된 신문 조각
Widget _frameOldNewspaperImpl(Widget image) {
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
        Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: const Color(0xFFD8D0C4),
        ),
        const SizedBox(height: 2),
        Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: const Color(0xFFD8D0C4),
        ),
        const SizedBox(height: 6),
      ],
    ),
  );
}

/// 우표 프레임
Widget _framePostalStampImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: const Color(0xFFC0C0C0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
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
            child: const Text(
              '1924',
              style: TextStyle(fontSize: 8, color: Color(0xFF707070)),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 크라프트 종이
Widget _frameKraftPaperImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFB8956E),
      borderRadius: BorderRadius.circular(4),
      boxShadow: [
        BoxShadow(
          color: Colors.brown.withOpacity(0.2),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
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
Widget _frameGoldFrameImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: const Color(0xFFC9A227), width: 10),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF8B6914).withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.all(4),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(1),
      child: FittedBox(fit: BoxFit.cover, child: image),
    ),
  );
}

Widget _frameBlobImpl(Widget image) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final clipper = _BlobClipper();
      return Stack(
        children: [
          ClipPath(
            clipper: clipper,
            child: Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFEFB),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          ClipPath(
            clipper: clipper,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: image,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ClipPath(
                clipper: clipper,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFE6E0D7),
                      width: 1.0,
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

/// 핑크 스플래터
Widget _framePinkSplatterImpl(Widget image) {
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
Widget _frameToxicGlowImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF0D0D0D),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF39FF14), width: 3),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF39FF14).withOpacity(0.5),
          blurRadius: 12,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: FittedBox(fit: BoxFit.cover, child: image),
    ),
  );
}

/// 스텐실 블록
Widget _frameStencilBlockImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF8F4EC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFD0B898), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.brown.withOpacity(0.06),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FittedBox(fit: BoxFit.cover, child: image),
    ),
  );
}

/// 미드나잇 드립
Widget _frameMidnightDripImpl(Widget image) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF0E8DC),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFD8D0C0)),
      boxShadow: [
        BoxShadow(
          color: Colors.brown.withOpacity(0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
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
Widget _frameVaporStreetImpl(Widget image) {
  return Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFC44DFF), width: 3),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFC44DFF).withOpacity(0.35),
          blurRadius: 10,
        ),
      ],
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
