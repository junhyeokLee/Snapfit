import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/social/data/social_template_catalog.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

void main() {
  test('source parser ignores malformed, private, arbitrary URL metadata', () {
    for (final value in [
      null,
      'template:lightbound',
      {},
      {'productKey': 9, 'title': 'a'},
      {'productKey': 'https://private/photo.png', 'title': 'a'},
      {'productKey': 'template:lightbound', 'title': ''},
    ]) {
      expect(SocialTemplateSource.tryParse(value), isNull);
    }
    final json = {
      'id': 'work',
      'author': {'userId': 'author', 'displayName': '작가', 'handle': 'artist'},
      'title': '공개 기록',
      'createdAt': '2026-10-26T00:00:00Z',
      'sourceTemplate': {'productKey': 'template:lightbound', 'title': '빛의 기록'},
    };
    expect(
      SocialWork.fromJson(json).sourceTemplate!.productKey,
      'template:lightbound',
    );
    expect(
      SocialWork.fromJson({...json, 'status': 'private'}).sourceTemplate,
      isNull,
    );
  });

  test(
    'catalog lookup uses stable keys without materializing document builders',
    () {
      final template = publishedCreationTemplates.first;
      var builds = 0;
      final source = SocialTemplateSource(
        productKey: pointShopTemplateKey(template),
        title: '이름이 달라져도 같은 디자인',
      );
      final lazy = PremiumTemplate(
        id: template.id,
        title: '현재 제목',
        coverImageUrl: '',
        previewImages: const [],
        pageCount: 20,
        userCount: 0,
        documentBuilder: () {
          builds++;
          return '{"pages":[]}';
        },
      );
      expect(socialSourceCatalogTemplate(source, [lazy]), same(lazy));
      expect(builds, 0);
      expect(
        socialSourceCatalogTemplate(
          const SocialTemplateSource(
            productKey: 'template:unknown',
            title: '현재 제목',
          ),
          [lazy],
        ),
        isNull,
      );
      expect(socialSourceCatalogTemplate(null, [lazy]), isNull);
    },
  );
}
