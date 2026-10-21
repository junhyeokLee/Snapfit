import '../../domain/entities/layer.dart';
import '../../printing/album_print_exporter.dart';
import '../../printing/print_album_document.dart';

/// A photo in the reviewed saved document, never an arbitrary report index.
class PrintPhotoEditTarget {
  const PrintPhotoEditTarget({
    required this.pageIndex,
    required this.layerId,
    required this.reviewedRevision,
  });

  /// Position in the editor's sorted page list, including the cover at zero.
  final int pageIndex;
  final String layerId;
  final String reviewedRevision;
}

class PrintPhotoIssue {
  const PrintPhotoIssue({
    required this.target,
    required this.photoNumber,
    required this.effectivePpi,
    required this.recommendedPpi,
    this.blocksPrinting = false,
  });

  final PrintPhotoEditTarget target;
  final int photoNumber;
  final double? effectivePpi;
  final int recommendedPpi;
  final bool blocksPrinting;

  String get pageLabel =>
      target.pageIndex == 0 ? '앞표지' : '내지 ${target.pageIndex}쪽';
  String get label => '$pageLabel · 사진 $photoNumber';
}

bool printPhotoTargetMatchesDocument(
  PrintPhotoEditTarget target,
  PrintAlbumDocument document,
) {
  if (target.pageIndex < 0 ||
      target.pageIndex >= document.pages.length ||
      target.layerId.isEmpty ||
      target.layerId == '__print_cover_theme')
    return false;
  final matching = document.pages[target.pageIndex].layers.where(
    (layer) => layer.id == target.layerId,
  );
  return matching.length == 1 && matching.single.type == LayerType.image;
}

/// Resolve only actual, unambiguous photo layers. Print-only cover artwork,
/// malformed rows and stale layer IDs must never point the editor elsewhere.
List<PrintPhotoIssue> printPhotoIssues({
  required PrintAlbumDocument document,
  required String reviewedRevision,
  required int recommendedPpi,
  Map<String, dynamic>? report,
  PrintPreflightException? failure,
}) {
  final issues = <String, PrintPhotoIssue>{};
  void add(Object? rawPage, Object? rawLayer, double? ppi, bool blocking) {
    if (rawPage is! num ||
        !rawPage.isFinite ||
        rawPage < 0 ||
        rawPage != rawPage.toInt() ||
        rawLayer is! String ||
        rawLayer.isEmpty ||
        (ppi != null && (!ppi.isFinite || ppi < 0))) {
      return;
    }
    final pageIndex = document.pages.indexWhere(
      (page) => page.index == rawPage,
    );
    if (pageIndex < 0) return;
    final target = PrintPhotoEditTarget(
      pageIndex: pageIndex,
      layerId: rawLayer,
      reviewedRevision: reviewedRevision,
    );
    if (!printPhotoTargetMatchesDocument(target, document)) return;
    final photos = document.pages[pageIndex].layers
        .where(
          (layer) =>
              layer.type == LayerType.image &&
              layer.id != '__print_cover_theme',
        )
        .toList(growable: false);
    final photoIndex = photos.indexWhere((layer) => layer.id == rawLayer);
    final key = '$pageIndex:$rawLayer';
    if (!blocking && issues.containsKey(key)) return;
    issues[key] = PrintPhotoIssue(
      target: target,
      photoNumber: photoIndex + 1,
      effectivePpi: ppi,
      recommendedPpi: recommendedPpi,
      blocksPrinting: blocking,
    );
  }

  final rows = report?['imageResolution'];
  if (rows is List) {
    for (final row in rows.whereType<Map>()) {
      final ppi = row['effectivePpi'];
      if (ppi is num && ppi.isFinite && ppi + .1 < recommendedPpi) {
        add(row['page'], row['layerId'], ppi.toDouble(), false);
      }
    }
  }
  if (failure?.code == 'print_image_resolution_too_low') {
    String? page;
    String? layer;
    double? ppi;
    for (final detail in failure!.details) {
      if (detail.startsWith('page:')) page = detail.substring(5);
      if (detail.startsWith('layer:')) layer = detail.substring(6);
      if (RegExp(r'^\d+(?:\.\d+)?ppi$').hasMatch(detail)) {
        ppi = double.tryParse(detail.substring(0, detail.length - 3));
      }
    }
    add(int.tryParse(page ?? ''), layer, ppi, true);
  }
  return List.unmodifiable(issues.values);
}
