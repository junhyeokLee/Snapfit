import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../domain/store_product_discovery.dart';

// A long-open store loses expired badges without an app restart. This does not
// poll the database; the public aggregate is refreshed independently below.
final storeDiscoveryClockProvider = Provider<DateTime>((ref) {
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return DateTime.now().toUtc();
});

final storeDiscoveryProvider =
    FutureProvider<Map<String, StoreProductDiscovery>>((ref) async {
      final refresh = Timer(const Duration(minutes: 15), ref.invalidateSelf);
      ref.onDispose(refresh.cancel);
      try {
        final rows = await ref
            .watch(supabaseClientProvider)
            .rpc('get_store_product_discovery')
            .timeout(const Duration(seconds: 4));
        return Map.unmodifiable({
          for (final row in rows as List)
            row['product_key'] as String: StoreProductDiscovery.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
        });
      } catch (_) {
        // Only verified first releases can fall back offline; BEST never does.
        return bundledStoreDiscovery;
      }
    }, retry: (_, _) => null);
