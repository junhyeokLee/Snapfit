import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';

void main() {
  test('cover binding preserves size and round-trips all ten product IDs', () {
    final ids = <String>{};
    for (final size in coverSizes) {
      for (final type in PrintCoverType.values) {
        final product = size.withCoverType(type);
        ids.add(product.productId!);
        expect(product.realSize, size.realSize);
        expect(product.ratio, size.ratio);
        expect(product.coverType, type);
        expect(product.sizeProductId, size.productId);
        expect(
          product.printProduct!.keys,
          unorderedEquals(['id', 'trimWidthMm', 'trimHeightMm']),
        );
        expect(coverSizeForProduct(product.productId)!.coverType, type);
        expect(newAlbumCoverSize(product).productId, product.productId);
        expect(
          resolveCoverSize(
            ratio: product.ratio,
            printProduct: product.printProduct,
          ).productId,
          product.productId,
        );
        expect(
          product.withCoverType(PrintCoverType.soft).productId,
          size.productId,
        );
      }
    }
    expect(ids.length, 10);
    expect(coverSizes.length, 5);
    expect(coverSizeForProduct('REDP_200_FABRIC'), isNull);
  });
  test('five print products retain distinct physical dimensions and IDs', () {
    expect(coverSizes.map((cover) => cover.productId).toSet().length, 5);
    expect(coverSizes.every((cover) => cover.ratio >= 1), isTrue);
    expect(defaultCoverSize.productId, 'REDP_200_SOFT');
    expect(coverSizes.map((cover) => cover.printProduct), [
      {'id': 'REDP_200_SOFT', 'trimWidthMm': 200, 'trimHeightMm': 200},
      {'id': 'REDP_200X150_SOFT', 'trimWidthMm': 200, 'trimHeightMm': 150},
      {'id': 'REDP_250X200_SOFT', 'trimWidthMm': 250, 'trimHeightMm': 200},
      {'id': 'REDP_250_SOFT', 'trimWidthMm': 250, 'trimHeightMm': 250},
      {'id': 'REDP_300_SOFT', 'trimWidthMm': 300, 'trimHeightMm': 300},
    ]);
    for (final cover in coverSizes) {
      expect(cover.ratio, cover.realSize.aspectRatio);
      expect(
        resolveCoverSize(ratio: cover.ratio, printProduct: cover.printProduct),
        same(cover),
      );
    }
  });

  test(
    'rounded saved ratio follows the same product tolerance as print quotes',
    () {
      final cover = coverSizeForProduct('REDP_250X200_SOFT')!;
      expect(
        resolveCoverSize(ratio: 1.249, printProduct: cover.printProduct),
        same(cover),
      );
    },
  );

  test(
    'legacy orientation and canvas stay unchanged without valid metadata',
    () {
      final portrait = resolveCoverSize(ratio: .75);
      expect(portrait.realSize, const Size(14.5, 19.4));
      expect(portrait.ratio, .75);
      expect(portrait.printProduct, isNull);
      expect(resolveCoverSize(ratio: 4 / 3).realSize, const Size(19.4, 14.5));
      for (final invalid in <Map<String, dynamic>>[
        {'id': 7},
        {'id': 'REDP_300_SOFT', 'trimWidthMm': 200, 'trimHeightMm': 200},
        {'id': 'REDP_300_SOFT', 'trimWidthMm': 300, 'trimHeightMm': 300},
      ]) {
        expect(
          resolveCoverSize(ratio: .75, printProduct: invalid).realSize,
          portrait.realSize,
        );
      }
      expect(newAlbumCoverSize(portrait), defaultCoverSize);
      final mismatchedDimensions = resolveCoverSize(
        ratio: 1,
        printProduct: {
          'id': 'REDP_300_SOFT',
          'trimWidthMm': 200,
          'trimHeightMm': 200,
        },
      );
      expect(mismatchedDimensions.realSize, const Size(20, 20));
      expect(mismatchedDimensions.productId, isNull);
      expect(
        newAlbumCoverSize(legacyCoverSizes.last).realSize,
        const Size(20, 15),
      );
    },
  );
}
