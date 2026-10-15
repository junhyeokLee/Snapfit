import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/supabase/supabase_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
