import 'dart:convert';

/// Retired catalog identities, never a rule for loading a saved album document.
/// Shared photographs and material assets remain valid in current designs.
abstract final class RetiredStoreTemplates {
  static const ids = <int>{
    46,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55,
    -1115056,
    -8006,
    -8007,
    -8008,
  };

  static const titles = <String>{
    '제주의 기록',
    '가족의 주말',
    '우리의 기념일',
    'Wedding Editorial',
    'Scrapbook',
    'SAVE THE DATE',
    '화이트 에디토리얼',
    '필름 다이어리',
    '소프트 베이비북',
  };

  static const stems = <String>{
    'jeju_travel',
    'family_weekend',
    'anniversary_days',
    'wedding_editorial',
    'scrapbook',
    'save_the_date',
    'minimal_editorial',
    'film_diary',
    'soft_babybook',
  };

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

  static final _normalizedTitles = titles.map(_normalize).toSet();
  static final _normalizedStems = stems.map(_normalize).toSet();
  static final _versionedStem = RegExp(
    '^(${_normalizedStems.join('|')})v[0-9]+\$',
  );

  static bool _identity(Object? value) {
    if (value is! String) return false;
    if (value == 'figma_import_1775063050456') return true;
    final normalized = _normalize(value);
    return _normalizedStems.contains(normalized) ||
        _versionedStem.hasMatch(normalized);
  }

  static bool matches({
    int? id,
    String? title,
    String? templateId,
    String? templateJson,
  }) {
    if (ids.contains(id)) return true;
    if (title != null &&
        (_normalizedTitles.contains(_normalize(title)) || _identity(title))) {
      return true;
    }
    if (_identity(templateId)) return true;
    if (templateJson == null || templateJson.trim().isEmpty) return false;
    try {
      final document = jsonDecode(templateJson);
      if (document is! Map) return false;
      if (_identity(document['id']) || _identity(document['templateId'])) {
        return true;
      }
      final metadata = document['metadata'];
      return metadata is Map &&
          (_identity(metadata['id']) || _identity(metadata['templateId']));
    } on FormatException {
      return false;
    }
  }
}
