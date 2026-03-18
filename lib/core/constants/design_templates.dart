import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/album/domain/entities/layer.dart';

enum TemplateAspect { portrait, square, landscape, any }

class DesignTemplate {
  final String id;
  final String name;
  final bool forCover;
  final TemplateAspect aspect;
  final String category;
  final List<String> tags;
  final List<LayerModel> Function(Size canvasSize) buildLayers;

  const DesignTemplate({
    required this.id,
    required this.name,
    required this.buildLayers,
    this.forCover = false,
    this.aspect = TemplateAspect.any,
    this.category = '전체',
    this.tags = const [],
  });
}

Offset _p(Size canvas, double x, double y) =>
    Offset(canvas.width * x, canvas.height * y);

Size _s(Size canvas, double w, double h) =>
    Size(canvas.width * w, canvas.height * h);

LayerModel _image(
  Size canvas,
  String id,
  double x,
  double y,
  double w,
  double h, {
  double rotation = 0,
  String frame = '',
  int z = 0,
}) {
  return LayerModel(
    id: id,
    type: LayerType.image,
    position: _p(canvas, x, y),
    width: _s(canvas, w, h).width,
    height: _s(canvas, w, h).height,
    rotation: rotation,
    imageBackground: frame,
    opacity: 1,
    zIndex: z,
  );
}

LayerModel _bg(Size canvas, String id, String style, {int z = 0}) {
  return LayerModel(
    id: id,
    type: LayerType.decoration,
    position: Offset.zero,
    width: canvas.width,
    height: canvas.height,
    imageBackground: style,
    opacity: 1,
    zIndex: z,
  );
}

LayerModel _text(
  Size canvas,
  String id,
  double x,
  double y,
  double w,
  double h,
  String value,
  String? bg,
  double fontSize, {
  FontWeight weight = FontWeight.w600,
  TextAlign align = TextAlign.center,
  Color color = Colors.black87,
  String? fontFamily,
  double? letterSpacing,
  double? height,
  double rotation = 0,
  int z = 0,
}) {
  final textBackground = (bg == null || bg.isEmpty) ? null : bg;
  return LayerModel(
    id: id,
    type: LayerType.text,
    position: _p(canvas, x, y),
    width: _s(canvas, w, h).width,
    height: _s(canvas, w, h).height,
    rotation: rotation,
    text: value,
    textBackground: textBackground,
    textStyle: TextStyle(
      fontSize: fontSize * (canvas.width / 300.0),
      fontWeight: weight,
      color: color,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
      height: height,
    ),
    textStyleType: TextStyleType.none,
    textAlign: align,
    opacity: 1,
    zIndex: z,
  );
}

List<LayerModel> _buildPortraitMagazine(Size canvas) {
  return [
    _text(
      canvas,
      'pm_tag',
      0.06,
      0.05,
      0.28,
      0.07,
      'WEEKEND',
      'tagMint',
      10,
      weight: FontWeight.w700,
      color: Colors.black87,
      z: 20,
    ),
    _text(
      canvas,
      'pm_title',
      0.06,
      0.13,
      0.76,
      0.10,
      '우리의 작은 이야기',
      'note',
      18,
      weight: FontWeight.w700,
      align: TextAlign.left,
      z: 20,
    ),
    _image(canvas, 'pm_main', 0.06, 0.26, 0.88, 0.42, frame: 'softGlow', z: 10),
    _image(canvas, 'pm_left', 0.06, 0.72, 0.42, 0.22, frame: 'round', z: 11),
    _image(canvas, 'pm_right', 0.52, 0.72, 0.42, 0.22, frame: 'round', z: 11),
    _text(
      canvas,
      'pm_date',
      0.60,
      0.94,
      0.34,
      0.05,
      '2026.03.17',
      'labelSolid',
      9,
      align: TextAlign.right,
      color: Colors.white,
      z: 20,
    ),
  ];
}

List<LayerModel> _buildPortraitStory(Size canvas) {
  return [
    _image(
      canvas,
      'ps_main',
      0.06,
      0.06,
      0.88,
      0.52,
      frame: 'thinDoubleLine',
      z: 10,
    ),
    _text(
      canvas,
      'ps_title',
      0.06,
      0.60,
      0.88,
      0.10,
      '오늘의 기록',
      'highlightPink',
      16,
      weight: FontWeight.w800,
      align: TextAlign.left,
      z: 20,
    ),
    _image(
      canvas,
      'ps_left',
      0.06,
      0.72,
      0.42,
      0.22,
      frame: 'polaroid',
      rotation: -3,
      z: 11,
    ),
    _image(
      canvas,
      'ps_right',
      0.52,
      0.72,
      0.42,
      0.22,
      frame: 'polaroidClassic',
      rotation: 4,
      z: 12,
    ),
  ];
}

List<LayerModel> _buildPortraitCollage(Size canvas) {
  return [
    _image(
      canvas,
      'pc_1',
      0.08,
      0.10,
      0.44,
      0.30,
      frame: 'polaroidFilm',
      rotation: -6,
      z: 10,
    ),
    _image(
      canvas,
      'pc_2',
      0.48,
      0.16,
      0.44,
      0.32,
      frame: 'polaroid',
      rotation: 4,
      z: 11,
    ),
    _image(
      canvas,
      'pc_3',
      0.10,
      0.46,
      0.36,
      0.26,
      frame: 'round',
      rotation: -2,
      z: 12,
    ),
    _image(
      canvas,
      'pc_4',
      0.52,
      0.50,
      0.38,
      0.28,
      frame: 'roundSoft',
      rotation: 3,
      z: 12,
    ),
    _text(
      canvas,
      'pc_label',
      0.18,
      0.78,
      0.64,
      0.10,
      'MEMORY FILE',
      'sticker',
      12,
      weight: FontWeight.w700,
      z: 20,
    ),
  ];
}

List<LayerModel> _buildSquareGrid(Size canvas) {
  return [
    _image(
      canvas,
      'sg_1',
      0.06,
      0.06,
      0.42,
      0.36,
      frame: 'offsetColorBlock',
      z: 10,
    ),
    _image(
      canvas,
      'sg_2',
      0.52,
      0.06,
      0.42,
      0.36,
      frame: 'gradientEdge',
      z: 10,
    ),
    _image(
      canvas,
      'sg_3',
      0.06,
      0.46,
      0.42,
      0.36,
      frame: 'thinDoubleLine',
      z: 10,
    ),
    _image(canvas, 'sg_4', 0.52, 0.46, 0.42, 0.36, frame: 'neon', z: 10),
    _text(
      canvas,
      'sg_label',
      0.18,
      0.84,
      0.64,
      0.10,
      'COLOR DAY',
      'highlightYellow',
      14,
      weight: FontWeight.w800,
      z: 20,
    ),
  ];
}

List<LayerModel> _buildSquareCenter(Size canvas) {
  return [
    _text(
      canvas,
      'sc_tag',
      0.06,
      0.05,
      0.30,
      0.08,
      'MOOD',
      'labelRose',
      11,
      weight: FontWeight.w700,
      color: Colors.white,
      z: 30,
    ),
    _image(
      canvas,
      'sc_main',
      0.10,
      0.16,
      0.80,
      0.56,
      frame: 'floatingGlass',
      z: 10,
    ),
    _image(canvas, 'sc_left', 0.10, 0.74, 0.36, 0.20, frame: 'circle', z: 11),
    _image(canvas, 'sc_right', 0.54, 0.74, 0.36, 0.20, frame: 'round', z: 11),
  ];
}

