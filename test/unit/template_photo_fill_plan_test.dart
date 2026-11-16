import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_plan.dart';

class _Photo extends Mock implements AssetEntity {}

LayerModel _slot(String id) => LayerModel(
  id: id,
  type: LayerType.image,
  position: const Offset(32, 48),
  width: 180,
  height: 220,
  imageBackground: 'polaroid',
  rotation: .1,
);

void main() {
  test(
    'proposal fills only empty photo slots in document and selection order',
    () {
      final a = _Photo(), b = _Photo(), c = _Photo();
      final existing = _slot('existing').copyWith(
        imageUrl: 'https://example.test/photo.jpg',
        imageZoom: 1.8,
        imageOffset: const Offset(4, -9),
      );
      final caption = LayerModel(
        id: 'caption',
        type: LayerType.text,
        position: Offset.zero,
        text: '내 이야기',
      );
      final decoration = LayerModel(
        id: 'decoration',
        type: LayerType.decoration,
        position: Offset.zero,
        imageUrl: 'https://example.test/texture.png',
      );
      final empty = _slot('first'), second = _slot('second');
      final pages = [
        [caption, existing],
        [decoration, empty, second],
      ];
      final photos = [a, b, c];
      final plan = TemplatePhotoFillPlan.create(pages: pages, photos: photos);
      final proposal = plan.buildPages();
      expect(plan.placements.map((p) => p.original.id), ['first', 'second']);
      expect(proposal[1][1].asset, same(a));
      expect(proposal[1][2].asset, same(b));
      expect(plan.remainingPhotos.single, same(c));
      expect(plan.remainingEmptySlots, 0);
      expect(proposal[0][0], same(caption));
      expect(proposal[0][1], same(existing));
      expect(proposal[1][0], same(decoration));
      expect(proposal[1][1].position, empty.position);
      expect(proposal[1][1].rotation, empty.rotation);
      expect(proposal[1][1].imageBackground, empty.imageBackground);
      expect(existing.imageZoom, 1.8);
      expect(existing.imageOffset, const Offset(4, -9));
      expect(pages[1][1], same(empty));
      expect(pages[1][1].asset, isNull);
      expect(photos, [a, b, c]);
    },
  );

  test(
    'too few photos leave later slots empty and stale proposals do not match',
    () {
      final a = _Photo(), b = _Photo();
      final pages = [
        [_slot('cover')],
        [_slot('inner')],
      ];
      final plan = TemplatePhotoFillPlan.create(pages: pages, photos: [a]);
      final proposal = plan.buildPages();
      expect(plan.remainingEmptySlots, 1);
      expect(plan.remainingPhotos, isEmpty);
      expect(proposal[1].single, same(pages[1].single));
      expect(plan.matches(pages, [a]), isTrue);
      expect(plan.matches(pages, [b]), isFalse);
      expect(plan.matches(pages, [a, b]), isFalse);
      expect(
        plan.matches(
          [
            [pages[0].single.copyWith(text: 'changed')],
            pages[1],
          ],
          [a],
        ),
        isFalse,
      );
    },
  );

  test(
    'a fully filled document proposes no changes and preserves every photo',
    () {
      final a = _Photo();
      final existing = _slot('cover').copyWith(asset: a);
      final plan = TemplatePhotoFillPlan.create(
        pages: [
          [existing],
        ],
        photos: [a],
      );
      expect(plan.placements, isEmpty);
      expect(plan.buildPages().single.single, same(existing));
      expect(plan.remainingPhotos, [a]);
      expect(plan.remainingEmptySlots, 0);
    },
  );
}
