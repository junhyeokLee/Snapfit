part of 'ai_template_design.dart';

class AiTemplateCompositionPlan {
  const AiTemplateCompositionPlan({
    required this.understanding,
    required this.mood,
    required this.avoid,
    required this.verbatim,
    required this.density,
    required this.frames,
    required this.papers,
    required this.compositions,
  });
  final String understanding, density;
  final List<String> mood, avoid, verbatim, frames, papers, compositions;

  factory AiTemplateCompositionPlan.fromJson(
    Map<String, Object?> document,
    int count,
  ) {
    Map rawMap(Object? value) {
      if (value is! Map)
        throw const FormatException('Invalid original book plan');
      return value;
    }

    List<String> list(Object? value, int limit, int length) {
      if (value is! List || value.length > limit)
        throw const FormatException('Invalid original book list');
      final result = value.map((v) => _text(v, length)).toList(growable: false);
      if (result.toSet().length != result.length)
        throw const FormatException('Repeated original book intent');
      return result;
    }

    final generation = rawMap(document['generation']);
    if (document['layoutExpansion'] != null ||
        generation['strategy'] != 'original_spread_batches_v1' ||
        generation['pageCount'] != count) {
      throw const FormatException('Original book must not repeat page layouts');
    }
    final direction = rawMap(document['artDirection']);
    final intent = rawMap(direction['intent']),
        kit = rawMap(direction['materials']);
    final frames = list(kit['frames'], 5, 40),
        papers = list(kit['papers'], 5, 40);
    if (frames.any(
          (f) =>
              !(aiTemplateCompositionContract['frames'] as Map).containsKey(f),
        ) ||
        papers.any(
          (p) =>
              !(aiTemplateCompositionContract['papers'] as Map).containsKey(p),
        )) {
      throw const FormatException('Unlicensed original book materials');
    }
    final compositions = list(direction['compositions'], count + 1, 180);
    if (compositions.length != count + 1 ||
        !['quiet', 'balanced', 'layered'].contains(intent['density'])) {
      throw const FormatException('Incomplete original book plan');
    }
    return AiTemplateCompositionPlan(
      understanding: _text(intent['understanding'], 400),
      mood: list(intent['mood'], 6, 60),
      avoid: list(intent['avoid'], 8, 120),
      verbatim: list(intent['verbatim'], 8, 160),
      density: intent['density'] as String,
      frames: frames,
      papers: papers,
      compositions: compositions,
    );
  }

  void validateRequest(
    AiTemplateBrief brief, {
    required Iterable<String> copy,
  }) {
    final quotes = RegExp('["“「『‘]([^"”」』’\\n]+)["”」』’]')
        .allMatches(brief.prompt)
        .map((m) => m[1]!.trim())
        .where((v) => v.isNotEmpty)
        .toSet();
    if (quotes.length > 8 ||
        quotes.any((text) => text.length > 160) ||
        verbatim.any((text) => !brief.prompt.contains(text)) ||
        quotes.any((text) => !verbatim.contains(text))) {
      throw const FormatException(
        'template_quality_failed: requested copy changed',
      );
    }
    final dates = RegExp(
      r'\b20\d{2}(?:[./-]\d{1,2}(?:[./-]\d{1,2})?\b|년\s*\d{1,2}월(?:\s*\d{1,2}일)?)',
    );
    if (copy
        .expand((text) => dates.allMatches(text))
        .any((match) => !brief.prompt.contains(match[0]!))) {
      throw const FormatException('template_quality_failed: invented date');
    }
  }
}

Rect _compositionBounds(AiTemplateDesignElement e, Size canvas) {
  final ratio = canvas.height / canvas.width;
  final c = math.cos(e.rotation), s = math.sin(e.rotation).abs();
  final w = e.rect.width * c + e.rect.height * ratio * s;
  final h = e.rect.height * c + e.rect.width / ratio * s;
  return Rect.fromCenter(center: e.rect.center, width: w, height: h);
}

bool _compositionOverlaps(Rect a, Rect b) =>
    math.min(a.right, b.right) - math.max(a.left, b.left) > .001 &&
    math.min(a.bottom, b.bottom) - math.max(a.top, b.top) > .001;

bool _compositionContains(Rect a, Rect b) =>
    a.left <= b.left + .0001 &&
    a.top <= b.top + .0001 &&
    a.right >= b.right - .0001 &&
    a.bottom >= b.bottom - .0001;