List<LayerModel> _buildSquareTape(Size canvas) {
  return [
    _image(
      canvas,
      'st_main',
      0.10,
      0.08,
      0.80,
      0.60,
      frame: 'polaroidClassic',
      z: 10,
    ),
    _text(
      canvas,
      'st_title',
      0.14,
      0.72,
      0.72,
      0.12,
      'SOFT MOMENT',
      'noteTornCream',
      14,
      weight: FontWeight.w800,
      z: 20,
    ),
    _text(
      canvas,
      'st_date',
      0.60,
      0.05,
      0.28,
      0.06,
      'APR 2026',
      'tagOrange',
      9,
      weight: FontWeight.w700,
      z: 30,
    ),
  ];
}

List<LayerModel> _buildLandscapeBanner(Size canvas) {
  return [
    _text(
      canvas,
      'lb_tag',
      0.04,
      0.06,
      0.24,
      0.12,
      'TRAVEL',
      'labelSolidGreen',
      11,
      weight: FontWeight.w700,
      color: Colors.white,
      z: 30,
    ),
    _image(
      canvas,
      'lb_main',
      0.04,
      0.22,
      0.62,
      0.70,
      frame: 'goldFrame',
      z: 10,
    ),
    _image(canvas, 'lb_top', 0.70, 0.22, 0.26, 0.32, frame: 'roundSoft', z: 11),
    _image(
      canvas,
      'lb_bottom',
      0.70,
      0.60,
      0.26,
      0.32,
      frame: 'roundSoft',
      z: 11,
    ),
  ];
}

List<LayerModel> _buildLandscapeFilm(Size canvas) {
  return [
    _text(
      canvas,
      'lf_tag',
      0.04,
      0.06,
      0.24,
      0.12,
      'FILM STRIP',
      'labelSolidBlue',
      11,
      weight: FontWeight.w700,
      color: Colors.white,
      z: 30,
    ),
    _image(canvas, 'lf_1', 0.04, 0.26, 0.30, 0.66, frame: 'film', z: 10),
    _image(canvas, 'lf_2', 0.35, 0.26, 0.30, 0.66, frame: 'film', z: 11),
    _image(canvas, 'lf_3', 0.66, 0.26, 0.30, 0.66, frame: 'film', z: 12),
  ];
}

List<LayerModel> _buildLandscapeTriptych(Size canvas) {
  return [
    _text(
      canvas,
      'lt_title',
      0.04,
      0.06,
      0.64,
      0.14,
      '우리의 하루',
      'highlightPink',
      16,
      weight: FontWeight.w800,
      align: TextAlign.left,
      z: 20,
    ),
    _image(
      canvas,
      'lt_1',
      0.04,
      0.24,
      0.30,
      0.68,
      frame: 'thinDoubleLine',
      z: 10,
    ),
    _image(
      canvas,
      'lt_2',
      0.35,
      0.24,
      0.30,
      0.68,
      frame: 'thinDoubleLine',
      z: 10,
    ),
    _image(
      canvas,
      'lt_3',
      0.66,
      0.24,
      0.30,
      0.68,
      frame: 'thinDoubleLine',
      z: 10,
    ),
  ];
}

List<LayerModel> _buildPortraitPastel(Size canvas) {
  return [
    _text(
      canvas,
      'pp_tag',
      0.06,
      0.05,
      0.28,
      0.07,
      'PASTEL',
      'tagMint',
      10,
      weight: FontWeight.w700,
      z: 30,
    ),
    _image(
      canvas,
      'pp_main',
      0.06,
      0.16,
      0.88,
      0.48,
      frame: 'roundSoft',
      z: 10,
    ),
    _text(
      canvas,
      'pp_title',
      0.10,
      0.66,
      0.80,
      0.10,
      '따뜻한 하루',
      'note',
      16,
      weight: FontWeight.w700,
      align: TextAlign.left,
      z: 20,
    ),
    _image(canvas, 'pp_left', 0.06, 0.78, 0.42, 0.18, frame: 'round', z: 11),
    _image(canvas, 'pp_right', 0.52, 0.78, 0.42, 0.18, frame: 'round', z: 11),
  ];
}

List<LayerModel> _buildPortraitVintage(Size canvas) {
  return [
    _text(
      canvas,
      'pv_tag',
      0.06,
      0.05,
      0.30,
      0.07,
      'VINTAGE',
      'tagOrange',
      10,
      weight: FontWeight.w700,
      z: 30,
    ),
    _image(
      canvas,
      'pv_main',
      0.10,
      0.16,
      0.80,
      0.52,
      frame: 'polaroidClassic',
      rotation: -2,
      z: 10,
    ),
    _image(
      canvas,
      'pv_left',
      0.12,
      0.70,
      0.36,
      0.22,
      frame: 'polaroidFilm',
      rotation: -5,
      z: 11,
    ),
    _image(
      canvas,
      'pv_right',
      0.52,
      0.70,
      0.36,
      0.22,
      frame: 'polaroid',
      rotation: 4,
      z: 12,
    ),
  ];
}

List<LayerModel> _buildPortraitMinimal(Size canvas) {
  return [
    _text(
      canvas,
      'pmn_tag',
      0.06,
      0.05,
      0.32,
      0.07,
      'MINIMAL',
      'tagBlue',
      10,
      weight: FontWeight.w700,
      z: 30,
    ),
    _image(
      canvas,
      'pmn_main',
      0.06,
      0.18,
      0.88,
      0.52,
      frame: 'thinDoubleLine',
      z: 10,
    ),
    _text(
      canvas,
      'pmn_title',
      0.06,
      0.72,
      0.88,
      0.10,
      '심플한 기록',
      'highlightYellow',
      14,
      weight: FontWeight.w800,
      align: TextAlign.left,
      z: 20,
    ),
    _text(
      canvas,
      'pmn_body',
      0.06,
      0.82,
      0.88,
      0.12,
      '작은 순간을 선명하게 담아요.',
      'noteGrid',
      11,
      align: TextAlign.left,
      z: 20,
    ),
  ];
}

List<LayerModel> _buildPortraitTravel(Size canvas) {
  return [
    _text(
      canvas,
      'ptr_tag',
      0.06,
      0.05,
      0.30,
      0.07,
      'TRAVEL',
      'labelSolidGreen',
      10,
      weight: FontWeight.w700,
      color: Colors.white,
      z: 30,
    ),
    _image(
      canvas,
      'ptr_main',
      0.06,
      0.16,
      0.88,
      0.48,
      frame: 'goldFrame',
      z: 10,
    ),
    _text(
      canvas,
      'ptr_title',
      0.10,
      0.66,
      0.80,
      0.10,
      '여행 기록',
      'noteTornCream',
      16,
      weight: FontWeight.w800,
      z: 20,
    ),
    _image(
      canvas,
      'ptr_left',
      0.06,
      0.78,
      0.42,
      0.18,
      frame: 'roundSoft',
      z: 11,
    ),
    _image(
      canvas,
      'ptr_right',
      0.52,
      0.78,
      0.42,
      0.18,
      frame: 'roundSoft',
      z: 11,
    ),
  ];
}

