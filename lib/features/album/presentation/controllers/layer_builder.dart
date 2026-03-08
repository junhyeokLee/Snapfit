import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../shared/snapfit_image.dart';
import '../../domain/entities/layer.dart';
import 'layer_interaction_manager.dart';

/// 이미지/텍스트 레이어의 렌더링과 기본 사이즈 계산 전담
class LayerBuilder {
  final LayerInteractionManager interaction;
  final Size Function() getCoverSize;

  LayerBuilder(this.interaction, this.getCoverSize);

  Size _calculateStyleSize(String type, LayerModel layer, TextPainter painter) {
    final textSize = painter.size;

    switch (type) {
      case "round":
        return Size(textSize.width + 24, textSize.height + 16);
      case "tag":
      case "label":
      case "labelSolid":
      case "labelOutline":
        return Size(textSize.width + 24, textSize.height + 12);
      case "bubble":
      case "bubbleCenter":
      case "bubbleRight":
      case "bubbleSquare":
      case "bubbleSquareCenter":
      case "bubbleSquareRight":
        return Size(textSize.width + 36, textSize.height + 44);
      case "note":
      case "noteBlue":
      case "notePink":
      case "noteMint":
      case "noteLavender":
        return Size(textSize.width + 24, textSize.height + 24);
      case "tape":
      case "tapeYellow":
      case "tapePink":
        return Size(textSize.width + 36, textSize.height + 20);
      case "calligraphy":
        return Size(textSize.width + 32, textSize.height + 20);
      case "sticker":
        return Size(textSize.width + 36, textSize.height + 22);
      default:
        return Size(textSize.width + 20, textSize.height + 10);
    }
  }

  /// 템플릿 적용 시 템플릿 비율 슬롯에 사진이 꽉 차게 cover, 자유 비율이면 cover
  static BoxFit _imageFitForLayer(LayerModel layer) {
    // 템플릿이 있든 없든 모두 cover로 꽉 차게 표시
    return BoxFit.cover;
  }

  /// 이미지 레이어 빌드
  Widget buildImage(LayerModel layer, {bool isCover = false}) {
    // 편집 중인 레이어면 숨김
    if (_isEditing(layer)) return const SizedBox.shrink();

    final fit = _imageFitForLayer(layer);

    if (layer.asset != null) {
      // 아직 업로드 전: 로컬 AssetEntity로 표시
      return interaction.buildInteractiveLayer(
        layer: layer,
        baseWidth: layer.width,
        baseHeight: layer.height,
        isCover: isCover,
        child: Opacity(
          opacity: layer.opacity,
          child: _buildFramedImage(
            layer,
            Image(
              image: AssetEntityImageProvider(layer.asset!),
              fit: fit,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      );
    }

    final url = layer.previewUrl ?? layer.imageUrl ?? layer.originalUrl;
    if (url == null || url.isEmpty) {
      return interaction.buildInteractiveLayer(
        layer: layer,
        baseWidth: layer.width,
        baseHeight: layer.height,
        isCover: isCover,
        child: Opacity(
          opacity: layer.opacity,
          child: _buildImagePlaceholder(layer),
        ),
      );
    }

    return interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: layer.width,
      baseHeight: layer.height,
      isCover: isCover,
      child: Opacity(
        opacity: layer.opacity,
        child: _buildFramedImage(
          layer,
          SnapfitImage(
            key: ValueKey(layer.id), // Stable key to prevent reloading
            urlOrGs: url, 
            fit: fit,
          ),
        ),
      ),
    );
  }

  /// 빈 이미지 슬롯(플레이스홀더) – 템플릿 적용 후 사진을 넣을 자리
  Widget _buildImagePlaceholder(LayerModel layer) {
    final placeholder = Container(
      width: layer.width,
      height: layer.height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400, width: 1.5, style: BorderStyle.solid),
      ),
      child: Center(
        child: Icon(Icons.add_a_photo, size: 28, color: Colors.grey.shade500),
      ),
    );
    return _buildFramedImage(layer, placeholder);
  }

