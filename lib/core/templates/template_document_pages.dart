/// Some catalog documents store the cover separately from their inner pages.
/// Other documents already include it as the first page.
List<Map<String, dynamic>> templateDocumentPages(Map<String, dynamic> data) {
  final pages = (data['pages'] as List? ?? const [])
      .whereType<Map>()
      .map((p) => Map<String, dynamic>.from(p))
      .toList();
  final cover = data['cover'];
  if (cover is! Map || cover['layers'] is! List) return pages;
  final coverIds = (cover['layers'] as List)
      .whereType<Map>()
      .map((l) => l['id'])
      .toList();
  final firstIds = pages.isEmpty
      ? const []
      : (pages.first['layers'] as List? ?? const [])
            .whereType<Map>()
            .map((l) => l['id'])
            .toList();
  final alreadyIncluded =
      coverIds.isNotEmpty &&
      coverIds.every((id) => id != null) &&
      coverIds.length == firstIds.length &&
      List.generate(
        coverIds.length,
        (i) => coverIds[i] == firstIds[i],
      ).every((same) => same);
  return [if (!alreadyIncluded) Map<String, dynamic>.from(cover), ...pages];
}
