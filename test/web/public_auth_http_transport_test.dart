@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:snap_fit/config/env.dart';
import 'package:snap_fit/core/supabase/auth_request_http_client.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Opt-in public connectivity diagnostic in an isolated Chrome test profile.
// Uses only the client publishable key; no browser session or customer data.
void main() {
  test(
    'public auth endpoints work through the real browser transport',
    () async {
      final direct = http.Client();
      final bounded = AuthRequestHttpClient(
        supabaseUrl: Env.supabaseUrl,
        timeout: const Duration(seconds: 10),
      );
      addTearDown(direct.close);
      addTearDown(bounded.close);
      final headers = {'apikey': Env.supabaseAnonKey};
      final health = Uri.parse('${Env.supabaseUrl}/auth/v1/health');
      final baseline = await direct
          .get(health, headers: headers)
          .timeout(const Duration(seconds: 12));
      expect(baseline.statusCode, 200);
      final response = await bounded.get(health, headers: headers);
      expect(response.statusCode, 200);
      expect(jsonDecode(response.body), jsonDecode(baseline.body));
      final settings = await bounded.get(
        Uri.parse('${Env.supabaseUrl}/auth/v1/settings'),
        headers: headers,
      );
      expect(settings.statusCode, 200);
      expect(jsonDecode(settings.body), contains('external'));
    },
    skip: !const bool.fromEnvironment('RUN_PUBLIC_AUTH_TRANSPORT'),
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'live anonymous catalog and four free quotes load in the browser SDK',
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
      final repository = SupabasePointShopRepository(client);
      expect(repository.currentUserId, isNull);
      final rows = await repository.loadCatalog().timeout(
        const Duration(seconds: 12),
      );
      for (final id in ['bold-cut', 'ticket-label', 'hand-note', 'diecut']) {
        final key = 'phrase:collage-$id';
        final product = rows.singleWhere((p) => p.productKey == key);
        expect(product.isActive, isTrue);
        expect(product.pointPrice, 0);
        final quote = await repository
            .getAccess(key)
            .timeout(const Duration(seconds: 12));
        expect(quote.productKey, key);
        expect(quote.available, isTrue);
        expect(quote.isFree, isTrue);
      }
    },
    skip: !const bool.fromEnvironment('RUN_PUBLIC_AUTH_TRANSPORT'),
    timeout: const Timeout(Duration(seconds: 50)),
  );
}