  /// 이미지 프레임 적용 스위치
  Widget _buildFramedImage(LayerModel layer, Widget image) {
    switch (layer.imageBackground) {
      case "circle":
        return _frameCircle(image);
      case "round":
        return _frameRound(image);
      case "polaroid":
        return _framePolaroid(image);
      case "polaroidClassic":
        return _framePolaroidClassic(image);
      case "polaroidWide":
        return _framePolaroidWide(image);
      case "softGlow":
        return _frameSoftGlow(image);
      case "sticker":
        return _frameSticker(image);
      case "vintage":
        return _frameVintage(image);
      case "film":
        return _frameFilm(image);
      case "sketch":
        return _frameSketch(image);
      case "win95":
        return _frameWin95(image);
      case "pixel8":
        return _framePixel8(image);
      case "vhs":
        return _frameVhs(image);
      case "neon":
        return _frameNeon(image);
      case "crayon":
        return _frameCrayon(image);
      case "notebook":
        return _frameNotebook(image);
      case "tapeClip":
        return _frameTapeClip(image);
      case "comicBubble":
        return _frameComicBubble(image);
      case "thinDoubleLine":
        return _frameThinDoubleLine(image);
      case "offsetColorBlock":
        return _frameOffsetColorBlock(image);
      case "floatingGlass":
        return _frameFloatingGlass(image);
      case "gradientEdge":
        return _frameGradientEdge(image);
      case "tornNotebook":
        return _frameTornNotebook(image);
      case "oldNewspaper":
        return _frameOldNewspaper(image);
      case "postalStamp":
        return _framePostalStamp(image);
      case "kraftPaper":
        return _frameKraftPaper(image);
      case "goldFrame":
        return _frameGoldFrame(image);
      case "pinkSplatter":
        return _framePinkSplatter(image);
      case "toxicGlow":
        return _frameToxicGlow(image);
      case "stencilBlock":
        return _frameStencilBlock(image);
      case "midnightDrip":
        return _frameMidnightDrip(image);
      case "vaporStreet":
        return _frameVaporStreet(image);
      default:
        return image;
    }
  }

  /// 기본 원형 – 바텀시트 디자인대로 원형
  Widget _frameCircle(Widget image) {
    return ClipOval(
      child: FittedBox(fit: BoxFit.cover, child: image),
    );
  }

