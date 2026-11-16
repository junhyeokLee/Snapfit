@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/config/env.dart';
import 'package:snap_fit/core/supabase/auth_request_http_client.dart';
import 'package:snap_fit/core/templates/catalog_publication_dates.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';

void main() {
  test(
    'anonymous production discovery returns only public release dates and qualified ranks',
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
      final rows = await client.rpc('get_store_product_discovery') as List;
      final byKey = {
        for (final row in rows)
          row['product_key'] as String: Map<String, dynamic>.from(row as Map),
      };
      for (final entry in catalogFirstPublicationDates.entries) {
        expect(byKey.containsKey(entry.key), isTrue, reason: entry.key);
        expect(
          DateTime.parse(byKey[entry.key]!['first_published_at'] as String),
          DateTime.parse(entry.value),
        );
      }
      for (final row in byKey.values) {
        expect(row.keys.toSet(), {
          'product_key',
          'first_published_at',
          'best_rank',
        });
        final rank = row['best_rank'];
        if (rank != null) expect(rank, inInclusiveRange(1, 5));
        final metadata = StoreProductDiscovery.fromJson(row);
        if (metadata.firstPublishedAt == null)
          expect(metadata.isNewAt(DateTime.now().toUtc()), isFalse);
      }
    },
    skip: !const bool.fromEnvironment('RUN_STORE_DISCOVERY_PRODUCTION_CHECK'),
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
