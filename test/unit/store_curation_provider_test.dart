import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/supabase/supabase_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/domain/store_template_editorial_selection.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'editorial selection resolves twelve reviewed books across eleven topics',
    () {
      final selected = StoreCuration.templates.resolve(
        publishedCreationTemplates,
        pointShopTemplateKey,
      );
      expect(selected, hasLength(12));
      expect(
        selected.map(pointShopTemplateKey),
        storeTemplateEditorialProductKeys,
      );
      expect(selected.map((t) => t.id).toSet(), hasLength(12));
      expect(selected.map((t) => t.category).toSet(), hasLength(11));
      expect(selected.where((t) => !t.isPremium), hasLength(4));
      expect(selected.where((t) => t.isPremium), hasLength(8));
      expect(
        selected.where((t) => t.id <= -9801 && t.id >= -9844),
        hasLength(6),
      );
      expect(
        selected.every((t) => reviewedStoreTemplateIds.contains(t.id)),
        isTrue,
      );
      expect(
        publishedCreationTemplates.map((t) => t.id).toSet(),
        containsAll(reviewedStoreTemplateIds),
      );
    },
  );

  test(
    'a catalog without the quartet release retains six explicit selections',
    () {
      final established = publishedCreationTemplates.where(
        (item) => item.id > -9801 || item.id < -9844,
      );
      final selected = StoreCuration.templates.resolve(
        established,
        pointShopTemplateKey,
      );
      expect(selected, hasLength(6));
      expect(selected.where((item) => !item.isPremium), hasLength(4));
      expect(selected.map(pointShopTemplateKey), [
        'template:story-coffee-notebook',
        'template:story-sport-pace-study',
        'template:dates-of-us',
        'template:story-club-run-together',
        'template:our-good-company',
        'template:taste-archive',
      ]);
    },
  );

  test(
    'material selection balances four kinds and contains priced products',
    () {
      final selected = StoreCuration.materials.resolve(
        pointShopKnownProducts,
        (item) => item.productKey,
      );
      expect(selected, hasLength(12));
      String kind(String productKey) {
        if (!productKey.startsWith('sticker:'))
          return productKey.split(':').first;
        final decoration = studioDecorationById(productKey.substring(8));
        return decoration?.category == StudioDecorationCategory.paper
            ? 'paper'
            : 'sticker';
      }

      expect(selected.take(4).map((item) => kind(item.productKey)), [
        'frame',
        'paper',
        'sticker',
        'phrase',
      ]);
      for (final type in ['frame', 'paper', 'sticker', 'phrase']) {
        expect(
          selected.where((item) => kind(item.productKey) == type),
          hasLength(3),
        );
      }
      expect(
        selected.every(
          (item) => pointShopLaunchPrices.containsKey(item.productKey),
        ),
        isTrue,
      );
      expect(
        selected.where(
          (item) => pointShopLaunchPrices[item.productKey]!.points == 0,
        ),
        hasLength(4),
      );
    },
  );

  test(
    'resolve preserves administrator order; missing items never replace selections',
    () {
      const slot = StoreCuration(
        placement: 'templates',
        title: '선택',
        subtitle: '',
        productKeys: ['b', 'absent', 'a'],
      );
      expect(slot.resolve(['a', 'c', 'b'], (v) => v), ['b', 'a']);
      const hidden = StoreCuration(
        placement: 'materials',
        title: '숨김',
        subtitle: '',
        productKeys: ['a'],
        enabled: false,
      );
      expect(hidden.resolve(['a'], (v) => v), isEmpty);
    },
  );
  test(
    'hidden and empty server selections survive subsequent offline refresh',
    () async {
      SharedPreferences.setMockInitialValues({});
      var offline = false;
      final client = SupabaseClient(
        'https://example.invalid',
        'public-test-key',
        httpClient: MockClient((request) async {
          if (offline) return http.Response('{}', 503);
          return http.Response(
            jsonEncode([
              {
                'placement': 'templates',
                'title': '숨김',
                'enabled': false,
                'product_keys': ['template:a'],
              },
              {
                'placement': 'materials',
                'title': '비어 있음',
                'enabled': true,
                'product_keys': [],
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      expect((await client.from('store_curations').select()).length, 2);
      var slots = await container.read(storeCurationsProvider.future);
      expect(slots['templates']!.enabled, isFalse);
      expect(slots['materials']!.productKeys, isEmpty);
      offline = true;
      container.invalidate(storeCurationsProvider);
      slots = await container.read(storeCurationsProvider.future);
      expect(slots['templates']!.enabled, isFalse);
      expect(slots['materials']!.productKeys, isEmpty);
    },
  );
  test(
    'unconfigured/offline first installation has the explicit launch selection',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = SupabaseClient(
        'https://example.invalid',
        'public-test-key',
        httpClient: MockClient((_) async => http.Response('{}', 404)),
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final slots = await container.read(storeCurationsProvider.future);
      expect(
        slots['templates']!.productKeys,
        StoreCuration.templates.productKeys,
      );
      expect(
        slots['materials']!.productKeys,
        StoreCuration.materials.productKeys,
      );
    },
  );
}
