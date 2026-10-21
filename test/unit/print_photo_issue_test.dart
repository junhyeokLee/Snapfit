import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/utils/print_photo_issue.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';

void main() {
  LayerModel photo(String id, {LayerType type = LayerType.image}) => LayerModel(
    id: id,
    type: type,
    position: Offset.zero,
    width: 100,
    height: 100,
  );
  PrintAlbumDocument document({bool duplicateId = false}) =>
      PrintAlbumDocument([
        PrintAlbumPage(
          index: 0,
          isCover: true,
          canvasSize: const Size(486, 500),
          layers: [photo('__print_cover_theme')],
          backgroundColor: Colors.white,
        ),
        PrintAlbumPage(
          index: 7,
          isCover: false,
          canvasSize: const Size(500, 500),
          layers: [
            photo('first'),
            photo('second'),
            photo('text', type: LayerType.text),
            if (duplicateId) photo('first', type: LayerType.text),
          ],
          backgroundColor: Colors.white,
        ),
      ], ratio: 1);
  List<PrintPhotoIssue> issues(
    List<Object> rows, {
    int dpi = 300,
    bool duplicateId = false,
  }) => printPhotoIssues(
    document: document(duplicateId: duplicateId),
    reviewedRevision: 'saved-revision',
    recommendedPpi: dpi,
    report: {'imageResolution': rows},
  );

  test(
    'maps stored page IDs to editor positions and deduplicates actual photos',
    () {
      final found = issues([
        {'page': 7, 'layerId': 'second', 'effectivePpi': 190},
        {'page': 7, 'layerId': 'second', 'effectivePpi': 190},
      ]);
      expect(found, hasLength(1));
      expect(found.single.target.pageIndex, 1);
      expect(found.single.target.layerId, 'second');
      expect(found.single.target.reviewedRevision, 'saved-revision');
      expect(found.single.label, '내지 1쪽 · 사진 2');
      expect(found.single.blocksPrinting, isFalse);
    },
  );

  test('rejects stale, malformed, ambiguous and print-only targets', () {
    expect(
      issues([
        {'page': 1, 'layerId': 'first', 'effectivePpi': 100},
        {'page': -1, 'layerId': 'first', 'effectivePpi': 100},
        {'page': 7.5, 'layerId': 'first', 'effectivePpi': 100},
        {'page': '7', 'layerId': 'first', 'effectivePpi': 100},
        {'page': 7, 'layerId': 'gone', 'effectivePpi': 100},
        {'page': 7, 'layerId': 'text', 'effectivePpi': 100},
        {'page': 0, 'layerId': '__print_cover_theme', 'effectivePpi': 100},
        {'page': 7, 'layerId': 'first', 'effectivePpi': double.nan},
        {'page': 7, 'layerId': 'first', 'effectivePpi': -10},
        {'page': 7, 'layerId': 'first', 'effectivePpi': '100'},
        {'page': 7, 'layerId': 'first', 'effectivePpi': 300},
      ]),
      isEmpty,
    );
    expect(
      issues([
        {'page': 7, 'layerId': 'first', 'effectivePpi': 100},
      ], duplicateId: true),
      isEmpty,
    );
  });

  test(
    'uses the selected print specification and exporter rounding tolerance',
    () {
      expect(
        issues([
          {'page': 7, 'layerId': 'first', 'effectivePpi': 250},
        ], dpi: 240),
        isEmpty,
      );
      expect(
        issues([
          {'page': 7, 'layerId': 'first', 'effectivePpi': 299.9},
        ]),
        isEmpty,
      );
      expect(
        issues([
          {'page': 7, 'layerId': 'first', 'effectivePpi': 250},
        ], dpi: 350).single.recommendedPpi,
        350,
      );
    },
  );

  test('blocking exception metadata opens only a matching photo', () {
    final found = printPhotoIssues(
      document: document(),
      reviewedRevision: 'saved-revision',
      recommendedPpi: 300,
      failure: const PrintPreflightException('print_image_resolution_too_low', [
        'page:7',
        'layer:second',
        '80ppi',
      ]),
    );
    expect(found.single.blocksPrinting, isTrue);
    expect(found.single.target.pageIndex, 1);
    expect(found.single.effectivePpi, 80);
    expect(
      printPhotoIssues(
        document: document(),
        reviewedRevision: 'saved-revision',
        recommendedPpi: 300,
        failure: const PrintPreflightException('print_original_missing', [
          'page:7',
          'layer:second',
        ]),
      ),
      isEmpty,
    );
    expect(
      printPhotoIssues(
        document: document(),
        reviewedRevision: 'saved-revision',
        recommendedPpi: 300,
        failure: const PrintPreflightException(
          'print_image_resolution_too_low',
          ['80ppi'],
        ),
      ),
      isEmpty,
    );
  });

  test(
    'public target validation rejects out of range and non-photo layers',
    () {
      bool matches(int page, String id) => printPhotoTargetMatchesDocument(
        PrintPhotoEditTarget(
          pageIndex: page,
          layerId: id,
          reviewedRevision: 'saved',
        ),
        document(),
      );
      expect(matches(1, 'first'), isTrue);
      expect(matches(7, 'first'), isFalse);
      expect(matches(1, 'text'), isFalse);
      expect(matches(0, '__print_cover_theme'), isFalse);
      expect(matches(-1, 'first'), isFalse);
    },
  );
}
