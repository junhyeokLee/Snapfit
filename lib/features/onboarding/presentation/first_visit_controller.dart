import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/first_visit_store.dart';

final firstVisitStoreProvider = Provider<FirstVisitStore>(
  (_) => PreferencesFirstVisitStore(),
);

final firstVisitProvider =
    AsyncNotifierProvider<FirstVisitController, FirstVisitProgress>(
      FirstVisitController.new,
    );

class FirstVisitProgress {
  const FirstVisitProgress({
    this.introductionSeen = false,
    this.homeGuideSeen = false,
    this.homeGuideRequested = false,
  });

  factory FirstVisitProgress.fromFlags(int flags) => FirstVisitProgress(
    introductionSeen: flags & 1 != 0,
    homeGuideSeen: flags & 2 != 0,
  );

  final bool introductionSeen, homeGuideSeen;
  // Replay is a consumable request, never a persisted reset of the seen flags.
  final bool homeGuideRequested;

  int get flags => (introductionSeen ? 1 : 0) | (homeGuideSeen ? 2 : 0);
  bool get shouldShowHomeGuide =>
      homeGuideRequested || (introductionSeen && !homeGuideSeen);
}

class FirstVisitController extends AsyncNotifier<FirstVisitProgress> {
  Future<void> _writes = Future.value();

  @override
  Future<FirstVisitProgress> build() async {
    try {
      return FirstVisitProgress.fromFlags(
        await ref.read(firstVisitStoreProvider).read(),
      );
    } catch (_) {
      return const FirstVisitProgress();
    }
  }

  Future<void> completeIntroduction({required bool skipped}) async {
    final progress = await future;
    if (!ref.mounted) return;
    final next = FirstVisitProgress(
      introductionSeen: true,
      // Respect skipping the introduction: no unsolicited follow-up tutorial.
      homeGuideSeen: progress.homeGuideSeen || skipped,
      homeGuideRequested: progress.homeGuideRequested,
    );
    state = AsyncData(next);
    if (next.flags != progress.flags) unawaited(_persist(next));
  }

  void requestHomeGuide() {
    final progress = state.asData?.value;
    if (progress == null) return;
    state = AsyncData(
      FirstVisitProgress(
        introductionSeen: progress.introductionSeen,
        homeGuideSeen: progress.homeGuideSeen,
        homeGuideRequested: true,
      ),
    );
  }

  /// Claim only when the actual main target is visible, not in a hidden tab.
  bool takeHomeGuide() {
    final progress = state.asData?.value;
    if (progress?.shouldShowHomeGuide != true) return false;
    final next = FirstVisitProgress(
      introductionSeen: progress!.introductionSeen,
      homeGuideSeen: true,
    );
    state = AsyncData(next);
    if (next.flags != progress.flags) unawaited(_persist(next));
    return true;
  }

  Future<void> _persist(FirstVisitProgress progress) {
    final store = ref.read(firstVisitStoreProvider);
    // A delayed introduction write must not erase the guide's newer flag.
    return _writes = _writes
        .then((_) => store.write(progress.flags))
        .catchError((Object _) {
          // Keep the in-session decision even if device storage is unavailable.
        });
  }
}
