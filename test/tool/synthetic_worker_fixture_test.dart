import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/album/printing/print_vendor_spec.dart';

import '../../tool/print_fulfillment/render_paid_album_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source =
      'supabase://album-assets/11111111-1111-4111-8111-111111111111/generated-test-card.png';

  for (final item in [('SOFT_20', 20), ('HARD_80', 80)]) {
    test(
      'synthetic ${item.$1} has every purchased page and stays non-production',
      () {
        final input = fixture.syntheticWorkerFixture(item.$1, source);
        final spec = PrintVendorSpec.fromJson(input['spec']);
        final document = PrintAlbumDocument.fromSnapshot(input['snapshot']);
        document.validateSpec(spec);
        expect(input['fixtureOnly'], true);
        expect(input['productionApproved'], false);
        expect(document.interiors.length, item.$2);
        expect(spec.pageCount, item.$2);
        expect(spec.dpi, 300);
        expect(spec.colorSpace, 'sRGB');
        expect(spec.data['geometrySource'], contains('LOCAL FIXTURE ONLY'));
        for (final page in document.pages) {
          expect(page.layers, isNotEmpty);
          expect(
            page.layers.map((layer) => layer.id).toSet().length,
            page.layers.length,
          );
        }
        if (item.$1 == 'HARD_80') {
          expect(spec.id, 'REDP_300_HARD');
          expect(spec.isHardcover, true);
          expect(spec.data['coverType'], 'HARD');
          expect(spec.trimWidthMm, 300);
          expect(spec.trimHeightMm, 300);
          expect(spec.coverSize.width, 681.2);
          expect(spec.coverSize.height, 346);
          expect(document.interiors.last.index, 80);
        }
      },
    );
  }

  test('synthetic factory rejects production and unsupported combinations', () {
    for (final value in ['LIVE', 'HARD_82', '', 'SOFT_80']) {
      expect(
        () => fixture.syntheticWorkerFixture(value, source),
        throwsStateError,
      );
    }
  });
}