List<LayerModel> _buildSquarePastel(Size canvas) {
  return [
    _text(
      canvas,
      'sp_tag',
      0.06,
      0.05,
      0.30,
      0.08,
      'PASTEL',
      'tagMint',
      11,
      weight: FontWeight.w700,
      z: 30,
    ),
    _image(
      canvas,
      'sp_main',
      0.08,
      0.16,
      0.84,
      0.54,
      frame: 'roundSoft',
      z: 10,
    ),
    _image(canvas, 'sp_left', 0.08, 0.72, 0.40, 0.20, frame: 'round', z: 11),
    _image(canvas, 'sp_right', 0.52, 0.72, 0.40, 0.20, frame: 'round', z: 11),
  ];
}

List<LayerModel> _buildSquareVintage(Size canvas) {
  return [
    _text(
      canvas,
      'sv_tag',
      0.06,
      0.05,
      0.30,
      0.08,
      'VINTAGE',
      'tagOrange',
      11,
      weight: FontWeight.w700,
      z: 30,
    ),
    _image(
      canvas,
      'sv_main',
      0.12,
      0.16,
      0.76,
      0.54,
      frame: 'polaroidClassic',
      rotation: -2,
      z: 10,
    ),
    _text(
      canvas,
      'sv_label',
      0.18,
      0.74,
      0.64,
      0.12,
      'GOOD DAYS',
      'sticker',
      12,
      weight: FontWeight.w700,
      z: 20,
    ),
  ];
}

List<LayerModel> _buildSquareMinimal(Size canvas) {
  return [
    _text(
      canvas,
      'sm_tag',
      0.06,
      0.05,
      0.30,
      0.08,
      'MINIMAL',
      'tagBlue',
      11,
      weight: FontWeight.w700,
      z: 30,
    ),
    _image(
      canvas,
      'sm_main',
      0.08,
      0.16,
      0.84,
      0.50,
      frame: 'thinDoubleLine',
      z: 10,
    ),
    _text(
      canvas,
      'sm_title',
      0.08,
      0.70,
      0.84,
      0.12,
      'Simple Day',
      'highlightPink',
      14,
      weight: FontWeight.w800,
      align: TextAlign.left,
      z: 20,
    ),
  ];
}

List<LayerModel> _buildSquareTravel(Size canvas) {
  return [
    _text(
      canvas,
      'stt_tag',
      0.06,
      0.05,
      0.30,
      0.08,
      'TRAVEL',
      'labelSolidGreen',
      11,
      weight: FontWeight.w700,
      color: Colors.white,
      z: 30,
    ),
    _image(
      canvas,
      'stt_main',
      0.08,
      0.16,
      0.84,
      0.50,
      frame: 'goldFrame',
      z: 10,
    ),
    _image(
      canvas,
      'stt_left',
      0.08,
      0.70,
      0.40,
      0.22,
      frame: 'roundSoft',
      z: 11,
    ),
    _image(
      canvas,
      'stt_right',
      0.52,
      0.70,
      0.40,
      0.22,
      frame: 'roundSoft',
      z: 11,
    ),
  ];
}

List<LayerModel> _buildLandscapePastel(Size canvas) {
  return [
    _text(
      canvas,
      'lp_tag',
      0.04,
      0.06,
      0.24,
      0.12,
      'PASTEL',
      'tagMint',
      11,
      weight: FontWeight.w700,
      z: 30,
    ),
    _image(
      canvas,
      'lp_main',
      0.04,
      0.22,
      0.62,
      0.70,
      frame: 'roundSoft',
      z: 10,
    ),
    _image(canvas, 'lp_top', 0.70, 0.22, 0.26, 0.32, frame: 'round', z: 11),
    _image(canvas, 'lp_bottom', 0.70, 0.60, 0.26, 0.32, frame: 'round', z: 11),
  ];
}

List<LayerModel> _buildLandscapeVintage(Size canvas) {
  return [
    _text(
      canvas,
      'lv_tag',
      0.04,
      0.06,
      0.24,
      0.12,
      'VINTAGE',
      'tagOrange',
      11,
      weight: FontWeight.w700,
      z: 30,
    ),
    _image(
      canvas,
      'lv_main',
      0.04,
      0.22,
      0.62,
      0.70,
      frame: 'polaroidClassic',
      rotation: -2,
      z: 10,
    ),
    _image(
      canvas,
      'lv_right',
      0.70,
      0.26,
      0.26,
      0.60,
      frame: 'polaroidFilm',
      rotation: 2,
      z: 11,
    ),
  ];
}

List<LayerModel> _buildLandscapeMinimal(Size canvas) {
  return [
    _text(
      canvas,
      'lmn_tag',
      0.04,
      0.06,
      0.24,
      0.12,
      'MINIMAL',
      'tagBlue',
      11,
      weight: FontWeight.w700,
      z: 30,
    ),
    _image(
      canvas,
      'lmn_main',
      0.04,
      0.22,
      0.62,
      0.70,
      frame: 'thinDoubleLine',
      z: 10,
    ),
    _text(
      canvas,
      'lmn_title',
      0.70,
      0.26,
      0.26,
      0.18,
      'Clean\nMoment',
      'highlightYellow',
      12,
      weight: FontWeight.w800,
      align: TextAlign.left,
      z: 20,
    ),
    _text(
      canvas,
      'lmn_body',
      0.70,
      0.46,
      0.26,
      0.34,
      '심플한 구성이\n사진을 돋보이게 합니다.',
      'noteGrid',
      10,
      align: TextAlign.left,
      z: 20,
    ),
  ];
}

List<LayerModel> _buildLandscapeTravel(Size canvas) {
  return [
    _text(
      canvas,
      'ltr_tag',
      0.04,
      0.06,
      0.24,
      0.12,
      'TRAVEL',
      'labelSolidGreen',
      11,
      weight: FontWeight.w700,
      color: Colors.white,
      z: 30,
    ),
    _image(
      canvas,
      'ltr_main',
      0.04,
      0.22,
      0.62,
      0.70,
      frame: 'goldFrame',
      z: 10,
    ),
    _image(
      canvas,
      'ltr_top',
      0.70,
      0.22,
      0.26,
      0.32,
      frame: 'roundSoft',
      z: 11,
    ),
    _image(
      canvas,
      'ltr_bottom',
      0.70,
      0.60,
      0.26,
      0.32,
      frame: 'roundSoft',
      z: 11,
    ),
  ];
}

// 추가 페이지 템플릿 (모바일 톤)
List<LayerModel> _buildPortraitClassicPoster(Size canvas) {
  return [
    _bg(canvas, 'pp_classic_bg', 'paperWarm', z: 0),
    _text(
      canvas,
      'pp_classic_title',
      0.08,
      0.05,
      0.84,
      0.12,
      'CLASSIC DAY',
      null,
      16,
      weight: FontWeight.w800,
      align: TextAlign.center,
      color: const Color(0xFF8C5A3C),
      letterSpacing: 1.1,
      z: 30,
    ),
    _image(
      canvas,
      'pp_classic_main',
      0.12,
      0.20,
      0.76,
      0.52,
      frame: 'polaroidClassic',
      z: 10,
    ),
    _text(
      canvas,
      'pp_classic_footer',
      0.12,
      0.76,
      0.76,
      0.16,
      'a quiet day to remember',
      null,
      11,
      align: TextAlign.center,
      color: const Color(0xFF8C5A3C),
      letterSpacing: 0.5,
      z: 20,
    ),
  ];
}