  /// 소프트 라운드 – 바텀시트와 동일: 카드 없이 18px 둥글게
  Widget _frameRound(Widget image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: image,
    );
  }

  /// 공통: 폴라로이드 하단 가로선 (클래식/카드 동일)
  static Widget _polaroidBottomLine() {
    return Container(
      height: 3,
      width: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFD0D3DC),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  /// 클래식 폴라로이드 – 바텀시트 디자인 그대로 (padding 6,6,6,14 / radius 10 / 하단선)
  Widget _framePolaroid(Widget image) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final lineWidth = constraints.maxWidth * 0.45;
        return Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E3EC), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: FittedBox(fit: BoxFit.cover, child: image),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 2.5,
                width: lineWidth,
                child: Center(
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D3DC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 카드 폴라로이드 – 바텀시트 디자인 그대로 (padding 8,8,8,14 / radius 12 / 하단선 full)
  Widget _framePolaroidClassic(Widget image) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E4D8), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: FittedBox(fit: BoxFit.cover, child: image),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFD7D1C2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }

  /// 와이드 폴라로이드 – 바텀시트와 동일: 흰색 6r, 패딩 2/6/2/14, 사진 3r
  Widget _framePolaroidWide(Widget image) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 14),
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
  }

  /// 소프트 글로우 – 바텀시트와 동일: 그라데이션 FFF5FB→E9F4FF, 24r, 패딩 10, 사진 20r
  Widget _frameSoftGlow(Widget image) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF5FB),
            Color(0xFFE9F4FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: image,
      ),
    );
  }

  /// 아티스틱 브러쉬 – 바텀시트와 동일: 흰색 24r/E0E4F2 2, 내부 F7F8FF 20r/D0D7F0 1.4
  Widget _frameVintage(Widget image) {
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: image,
        ),
      ),
    );
  }

  /// 스케치 – 바텀시트와 동일: 투명 4r, black87 1.5, 패딩 4, 사진 2r
  Widget _frameSketch(Widget image) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black87, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: image,
      ),
    );
  }

  /// 스티커 프레임 – 바텀시트와 동일: 흰색 10r, 검정 2, 패딩 4, 사진 6r
  Widget _frameSticker(Widget image) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: image,
      ),
    );
  }


  /// 빈티지 필름 스트립 – 바텀시트 프리뷰와 동일한 구조/색/점 크기
  Widget _frameFilm(Widget image) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
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
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Row(
          children: [
            // 왼쪽 점 4개 (프리뷰와 동일)
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (_) {
                return Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D4556),
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }),
            ),
            const SizedBox(width: 4),
            // 중앙 화면 영역 (사진 + 배경색)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  color: const Color(0xFF1E2433),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: image,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // 오른쪽 점 4개 (프리뷰와 동일)
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (_) {
                return Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D4556),
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// 90s 윈도우 프레임
  Widget _frameWin95(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFC0C0C0),
        border: Border.all(color: const Color(0xFF808080), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            color: const Color(0xFF000080),
            child: Row(
              children: [
                Text('image.exe', style: TextStyle(color: Colors.white, fontSize: 11)),
                const Spacer(),
                _win95Button(),
                const SizedBox(width: 2),
                _win95Button(),
                const SizedBox(width: 2),
                _win95Button(),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: ClipRect(
                child: FittedBox(fit: BoxFit.cover, child: image),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _win95Button() {
    return Container(
      width: 14,
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xFFC0C0C0),
        border: Border.all(color: const Color(0xFF808080)),
      ),
    );
  }

  /// 8비트 픽셀 보더
  Widget _framePixel8(Widget image) {
    const cornerColors = [Color(0xFFFFFF00), Color(0xFFFF0000), Color(0xFF0000FF), Color(0xFF00FF00)];
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54, width: 1),
                ),
                child: FittedBox(fit: BoxFit.cover, child: image),
              ),
            ),
          ),
          Positioned(top: -2, left: -2, child: Container(width: 6, height: 6, color: cornerColors[0])),
          Positioned(top: -2, right: -2, child: Container(width: 6, height: 6, color: cornerColors[1])),
          Positioned(bottom: -2, left: -2, child: Container(width: 6, height: 6, color: cornerColors[2])),
          Positioned(bottom: -2, right: -2, child: Container(width: 6, height: 6, color: cornerColors[3])),
        ],
      ),
    );
  }

  /// VHS 글리치
  Widget _frameVhs(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _VhsScanLinePainter(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('PLAY', style: TextStyle(color: const Color(0xFF00FF00), fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 2),
                    Icon(Icons.play_arrow, color: const Color(0xFF00FF00), size: 12),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: FittedBox(fit: BoxFit.cover, child: image),
                  ),
                ),
                Center(
                  child: Text('SP 00:12:44', style: TextStyle(color: Colors.white70, fontSize: 9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 네온 사이버펑크
  Widget _frameNeon(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF00FFFF), width: 2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00FFFF).withOpacity(0.6), blurRadius: 8, spreadRadius: 0),
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
  Widget _frameCrayon(Widget image) {
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
  Widget _frameNotebook(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          _notebookMarginDots(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.pink.shade100, width: 1)),
              ),
              child: FittedBox(fit: BoxFit.cover, child: image),
            ),
          ),
          _notebookMarginDots(),
        ],
      ),
    );
  }

  Widget _notebookMarginDots() {
    return SizedBox(
      width: 8,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (_) => Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: Color(0xFFB0B0B0),
            shape: BoxShape.circle,
          ),
        )),
      ),
    );
  }

  /// 테이프 & 클립
  Widget _frameTapeClip(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E4DC)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
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
          Positioned(top: -4, left: 0, right: 0, child: Center(child: Icon(Icons.attach_file, size: 20, color: const Color(0xFF505050)))),
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
  Widget _frameComicBubble(Widget image) {
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
  Widget _frameThinDoubleLine(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
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
  Widget _frameOffsetColorBlock(Widget image) {
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
  Widget _frameFloatingGlass(Widget image) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFFA0B0E0).withOpacity(0.25), blurRadius: 16)],
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
  Widget _frameGradientEdge(Widget image) {
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
  Widget _frameTornNotebook(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }

  /// 오래된 신문 조각
  Widget _frameOldNewspaper(Widget image) {
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
          Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFFD8D0C4)),
          const SizedBox(height: 2),
          Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFFD8D0C4)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// 우표 프레임
  Widget _framePostalStamp(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFC0C0C0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))],
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
              child: const Text('1924', style: TextStyle(fontSize: 8, color: Color(0xFF707070))),
            ),
          ),
        ],
      ),
    );
  }

  /// 크라프트 종이
  Widget _frameKraftPaper(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFB8956E),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
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
  Widget _frameGoldFrame(Widget image) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFC9A227), width: 10),
        boxShadow: [BoxShadow(color: const Color(0xFF8B6914).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }

  /// 핑크 스플래터
  Widget _framePinkSplatter(Widget image) {
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
  Widget _frameToxicGlow(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF39FF14), width: 3),
        boxShadow: [BoxShadow(color: const Color(0xFF39FF14).withOpacity(0.5), blurRadius: 12)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }

  /// 스텐실 블록
  Widget _frameStencilBlock(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD0B898), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
    );
  }

  /// 미드나잇 드립
  Widget _frameMidnightDrip(Widget image) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8DC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD8D0C0)),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))],
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
  Widget _frameVaporStreet(Widget image) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC44DFF), width: 3),
        boxShadow: [BoxShadow(color: const Color(0xFFC44DFF).withOpacity(0.35), blurRadius: 10)],
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

  /// 텍스트 레이어 빌드
  Widget buildText(LayerModel layer, {bool isCover = false}) {
    if (_isEditing(layer)) return const SizedBox.shrink();

    // ✅ 기본 생성 텍스트 최소 폰트 크기 (너무 작게 생성되는 것 방지)
    const double minFontSize = 18;

    final TextStyle baseStyle = layer.textStyle ?? const TextStyle(fontSize: 18);

    // ✅ 실제 적용될 스타일 (최소값 보장)
    final TextStyle effectiveStyle = baseStyle.fontSize != null && baseStyle.fontSize! < minFontSize
        ? baseStyle.copyWith(fontSize: minFontSize)
        : baseStyle;

    final coverSize = getCoverSize();
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
          styled = _buildRoundStyle(layer, textPainter, effectiveStyle);
          break;
        case "tag":
        case "label":
          styled = _buildTagStyle(layer, textPainter, effectiveStyle);
          break;
        case "labelSolid":
          styled = _buildLabelSolidStyle(layer, textPainter, effectiveStyle);
          break;
        case "labelOutline":
          styled = _buildLabelOutlineStyle(layer, textPainter, effectiveStyle);
          break;
        case "bubble":
        case "bubbleCenter":
        case "bubbleRight":
        case "bubbleSquare":
        case "bubbleSquareCenter":
        case "bubbleSquareRight":
          styled = _buildBubbleStyle(layer, textPainter, effectiveStyle);
          break;
        case "note":
        case "noteBlue":
        case "notePink":
        case "noteMint":
        case "noteLavender":
          styled = _buildNoteStyle(layer, textPainter, effectiveStyle);
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
          styled = _buildTapeStyle(layer, textPainter, effectiveStyle);
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
      final Size styleSize = _calculateStyleSize(layer.textBackground!, layer, textPainter);
      final realSize = Size(
        styleSize.width,
        styleSize.height + 12,
      );
      interaction.setBaseSize(layer.id, realSize);

      return interaction.buildInteractiveLayer(
        layer: layer,
        baseWidth: realSize.width,
        baseHeight: realSize.height,
        isCover: isCover,
        child: Opacity(
          opacity: layer.opacity,
          child: styled,
        ),
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
    interaction.setBaseSize(layer.id, realSize);

    return interaction.buildInteractiveLayer(
      layer: layer,
      baseWidth: realSize.width,
      baseHeight: realSize.height,
      isCover: isCover,
      child: Opacity(
        opacity: layer.opacity,
        child: content,
      ),
    );
  }

  bool _isEditing(LayerModel layer) {
    return interaction.selectedLayerId == layer.id
        ? false
        : false; // 현재 편집 중 레이어 숨김은 interaction에서 editing id로 제어 가능
  }

  // ImageInfo 프리패치가 필요해지면 여기에 precacheImage 등을 추가한다.

  /// 라운드 – 바텀시트 디자인: 흰색 pill
  Widget _buildRoundStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE0E4EC), width: 1),
          ),
          child: Text(
            layer.text ?? "",
            style: effectiveStyle,
            textAlign: layer.textAlign ?? TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildTagStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3);
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(layer.text ?? "", style: style, textAlign: layer.textAlign),
        ),
      ),
    );
  }

  /// 라벨 – 진한 파랑 채움 (MEMORIES 스타일)
  Widget _buildLabelSolidStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 0.5,
    );
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(layer.text ?? "", style: style, textAlign: layer.textAlign ?? TextAlign.center),
        ),
      ),
    );
  }

  /// 라벨 – 아웃라인만 (TODAY 스타일)
  Widget _buildLabelOutlineStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
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
          child: Text(layer.text ?? "", style: style, textAlign: layer.textAlign ?? TextAlign.center),
        ),
      ),
    );
  }

  Widget _buildBubbleStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(
      fontWeight: FontWeight.w500,
      height: 1.2,
    );
    // 말풍선: 라운드(0.28/0.5/0.72) 사각형(0/0.5/1) – 꼬리가 가장자리에서 살짝 안쪽으로
    final bg = layer.textBackground ?? '';
    final isSquare = bg == 'bubbleSquare' || bg == 'bubbleSquareCenter' || bg == 'bubbleSquareRight';
    final tailPosition = isSquare
        ? (bg == 'bubbleSquare' ? 0.0 : bg == 'bubbleSquareRight' ? 1.0 : 0.5)
        : (bg == 'bubbleCenter' ? 0.5 : bg == 'bubbleRight' ? 0.72 : 0.28);

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: CustomPaint(
          painter: _BubbleBackgroundPainter(
            fillColor: Colors.white,
            borderColor: Colors.black.withOpacity(0.22),
            tailPosition: tailPosition,
            shapeSquare: isSquare,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
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

  /// 메모지 – 찢어짐 없음, 스티커노트 느낌, 여러 색상
  Widget _buildNoteStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final baseStyle = effectiveStyle;
    final style = baseStyle.copyWith(height: 1.25);

    Color background;
    Color border;
    switch (layer.textBackground) {
      case "noteBlue":
        background = const Color(0xFFE8F0FF);
        border = const Color(0xFFBBC8EC);
        break;
      case "notePink":
        background = const Color(0xFFFFEFF4);
        border = const Color(0xFFE4B4C7);
        break;
      case "noteMint":
        background = const Color(0xFFE0F7F0);
        border = const Color(0xFFB0D9CC);
        break;
      case "noteLavender":
        background = const Color(0xFFF3E8FF);
        border = const Color(0xFFD4C0EB);
        break;
      case "note":
      default:
        background = const Color(0xFFFFF9C4);
        border = Colors.brown.withOpacity(0.35);
        break;
    }

    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            layer.text ?? "",
            style: style,
            textAlign: layer.textAlign,
          ),
        ),
      ),
    );
  }

  Widget _buildCalligraphyStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
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
          child: Text(
            layer.text ?? "",
            style: style,
            textAlign: layer.textAlign,
          ),
        ),
      ),
    );
  }

  Widget _buildStickerStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
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
          child: Text(
            layer.text ?? "",
            style: style,
            textAlign: layer.textAlign,
          ),
        ),
      ),
    );
  }

  Widget _buildTapeStyle(LayerModel layer, TextPainter painter, TextStyle effectiveStyle) {
    final style = effectiveStyle.copyWith(fontWeight: FontWeight.w500);
    List<Color> gradientColors;
    switch (layer.textBackground) {
      case "tapeYellow":
        gradientColors = [const Color(0xFFFFF9C4), const Color(0xFFFFFDE7)];
        break;
      case "tapePink":
        gradientColors = [const Color(0xFFFFE4EC), const Color(0xFFFFF0F4)];
        break;
      case "tape":
      default:
        gradientColors = [const Color(0xFFB6E8FF), const Color(0xFFE3F7FF)];
        break;
    }
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
          child: Text(
            layer.text ?? "",
            style: style,
            textAlign: layer.textAlign,
          ),
        ),
      ),
    );
  }
}

