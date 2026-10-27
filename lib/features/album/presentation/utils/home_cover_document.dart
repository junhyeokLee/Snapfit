import 'dart:convert';

/// Background workers return only the saved cover, not the album's interiors,
/// history or other document metadata. Keep the legacy first-page layer rule
/// and the independent isCover/index background-color lookup intact.
Map<String, dynamic>? compactHomeCoverDocument(String source) {
  try {
    final document = jsonDecode(source);
    if (document is! Map<String, dynamic>) return null;
    final pages = document['pages'] as List?;
    final first = pages?.firstOrNull;
    final layers = pages != null && pages.isNotEmpty
        ? (first is Map ? first['layers'] : null)
        : document['layers'];
    Map? background;
    try {
      if (pages != null) {
        for (final page in pages) {
          if (page is Map &&
              (page['isCover'] == true ||
                  (page['index'] as num?)?.toInt() == 0)) {
            background = page;
            break;
          }
        }
      }
      background ??= first is Map ? first : null;
    } on Object {
      // Bad legacy background metadata must not discard valid cover layers.
    }
    return {
      'pages': [
        {
          'index': 0,
          'layers': layers,
          for (final key in const [
            'backgroundColor',
            'canvasColor',
            'bgColor',
            'color',
          ])
            if (background?.containsKey(key) ?? false) key: background![key],
        },
      ],
    };
  } on Object {
    return null;
  }
}