List<LayerModel> _buildPortraitRibbon(Size canvas) {
  return [
    _image(
      canvas,
      'pp_ribbon_main',
      0.06,
      0.10,
      0.88,
      0.56,
      frame: 'softGlow',
      z: 10,
    ),
    _text(
      canvas,
      'pp_ribbon_label',
      0.14,
      0.70,
      0.72,
      0.12,
      'TODAY\'S NOTE',
      'labelSolid',
      12,
      weight: FontWeight.w800,
      align: TextAlign.center,
      color: Colors.white,
      letterSpacing: 0.8,
      z: 30,
    ),
    _image(
      canvas,
      'pp_ribbon_left',
      0.06,
      0.84,
      0.42,
      0.12,
      frame: 'round',
      z: 11,
    ),
    _image(
      canvas,
      'pp_ribbon_right',
      0.52,
      0.84,
      0.42,
      0.12,
      frame: 'round',
      z: 11,
    ),
  ];
}

List<LayerModel> _buildSquareMosaic(Size canvas) {
  return [
    _image(canvas, 'sq_m1', 0.06, 0.06, 0.42, 0.28, frame: 'roundSoft', z: 10),
    _image(canvas, 'sq_m2', 0.52, 0.06, 0.42, 0.28, frame: 'roundSoft', z: 10),
    _image(canvas, 'sq_m3', 0.06, 0.36, 0.42, 0.28, frame: 'roundSoft', z: 10),
    _image(canvas, 'sq_m4', 0.52, 0.36, 0.42, 0.28, frame: 'roundSoft', z: 10),
    _text(
      canvas,
      'sq_m_title',
      0.10,
      0.70,
      0.80,
      0.10,
      'MOSAIC MOMENT',
      null,
      12,
      weight: FontWeight.w800,
      align: TextAlign.center,
      color: const Color(0xFF5B4A3A),
      letterSpacing: 0.8,
      z: 30,
    ),
    _image(canvas, 'sq_m5', 0.06, 0.82, 0.42, 0.12, frame: 'round', z: 11),
    _image(canvas, 'sq_m6', 0.52, 0.82, 0.42, 0.12, frame: 'round', z: 11),
  ];
}

List<LayerModel> _buildSquareStamp(Size canvas) {
  return [
    _bg(canvas, 'sq_stamp_bg', 'paperWhite', z: 0),
    _text(
      canvas,
      'sq_stamp_top',
      0.08,
      0.06,
      0.84,
      0.12,
      'A LITTLE POSTCARD',
      null,
      12,
      weight: FontWeight.w800,
      align: TextAlign.center,
      color: const Color(0xFFB24A3A),
      letterSpacing: 1.0,
      z: 30,
    ),
    _image(
      canvas,
      'sq_stamp_main',
      0.12,
      0.22,
      0.76,
      0.52,
      frame: 'postalStamp',
      z: 10,
    ),
    _text(
      canvas,
      'sq_stamp_footer',
      0.12,
      0.78,
      0.76,
      0.14,
      'from our favorite place',
      null,
      10,
      align: TextAlign.center,
      color: const Color(0xFFB24A3A),
      letterSpacing: 0.6,
      z: 20,
    ),
  ];
}

List<LayerModel> _buildLandscapeMagazine(Size canvas) {
  return [
    _text(
      canvas,
      'lm_tag',
      0.04,
      0.05,
      0.28,
      0.10,
      'MAGAZINE',
      'tagMint',
      11,
      weight: FontWeight.w800,
      z: 30,
    ),
    _image(canvas, 'lm_main', 0.04, 0.20, 0.60, 0.72, frame: 'softGlow', z: 10),
    _text(
      canvas,
      'lm_title',
      0.68,
      0.22,
      0.28,
      0.20,
      'WEEKEND\nMEMORY',
      null,
      13,
      weight: FontWeight.w900,
      align: TextAlign.left,
      color: const Color(0xFF2E2E2E),
      letterSpacing: 0.6,
      z: 30,
    ),
    _image(canvas, 'lm_top', 0.68, 0.48, 0.28, 0.20, frame: 'round', z: 11),
    _image(canvas, 'lm_bottom', 0.68, 0.72, 0.28, 0.20, frame: 'round', z: 11),
  ];
}

List<LayerModel> _buildLandscapeStrip(Size canvas) {
  return [
    _text(
      canvas,
      'ls_title',
      0.04,
      0.05,
      0.92,
      0.12,
      'PHOTO STRIP',
      null,
      14,
      weight: FontWeight.w800,
      align: TextAlign.center,
      color: const Color(0xFF444444),
      letterSpacing: 1.1,
      z: 30,
    ),
    _image(
      canvas,
      'ls_1',
      0.06,
      0.24,
      0.26,
      0.66,
      frame: 'thinDoubleLine',
      z: 10,
    ),
    _image(
      canvas,
      'ls_2',
      0.37,
      0.24,
      0.26,
      0.66,
      frame: 'thinDoubleLine',
      z: 10,
    ),
    _image(
      canvas,
      'ls_3',
      0.68,
      0.24,
      0.26,
      0.66,
      frame: 'thinDoubleLine',
      z: 10,
    ),
  ];
}

// -------------------- Cover-only templates --------------------
List<LayerModel> _buildWeddingDayPortrait(Size canvas) {
  return [
    _bg(canvas, 'wd_bg', 'paperWhite', z: 0),
    _text(
      canvas,
      'wd_title',
      0.11,
      0.05,
      0.62,
      0.15,
      'Our\nWedding Day',
      null,
      19,
      weight: FontWeight.w800,
      align: TextAlign.left,
      color: const Color(0xFF4E7A4A),
      fontFamily: 'Run',
      letterSpacing: 0.4,
      height: 0.90,
      rotation: -13,
      z: 30,
    ),
    _image(
      canvas,
      'wd_main',
      0.24,
      0.21,
      0.50,
      0.45,
      frame: 'polaroid',
      rotation: -7,
      z: 10,
    ),
    _image(
      canvas,
      'wd_sub',
      0.58,
      0.56,
      0.26,
      0.22,
      frame: 'polaroidClassic',
      rotation: 10,
      z: 16,
    ),
    _text(
      canvas,
      'wd_pin',
      0.73,
      0.18,
      0.14,
      0.08,
      '🎀',
      null,
      17,
      color: const Color(0xFF6A7EB8),
      z: 32,
    ),
    _text(
      canvas,
      'wd_flower',
      0.09,
      0.36,
      0.10,
      0.08,
      '❀',
      null,
      15,
      weight: FontWeight.w800,
      color: const Color(0xFFCF5C50),
      z: 28,
    ),
    _text(
      canvas,
      'wd_flower2',
      0.13,
      0.42,
      0.07,
      0.05,
      '✿',
      null,
      10,
      color: const Color(0xFFDE8A7A),
      z: 28,
    ),
    _text(
      canvas,
      'wd_date',
      0.22,
      0.82,
      0.56,
      0.055,
      'August 24, 20XX / 4:00 PM',
      null,
      7.8,
      align: TextAlign.center,
      color: const Color(0xFF6A6A6A),
      fontFamily: 'Cormorant',
      letterSpacing: 0.9,
      z: 20,
    ),
    _text(canvas, 'wd_cake', 0.08, 0.31, 0.08, 0.06, '🧁', null, 16, z: 25),
    _text(
      canvas,
      'wd_lace',
      0.09,
      0.67,
      0.12,
      0.07,
      '✧ ❦',
      null,
      10,
      color: const Color(0xFFC9B9A8),
      z: 24,
    ),
  ];
}

