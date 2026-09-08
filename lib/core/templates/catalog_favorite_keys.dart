import 'authored_collections.dart';
import 'studio_decoration_catalog.dart';
import 'studio_word_art_catalog.dart';

abstract final class CatalogFavoriteKeys {
  static String template(int id) {
    final collection = authoredCollections
        .where((c) => c.bundledId == id)
        .firstOrNull;
    return collection == null ? 'template:remote:$id' : design(collection.id);
  }

  static String design(String id) => 'template:$id';
  static String frame(String id) => 'frame:$id';
  static String phrase(String id) => 'phrase:$id';
  static String font(String id) => 'font:$id';
  static String layout(String id) => 'layout:$id';
  static String textStyle(String id) => 'textStyle:$id';
  static String decoration(String value) {
    if (value.startsWith('wordart:')) {
      final art = studioWordArtById(value.substring('wordart:'.length));
      if (art != null) return art.favoriteKey;
    }
    final spec = studioDecorations
        .where((s) => s.insertionValue == value)
        .firstOrNull;
    return 'decoration:${spec?.id ?? value}';
  }
}