double _compositionCoverage(Rect photo, Iterable<Rect> overlays) {
  final clipped = overlays
      .where((o) => _compositionOverlaps(photo, o))
      .toList();
  final xs = <double>{
    photo.left,
    photo.right,
    for (final o in clipped) ...[
      math.max(photo.left, o.left),
      math.min(photo.right, o.right),
    ],
  }.toList()..sort();
  final ys = <double>{
    photo.top,
    photo.bottom,
    for (final o in clipped) ...[
      math.max(photo.top, o.top),
      math.min(photo.bottom, o.bottom),
    ],
  }.toList()..sort();
  var area = 0.0;
  for (var x = 1; x < xs.length; x++) {
    for (var y = 1; y < ys.length; y++) {
      final center = Offset((xs[x - 1] + xs[x]) / 2, (ys[y - 1] + ys[y]) / 2);
      if (clipped.any((o) => o.contains(center)))
        area += (xs[x] - xs[x - 1]) * (ys[y] - ys[y - 1]);
    }
  }
  return area / (photo.width * photo.height);
}

void _validateOriginalComposition(AiTemplateDesign design) {
  final signatures = <String>{}, copy = <String>[];
  for (final (index, page) in design.pages.indexed) {
    final elements = [...page.elements]
      ..sort((a, b) => a.zIndex!.compareTo(b.zIndex!));
    if (elements.map((e) => e.zIndex).toSet().length != elements.length)
      throw const FormatException('Invalid original stacking');
    for (final e in elements) {
      final bounds = _compositionBounds(e, design.canvasSize);
      if (bounds.left < -.0001 ||
          bounds.top < -.0001 ||
          bounds.right > 1.0001 ||
          bounds.bottom > 1.0001)
        throw const FormatException('Rotated artwork outside page');
    }
    final photos = elements.where((e) => e.kind == 'photo').toList();
    final texts = elements.where((e) => e.kind == 'text').toList();
    copy.addAll(texts.map((e) => e.text!));
    if (index > 0) {
      String signature(bool mirror) {
        final geometry =
            (photos.isEmpty ? texts : photos)
                .map(
                  (e) => [
                    mirror ? 1 - e.rect.left - e.rect.width : e.rect.left,
                    e.rect.top,
                    e.rect.width,
                    e.rect.height,
                  ].map((v) => (v * 20).round()).join(','),
                )
                .toList()
              ..sort();
        return geometry.join(';');
      }

      final geometry = [signature(false), signature(true)]..sort();
      if (!signatures.add(geometry.first))
        throw const FormatException('Repeated original page geometry');
    }
    for (final photo in photos) {
      if (_compositionCoverage(
            _compositionBounds(photo, design.canvasSize),
            elements
                .where((e) => e.zIndex! > photo.zIndex!)
                .map((e) => _compositionBounds(e, design.canvasSize)),
          ) >
          .2501) {
        throw const FormatException('Original photo excessively covered');
      }
    }
    for (final text in texts) {
      final box = text.rect;
      if (elements.any(
        (e) =>
            e.zIndex! > text.zIndex! &&
            _compositionOverlaps(box, _compositionBounds(e, design.canvasSize)),
      ))
        throw const FormatException('Original text occluded');
      final behind = elements
          .where(
            (e) =>
                e.zIndex! < text.zIndex! &&
                _compositionOverlaps(
                  box,
                  _compositionBounds(e, design.canvasSize),
                ),
          )
          .toList();
      final uncertain = behind.any(
        (e) => e.kind == 'photo' || (e.kind == 'paper' && e.style != 'rect'),
      );
      final backing = behind
          .where(
            (e) =>
                e.kind == 'paper' &&
                e.style == 'rect' &&
                e.rotation == 0 &&
                _compositionContains(e.rect, box),
          )
          .lastOrNull;
      final backingOnTop =
          backing != null &&
          behind.every(
            (e) => identical(e, backing) || e.zIndex! < backing.zIndex!,
          );
      if (uncertain &&
          !backingOnTop &&
          !(text.style == 'outline' && text.fontSize >= 32))
        throw const FormatException('Original copy needs opaque backing');
      if (!uncertain || backingOnTop) {
        final backgrounds = [
          backingOnTop ? backing.color : page.background,
          ...behind
              .where(
                (e) =>
                    e.kind == 'paper' &&
                    e.style == 'rect' &&
                    (!backingOnTop || e.zIndex! >= backing.zIndex!),
              )
              .map((e) => e.color),
        ];
        for (final color in backgrounds) {
          final a = text.color.computeLuminance(), b = color.computeLuminance();
          if ((math.max(a, b) + .05) / (math.min(a, b) + .05) < 4.5)
            throw const FormatException('Original text contrast');
        }
      }
    }
  }
  if (design.compositionPlan!.verbatim.any((text) => !copy.contains(text)))
    throw const FormatException('Missing requested original copy');
}