List<LayerModel> _buildKidsCollagePortrait(Size canvas) {
  return [
    _bg(canvas, 'kids_bg', 'paperWhite', z: 0),
    _image(
      canvas,
      'kids_1',
      0.00,
      0.03,
      0.34,
      0.36,
      frame: 'collageTile',
      z: 10,
    ),
    _image(
      canvas,
      'kids_2',
      0.35,
      0.03,
      0.31,
      0.28,
      frame: 'collageTile',
      z: 10,
    ),
    _image(
      canvas,
      'kids_3',
      0.67,
      0.03,
      0.25,
      0.28,
      frame: 'collageTile',
      z: 10,
    ),
    _image(
      canvas,
      'kids_4',
      0.87,
      0.03,
      0.13,
      0.34,
      frame: 'collageTile',
      z: 10,
    ),
    _image(
      canvas,
      'kids_5',
      0.00,
      0.40,
      0.39,
      0.27,
      frame: 'collageTile',
      z: 11,
    ),
    _image(
      canvas,
      'kids_6',
      0.40,
      0.42,
      0.34,
      0.25,
      frame: 'collageTile',
      z: 11,
    ),
    _image(
      canvas,
      'kids_7',
      0.75,
      0.40,
      0.25,
      0.29,
      frame: 'collageTile',
      z: 11,
    ),
    _text(
      canvas,
      'kids_title',
      0.23,
      0.655,
      0.54,
      0.13,
      'my kids,\nmy life,',
      'noteTornPink',
      22,
      weight: FontWeight.w900,
      align: TextAlign.center,
      color: const Color(0xFF171717),
      fontFamily: 'BookMyungjo',
      height: 0.92,
      z: 33,
    ),
    _image(
      canvas,
      'kids_8',
      0.00,
      0.78,
      0.40,
      0.19,
      frame: 'collageTile',
      z: 11,
    ),
    _image(
      canvas,
      'kids_9',
      0.41,
      0.785,
      0.20,
      0.18,
      frame: 'collageTile',
      z: 11,
    ),
    _image(
      canvas,
      'kids_10',
      0.63,
      0.785,
      0.17,
      0.18,
      frame: 'collageTile',
      z: 11,
    ),
    _image(
      canvas,
      'kids_11',
      0.81,
      0.785,
      0.19,
      0.18,
      frame: 'collageTile',
      z: 11,
    ),
    _text(
      canvas,
      'kids_doodle',
      0.36,
      0.325,
      0.20,
      0.07,
      'ฅ^•ﻌ•^ฅ',
      null,
      11,
      color: const Color(0xFF6E6E6E),
      fontFamily: 'NotoSans',
      z: 34,
    ),
    _text(
      canvas,
      'kids_note_quote',
      0.80,
      0.74,
      0.18,
      0.09,
      'more fun with us',
      'noteTornBeige',
      6.8,
      align: TextAlign.left,
      color: const Color(0xFF6A6258),
      fontFamily: 'Cormorant',
      rotation: -9,
      z: 35,
    ),
    _text(
      canvas,
      'kids_note_ticket',
      0.26,
      0.55,
      0.16,
      0.06,
      'ticket\n02.05.20',
      'noteTornBeige',
      6.4,
      align: TextAlign.left,
      color: const Color(0xFF635D53),
      fontFamily: 'Cormorant',
      height: 1.0,
      rotation: -18,
      z: 35,
    ),
    _text(
      canvas,
      'kids_note_torn',
      0.80,
      0.33,
      0.18,
      0.10,
      'small notes',
      'noteTornBeige',
      7.0,
      align: TextAlign.left,
      color: const Color(0xFF6A6157),
      fontFamily: 'Cormorant',
      rotation: -12,
      z: 35,
    ),
    _text(
      canvas,
      'kids_flower1',
      0.55,
      0.81,
      0.10,
      0.06,
      '✾',
      null,
      18,
      color: const Color(0xFFE65D8D),
      z: 34,
    ),
    _text(
      canvas,
      'kids_flower2',
      0.66,
      0.81,
      0.10,
      0.06,
      '✿',
      null,
      17,
      color: const Color(0xFFED8BAF),
      z: 34,
    ),
  ];
}

List<LayerModel> _buildPhotoDumpPortrait(Size canvas) {
  return [
    _bg(canvas, 'pd_bg', 'notebookPunchPage', z: 0),
    _text(
      canvas,
      'pd_title_photo',
      0.18,
      0.04,
      0.40,
      0.09,
      'PHOTO',
      null,
      23,
      weight: FontWeight.w900,
      align: TextAlign.left,
      color: const Color(0xFF2D2D2D),
      fontFamily: 'Maker',
      letterSpacing: 0.3,
      height: 0.9,
      z: 30,
    ),
    _text(
      canvas,
      'pd_title_dump',
      0.50,
      0.105,
      0.36,
      0.08,
      'DUMP',
      null,
      22,
      weight: FontWeight.w900,
      align: TextAlign.left,
      color: const Color(0xFF2D2D2D),
      fontFamily: 'Maker',
      letterSpacing: 0.3,
      z: 30,
    ),
    _image(canvas, 'pd_1', 0.10, 0.23, 0.42, 0.29, frame: 'collageTile', z: 10),
    _image(canvas, 'pd_2', 0.54, 0.30, 0.33, 0.19, frame: 'collageTile', z: 10),
    _image(canvas, 'pd_3', 0.10, 0.60, 0.40, 0.22, frame: 'collageTile', z: 10),
    _image(
      canvas,
      'pd_4',
      0.53,
      0.57,
      0.35,
      0.21,
      frame: 'tornPaperCard',
      rotation: -5,
      z: 10,
    ),
    _text(
      canvas,
      'pd_star1',
      0.68,
      0.06,
      0.12,
      0.10,
      '✶',
      null,
      34,
      weight: FontWeight.w900,
      align: TextAlign.center,
      color: const Color(0xFF335AA6),
      z: 40,
    ),
    _text(
      canvas,
      'pd_star2',
      0.69,
      0.73,
      0.12,
      0.10,
      '✶',
      null,
      35,
      weight: FontWeight.w900,
      align: TextAlign.center,
      color: const Color(0xFF335AA6),
      z: 40,
    ),
    _text(
      canvas,
      'pd_star3',
      0.84,
      0.12,
      0.10,
      0.08,
      '✶',
      null,
      16,
      weight: FontWeight.w900,
      color: const Color(0xFF335AA6),
      z: 40,
    ),
    _text(
      canvas,
      'pd_star4',
      0.84,
      0.80,
      0.08,
      0.06,
      '✶',
      null,
      13,
      weight: FontWeight.w900,
      color: const Color(0xFF335AA6),
      z: 40,
    ),
    _text(
      canvas,
      'pd_note',
      0.54,
      0.50,
      0.32,
      0.15,
      'Please add a short\ndescription about the topic.',
      null,
      7.4,
      align: TextAlign.left,
      color: const Color(0xFF555555),
      fontFamily: 'Cormorant',
      height: 1.2,
      z: 20,
    ),
    _text(
      canvas,
      'pd_note2',
      0.09,
      0.53,
      0.42,
      0.07,
      'Explain the chosen detail\nwe selected on the picture',
      null,
      6.8,
      align: TextAlign.left,
      color: const Color(0xFF555555),
      fontFamily: 'Cormorant',
      height: 1.15,
      z: 20,
    ),
  ];
}

