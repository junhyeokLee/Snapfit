/// JSON parsing never proves that a user authored content. Explicit example
/// flags take precedence; unmarked or malformed legacy provenance stays unknown.
/// Keep this independent of Flutter so the document worker uses the same rules.
bool? layerTemplateContentFromJson(Map layer, Map payload) {
  if (layer['isSample'] == true ||
      payload['isSample'] == true ||
      layer['isPlaceholder'] == true ||
      payload['isPlaceholder'] == true) {
    return true;
  }
  final value = layer['templateContent'];
  return value is bool ? value : null;
}
