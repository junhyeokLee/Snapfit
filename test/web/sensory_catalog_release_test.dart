@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/config/env.dart';
import 'package:snap_fit/core/supabase/auth_request_http_client.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';

// Explicit opt-in only: public read-only production checks; no customer session,
// purchase, wallet, ownership or album write is performed.
const expectedPrices = <String, int>{
  'frame:cafeGlassine': 0,
  'frame:cafeLedgerMat': 0,
  'frame:cafeReceiptFold': 0,
  'frame:nocturneContact': 0,
  'frame:nocturneDuplex': 400,
  'frame:nocturneTransit': 300,
  'phrase:collage-sensory-coffee-note': 0,
  'phrase:collage-sensory-night-index': 300,
  'phrase:collage-story-coffee-notebook': 0,
  'phrase:collage-story-night-city-archive': 300,
  'sticker:cafeRoastedLeaf': 0,
  'sticker:nocturneGlassine': 200,
  'sticker:story-coffee-notebook-motif': 0,
  'sticker:story-coffee-notebook-paper': 0,
  'sticker:story-night-city-archive-motif': 200,
  'sticker:story-night-city-archive-paper': 100,
  'template:story-coffee-notebook': 0,
  'template:story-night-city-archive': 1800,
};
void main() {
  test(
    'all 18 sensory products have the live public price, tier and access quote',
    () async {
      final transport = AuthRequestHttpClient(supabaseUrl: Env.supabaseUrl);
      final client = SupabaseClient(
        Env.supabaseUrl,
        Env.supabaseAnonKey,
        httpClient: transport,
      );
      addTearDown(() async {
        await client.dispose();
        transport.close();
      });
      final repo = SupabasePointShopRepository(client);
      expect(repo.currentUserId, isNull);
      final rows = await repo.loadCatalog().timeout(
        const Duration(seconds: 12),
      );
      for (final e in expectedPrices.entries) {
        final product = rows.singleWhere((r) => r.productKey == e.key);
        expect(product.pointPrice, e.value, reason: e.key);
        expect(product.isActive, isTrue, reason: e.key);
        final quote = await repo
            .getAccess(e.key)
            .timeout(const Duration(seconds: 12));
        expect(quote.productKey, e.key);
        expect(quote.pointPrice, e.value, reason: e.key);
        expect(quote.available, isTrue, reason: e.key);
        expect(quote.isFree, e.value == 0, reason: e.key);
        expect(
          quote.owned,
          isFalse,
          reason: 'anonymous requests have no customer ownership',
        );
      }
    },
    skip: !const bool.fromEnvironment('RUN_SENSORY_PRODUCTION_CHECK'),
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
