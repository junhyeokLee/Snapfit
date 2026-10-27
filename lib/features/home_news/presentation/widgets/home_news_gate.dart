import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/presentation/first_visit_controller.dart';
import '../home_news_navigation.dart';
import '../../data/home_news_repository.dart';
import '../providers/home_news_providers.dart';

/// One opportunity per signed-in owner and app run. Returning from a reader,
/// changing tabs, rebuilding the home or resuming never opens another popup.
class HomeNewsGate extends ConsumerStatefulWidget {
  const HomeNewsGate({
    super.key,
    required this.child,
    this.active = true,
    this.respectFirstVisitGuide = true,
  });
  final Widget child;
  final bool active;
  final bool respectFirstVisitGuide;

  @override
  ConsumerState<HomeNewsGate> createState() => _HomeNewsGateState();
}

class _HomeNewsGateState extends ConsumerState<HomeNewsGate>
    with WidgetsBindingObserver {
  String? _scheduledOwner;
  String? _observedOwner;
  bool _guideWasPending = false;
  bool _foreground = true;
  bool _wasVisible = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _revision++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _revision++;
  }

  bool _current(String owner, int revision) =>
      mounted &&
      _revision == revision &&
      widget.active &&
      (!widget.respectFirstVisitGuide || !_guideWasPending) &&
      _foreground &&
      TickerMode.of(context) &&
      ModalRoute.isCurrentOf(context) != false &&
      ref.read(homeNewsCurrentOwnerProvider) == owner &&
      ref.read(homeNewsRepositoryProvider).currentUserId == owner;

  Future<void> _attempt(String owner, int revision) async {
    final subscriptions = <ProviderSubscription>[];
    try {
      final delay = ref.read(homeNewsReadyDelayProvider);
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (!_current(owner, revision)) return;
      if (widget.respectFirstVisitGuide) {
        final progress = await ref.read(firstVisitProvider.future);
        if (!progress.introductionSeen || progress.shouldShowHomeGuide) {
          _guideWasPending = true;
        }
      }
      if (_guideWasPending || !_current(owner, revision)) return;
      subscriptions.add(
        ref.listenManual(homeNewsRecoveryBlockProvider, (_, __) {}),
      );
      final blocked = await ref.read(homeNewsRecoveryBlockProvider.future);
      if (blocked || !_current(owner, revision)) return;
      subscriptions.add(
        ref.listenManual(homeNewsExposureStateProvider, (_, __) {}),
      );
      ref.invalidate(homeNewsExposureStateProvider);
      final state = await ref.read(homeNewsExposureStateProvider.future);
      if (state?.canAutoShow != true || !_current(owner, revision)) return;
      subscriptions.add(ref.listenManual(homeNewsCatalogProvider, (_, __) {}));
      final items = await ref.read(homeNewsCatalogProvider.future);
      if (!_current(owner, revision) ||
          ref.read(homeNewsRecoveryBlockProvider).asData?.value != false ||
          ref.read(homeNewsPresentationCoordinatorProvider).busy)
        return;
      final first = items.indexWhere(
        (item) => item.autoEligible && !state!.hasSeen(item.id),
      );
      if (first < 0) return;
      // Start with the eligible story, then cycle through every enabled story.
      final ordered = [...items.skip(first), ...items.take(first)];
      final claim = await ref
          .read(homeNewsRepositoryProvider)
          .claimDelivery(ordered.map((item) => item.id).toList());
      if (!claim.claimed ||
          !_current(owner, revision) ||
          ref.read(homeNewsRecoveryBlockProvider).asData?.value != false)
        return;
      final accepted = ordered
          .where((item) => claim.campaignIds.contains(item.id))
          .toList(growable: false);
      if (accepted.isEmpty) return;
      await openHomeNews(
        context,
        ref,
        accepted.first,
        automatic: true,
        carouselItems: accepted,
        deliveryId: claim.deliveryId,
      );
    } catch (_) {
      // Optional news must never block an album, recovery or navigation.
    } finally {
      for (final subscription in subscriptions) subscription.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(homeNewsCurrentOwnerProvider);
    final visible =
        widget.active &&
        _foreground &&
        TickerMode.of(context) &&
        ModalRoute.isCurrentOf(context) != false;
    if (_wasVisible && !visible) _revision++;
    _wasVisible = visible;
    if (widget.respectFirstVisitGuide) {
      final progress = ref.watch(firstVisitProvider).asData?.value;
      if (progress?.shouldShowHomeGuide == true ||
          progress != null && !progress.introductionSeen)
        _guideWasPending = true;
      ref.listen(firstVisitProvider, (_, next) {
        if (next.asData?.value.shouldShowHomeGuide == true)
          _guideWasPending = true;
      });
    }
    if (owner != _observedOwner) {
      _revision++;
      _observedOwner = owner;
    }
    if (owner != null && visible && owner != _scheduledOwner) {
      _scheduledOwner = owner;
      if (ref.read(homeNewsSessionGuardProvider).begin(owner)) {
        final revision = _revision;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_current(owner, revision)) unawaited(_attempt(owner, revision));
        });
      }
    }
    // Once the person starts interacting, a late response must not interrupt it.
    return Listener(onPointerDown: (_) => _revision++, child: widget.child);
  }
}