List<LayerModel> _buildKidsLifePortrait(Size canvas) {
  return [
    _bg(canvas, 'kl_bg', 'paperBrown', z: 0),
    _text(
      canvas,
      'kl_strip',
      0.04,
      0.02,
      0.92,
      0.07,
      '✎  ᯓ  ૮   little moments',
      null,
      9,
      color: const Color(0xFF6C4D32),
      fontFamily: 'Run',
      letterSpacing: 0.4,
      z: 24,
    ),
    _text(
      canvas,
      'kl_title',
      0.29,
      0.37,
      0.40,
      0.12,
      'My Kids,\nMy Life.',
      null,
      18,
      weight: FontWeight.w900,
      align: TextAlign.center,
      color: const Color(0xFF2F1F12),
      fontFamily: 'BookMyungjo',
      height: 0.90,
      z: 40,
    ),
    _text(
      canvas,
      'kl_note',
      0.17,
      0.45,
      0.28,
      0.07,
      'Lorem ipsum',
      'noteTornBeige',
      7.2,
      align: TextAlign.left,
      color: const Color(0xFF4C3A2B),
      fontFamily: 'Cormorant',
      z: 41,
    ),
    _text(
      canvas,
      'kl_doodle_top',
      0.06,
      0.01,
      0.20,
      0.05,
      '🐻  ∿  🐶',
      null,
      10,
      color: const Color(0xFF4B3525),
      z: 30,
    ),
    _image(
      canvas,
      'kl_1',
      0.04,
      0.08,
      0.31,
      0.29,
      frame: 'photoCard',
      rotation: -3,
      z: 10,
    ),
    _image(
      canvas,
      'kl_2',
      0.36,
      0.08,
      0.29,
      0.29,
      frame: 'photoCard',
      rotation: 1.5,
      z: 10,
    ),
    _image(
      canvas,
      'kl_3',
      0.66,
      0.08,
      0.30,
      0.30,
      frame: 'photoCard',
      rotation: 5,
      z: 10,
    ),
    _image(
      canvas,
      'kl_4',
      0.04,
      0.49,
      0.39,
      0.30,
      frame: 'photoCard',
      rotation: -2,
      z: 10,
    ),
    _image(
      canvas,
      'kl_5',
      0.57,
      0.49,
      0.39,
      0.29,
      frame: 'photoCard',
      rotation: 3.5,
      z: 10,
    ),
    _image(
      canvas,
      'kl_6',
      0.04,
      0.81,
      0.31,
      0.15,
      frame: 'photoCard',
      rotation: -1,
      z: 10,
    ),
    _image(
      canvas,
      'kl_7',
      0.36,
      0.81,
      0.28,
      0.15,
      frame: 'photoCard',
      rotation: 1,
      z: 10,
    ),
    _image(
      canvas,
      'kl_8',
      0.66,
      0.80,
      0.30,
      0.17,
      frame: 'photoCard',
      rotation: -2.8,
      z: 10,
    ),
    _text(
      canvas,
      'kl_bottom_torn',
      0.26,
      0.94,
      0.48,
      0.055,
      '',
      'noteTornGray',
      1,
      z: 6,
    ),
    _text(
      canvas,
      'kl_flower',
      0.43,
      0.90,
      0.14,
      0.06,
      '✿',
      null,
      18,
      color: const Color(0xFFF2B2B8),
      z: 41,
    ),
  ];
}

List<LayerModel> _buildPaperNotePortrait(Size canvas) {
  return [
    _bg(canvas, 'pn_bg', 'paperWarm', z: 0),
    _image(
      canvas,
      'pn_main',
      0.11,
      0.14,
      0.78,
      0.47,
      frame: 'tornPaperCard',
      z: 10,
    ),
    _text(
      canvas,
      'pn_torn_border',
      0.095,
      0.13,
      0.81,
      0.50,
      '',
      'noteTornCream',
      1,
      z: 9,
    ),
    _text(
      canvas,
      'pn_title',
      0.16,
      0.66,
      0.68,
      0.11,
      '매 순간이 특별한\n당신의 일상',
      null,
      14.2,
      weight: FontWeight.w500,
      align: TextAlign.center,
      color: Colors.white,
      fontFamily: 'SeoulNamsan',
      height: 1.2,
      z: 30,
    ),
    _text(
      canvas,
      'pn_clip',
      0.72,
      0.15,
      0.10,
      0.06,
      '📎',
      null,
      16,
      color: const Color(0xFFA4AFB8),
      z: 32,
    ),
    _text(
      canvas,
      'pn_handle',
      0.16,
      0.83,
      0.68,
      0.055,
      '@MIRI_HAPPY',
      null,
      8.2,
      align: TextAlign.center,
      color: Colors.white.withOpacity(0.9),
      fontFamily: 'Cormorant',
      letterSpacing: 1.4,
      z: 30,
    ),
  ];
}

List<LayerModel> _buildMiricarPortrait(Size canvas) {
  return [
    _bg(canvas, 'mc_bg', 'darkVignette', z: 0),
    _image(
      canvas,
      'mc_main',
      0.18,
      0.14,
      0.64,
      0.62,
      frame: 'posterPolaroid',
      z: 10,
    ),
    _text(
      canvas,
      'mc_caption',
      0.25,
      0.61,
      0.50,
      0.10,
      '오늘의 선택이 내일의 웃음을 만듭니다.\n당신의 선택을 응원합니다.',
      null,
      9.6,
      align: TextAlign.center,
      color: const Color(0xFF111111),
      fontFamily: 'SeoulNamsan',
      height: 1.3,
      z: 30,
    ),
    _text(
      canvas,
      'mc_brand',
      0.25,
      0.88,
      0.50,
      0.075,
      '◜  MIRICAR',
      null,
      11.0,
      weight: FontWeight.w800,
      align: TextAlign.center,
      color: Colors.white,
      fontFamily: 'Raleway',
      letterSpacing: 1.2,
      z: 30,
    ),
  ];
}

List<LayerModel> _buildTravelTapePortrait(Size canvas) {
  return [
    _bg(canvas, 'tt_bg', 'paperWarm', z: 0),
    _image(
      canvas,
      'tt_main',
      0.19,
      0.15,
      0.62,
      0.54,
      frame: 'paperTapeCard',
      z: 10,
    ),
    _text(
      canvas,
      'tt_tape',
      0.40,
      0.105,
      0.20,
      0.05,
      '╶╶╶╶',
      null,
      20,
      color: const Color(0xFFD8BF8D),
      z: 32,
    ),
    _text(
      canvas,
      'tt_title',
      0.22,
      0.705,
      0.56,
      0.115,
      '두근 두근\n바캉스 가자',
      null,
      14.5,
      weight: FontWeight.w700,
      align: TextAlign.center,
      color: const Color(0xFFB16A3E),
      fontFamily: 'Yeongwol',
      height: 1.18,
      z: 30,
    ),
    _text(
      canvas,
      'tt_flower',
      0.71,
      0.48,
      0.11,
      0.09,
      '❀',
      null,
      18,
      color: const Color(0xFFE7E2B5),
      z: 32,
    ),
    _text(
      canvas,
      'tt_tape2',
      0.64,
      0.56,
      0.16,
      0.05,
      '╶╶',
      null,
      16,
      color: const Color(0xFFEAD8B4),
      rotation: -20,
      z: 32,
    ),
  ];
}

