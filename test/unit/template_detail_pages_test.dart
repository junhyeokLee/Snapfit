import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/store/presentation/utils/template_detail_pages.dart';

Map<String, dynamic> _page(int index) => {
  'layers': [
    {
      'id': 'photo-$index',
      'type': 'image',
      'x': .1,
      'y': .1,
      'width': .8,
      'height': .6,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('large books compile only indexed pages and reuse recent models', () {
    final cache = TemplateDetailPageCache();
    final pages = TemplateDetailPages(
      pages: List.generate(1001, _page),
      canvas: const Size(500, 500),
      cache: cache,
    );
    expect(pages.length, 1001);
    expect(pages.isNotEmpty, isTrue);
    expect(cache.length, 0);
    final cover = pages[0];
    expect(cover.single.id, 'photo-0');
    expect(pages[0], same(cover));
    expect(cache.length, 1);
    expect(pages[1000].single.id, 'photo-1000');
    expect(cache.length, 2);
  });

  test('variants share one budget without mixing canvas geometry', () {
    final cache = TemplateDetailPageCache(limit: 4);
    final sources = List.generate(101, _page);
    final square = TemplateDetailPages(
      pages: sources,
      canvas: const Size(500, 500),
      cache: cache,
    );
    final wide = TemplateDetailPages(
      pages: sources,
      canvas: const Size(800, 500),
      cache: cache,
    );
    expect(square[0].single.width, 400);
    expect(wide[0].single.width, 640);
    for (var index = 0; index < square.length; index++) {
      square[index];
      wide[index];
      expect(cache.length, lessThanOrEqualTo(4));
    }
    final recent = wide[100];
    square[0];
    expect(wide[100], same(recent));
    expect(cache.length, 4);
  });

  test(
    'cache cleanup releases models and reconstructs the same authored page',
    () {
      final cache = TemplateDetailPageCache();
      final pages = TemplateDetailPages(
        pages: [_page(1)],
        canvas: const Size(500, 700),
        cache: cache,
      );
      final first = pages.single;
      cache.clear();
      expect(cache.length, 0);
      final rebuilt = pages.single;
      expect(rebuilt, isNot(same(first)));
      expect(rebuilt.single.id, first.single.id);
      expect(rebuilt.single.position, first.single.position);
      expect(rebuilt.single.width, first.single.width);
      expect(() => pages.clear(), throwsUnsupportedError);
      expect(() => rebuilt.clear(), throwsUnsupportedError);
    },
  );
}
