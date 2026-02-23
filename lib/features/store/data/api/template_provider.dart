import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/interceptors/token_storage.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart'; // tokenStorageProvider
import '../../domain/repositories/template_repository.dart';
import '../../domain/entities/premium_template.dart'; // PremiumTemplate
import '../repositories/template_repository_impl.dart';
import 'template_api.dart';

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
  return repository.getTemplates();
});

