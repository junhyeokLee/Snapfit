import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/album/domain/entities/layer.dart';

enum TemplateAspect { portrait, square, landscape, any }

enum TemplateDifficulty { easy, normal, hard }

class DesignTemplate {
  final String id;
  final String name;
  final bool forCover;
  final TemplateAspect aspect;
  final String category;
  final List<String> tags;
  final String style;
  final int recommendedPhotoCount;
  final TemplateDifficulty difficulty;
  final bool isFeatured;
  final int priority;
  final Color? backgroundColor;
  final String previewThumbUrl;
  final String previewDetailUrl;
  final List<String> previewImageUrls;
  final List<LayerModel> Function(Size canvasSize) buildLayers;

  const DesignTemplate({
    required this.id,
    required this.name,
    required this.buildLayers,
    this.forCover = false,
    this.aspect = TemplateAspect.any,
    this.category = '전체',
    this.tags = const [],
    this.style = 'general',
    this.recommendedPhotoCount = 6,
    this.difficulty = TemplateDifficulty.normal,
    this.isFeatured = false,
    this.priority = 0,
    this.backgroundColor,
    this.previewThumbUrl = '',
    this.previewDetailUrl = '',
    this.previewImageUrls = const [],
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

LayerModel _deco(
  Size canvas,
  String id,
  double x,
  double y,
  double w,
  double h,
  String style, {
  double rotation = 0,
  int z = 50,
}) {
  return LayerModel(
    id: id,
    type: LayerType.decoration,
    position: _p(canvas, x, y),
    width: _s(canvas, w, h).width,
    height: _s(canvas, w, h).height,
    rotation: rotation,
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

List<LayerModel> _buildLandscapeNightTape(Size canvas) {
  return [
    _bg(canvas, 'lnt_bg', 'darkVignette', z: 0),
    _image(canvas, 'lnt_1', 0.04, 0.18, 0.28, 0.68, frame: 'vhs', z: 10),
    _image(canvas, 'lnt_2', 0.35, 0.18, 0.28, 0.68, frame: 'neon', z: 11),
    _image(canvas, 'lnt_3', 0.66, 0.18, 0.30, 0.68, frame: 'toxicGlow', z: 12),
    _text(
      canvas,
      'lnt_title',
      0.08,
      0.05,
      0.44,
      0.09,
      'NIGHT TAPE',
      'labelSolidBlue',
      11,
      weight: FontWeight.w800,
      color: Colors.white,
      z: 30,
    ),
    _deco(canvas, 'lnt_s1', 0.93, 0.06, 0.06, 0.06, 'stickerSparkleGold'),
    _deco(canvas, 'lnt_s2', 0.01, 0.84, 0.08, 0.08, 'stickerSparkleBlue'),
  ];
}

List<LayerModel> _buildPortraitBlossomPoster(Size canvas) {
  return [
    _bg(canvas, 'pbp_bg', 'blossomPinkDust', z: 0),
    _image(
      canvas,
      'pbp_main',
      0.22,
      0.26,
      0.56,
      0.56,
      frame: 'polaroidClassic',
      z: 10,
    ),
    _image(
      canvas,
      'pbp_left',
      0.06,
      0.44,
      0.30,
      0.26,
      frame: 'posterPolaroid',
      rotation: -7,
      z: 9,
    ),
    _image(
      canvas,
      'pbp_right',
      0.64,
      0.42,
      0.30,
      0.26,
      frame: 'posterPolaroid',
      rotation: 6,
      z: 9,
    ),
    _text(
      canvas,
      'pbp_title',
      0.18,
      0.06,
      0.64,
      0.15,
      '꽃은 피고\n셔터는 터지고',
      '',
      20,
      weight: FontWeight.w800,
      color: Colors.white,
      z: 30,
    ),
    _deco(
      canvas,
      'pbp_flower1',
      0.84,
      0.30,
      0.10,
      0.10,
      'stickerCherryBlossom',
    ),
    _deco(
      canvas,
      'pbp_flower2',
      0.05,
      0.54,
      0.10,
      0.10,
      'stickerCherryBlossom',
    ),
    _deco(
      canvas,
      'pbp_flower3',
      0.80,
      0.60,
      0.10,
      0.10,
      'stickerCherryBlossom',
    ),
    _deco(canvas, 'pbp_cam', 0.77, 0.79, 0.17, 0.12, 'stickerInstantCamera'),
  ];
}

List<LayerModel> _buildSquareSummerLetter(Size canvas) {
  return [
    _bg(canvas, 'ssl_bg', 'softSkyBloom', z: 0),
    _deco(
      canvas,
      'ssl_env',
      0.24,
      0.30,
      0.52,
      0.40,
      'stickerEnvelopeBlue',
      z: 15,
    ),
    _text(
      canvas,
      'ssl_title',
      0.20,
      0.10,
      0.60,
      0.10,
      'Summer day',
      '',
      18,
      weight: FontWeight.w500,
      color: Colors.white,
      z: 30,
    ),
    _text(
      canvas,
      'ssl_msg',
      0.33,
      0.40,
      0.34,
      0.12,
      '무더운 날씨에도\n무너지지 말아요',
      'note',
      8,
      weight: FontWeight.w600,
      color: Colors.black87,
      z: 35,
    ),
    _deco(canvas, 'ssl_clover1', 0.16, 0.34, 0.10, 0.10, 'stickerCloverGreen'),
    _deco(canvas, 'ssl_clover2', 0.72, 0.56, 0.10, 0.10, 'stickerCloverGreen'),
    _deco(canvas, 'ssl_cloud1', 0.04, 0.78, 0.24, 0.12, 'stickerCloudSoft'),
    _deco(canvas, 'ssl_cloud2', 0.72, 0.80, 0.22, 0.12, 'stickerCloudSoft'),
  ];
}

List<LayerModel> _buildPortraitSaveTheDate(Size canvas) {
  return [
    _bg(canvas, 'psd2_bg', 'softSkyBloom', z: 0),
    _image(
      canvas,
      'psd2_main',
      0.08,
      0.12,
      0.84,
      0.74,
      frame: 'floatingGlass',
      z: 10,
    ),
    _text(
      canvas,
      'psd2_date',
      0.30,
      0.05,
      0.40,
      0.06,
      '2025.10.12 SAT',
      '',
      10,
      weight: FontWeight.w800,
      color: Colors.white,
      z: 30,
    ),
    _text(
      canvas,
      'psd2_title',
      0.30,
      0.66,
      0.40,
      0.10,
      'SAVE\nTHE DATE',
      '',
      18,
      weight: FontWeight.w800,
      color: Colors.white,
      z: 30,
    ),
    _deco(
      canvas,
      'psd2_flower',
      0.84,
      0.74,
      0.10,
      0.10,
      'stickerCherryBlossom',
    ),
    _deco(
      canvas,
      'psd2_flower2',
      0.05,
      0.74,
      0.10,
      0.10,
      'stickerCherryBlossom',
    ),
  ];
}

List<LayerModel> _buildPortraitFullBleedWeddingClassic(Size canvas) {
  return [
    _image(canvas, 'pfwc_bg', 0, 0, 1, 1, z: 0),
    _text(
      canvas,
      'pfwc_head',
      0.30,
      0.08,
      0.40,
      0.05,
      'THE MARRIAGE OF',
      '',
      9,
      weight: FontWeight.w700,
      letterSpacing: 1.0,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'pfwc_names',
      0.10,
      0.16,
      0.80,
      0.20,
      'Jiwon Park\nand Minji Kim',
      '',
      22,
      weight: FontWeight.w500,
      height: 1.2,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'pfwc_info',
      0.10,
      0.78,
      0.80,
      0.06,
      '2025.10.12  |  SATURDAY  |  3PM  |  SEOUL',
      '',
      10,
      weight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'pfwc_desc',
      0.14,
      0.86,
      0.72,
      0.08,
      'Together with their families, invite you\n to celebrate their love.',
      '',
      8,
      weight: FontWeight.w500,
      color: const Color(0xFFEAEAEA),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildPortraitFullBleedRoseDay(Size canvas) {
  return [
    _image(canvas, 'pfrd_bg', 0, 0, 1, 1, z: 0),
    _text(
      canvas,
      'pfrd_title',
      0.22,
      0.12,
      0.56,
      0.10,
      'ROSE DAY',
      '',
      20,
      weight: FontWeight.w800,
      letterSpacing: 0.6,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'pfrd_sub',
      0.22,
      0.22,
      0.56,
      0.05,
      'you are prettier than roses',
      '',
      8,
      weight: FontWeight.w500,
      color: const Color(0xFFEAF2FF),
      z: 20,
    ),
    _text(
      canvas,
      'pfrd_date',
      0.20,
      0.30,
      0.60,
      0.05,
      '5월 14일, 당신과 함께하는 특별한 날',
      '',
      8,
      weight: FontWeight.w600,
      color: const Color(0xFFDCE6F2),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildPortraitFullBleedTimeInvite(Size canvas) {
  return [
    _image(canvas, 'pfti_bg', 0, 0, 1, 1, z: 0),
    _text(
      canvas,
      'pfti_date',
      0.38,
      0.06,
      0.24,
      0.05,
      '10/12',
      '',
      10,
      weight: FontWeight.w700,
      letterSpacing: 1.2,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'pfti_time',
      0.24,
      0.12,
      0.52,
      0.14,
      '3:00',
      '',
      34,
      weight: FontWeight.w800,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'pfti_names',
      0.22,
      0.30,
      0.56,
      0.07,
      'Jiwon and Minji',
      '',
      11,
      weight: FontWeight.w500,
      color: const Color(0xFFF4F4F4),
      z: 20,
    ),
    _text(
      canvas,
      'pfti_loc',
      0.20,
      0.84,
      0.60,
      0.05,
      'MAISON DE BLOSSOM, SEOUL',
      '',
      8,
      weight: FontWeight.w700,
      letterSpacing: 0.8,
      color: const Color(0xFFEEEEEE),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildSquareFullBleedMarriageScript(Size canvas) {
  return [
    _image(canvas, 'sfbms_bg', 0, 0, 1, 1, z: 0),
    _text(
      canvas,
      'sfbms_top',
      0.32,
      0.07,
      0.36,
      0.05,
      '10월 12일 토요일',
      '',
      8,
      weight: FontWeight.w700,
      color: const Color(0xFFE9E9E9),
      z: 20,
    ),
    _text(
      canvas,
      'sfbms_title',
      0.22,
      0.20,
      0.56,
      0.18,
      'The\nMarriage\nof',
      '',
      20,
      weight: FontWeight.w500,
      height: 1.05,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'sfbms_names',
      0.22,
      0.54,
      0.56,
      0.07,
      'SANGWOO KANG & JISOO YOON',
      '',
      8,
      weight: FontWeight.w700,
      letterSpacing: 0.7,
      color: const Color(0xFFF5F5F5),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildSquareFullBleedDateStack(Size canvas) {
  return [
    _image(canvas, 'sfbds_bg', 0, 0, 1, 1, z: 0),
    _text(
      canvas,
      'sfbds_date',
      0.64,
      0.24,
      0.18,
      0.28,
      '26\n04\n25',
      '',
      20,
      weight: FontWeight.w700,
      height: 1.2,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'sfbds_names',
      0.22,
      0.78,
      0.56,
      0.07,
      '박지준  &  김미리',
      '',
      10,
      weight: FontWeight.w700,
      color: const Color(0xFFF2F2F2),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildLandscapeFullBleedEditorialWedding(Size canvas) {
  return [
    _image(canvas, 'lfbew_bg', 0, 0, 1, 1, z: 0),
    _text(
      canvas,
      'lfbew_top',
      0.32,
      0.08,
      0.36,
      0.05,
      'SANGWOO KANG  &  JISOO YOON',
      '',
      8,
      weight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'lfbew_title',
      0.24,
      0.62,
      0.52,
      0.14,
      'Our Wedding Day',
      '',
      28,
      weight: FontWeight.w500,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'lfbew_info',
      0.32,
      0.77,
      0.36,
      0.05,
      '2025.9.7 SUN',
      '',
      8,
      weight: FontWeight.w700,
      color: const Color(0xFFECECEC),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildLandscapeFullBleedMinimalInvite(Size canvas) {
  return [
    _image(canvas, 'lfbmi_bg', 0, 0, 1, 1, z: 0),
    _text(
      canvas,
      'lfbmi_names_l',
      0.05,
      0.24,
      0.22,
      0.30,
      'JI\nWON',
      '',
      24,
      weight: FontWeight.w500,
      height: 1.0,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'lfbmi_names_r',
      0.73,
      0.54,
      0.22,
      0.30,
      'MIN\nJI',
      '',
      24,
      weight: FontWeight.w500,
      height: 1.0,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'lfbmi_center',
      0.42,
      0.56,
      0.16,
      0.06,
      'and',
      '',
      10,
      weight: FontWeight.w600,
      color: const Color(0xFFF0F0F0),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildPortraitPosterSummerCover(Size canvas) {
  return [
    _image(canvas, 'ppsc_bg', 0, 0, 1, 1, z: 0),
    _deco(canvas, 'ppsc_top', 0.00, 0.00, 1.00, 0.16, 'paperYellow', z: 8),
    _deco(canvas, 'ppsc_bottom', 0.00, 0.92, 1.00, 0.08, 'paperYellow', z: 8),
    _text(
      canvas,
      'ppsc_title',
      0.05,
      0.02,
      0.90,
      0.10,
      'SUMMER',
      '',
      42,
      weight: FontWeight.w900,
      letterSpacing: 1.2,
      align: TextAlign.left,
      color: const Color(0xFF1F2E46),
      z: 20,
    ),
    _text(
      canvas,
      'ppsc_open',
      0.08,
      0.18,
      0.40,
      0.07,
      'Opening: 08.17 2:00\n08.17-09.20',
      '',
      8,
      weight: FontWeight.w600,
      align: TextAlign.left,
      color: const Color(0xFFDFE6ED),
      z: 20,
    ),
    _text(
      canvas,
      'ppsc_name',
      0.64,
      0.72,
      0.30,
      0.06,
      'MIRI KIM',
      '',
      12,
      weight: FontWeight.w800,
      align: TextAlign.right,
      color: const Color(0xFFFADE78),
      z: 20,
    ),
    _text(
      canvas,
      'ppsc_foot',
      0.20,
      0.94,
      0.60,
      0.04,
      'MIRIKIM 1ST ART EXHIBITION',
      '',
      8,
      weight: FontWeight.w700,
      letterSpacing: 1.2,
      color: const Color(0xFF3D4660),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildPortraitPosterNoirCover(Size canvas) {
  return [
    _image(canvas, 'ppnc_bg', 0, 0, 1, 1, z: 0),
    _deco(canvas, 'ppnc_top', 0.00, 0.00, 1.00, 0.14, 'darkVignette', z: 8),
    _deco(canvas, 'ppnc_bottom', 0.00, 0.88, 1.00, 0.12, 'darkVignette', z: 8),
    _text(
      canvas,
      'ppnc_title',
      0.08,
      0.03,
      0.84,
      0.08,
      'MIDNIGHT ISSUE',
      '',
      18,
      weight: FontWeight.w900,
      letterSpacing: 1.0,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'ppnc_sub',
      0.10,
      0.14,
      0.40,
      0.06,
      'VOL. 02  |  NIGHT CITY',
      '',
      8,
      weight: FontWeight.w700,
      align: TextAlign.left,
      color: const Color(0xFFD4D7E0),
      z: 20,
    ),
    _text(
      canvas,
      'ppnc_quote',
      0.10,
      0.76,
      0.80,
      0.08,
      'Silence is also a color.',
      '',
      11,
      weight: FontWeight.w500,
      align: TextAlign.left,
      color: const Color(0xFFF2F2F2),
      z: 20,
    ),
    _text(
      canvas,
      'ppnc_foot',
      0.10,
      0.92,
      0.80,
      0.05,
      'EDITORIAL ARCHIVE / 2026',
      '',
      8,
      weight: FontWeight.w700,
      letterSpacing: 1.2,
      align: TextAlign.center,
      color: const Color(0xFFD9DDE8),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildSquarePosterBoldCover(Size canvas) {
  return [
    _image(canvas, 'spbc_bg', 0, 0, 1, 1, z: 0),
    _deco(canvas, 'spbc_top', 0.00, 0.00, 1.00, 0.18, 'paperWarm', z: 8),
    _text(
      canvas,
      'spbc_title',
      0.05,
      0.03,
      0.90,
      0.10,
      'WEEKEND',
      '',
      30,
      weight: FontWeight.w900,
      letterSpacing: 1.0,
      align: TextAlign.left,
      color: const Color(0xFF243047),
      z: 20,
    ),
    _text(
      canvas,
      'spbc_mid',
      0.08,
      0.70,
      0.84,
      0.08,
      'A SIMPLE COVER STORY',
      '',
      10,
      weight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'spbc_foot',
      0.10,
      0.84,
      0.80,
      0.06,
      'MIRI MAGAZINE',
      '',
      9,
      weight: FontWeight.w700,
      letterSpacing: 1.0,
      color: const Color(0xFFECECEC),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildSquarePosterDateCover(Size canvas) {
  return [
    _image(canvas, 'spdc_bg', 0, 0, 1, 1, z: 0),
    _deco(canvas, 'spdc_left', 0.00, 0.00, 0.20, 1.00, 'darkVignette', z: 8),
    _text(
      canvas,
      'spdc_date',
      0.03,
      0.26,
      0.14,
      0.40,
      '26\n04\n25',
      '',
      17,
      weight: FontWeight.w800,
      height: 1.15,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'spdc_title',
      0.24,
      0.08,
      0.68,
      0.12,
      'COVER\nEDITION',
      '',
      20,
      weight: FontWeight.w900,
      align: TextAlign.left,
      color: Colors.white,
      z: 20,
    ),
    _text(
      canvas,
      'spdc_names',
      0.24,
      0.82,
      0.68,
      0.07,
      'JIWON  &  MINJI',
      '',
      10,
      weight: FontWeight.w700,
      letterSpacing: 0.8,
      color: const Color(0xFFF0F0F0),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildLandscapePosterExhibitionCover(Size canvas) {
  return [
    _image(canvas, 'lpec_bg', 0, 0, 1, 1, z: 0),
    _deco(canvas, 'lpec_top', 0.00, 0.00, 1.00, 0.17, 'paperYellow', z: 8),
    _deco(canvas, 'lpec_bottom', 0.00, 0.90, 1.00, 0.10, 'paperYellow', z: 8),
    _text(
      canvas,
      'lpec_title',
      0.04,
      0.03,
      0.92,
      0.10,
      'EXHIBITION',
      '',
      34,
      weight: FontWeight.w900,
      letterSpacing: 1.2,
      align: TextAlign.left,
      color: const Color(0xFF20304A),
      z: 20,
    ),
    _text(
      canvas,
      'lpec_meta',
      0.06,
      0.20,
      0.34,
      0.08,
      'Opening: 08.17\n08.17-09.20',
      '',
      8,
      align: TextAlign.left,
      weight: FontWeight.w700,
      color: const Color(0xFFE4EAF1),
      z: 20,
    ),
    _text(
      canvas,
      'lpec_foot',
      0.28,
      0.93,
      0.44,
      0.05,
      'MIRI 1ST ART EXHIBITION',
      '',
      8,
      weight: FontWeight.w700,
      letterSpacing: 1.1,
      color: const Color(0xFF36415A),
      z: 20,
    ),
  ];
}

List<LayerModel> _buildLandscapePosterSkyScriptCover(Size canvas) {
  return [
    _image(canvas, 'lpss_bg', 0, 0, 1, 1, z: 0),
    _deco(canvas, 'lpss_top', 0.00, 0.00, 1.00, 0.15, 'softSkyBloom', z: 8),
    _text(
      canvas,
      'lpss_title',
      0.24,
      0.05,
      0.52,
      0.08,
      'Weddingday',
      '',
      26,
      weight: FontWeight.w500,
      color: const Color(0xFFFCF3DA),
      z: 20,
    ),
    _text(
      canvas,
      'lpss_names',
      0.24,
      0.78,
      0.52,
      0.07,
      'JIWON PARK  ·  MINJI KIM',
      '',
      10,
      weight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Colors.white,
      z: 20,
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

typedef _TemplateLayerBuilder = List<LayerModel> Function(Size canvasSize);

class _TemplateSeed {
  final String id;
  final String name;
  final TemplateAspect aspect;
  final String category;
  final String style;
  final int recommendedPhotoCount;
  final TemplateDifficulty difficulty;
  final bool isFeatured;
  final int priority;
  final List<String> tags;
  final Color? backgroundColor;
  final _TemplateLayerBuilder buildLayers;

  const _TemplateSeed({
    required this.id,
    required this.name,
    required this.aspect,
    required this.category,
    required this.style,
    required this.recommendedPhotoCount,
    required this.difficulty,
    required this.buildLayers,
    this.tags = const [],
    this.isFeatured = false,
    this.priority = 0,
    this.backgroundColor,
  });
}

List<String> templatePreviewImagesFor(DesignTemplate template) {
  if (template.previewImageUrls.isNotEmpty) return template.previewImageUrls;
  return templatePreviewImagesForId(template.id);
}

List<LayerModel> injectTemplatePreviewImages(
  DesignTemplate template,
  List<LayerModel> layers, {
  bool fillPersistentUrls = false,
}) {
  final imageIndices = <int>[];
  for (var i = 0; i < layers.length; i++) {
    if (layers[i].type == LayerType.image) imageIndices.add(i);
  }
  if (imageIndices.isEmpty) return layers;

  final urls = templatePreviewImagesFor(template);
  if (urls.isEmpty) return layers;

  final next = [...layers];
  for (var i = 0; i < imageIndices.length; i++) {
    final idx = imageIndices[i];
    final layer = next[idx];
    final hasImage =
        (layer.previewUrl != null && layer.previewUrl!.isNotEmpty) ||
        (layer.imageUrl != null && layer.imageUrl!.isNotEmpty) ||
        (layer.originalUrl != null && layer.originalUrl!.isNotEmpty) ||
        layer.asset != null;
    if (hasImage) continue;
    final url = urls[i % urls.length];
    next[idx] = layer.copyWith(
      previewUrl: url,
      imageUrl: fillPersistentUrls ? url : layer.imageUrl,
      originalUrl: fillPersistentUrls ? url : layer.originalUrl,
    );
  }
  return next;
}

List<String> templatePreviewImagesForId(String templateId) {
  final fixed = _templatePreviewFixedById[templateId];
  if (fixed != null && fixed.isNotEmpty) return fixed;
  return _templatePreviewFallback(templateId);
}

String templatePreviewThumbForId(String templateId) =>
    templatePreviewImagesForId(templateId).first;

String templatePreviewDetailForId(String templateId) {
  final list = templatePreviewImagesForId(templateId);
  return list.length > 1 ? list[1] : list.first;
}

List<String> _templatePreviewFallback(String templateId) =>
    List.generate(8, (i) => _picsumSeed('$templateId-fallback', i + 1));

String _picsumSeed(
  String id,
  int slot, {
  bool grayscale = false,
  int blur = 0,
}) {
  final base = 'https://picsum.photos/seed/snapfit_${id}_$slot/1200/1600';
  final q = <String>[];
  if (grayscale) q.add('grayscale');
  if (blur > 0) q.add('blur=$blur');
  if (q.isEmpty) return base;
  return '$base?${q.join('&')}';
}

String _weddingSeed(int lock, {bool landscape = false}) {
  final list = landscape ? _weddingLandscapeSamples : _weddingPortraitSamples;
  return list[lock % list.length];
}

const List<String> _weddingPortraitSamples = [
  'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1520854221256-17451cc331bf?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1522673607350-04f725f60f4f?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1529636798458-92182e662485?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1504198458649-3128b932f49b?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1494783367193-149034c05e8f?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1519225421980-715cb0215aed?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?auto=format&fit=crop&w=1300&q=80',
  'https://images.unsplash.com/photo-1525328437458-0c4d4db7cab4?auto=format&fit=crop&w=1200&q=80',
];

const List<String> _weddingLandscapeSamples = [
  'https://images.unsplash.com/photo-1529636798458-92182e662485?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1519225421980-715cb0215aed?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1522673607350-04f725f60f4f?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1520854221256-17451cc331bf?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1504198458649-3128b932f49b?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1494783367193-149034c05e8f?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1525328437458-0c4d4db7cab4?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1700&q=80',
];

String _floralSeed(int lock) => _floralSamples[lock % _floralSamples.length];
String _partySeed(int lock) => _partySamples[lock % _partySamples.length];
String _noirSeed(int lock, {bool landscape = false}) {
  final list = landscape ? _noirLandscapeSamples : _noirPortraitSamples;
  return list[lock % list.length];
}

String _minimalSeed(int lock, {bool landscape = false}) {
  final list = landscape ? _minimalLandscapeSamples : _minimalPortraitSamples;
  return list[lock % list.length];
}

String _coverSeed(int lock, {bool landscape = false}) {
  final list = landscape ? _coverLandscapeSamples : _coverPortraitSamples;
  return list[lock % list.length];
}

const List<String> _floralSamples = [
  'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1468327768560-75b778cbb551?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1455659817273-f96807779a8a?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1527061011665-3652c757a4d4?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1525310072745-f49212b5ac6d?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1465146344425-f00d5f5c8f07?auto=format&fit=crop&w=1200&q=80',
];

const List<String> _partySamples = [
  'https://images.unsplash.com/photo-1464349153735-7db50ed83c84?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1530103862676-de8c9debad1d?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1469594292607-7bd90f8d3ba4?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1527529482837-4698179dc6ce?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1513151233558-d860c5398176?auto=format&fit=crop&w=1200&q=80',
];

const List<String> _noirPortraitSamples = [
  'https://images.unsplash.com/photo-1514565131-fce0801e5785?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1503342217505-b0a15ec3261c?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=80',
];

const List<String> _noirLandscapeSamples = [
  'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1514565131-fce0801e5785?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1494783367193-149034c05e8f?auto=format&fit=crop&w=1600&q=80',
];

const List<String> _minimalPortraitSamples = [
  'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1516222338250-863216ce01ea?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1493666438817-866a91353ca9?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1463320726281-696a485928c7?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?auto=format&fit=crop&w=1200&q=80',
];

const List<String> _minimalLandscapeSamples = [
  'https://images.unsplash.com/photo-1491553895911-0055eca6402d?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=1600&q=80',
];

const List<String> _coverPortraitSamples = [
  'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1521119989659-a83eee488004?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=1300&q=80',
  'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=1200&q=80',
];

const List<String> _coverLandscapeSamples = [
  'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1493244040629-496f6d136cc3?auto=format&fit=crop&w=1600&q=80',
  'https://images.unsplash.com/photo-1464822759844-d150ad6d07ea?auto=format&fit=crop&w=1600&q=80',
];

final Map<String, List<String>> _templatePreviewFixedById = {
  'data_ref_miricar_001': const [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=1200&q=80',
  ],
  'data_ref_seasons_001': const [
    'https://images.unsplash.com/photo-1473496169904-658ba7c44d8a?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1502082553048-f009c37129b9?auto=format&fit=crop&w=1200&q=80',
  ],
  'data_premium_blob_gallery_001': const [
    'https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1514852451047-f8e1d1cd9b64?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1510936111840-65e151ad71bb?auto=format&fit=crop&w=1200&q=80',
  ],
  'pack_portrait_travel_journal_001': [
    _weddingSeed(101),
    _weddingSeed(102),
    _weddingSeed(103),
    _weddingSeed(104),
  ],
  'pack_portrait_couple_story_001': [
    _weddingSeed(111),
    _weddingSeed(112),
    _weddingSeed(113),
    _weddingSeed(114),
  ],
  'pack_portrait_family_daily_001': [
    _noirSeed(201),
    _noirSeed(202),
    _noirSeed(203),
    _noirSeed(204),
  ],
  'pack_portrait_birthday_party_001': [
    _partySeed(211),
    _partySeed(212),
    _partySeed(213),
    _partySeed(214),
  ],
  'pack_portrait_mood_book_001': [
    _floralSeed(221),
    _floralSeed(222),
    _floralSeed(223),
    _floralSeed(224),
  ],
  'pack_portrait_wedding_day_001': [
    _weddingSeed(121),
    _weddingSeed(122),
    _weddingSeed(123),
    _weddingSeed(124),
  ],
  'pack_portrait_glitter_night_002': [
    _noirSeed(231),
    _noirSeed(232),
    _noirSeed(233),
    _noirSeed(234),
  ],
  'pack_portrait_ticket_journey_002': [
    _weddingSeed(131),
    _weddingSeed(132),
    _weddingSeed(133),
    _weddingSeed(134),
  ],
  'pack_square_travel_grid_001': [
    _coverSeed(301),
    _coverSeed(302),
    _coverSeed(303),
    _coverSeed(304),
  ],
  'pack_square_family_memory_001': [
    _coverSeed(311),
    _coverSeed(312),
    _coverSeed(313),
    _coverSeed(314),
  ],
  'pack_square_birthday_snap_001': [
    'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1513278974582-3e1b4a4fa21f?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1529635436167-b5f9b86f2f52?auto=format&fit=crop&w=1200&q=80',
  ],
  'pack_square_graduation_book_001': [
    _minimalSeed(331),
    _minimalSeed(332),
    _minimalSeed(333),
    _minimalSeed(334),
  ],
  'pack_square_minimal_sheet_001': [
    _minimalSeed(341),
    _minimalSeed(342),
    _minimalSeed(343),
    _minimalSeed(344),
  ],
  'pack_square_mood_card_001': [
    'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?auto=format&fit=crop&w=1200&q=80',
  ],
  'pack_square_retro_cut_002': [
    _minimalSeed(351),
    _minimalSeed(352),
    _minimalSeed(353),
    _minimalSeed(354),
  ],
  'pack_square_sugar_party_002': [
    _coverSeed(361),
    _coverSeed(362),
    _coverSeed(363),
    _coverSeed(364),
  ],
  'pack_landscape_travel_banner_001': [
    _weddingSeed(151, landscape: true),
    _weddingSeed(152, landscape: true),
    _weddingSeed(153, landscape: true),
    _weddingSeed(154, landscape: true),
  ],
  'pack_landscape_couple_film_001': [
    _weddingSeed(161, landscape: true),
    _weddingSeed(162, landscape: true),
    _weddingSeed(163, landscape: true),
    _weddingSeed(164, landscape: true),
  ],
  'pack_landscape_birthday_mix_001': [
    _coverSeed(411, landscape: true),
    _coverSeed(412, landscape: true),
    _coverSeed(413, landscape: true),
    _coverSeed(414, landscape: true),
  ],
  'pack_landscape_minimal_wide_001': [
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1600&q=80',
    'https://images.unsplash.com/photo-1473116763249-2faaef81ccda?auto=format&fit=crop&w=1600&q=80',
    'https://images.unsplash.com/photo-1493558103817-58b2924bce98?auto=format&fit=crop&w=1600&q=80',
    'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1600&q=80',
  ],
  'pack_landscape_city_travel_001': [
    _coverSeed(431, landscape: true),
    _coverSeed(432, landscape: true),
    _coverSeed(433, landscape: true),
    _coverSeed(434, landscape: true),
  ],
  'pack_landscape_ribbon_story_002': [
    _weddingSeed(171, landscape: true),
    _weddingSeed(172, landscape: true),
    _weddingSeed(173, landscape: true),
    _weddingSeed(174, landscape: true),
  ],
  'pack_landscape_night_reel_002': [
    _noirSeed(441, landscape: true),
    _noirSeed(442, landscape: true),
    _noirSeed(443, landscape: true),
    _noirSeed(444, landscape: true),
  ],
  'pack_landscape_poster_board_002': [
    'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1600&q=80',
    'https://images.unsplash.com/photo-1482192505345-5655af888cc4?auto=format&fit=crop&w=1600&q=80',
    'https://images.unsplash.com/photo-1514565131-fce0801e5785?auto=format&fit=crop&w=1600&q=80',
    'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=1600&q=80',
  ],
};

List<DesignTemplate> _buildExpandedTemplatePack() {
  const seeds = <_TemplateSeed>[
    _TemplateSeed(
      id: 'pack_portrait_travel_journal_001',
      name: '웨딩 클래식',
      aspect: TemplateAspect.portrait,
      category: '커플',
      style: 'editorial',
      backgroundColor: Color(0xFFE7D8CC),
      recommendedPhotoCount: 5,
      difficulty: TemplateDifficulty.easy,
      isFeatured: true,
      priority: 100,
      tags: ['웨딩', '클래식', '초대장'],
      buildLayers: _buildPortraitFullBleedWeddingClassic,
    ),
    _TemplateSeed(
      id: 'pack_portrait_couple_story_001',
      name: '서머 커버',
      aspect: TemplateAspect.portrait,
      category: '커플',
      style: 'soft',
      backgroundColor: Color(0xFFF2DCCF),
      recommendedPhotoCount: 4,
      difficulty: TemplateDifficulty.easy,
      isFeatured: true,
      priority: 96,
      tags: ['커버', '서머', '포스터'],
      buildLayers: _buildPortraitPosterSummerCover,
    ),
    _TemplateSeed(
      id: 'pack_portrait_family_daily_001',
      name: '누아르 커버',
      aspect: TemplateAspect.portrait,
      category: '감성',
      style: 'editorial',
      backgroundColor: Color(0xFF2E2C3E),
      recommendedPhotoCount: 6,
      difficulty: TemplateDifficulty.normal,
      tags: ['누아르', '매거진'],
      buildLayers: _buildPortraitPosterNoirCover,
    ),
    _TemplateSeed(
      id: 'pack_portrait_birthday_party_001',
      name: '생일 파티',
      aspect: TemplateAspect.portrait,
      category: '생일',
      style: 'colorful',
      backgroundColor: Color(0xFFE688A6),
      recommendedPhotoCount: 5,
      difficulty: TemplateDifficulty.normal,
      tags: ['생일', '파티'],
      buildLayers: _buildPortraitBlossomPoster,
    ),
    _TemplateSeed(
      id: 'pack_portrait_mood_book_001',
      name: '로즈 데이',
      aspect: TemplateAspect.portrait,
      category: '감성',
      style: 'emotional',
      backgroundColor: Color(0xFFF2C9D6),
      recommendedPhotoCount: 4,
      difficulty: TemplateDifficulty.easy,
      isFeatured: true,
      priority: 90,
      tags: ['로즈', '타이포', '포스터'],
      buildLayers: _buildPortraitFullBleedRoseDay,
    ),
    _TemplateSeed(
      id: 'pack_portrait_wedding_day_001',
      name: '타임 인비테이션',
      aspect: TemplateAspect.portrait,
      category: '커플',
      style: 'romantic',
      backgroundColor: Color(0xFFEADFD5),
      recommendedPhotoCount: 5,
      difficulty: TemplateDifficulty.normal,
      isFeatured: true,
      priority: 94,
      tags: ['웨딩', '시간', '초대장'],
      buildLayers: _buildPortraitFullBleedTimeInvite,
    ),
    _TemplateSeed(
      id: 'pack_portrait_glitter_night_002',
      name: '글리터 이슈',
      aspect: TemplateAspect.portrait,
      category: '감성',
      style: 'neon',
      backgroundColor: Color(0xFF2E2C3E),
      recommendedPhotoCount: 4,
      difficulty: TemplateDifficulty.normal,
      isFeatured: true,
      priority: 89,
      tags: ['나이트', '커버', '이슈'],
      buildLayers: _buildPortraitPosterNoirCover,
    ),
    _TemplateSeed(
      id: 'pack_portrait_ticket_journey_002',
      name: '메리지 스크립트',
      aspect: TemplateAspect.portrait,
      category: '커플',
      style: 'script',
      backgroundColor: Color(0xFFF2E7DA),
      recommendedPhotoCount: 5,
      difficulty: TemplateDifficulty.normal,
      tags: ['메리지', '스크립트', '포토'],
      buildLayers: _buildPortraitSaveTheDate,
    ),
    _TemplateSeed(
      id: 'pack_square_travel_grid_001',
      name: '위켄드 커버',
      aspect: TemplateAspect.square,
      category: '감성',
      style: 'cover',
      backgroundColor: Color(0xFFD9E2EA),
      recommendedPhotoCount: 6,
      difficulty: TemplateDifficulty.easy,
      tags: ['커버', '매거진'],
      buildLayers: _buildSquarePosterBoldCover,
    ),
    _TemplateSeed(
      id: 'pack_square_family_memory_001',
      name: '커버 스토리',
      aspect: TemplateAspect.square,
      category: '감성',
      style: 'cover',
      backgroundColor: Color(0xFFE8E2D8),
      recommendedPhotoCount: 5,
      difficulty: TemplateDifficulty.normal,
      tags: ['커버', '타이틀'],
      buildLayers: _buildSquarePosterBoldCover,
    ),
    _TemplateSeed(
      id: 'pack_square_birthday_snap_001',
      name: '데이트 커버',
      aspect: TemplateAspect.square,
      category: '커플',
      style: 'minimal',
      backgroundColor: Color(0xFFF2E8DC),
      recommendedPhotoCount: 4,
      difficulty: TemplateDifficulty.easy,
      tags: ['데이트', '날짜', '표지'],
      buildLayers: _buildSquarePosterDateCover,
    ),
    _TemplateSeed(
      id: 'pack_square_graduation_book_001',
      name: '모노 데이트',
      aspect: TemplateAspect.square,
      category: '감성',
      style: 'minimal',
      backgroundColor: Color(0xFFE9E4DE),
      recommendedPhotoCount: 5,
      difficulty: TemplateDifficulty.normal,
      tags: ['모노', '데이트', '타이포'],
      buildLayers: _buildSquarePosterDateCover,
    ),
    _TemplateSeed(
      id: 'pack_square_minimal_sheet_001',
      name: '미니멀 시트',
      aspect: TemplateAspect.square,
      category: '미니멀',
      style: 'minimal',
      backgroundColor: Color(0xFFF4EFE8),
      recommendedPhotoCount: 3,
      difficulty: TemplateDifficulty.easy,
      isFeatured: true,
      priority: 88,
      tags: ['미니멀', '화이트'],
      buildLayers: _buildSquareSummerLetter,
    ),
    _TemplateSeed(
      id: 'pack_square_mood_card_001',
      name: '메리지 스퀘어',
      aspect: TemplateAspect.square,
      category: '커플',
      style: 'script',
      backgroundColor: Color(0xFFF2E6DA),
      recommendedPhotoCount: 4,
      difficulty: TemplateDifficulty.easy,
      tags: ['웨딩', '스크립트'],
      buildLayers: _buildSquareFullBleedMarriageScript,
    ),
    _TemplateSeed(
      id: 'pack_square_retro_cut_002',
      name: '데이트 스택',
      aspect: TemplateAspect.square,
      category: '감성',
      style: 'minimal',
      backgroundColor: Color(0xFFE7DED3),
      recommendedPhotoCount: 4,
      difficulty: TemplateDifficulty.normal,
      tags: ['데이트', '모노', '타이포'],
      buildLayers: _buildSquareFullBleedDateStack,
    ),
    _TemplateSeed(
      id: 'pack_square_sugar_party_002',
      name: '포스터 커버',
      aspect: TemplateAspect.square,
      category: '감성',
      style: 'cover',
      backgroundColor: Color(0xFFDDE5EA),
      recommendedPhotoCount: 4,
      difficulty: TemplateDifficulty.easy,
      isFeatured: true,
      priority: 87,
      tags: ['포스터', '커버'],
      buildLayers: _buildSquarePosterBoldCover,
    ),
    _TemplateSeed(
      id: 'pack_landscape_travel_banner_001',
      name: '웨딩 에디토리얼',
      aspect: TemplateAspect.landscape,
      category: '커플',
      style: 'editorial',
      backgroundColor: Color(0xFFE7DCD2),
      recommendedPhotoCount: 4,
      difficulty: TemplateDifficulty.easy,
      isFeatured: true,
      priority: 86,
      tags: ['웨딩', '에디토리얼', '풀배경'],
      buildLayers: _buildLandscapeFullBleedEditorialWedding,
    ),
    _TemplateSeed(
      id: 'pack_landscape_couple_film_001',
      name: '스카이 웨딩',
      aspect: TemplateAspect.landscape,
      category: '커플',
      style: 'cover',
      backgroundColor: Color(0xFFB9CEE1),
      recommendedPhotoCount: 3,
      difficulty: TemplateDifficulty.easy,
      tags: ['웨딩', '스카이', '표지'],
      buildLayers: _buildLandscapePosterSkyScriptCover,
    ),
    _TemplateSeed(
      id: 'pack_landscape_birthday_mix_001',
      name: '전시 포스터',
      aspect: TemplateAspect.landscape,
      category: '감성',
      style: 'cover',
      backgroundColor: Color(0xFFE7E0D5),
      recommendedPhotoCount: 4,
      difficulty: TemplateDifficulty.normal,
      tags: ['전시', '포스터', '밴드'],
      buildLayers: _buildLandscapePosterExhibitionCover,
    ),
    _TemplateSeed(
      id: 'pack_landscape_minimal_wide_001',
      name: '스카이 인비테이션',
      aspect: TemplateAspect.landscape,
      category: '커플',
      style: 'cover',
      backgroundColor: Color(0xFFC7D8E7),
      recommendedPhotoCount: 3,
      difficulty: TemplateDifficulty.easy,
      isFeatured: true,
      priority: 84,
      tags: ['스카이', '인비테이션'],
      buildLayers: _buildLandscapePosterSkyScriptCover,
    ),
    _TemplateSeed(
      id: 'pack_landscape_city_travel_001',
      name: '커버 에디션',
      aspect: TemplateAspect.landscape,
      category: '감성',
      style: 'cover',
      backgroundColor: Color(0xFFD6DEE5),
      recommendedPhotoCount: 4,
      difficulty: TemplateDifficulty.normal,
      tags: ['커버', '에디션', '밴드'],
      buildLayers: _buildLandscapePosterExhibitionCover,
    ),
    _TemplateSeed(
      id: 'pack_landscape_ribbon_story_002',
      name: '웨딩 스크립트',
      aspect: TemplateAspect.landscape,
      category: '커플',
      style: 'cover',
      backgroundColor: Color(0xFFE6DBD2),
      recommendedPhotoCount: 4,
      difficulty: TemplateDifficulty.easy,
      tags: ['웨딩', '스크립트', '표지'],
      buildLayers: _buildLandscapePosterSkyScriptCover,
    ),
    _TemplateSeed(
      id: 'pack_landscape_night_reel_002',
      name: '나이트 릴',
      aspect: TemplateAspect.landscape,
      category: '감성',
      style: 'neon',
      backgroundColor: Color(0xFF2E2C3E),
      recommendedPhotoCount: 3,
      difficulty: TemplateDifficulty.normal,
      isFeatured: true,
      priority: 85,
      tags: ['나이트', '릴'],
      buildLayers: _buildLandscapeNightTape,
    ),
    _TemplateSeed(
      id: 'pack_landscape_poster_board_002',
      name: '와이드 미니멀 표지',
      aspect: TemplateAspect.landscape,
      category: '커플',
      style: 'cover',
      backgroundColor: Color(0xFFE9E0D5),
      recommendedPhotoCount: 5,
      difficulty: TemplateDifficulty.normal,
      tags: ['와이드', '미니멀', '타이포'],
      buildLayers: _buildLandscapeFullBleedMinimalInvite,
    ),
  ];

  return seeds
      .map(
        (seed) => DesignTemplate(
          id: seed.id,
          name: seed.name,
          aspect: seed.aspect,
          category: seed.category,
          style: seed.style,
          recommendedPhotoCount: seed.recommendedPhotoCount,
          difficulty: seed.difficulty,
          isFeatured: seed.isFeatured,
          priority: seed.priority,
          tags: seed.tags,
          backgroundColor: seed.backgroundColor,
          previewThumbUrl: templatePreviewThumbForId(seed.id),
          previewDetailUrl: templatePreviewDetailForId(seed.id),
          previewImageUrls: templatePreviewImagesForId(seed.id),
          buildLayers: seed.buildLayers,
        ),
      )
      .toList();
}

final List<DesignTemplate> _coreDesignTemplates = [
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

final List<DesignTemplate> designTemplates = [
  ..._coreDesignTemplates,
  ..._buildExpandedTemplatePack(),
];
