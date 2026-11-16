import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/social/presentation/social_page_boundaries.dart';

void main() {
  test('a changed middle page retires its downstream cursor only', () {
    final pages = SocialPageBoundaries<String>();
    const queries = ['start', 'after-89', 'after-77'];
    expect(pages.observe(queries, ['89', '77', '65']), isNull);
    expect(pages.observe(queries, ['89', '78', '65']), 2);
    expect(pages.observe(queries.take(2).toList(), ['89', '78']), isNull);
    expect(
      pages.observe(['start', 'after-89', 'after-78'], ['89', '78', '66']),
      isNull,
    );
  });

  test(
    'the earliest changed edge wins when several replies change together',
    () {
      final pages = SocialPageBoundaries<String>();
      const queries = ['one', 'two', 'three', 'four'];
      pages.observe(queries, ['a', 'b', 'c', 'd']);
      expect(pages.observe(queries, ['A', 'B', 'C', 'D']), 1);
    },
  );

  test(
    'loading and errors preserve earlier known edges for the next success',
    () {
      final pages = SocialPageBoundaries<String>();
      const queries = ['one', 'two', 'three'];
      pages.observe(queries, ['a', 'b', 'c']);
      expect(pages.observe(queries, [null, null, 'c']), isNull);
      expect(pages.observe(queries, ['a', 'new-b', 'c']), 2);
    },
  );

  test('retired replies do not establish a baseline for a future page', () {
    final pages = SocialPageBoundaries<String>();
    const queries = ['one', 'two', 'three', 'four'];
    pages.observe(queries, ['a', 'b', 'c', 'd']);
    expect(pages.observe(queries, ['a', 'B', 'stale-c', 'stale-d']), 2);
    expect(pages.observe(queries, ['a', 'B', 'new-c', 'new-d']), isNull);
  });

  test('a changed last edge also fences an already captured continuation', () {
    final pages = SocialPageBoundaries<String>();
    pages.observe(['one', 'two'], ['a', 'b']);
    expect(pages.observe(['one', 'two'], ['a', 'B']), 2);
    expect(pages.observe(['one', 'two', 'new-three'], ['a', 'B', 'c']), isNull);
  });

  test('session reset forgets the previous viewers page windows', () {
    final pages = SocialPageBoundaries<String>();
    pages.observe(['one', 'two', 'three'], ['a', 'b', 'c']);
    pages.clear();
    expect(pages.observe(['one', 'two', 'three'], ['A', 'B', 'C']), isNull);
  });

  test('cursor order is canonical and photo token renewal keeps the edge', () {
    final before = socialPageBoundary(
      nextCursor: {'recordDate': '2026-10-10', 'id': 'record-1'},
      nextOffset: 12,
      hasMore: true,
      itemKeys: ['record-1'],
    );
    final after = socialPageBoundary(
      nextCursor: {'id': 'record-1', 'recordDate': '2026-10-10'},
      nextOffset: 12,
      hasMore: true,
      itemKeys: ['another-visible-record', 'record-1'],
    );
    expect(after, before);
    expect(
      socialPageBoundary(
        nextCursor: {'id': 'record-1', 'recordDate': '2026-10-10'},
        nextOffset: 12,
        hasMore: false,
        itemKeys: ['record-1'],
      ),
      isNot(before),
    );
  });

  test('legacy offset windows notice changed contents and exhaustion', () {
    String boundary(List<String> ids, {bool more = true}) => socialPageBoundary(
      nextCursor: null,
      nextOffset: 12,
      hasMore: more,
      itemKeys: ids,
    );
    expect(boundary(['new', 'old']), isNot(boundary(['old'])));
    expect(boundary(['old'], more: false), isNot(boundary(['old'])));
  });
}
