import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../data/moment_engagement_repository.dart';

final momentEngagementRepositoryProvider = Provider<MomentEngagementRepository>(
  (ref) {
    final repository = SupabaseMomentEngagementRepository(
      ref.watch(supabaseClientProvider),
    );
    ref.onDispose(repository.dispose);
    return repository;
  },
);
