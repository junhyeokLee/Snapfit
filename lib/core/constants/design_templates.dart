import 'dart:ui';

import 'package:flutter/material.dart';

import 'cover_size.dart';
import '../../features/album/domain/entities/layer.dart';

class DesignTemplate {
  final String id;
  final String name;
  final bool forCover;
  final List<LayerModel> Function(Size canvasSize) buildLayers;

  const DesignTemplate({
    required this.id,
    required this.name,
    required this.buildLayers,
    this.forCover = false,
  });
}

const double _baseW = kCoverReferenceWidth;

double _scaleFor(Size canvasSize) => canvasSize.width / _baseW;

List<LayerModel> _buildWeddingTemplate(Size canvasSize) {
  final scale = _scaleFor(canvasSize);

  LayerModel image(String id, Offset pos, Size size, double rotation, {String frame = 'polaroidClassic', int z = 0}) {
    return LayerModel(
      id: id,
      type: LayerType.image,
      position: Offset(pos.dx * scale, pos.dy * scale),
      width: size.width * scale,
      height: size.height * scale,
      rotation: rotation,
      imageBackground: frame,
      opacity: 1,
      zIndex: z,
    );
  }

  LayerModel text(String id, Offset pos, Size size, String value, String bg, double fontSize, {FontWeight weight = FontWeight.w600, int z = 0}) {
    return LayerModel(
      id: id,
      type: LayerType.text,
      position: Offset(pos.dx * scale, pos.dy * scale),
      width: size.width * scale,
      height: size.height * scale,
      rotation: 0,
      text: value,
      textBackground: bg,
      textStyle: TextStyle(
        fontSize: fontSize * scale,
        fontWeight: weight,
        color: Colors.black87,
      ),
      textStyleType: TextStyleType.none,
      textAlign: TextAlign.center,
      opacity: 1,
      zIndex: z,
    );
  }

  LayerModel sticker(String id, Offset pos, Size size, {double rotation = 0, int z = 0}) {
    return LayerModel(
      id: id,
      type: LayerType.sticker,
      position: Offset(pos.dx * scale, pos.dy * scale),
      width: size.width * scale,
      height: size.height * scale,
      rotation: rotation,
      imageBackground: 'sticker',
      opacity: 1,
      zIndex: z,
    );
  }

  return [
    // 상단 메인 타이틀
    text(
      'wedding_title',
      const Offset(24, 30),
      const Size(252, 42),
      '우리 결혼해요!',
      'note',
      20,
      weight: FontWeight.w700,
      z: 20,
    ),
    // 부제
    text(
      'wedding_subtitle',
      const Offset(40, 76),
      const Size(220, 26),
      '우리의 결혼 이야기 미리보기',
      'tag',
      11,
      z: 20,
    ),
    // 왼쪽 폴라로이드
    image(
      'wedding_photo_1',
      const Offset(32, 122),
      const Size(124, 148),
      -6,
      z: 10,
    ),
    // 오른쪽 폴라로이드
    image(
      'wedding_photo_2',
      const Offset(152, 130),
      const Size(124, 148),
      4,
      z: 11,
    ),
    // 중앙 하트 낙서
    sticker(
      'wedding_heart',
      const Offset(138, 196),
      const Size(32, 32),
      rotation: -8,
      z: 30,
    ),
    // 우측 상단 스마일
    sticker(
      'wedding_smile',
      const Offset(238, 106),
      const Size(28, 28),
      rotation: 0,
      z: 18,
    ),
  ];
}

