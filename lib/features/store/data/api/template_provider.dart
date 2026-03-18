import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/interceptors/token_storage.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart'; // tokenStorageProvider
import '../../domain/repositories/template_repository.dart';
import '../../domain/entities/premium_template.dart'; // PremiumTemplate
import '../repositories/template_repository_impl.dart';
import 'template_api.dart';
import '../local/local_featured_templates.dart';

final templateApiProvider = Provider<TemplateApi>((ref) {
  final dio = ref.read(dioProvider);
  return TemplateApi(dio);
});

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  final api = ref.read(templateApiProvider);
  final tokenStorage = ref.read(tokenStorageProvider);
  return TemplateRepositoryImpl(api, tokenStorage: tokenStorage);
});

final templateListProvider = FutureProvider<List<PremiumTemplate>>((ref) async {
  final repository = ref.watch(templateRepositoryProvider);
  final local = localFeaturedTemplates();

  String normalizeTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

  PremiumTemplate pickBetter(PremiumTemplate a, PremiumTemplate b) {
    int score(PremiumTemplate t) {
      var s = 0;
      if (t.templateJson != null && t.templateJson!.trim().isNotEmpty) s += 5;
      if (t.previewImages.isNotEmpty) s += 3;
      if (t.coverImageUrl.trim().isNotEmpty) s += 1;
      if (t.id >= 0) s += 1; // server id slightly preferred for like/use sync
      return s;
    }

    final sa = score(a);
    final sb = score(b);
    if (sb > sa) return b;
    if (sa > sb) return a;
    return a.id >= 0 ? a : b;
  }

  List<PremiumTemplate> dedupeByTitle(List<PremiumTemplate> items) {
    final byTitle = <String, PremiumTemplate>{};
    for (final t in items) {
      final key = normalizeTitle(t.title);
      if (key.isEmpty) {
        byTitle['id:${t.id}'] = t;
        continue;
      }
      final prev = byTitle[key];
      if (prev == null) {
        byTitle[key] = t;
      } else {
        byTitle[key] = pickBetter(prev, t);
      }
    }
    return byTitle.values.toList();
  }

  try {
    final remote = await repository.getTemplates();
    final merged = <int, PremiumTemplate>{
      for (final t in local) t.id: t,
      for (final t in remote) t.id: t,
    };
    return dedupeByTitle(merged.values.toList());
  } catch (_) {
    return dedupeByTitle(local);
  }
});