List<LayerModel> _buildSeasonsPosterPortrait(Size canvas) {
  return [
    _bg(canvas, 'sp_bg', 'paperYellow', z: 0),
    _text(
      canvas,
      'sp_title',
      0.12,
      0.07,
      0.76,
      0.10,
      'SEASONS OF 2026',
      null,
      15,
      weight: FontWeight.w500,
      align: TextAlign.center,
      color: const Color(0xFF303030),
      fontFamily: 'BookMyungjo',
      letterSpacing: 0.8,
      z: 30,
    ),
    _image(
      canvas,
      'sp_main',
      0.21,
      0.20,
      0.58,
      0.50,
      frame: 'collageTile',
      z: 10,
    ),
    _text(
      canvas,
      'sp_footer',
      0.12,
      0.72,
      0.76,
      0.22,
      'TWELVE STORIES, ONE YEAR\nTHROUGH WINDING ROADS AND SHIFTING SKIES,\nWE RETURN TO OURSELVES. EACH JOURNEY CARRIES\nTHE HUES OF THE SEASON.',
      null,
      7.3,
      align: TextAlign.center,
      color: const Color(0xFF4D4D4D),
      fontFamily: 'BookMyungjo',
      height: 1.30,
      z: 20,
    ),
  ];
}

TemplateAspect _aspectForCanvas(Size canvas) {
  final ratio = canvas.width / canvas.height;
  if ((ratio - 1.0).abs() < 0.08) return TemplateAspect.square;
  return ratio > 1.0 ? TemplateAspect.landscape : TemplateAspect.portrait;
}

List<LayerModel> _buildPortraitReferenceTemplate(
  Size canvas,
  List<LayerModel> Function(Size referenceCanvas) portraitBuilder,
) {
  final aspect = _aspectForCanvas(canvas);
  if (aspect == TemplateAspect.portrait) return portraitBuilder(canvas);

  const reference = Size(300, 480);
  final layers = portraitBuilder(reference);
  // 가로/정사각 비율에서 잘림이 생기지 않도록 contain 스케일을 사용한다.
  final scaleX = canvas.width / reference.width;
  final scaleY = canvas.height / reference.height;
  final scale = (scaleX < scaleY ? scaleX : scaleY) * 0.98;
  final dx = (canvas.width - (reference.width * scale)) / 2;
  final dy = (canvas.height - (reference.height * scale)) / 2;

  final transformed = layers.map((layer) {
    if (layer.type == LayerType.decoration &&
        layer.position == Offset.zero &&
        (layer.width - reference.width).abs() < 0.1 &&
        (layer.height - reference.height).abs() < 0.1) {
      return layer.copyWith(
        position: Offset.zero,
        width: canvas.width,
        height: canvas.height,
      );
    }

    final baseStyle = layer.textStyle;
    final nextStyle = baseStyle?.copyWith(
      fontSize: (baseStyle.fontSize ?? 12) * scale,
      letterSpacing: baseStyle.letterSpacing == null
          ? null
          : baseStyle.letterSpacing! * scale,
    );
    return layer.copyWith(
      position: Offset(
        (layer.position.dx * scale) + dx,
        (layer.position.dy * scale) + dy,
      ),
      width: layer.width * scale,
      height: layer.height * scale,
      textStyle: nextStyle,
    );
  }).toList();

  // 비정사이즈(정사각/가로)에서 회전된 요소까지 포함해 자동으로 안쪽에 맞춘다.
  final fittingLayers = transformed
      .where((layer) => !_isTemplateBackgroundLayer(layer, canvas))
      .toList();
  if (fittingLayers.isEmpty) return transformed;

  final bounds = _computeLayerUnionBounds(fittingLayers);
  if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
    return transformed;
  }

  final target = Rect.fromLTWH(0, 0, canvas.width, canvas.height).deflate(2);
  final fitScale = math.min(
    1.0,
    math.min(target.width / bounds.width, target.height / bounds.height) *
        0.995,
  );
  final shift = target.center - bounds.center;

  return transformed.map((layer) {
    if (_isTemplateBackgroundLayer(layer, canvas)) return layer;
    final baseStyle = layer.textStyle;
    final nextStyle = baseStyle?.copyWith(
      fontSize: (baseStyle.fontSize ?? 12) * fitScale,
      letterSpacing: baseStyle.letterSpacing == null
          ? null
          : baseStyle.letterSpacing! * fitScale,
    );

    final center = Offset(
      layer.position.dx + (layer.width / 2),
      layer.position.dy + (layer.height / 2),
    );
    final alignedCenter = Offset(
      target.center.dx + ((center.dx - bounds.center.dx) * fitScale),
      target.center.dy + ((center.dy - bounds.center.dy) * fitScale),
    );
    final newW = layer.width * fitScale;
    final newH = layer.height * fitScale;
    return layer.copyWith(
      position: Offset(
        alignedCenter.dx - (newW / 2) + shift.dx * 0.05,
        alignedCenter.dy - (newH / 2) + shift.dy * 0.05,
      ),
      width: newW,
      height: newH,
      textStyle: nextStyle,
    );
  }).toList();
}

bool _isTemplateBackgroundLayer(LayerModel layer, Size canvas) {
  return layer.type == LayerType.decoration &&
      layer.position == Offset.zero &&
      (layer.width - canvas.width).abs() < 0.1 &&
      (layer.height - canvas.height).abs() < 0.1;
}

Rect? _computeLayerUnionBounds(List<LayerModel> layers) {
  Rect? union;
  for (final layer in layers) {
    final rect = _rotatedLayerBounds(layer);
    union = union == null ? rect : union.expandToInclude(rect);
  }
  return union;
}

Rect _rotatedLayerBounds(LayerModel layer) {
  final radians = layer.rotation * math.pi / 180.0;
  final cosA = math.cos(radians).abs();
  final sinA = math.sin(radians).abs();
  final rotatedW = (layer.width * cosA) + (layer.height * sinA);
  final rotatedH = (layer.width * sinA) + (layer.height * cosA);
  final center = Offset(
    layer.position.dx + (layer.width / 2),
    layer.position.dy + (layer.height / 2),
  );
  return Rect.fromCenter(center: center, width: rotatedW, height: rotatedH);
}

List<LayerModel> _buildWeddingDayTemplate(Size canvas) =>
    _buildPortraitReferenceTemplate(canvas, _buildWeddingDayPortrait);
List<LayerModel> _buildKidsCollageTemplate(Size canvas) =>
    _buildPortraitReferenceTemplate(canvas, _buildKidsCollagePortrait);
List<LayerModel> _buildPhotoDumpTemplate(Size canvas) =>
    _buildPortraitReferenceTemplate(canvas, _buildPhotoDumpPortrait);
List<LayerModel> _buildKidsLifeTemplate(Size canvas) =>
    _buildPortraitReferenceTemplate(canvas, _buildKidsLifePortrait);
List<LayerModel> _buildPaperNoteTemplate(Size canvas) =>
    _buildPortraitReferenceTemplate(canvas, _buildPaperNotePortrait);
List<LayerModel> _buildMiricarTemplate(Size canvas) =>
    _buildPortraitReferenceTemplate(canvas, _buildMiricarPortrait);
