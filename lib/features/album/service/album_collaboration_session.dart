import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/viewmodels/auth_view_model.dart';

/// Shared album requests and their UI belong to the account that started them.
final albumCollaborationActorProvider = Provider<String?>((ref) {
  return ref.watch(authViewModelProvider).asData?.value?.id;
});
