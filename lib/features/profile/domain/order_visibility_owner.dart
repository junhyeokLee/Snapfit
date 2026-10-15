import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/viewmodels/auth_view_model.dart';

/// A cached profile cannot keep an order visible after the SDK session changes.
/// Server ownership checks remain the authority for every order read or write.
class ObservedOrderSession {
  const ObservedOrderSession({this.observed = false, this.ownerId});
  final bool observed;
  final String? ownerId;
}

class OrderSessionOwner extends Notifier<ObservedOrderSession> {
  @override
  ObservedOrderSession build() => const ObservedOrderSession();

  void observe(String? ownerId) {
    if (state.observed && state.ownerId == ownerId) return;
    state = ObservedOrderSession(observed: true, ownerId: ownerId);
  }
}

final orderSessionOwnerProvider =
    NotifierProvider<OrderSessionOwner, ObservedOrderSession>(
      OrderSessionOwner.new,
    );

final visibleOrderOwnerProvider = Provider<String?>((ref) {
  final profileOwner = ref.watch(authViewModelProvider).asData?.value?.id;
  final session = ref.watch(orderSessionOwnerProvider);
  if (profileOwner == null ||
      session.observed && session.ownerId != profileOwner)
    return null;
  return profileOwner;
});