List<LayerModel> _buildTravelTapeTemplate(Size canvas) =>
    _buildPortraitReferenceTemplate(canvas, _buildTravelTapePortrait);
List<LayerModel> _buildSeasonsPosterTemplate(Size canvas) =>
    _buildPortraitReferenceTemplate(canvas, _buildSeasonsPosterPortrait);

List<DesignTemplate> designTemplates = [
  DesignTemplate(
    id: 'portrait_magazine_001',
    name: '세로 매거진',
    buildLayers: _buildPortraitMagazine,
    aspect: TemplateAspect.portrait,
  ),
  DesignTemplate(
    id: 'portrait_story_001',
    name: '세로 스토리',
    buildLayers: _buildPortraitStory,
    aspect: TemplateAspect.portrait,
  ),
  DesignTemplate(
    id: 'portrait_collage_001',
    name: '세로 콜라주',
    buildLayers: _buildPortraitCollage,
    aspect: TemplateAspect.portrait,
  ),
  DesignTemplate(
    id: 'portrait_pastel_001',
    name: '세로 파스텔',
    buildLayers: _buildPortraitPastel,
    aspect: TemplateAspect.portrait,
  ),
  DesignTemplate(
    id: 'portrait_vintage_001',
    name: '세로 빈티지',
    buildLayers: _buildPortraitVintage,
    aspect: TemplateAspect.portrait,
  ),
  DesignTemplate(
    id: 'portrait_minimal_001',
    name: '세로 미니멀',
    buildLayers: _buildPortraitMinimal,
    aspect: TemplateAspect.portrait,
  ),
  DesignTemplate(
    id: 'portrait_travel_001',
    name: '세로 트래블',
    buildLayers: _buildPortraitTravel,
    aspect: TemplateAspect.portrait,
  ),
  DesignTemplate(
    id: 'portrait_classic_001',
    name: '세로 클래식',
    buildLayers: _buildPortraitClassicPoster,
    aspect: TemplateAspect.portrait,
  ),
  DesignTemplate(
    id: 'portrait_ribbon_001',
    name: '세로 리본',
    buildLayers: _buildPortraitRibbon,
    aspect: TemplateAspect.portrait,
  ),
  DesignTemplate(
    id: 'portrait_wedding_001',
    name: '세로 웨딩데이',
    buildLayers: _buildWeddingDayTemplate,
    aspect: TemplateAspect.any,
  ),
  DesignTemplate(
    id: 'portrait_kids_collage_001',
    name: '세로 키즈 콜라주',
    buildLayers: _buildKidsCollageTemplate,
    aspect: TemplateAspect.any,
  ),
  DesignTemplate(
    id: 'portrait_photo_dump_001',
    name: '세로 포토덤프',
    buildLayers: _buildPhotoDumpTemplate,
    aspect: TemplateAspect.any,
  ),
  DesignTemplate(
    id: 'portrait_kids_life_001',
    name: '세로 키즈라이프',
    buildLayers: _buildKidsLifeTemplate,
    aspect: TemplateAspect.any,
  ),
  DesignTemplate(
    id: 'portrait_paper_note_001',
    name: '세로 페이퍼노트',
    buildLayers: _buildPaperNoteTemplate,
    aspect: TemplateAspect.any,
  ),
  DesignTemplate(
    id: 'portrait_miricar_001',
    name: '세로 미리카',
    buildLayers: _buildMiricarTemplate,
    aspect: TemplateAspect.any,
  ),
  DesignTemplate(
    id: 'portrait_travel_tape_001',
    name: '세로 트래블테이프',
    buildLayers: _buildTravelTapeTemplate,
    aspect: TemplateAspect.any,
  ),
  DesignTemplate(
    id: 'portrait_seasons_001',
    name: '세로 시즌즈',
    buildLayers: _buildSeasonsPosterTemplate,
    aspect: TemplateAspect.any,
  ),
  DesignTemplate(
    id: 'square_grid_001',
    name: '정사각 그리드',
    buildLayers: _buildSquareGrid,
    aspect: TemplateAspect.square,
  ),
  DesignTemplate(
    id: 'square_center_001',
    name: '정사각 센터',
    buildLayers: _buildSquareCenter,
    aspect: TemplateAspect.square,
  ),
  DesignTemplate(
    id: 'square_tape_001',
    name: '정사각 테이프',
    buildLayers: _buildSquareTape,
    aspect: TemplateAspect.square,
  ),
  DesignTemplate(
    id: 'square_pastel_001',
    name: '정사각 파스텔',
    buildLayers: _buildSquarePastel,
    aspect: TemplateAspect.square,
  ),
  DesignTemplate(
    id: 'square_vintage_001',
    name: '정사각 빈티지',
    buildLayers: _buildSquareVintage,
    aspect: TemplateAspect.square,
  ),
  DesignTemplate(
    id: 'square_minimal_001',
    name: '정사각 미니멀',
    buildLayers: _buildSquareMinimal,
    aspect: TemplateAspect.square,
  ),
  DesignTemplate(
    id: 'square_travel_001',
    name: '정사각 트래블',
    buildLayers: _buildSquareTravel,
    aspect: TemplateAspect.square,
  ),
  DesignTemplate(
    id: 'square_mosaic_001',
    name: '정사각 모자이크',
    buildLayers: _buildSquareMosaic,
    aspect: TemplateAspect.square,
  ),
  DesignTemplate(
    id: 'square_stamp_001',
    name: '정사각 스탬프',
    buildLayers: _buildSquareStamp,
    aspect: TemplateAspect.square,
  ),
  DesignTemplate(
    id: 'landscape_banner_001',
    name: '가로 배너',
    buildLayers: _buildLandscapeBanner,
    aspect: TemplateAspect.landscape,
  ),
  DesignTemplate(
    id: 'landscape_film_001',
    name: '가로 필름',
    buildLayers: _buildLandscapeFilm,
    aspect: TemplateAspect.landscape,
  ),
  DesignTemplate(
    id: 'landscape_triptych_001',
    name: '가로 트립틱',
    buildLayers: _buildLandscapeTriptych,
    aspect: TemplateAspect.landscape,
  ),
  DesignTemplate(
    id: 'landscape_pastel_001',
    name: '가로 파스텔',
    buildLayers: _buildLandscapePastel,
    aspect: TemplateAspect.landscape,
  ),
  DesignTemplate(
    id: 'landscape_vintage_001',
    name: '가로 빈티지',
    buildLayers: _buildLandscapeVintage,
    aspect: TemplateAspect.landscape,
  ),
  DesignTemplate(
    id: 'landscape_minimal_001',
    name: '가로 미니멀',
    buildLayers: _buildLandscapeMinimal,
    aspect: TemplateAspect.landscape,
  ),
  DesignTemplate(
    id: 'landscape_travel_001',
    name: '가로 트래블',
    buildLayers: _buildLandscapeTravel,
    aspect: TemplateAspect.landscape,
  ),
  DesignTemplate(
    id: 'landscape_magazine_001',
    name: '가로 매거진',
    buildLayers: _buildLandscapeMagazine,
    aspect: TemplateAspect.landscape,
  ),
  DesignTemplate(
    id: 'landscape_strip_001',
    name: '가로 스트립',
    buildLayers: _buildLandscapeStrip,
    aspect: TemplateAspect.landscape,
  ),
];