List<LayerModel> _buildPhotobookTemplate(Size canvasSize) {
  final scale = _scaleFor(canvasSize);

  LayerModel image(String id, Offset pos, Size size, {double rotation = 0, String frame = '', int z = 0}) {
    return LayerModel(
      id: id,
      type: LayerType.image,
      position: Offset(pos.dx * scale, pos.dy * scale),
      width: size.width * scale,
      height: size.height * scale,
      rotation: rotation,
      imageBackground: frame,
      opacity: 1,
      zIndex: z,
    );
  }

  LayerModel text(String id, Offset pos, Size size, String value, String bg, double fontSize, {FontWeight weight = FontWeight.w600, TextAlign align = TextAlign.left, int z = 0}) {
    return LayerModel(
      id: id,
      type: LayerType.text,
      position: Offset(pos.dx * scale, pos.dy * scale),
      width: size.width * scale,
      height: size.height * scale,
      rotation: 0,
      text: value,
      textBackground: bg,
      textStyle: TextStyle(
        fontSize: fontSize * scale,
        fontWeight: weight,
        color: Colors.black87,
      ),
      textStyleType: TextStyleType.none,
      textAlign: align,
      opacity: 1,
      zIndex: z,
    );
  }

  return [
    // 상단 태그
    text(
      'pb_tag',
      const Offset(96, 26),
      const Size(108, 22),
      'PHOTOBOOK',
      'tag',
      10,
      align: TextAlign.center,
      z: 20,
    ),
    // 타이틀
    text(
      'pb_title',
      const Offset(40, 64),
      const Size(220, 42),
      '김씨네 여름나기',
      'note',
      18,
      weight: FontWeight.w700,
      z: 20,
    ),
    // 큰 메인 사진
    image(
      'pb_main',
      const Offset(34, 124),
      const Size(232, 132),
      frame: '',
      z: 10,
    ),
    // 왼쪽 작은 사진
    image(
      'pb_side',
      const Offset(36, 270),
      const Size(96, 64),
      frame: '',
      z: 11,
    ),
    // 필름 프레임 사진
    image(
      'pb_film',
      const Offset(148, 266),
      const Size(132, 80),
      rotation: -4,
      frame: 'film',
      z: 12,
    ),
    // 날짜
    text(
      'pb_date',
      const Offset(172, 346),
      const Size(96, 18),
      '2099.07.01',
      'tag',
      9,
      align: TextAlign.right,
      z: 20,
    ),
  ];
}