// 말풍선 스타일: 라운드(꼬리 0.2/0.5/0.8) / 사각형(꼬리 0/0.5/1)
class _BubbleBackgroundPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double tailPosition; // 라운드: 0.2 왼 0.5 가운데 0.8 오른 / 사각: 0 왼 0.5 가운데 1 오른
  final bool shapeSquare;

  _BubbleBackgroundPainter({
    required this.fillColor,
    required this.borderColor,
    this.tailPosition = 0.2,
    this.shapeSquare = false,
  });

  static const double _tailWidth = 18.0;
  static const double _tailHeight = 10.0;
  static const double _radius = 16.0;
  /// 꼬리가 가장자리에 붙지 않도록 여백 (자연스러운 느낌)
  static const double _tailMargin = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    // 꼬리가 잘리지 않도록 본체 높이 = 전체 - 꼬리 높이 (그리기는 size 안에 완전히 포함)
    final h = size.height - _tailHeight;

    if (shapeSquare) {
      final tailCenterX = tailPosition <= 0.25
          ? _tailMargin + _tailWidth / 2
          : tailPosition >= 0.75
              ? w - _tailMargin - _tailWidth / 2
              : w / 2;
      final tailLeft = tailCenterX - _tailWidth / 2;
      final tailRight = tailCenterX + _tailWidth / 2;
      _drawSquareBubblePath(path, w, h, tailLeft, tailRight, tailCenterX);
    } else {
      final r = _radius;
      final minX = r + _tailMargin + _tailWidth / 2;
      final maxX = w - r - _tailMargin - _tailWidth / 2;
      // 라운드: 왼쪽(0.28) / 가운데(0.5) / 오른쪽(0.72) — 비율이 아닌 구간으로 명시 적용
      final bool isLeft = tailPosition < 0.4;
      final bool isRight = tailPosition > 0.6;
      final tailCenterX = minX <= maxX
          ? (isLeft ? minX : isRight ? maxX : w / 2)
          : (isLeft ? (r + _tailWidth / 2) : isRight ? (w - r - _tailWidth / 2) : w / 2);
      final tailLeft = tailCenterX - _tailWidth / 2;
      final tailRight = tailCenterX + _tailWidth / 2;
      _drawRoundBubblePath(path, w, h, tailLeft, tailRight, tailCenterX);
    }

    final fill = Paint()..color = fillColor..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  /// 라운드 말풍선: 둥근 사각형 본체 + 하단 평평한 구간에 꼬리 연결 (한 경로, 여백 없음)
  void _drawRoundBubblePath(Path path, double w, double h, double tailLeft, double tailRight, double tailCenterX) {
    final r = _radius;
    path.moveTo(tailLeft, h);
    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    path.lineTo(w, h - r);
    path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));
    path.lineTo(tailRight, h);
    path.lineTo(tailCenterX, h + _tailHeight);
    path.lineTo(tailLeft, h);
    path.close();
  }

  /// 사각형 말풍선: 직사각형 본체 + 꼬리 왼/가운데/오른쪽 (한 경로, 여백 없음)
  void _drawSquareBubblePath(Path path, double w, double h, double tailLeft, double tailRight, double tailCenterX) {
    path.moveTo(tailLeft, h);
    path.lineTo(0, h);
    path.lineTo(0, 0);
    path.lineTo(w, 0);
    path.lineTo(w, h);
    path.lineTo(tailRight, h);
    path.lineTo(tailCenterX, h + _tailHeight);
    path.lineTo(tailLeft, h);
    path.close();
  }

  @override
  bool shouldRepaint(covariant _BubbleBackgroundPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.tailPosition != tailPosition ||
        oldDelegate.shapeSquare != shapeSquare;
  }
}

