import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/home_news_today_store.dart';
import 'home_news_providers.dart';

final homeNewsTodayStoreProvider = Provider<HomeNewsTodayStore>(
  (_) => PreferencesHomeNewsTodayStore(),
);

final homeNewsTodayHiddenProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final owner = ref.watch(homeNewsCurrentOwnerProvider);
  if (owner == null) return false;
  final state = await ref.watch(homeNewsExposureStateProvider.future);
  if (!ref.mounted || state == null) return false;
  final store = ref.watch(homeNewsTodayStoreProvider);
  final until = await store.readUntil(owner);
  return ref.mounted &&
      ref.read(homeNewsCurrentOwnerProvider) == owner &&
      until != null &&
      until.isAfter(state.serverNow);
});