/// 여러 장의 사진이 자유롭게 배치된 스크랩북 콜라주
List<LayerModel> _buildScrapbookTemplate(Size canvasSize) {
  final scale = _scaleFor(canvasSize);

  LayerModel image(String id, Offset pos, Size size, {double rotation = 0, String frame = '', int z = 0}) {
    return LayerModel(
      id: id,
      type: LayerType.image,
      position: Offset(pos.dx * scale, pos.dy * scale),
      width: size.width * scale,
      height: size.height * scale,
      rotation: rotation,
      imageBackground: frame,
      opacity: 1,
      zIndex: z,
    );
  }

  LayerModel sticker(String id, Offset pos, Size size, {double rotation = 0, int z = 0}) {
    return LayerModel(
      id: id,
      type: LayerType.sticker,
      position: Offset(pos.dx * scale, pos.dy * scale),
      width: size.width * scale,
      height: size.height * scale,
      rotation: rotation,
      imageBackground: 'sticker',
      opacity: 1,
      zIndex: z,
    );
  }

  LayerModel textLabel(String id, Offset pos, Size size, String value, String bg, {int z = 0}) {
    return LayerModel(
      id: id,
      type: LayerType.text,
      position: Offset(pos.dx * scale, pos.dy * scale),
      width: size.width * scale,
      height: size.height * scale,
      text: value,
      textBackground: bg,
      textStyle: TextStyle(
        fontSize: 10 * scale,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
      textStyleType: TextStyleType.none,
      opacity: 1,
      zIndex: z,
    );
  }

  return [
    image('sb_top_left', const Offset(18, 26), const Size(92, 72), rotation: -4, frame: '', z: 5),
    image('sb_top_right', const Offset(130, 26), const Size(84, 70), rotation: 3, frame: '', z: 5),
    image('sb_mid_left', const Offset(32, 110), const Size(86, 96), rotation: 2, frame: '', z: 5),
    image('sb_mid_center', const Offset(126, 104), const Size(80, 88), rotation: -3, frame: '', z: 5),
    image('sb_mid_right', const Offset(210, 116), const Size(70, 80), rotation: 4, frame: '', z: 5),
    image('sb_bot_left', const Offset(18, 214), const Size(88, 86), rotation: -5, frame: '', z: 5),
    image('sb_bot_center', const Offset(112, 210), const Size(88, 94), rotation: 3, frame: '', z: 5),
    image('sb_bot_right', const Offset(204, 216), const Size(78, 88), rotation: -2, frame: '', z: 5),

    // 라벨 텍스트
    textLabel('sb_goals', const Offset(208, 36), const Size(64, 20), 'goals!', 'labelSolid', z: 20),
    textLabel('sb_habits', const Offset(20, 204), const Size(64, 20), 'habits', 'labelSolidPink', z: 20),
    textLabel('sb_amazing', const Offset(184, 210), const Size(72, 22), 'amazing', 'labelNeon', z: 20),

    // 컬러 스티커/도형 느낌
    sticker('sb_star1', const Offset(20, 116), const Size(32, 32), rotation: -8, z: 10),
    sticker('sb_star2', const Offset(230, 80), const Size(36, 36), rotation: 12, z: 10),
    sticker('sb_heart1', const Offset(136, 196), const Size(28, 28), rotation: -6, z: 12),
  ];
}

/// 하트 모양으로 사진들을 배치한 콜라주
List<LayerModel> _buildHeartCollageTemplate(Size canvasSize) {
  final scale = _scaleFor(canvasSize);

  LayerModel image(String id, Offset pos, Size size, {double rotation = 0, int z = 0}) {
    return LayerModel(
      id: id,
      type: LayerType.image,
      position: Offset(pos.dx * scale, pos.dy * scale),
      width: size.width * scale,
      height: size.height * scale,
      rotation: rotation,
      imageBackground: '',
      opacity: 1,
      zIndex: z,
    );
  }

  return [
    // 상단 아치
    image('heart_top_left', const Offset(70, 40), const Size(60, 60), rotation: -10, z: 5),
    image('heart_top_mid', const Offset(120, 34), const Size(64, 64), rotation: 0, z: 5),
    image('heart_top_right', const Offset(176, 40), const Size(60, 60), rotation: 10, z: 5),
    // 중단 좌우
    image('heart_mid_left', const Offset(48, 96), const Size(64, 70), rotation: -8, z: 6),
    image('heart_mid_right', const Offset(196, 96), const Size(64, 70), rotation: 8, z: 6),
    // 중앙
    image('heart_center_left', const Offset(86, 112), const Size(64, 74), rotation: -4, z: 7),
    image('heart_center_right', const Offset(150, 112), const Size(64, 74), rotation: 4, z: 7),
    // 하단 꼬리
    image('heart_bottom_left', const Offset(104, 188), const Size(58, 70), rotation: -6, z: 8),
    image('heart_bottom_right', const Offset(142, 188), const Size(58, 70), rotation: 6, z: 8),
  ];
}

List<DesignTemplate> designTemplates = [
  DesignTemplate(
    id: 'wedding_001',
    name: '우리 결혼해요',
    buildLayers: _buildWeddingTemplate,
    forCover: false,
  ),
  DesignTemplate(
    id: 'scrapbook_collage_001',
    name: '스크랩북 콜라주',
    buildLayers: _buildScrapbookTemplate,
    forCover: false,
  ),
  DesignTemplate(
    id: 'heart_collage_001',
    name: '하트 콜라주',
    buildLayers: _buildHeartCollageTemplate,
    forCover: false,
  ),
  DesignTemplate(
    id: 'photobook_summer_001',
    name: '여름 포토북',
    buildLayers: _buildPhotobookTemplate,
    forCover: false,
  ),
];