// 노트 스타일: 아래 찢어진 종이 효과
class _TornPaperClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - 4);

    // 아랫부분 찢어진 효과
    const step = 8.0;
    double x = size.width;
    bool up = true;
    while (x > 0) {
      x -= step;
      final y = size.height - (up ? 0 : 4);
      path.lineTo(x.clamp(0, size.width), y);
      up = !up;
    }

    path.lineTo(0, size.height - 4);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
// Film strip painter: 양쪽에 4개씩 연한 타공(perforation) — 레퍼런스 빈티지 필름 스트립
class _FilmHolePainterV2 extends CustomPainter {
  static const int holesPerSide = 4;
  static const double holeW = 5.0;
  static const double holeH = 5.0;
  static const Color holeColor = Color(0xFF3D4556);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = holeColor..style = PaintingStyle.fill;
    final leftX = 2.0;
    final rightX = size.width - 2.0 - holeW;
    final totalGap = size.height - (holesPerSide * holeH);
    final gap = holesPerSide > 1 ? totalGap / (holesPerSide + 1) : totalGap / 2;

    for (int i = 0; i < holesPerSide; i++) {
      final y = gap + i * (holeH + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(leftX, y, holeW, holeH),
        const Radius.circular(1),
      );
      canvas.drawRRect(rect, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rightX, y, holeW, holeH),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Sketch frame painter for _frameSketch
class _SketchFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(4, 8);
    path.lineTo(size.width - 4, 4);
    path.lineTo(size.width - 6, size.height - 6);
    path.lineTo(6, size.height - 4);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// VHS 스캔라인
class _VhsScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 네온 코너 L자
class _NeonCornerLPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const r = 6.0;
    canvas.drawPath(Path()
      ..moveTo(0, r)
      ..lineTo(0, 0)
      ..lineTo(r, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 점선 테두리 (핑크 스플래터 등)
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
    this.dashWidth = 4,
    this.dashSpace = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final segment = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}