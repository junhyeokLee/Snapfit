import 'ai_template_typography.g.dart';

class AiTemplateTypeStyle {
  const AiTemplateTypeStyle({
    required this.fontFamily,
    required this.weight,
    required this.fontSize,
    required this.lineHeight,
  });
  final String fontFamily;
  final int weight;
  final double fontSize;
  final double lineHeight;

  bool get supportsHangul => ((_fonts[fontFamily] as Map)['hangul'] as bool);
  static Map get _fonts => aiTemplateTypographyContract['fonts'] as Map;

  factory AiTemplateTypeStyle.fromJson(Object? value, String role) {
    final raw = _map(value);
    final font = _text(raw['fontFamily'], 40);
    final spec = _fonts[font];
    final range = (aiTemplateTypographyContract['roles'] as Map)[role];
    if (spec is! Map || range is! Map)
      throw const FormatException('Invalid typography role or font');
    final weight = _number(raw['weight'], 400, 800);
    if (!(spec['weights'] as List).contains(weight))
      throw const FormatException('Unsupported font weight');
    return AiTemplateTypeStyle(
      fontFamily: font,
      weight: weight.toInt(),
      fontSize: _number(
        raw['fontSize'],
        (range['min'] as num).toDouble(),
        (range['max'] as num).toDouble(),
      ),
      lineHeight: _number(raw['lineHeight'], 1, 1.6),
    );
  }
}

class AiTemplatePlannedPage {
  const AiTemplatePlannedPage(this.role, this.intent, this.photoCount);
  final String role;
  final String intent;
  final int photoCount;
}

class AiTemplateArtDirection {
  const AiTemplateArtDirection({
    required this.concept,
    required this.rationale,
    required this.requirements,
    required this.palette,
    required this.typography,
    required this.pages,
  });
  final String concept;
  final String rationale;
  final List<String> requirements;
  final List<String> palette;
  final Map<String, AiTemplateTypeStyle> typography;
  final List<AiTemplatePlannedPage> pages;

  factory AiTemplateArtDirection.fromJson(Object? value, int pageCount) {
    final raw = _map(value);
    final colors = raw['palette'],
        requirements = raw['requirements'],
        pages = raw['pages'];
    if (raw['version'] != 1 ||
        colors is! List ||
        colors.length < 2 ||
        colors.length > 6 ||
        requirements is! List ||
        requirements.isEmpty ||
        requirements.length > 6 ||
        pages is! List ||
        pages.length != pageCount + 1)
      throw const FormatException('Invalid art direction');
    final palette = colors
        .map((c) {
          if (c is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(c))
            throw const FormatException('Invalid plan palette');
          return c.toUpperCase();
        })
        .toList(growable: false);
    if (palette.toSet().length != palette.length)
      throw const FormatException('Duplicate plan color');
    final rawType = _map(raw['typography']);
    final typography = {
      for (final role in ['display', 'heading', 'body', 'caption'])
        role: AiTemplateTypeStyle.fromJson(rawType[role], role),
    };
    if (typography.values.map((t) => t.fontFamily).toSet().length > 3 ||
        typography['display']!.fontSize < typography['heading']!.fontSize ||
        typography['heading']!.fontSize < typography['body']!.fontSize ||
        typography['body']!.fontSize < typography['caption']!.fontSize)
      throw const FormatException('Invalid type hierarchy');
    final planned = pages.indexed
        .map((entry) {
          final (i, value) = entry;
          final page = _map(value), role = _text(_map(value)['role'], 16);
          if (![
                'cover',
                'opener',
                'story',
                'gallery',
                'closing',
              ].contains(role) ||
              (i == 0) != (role == 'cover') ||
              (i == pageCount && role != 'closing'))
            throw const FormatException('Invalid planned page role');
          final photos = _number(page['photoCount'], 0, 4);
          if (photos != photos.roundToDouble() ||
              (role == 'gallery' && photos == 0))
            throw const FormatException('Invalid planned photo count');
          return AiTemplatePlannedPage(
            role,
            _text(page['intent'], 120),
            photos.toInt(),
          );
        })
        .toList(growable: false);
    if (planned.skip(1).where((p) => p.photoCount > 0).length < 2)
      throw const FormatException('Insufficient photo pages');
    return AiTemplateArtDirection(
      concept: _text(raw['concept'], 80),
      rationale: _text(raw['rationale'], 300),
      requirements: requirements
          .map((v) => _text(v, 160))
          .toList(growable: false),
      palette: palette,
      typography: typography,
      pages: planned,
    );
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String))
    throw const FormatException('Invalid plan object');
  return Map<String, Object?>.from(value);
}

String _text(Object? value, int max) {
  if (value is! String || value.trim().isEmpty || value.length > max)
    throw const FormatException('Invalid plan text');
  return value.trim();
}

double _number(Object? value, double min, double max) {
  if (value is! num || !value.isFinite || value < min || value > max)
    throw const FormatException('Invalid plan number');
  return value.toDouble();
}
