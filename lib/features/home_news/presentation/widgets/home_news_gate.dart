import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/presentation/first_visit_controller.dart';
import '../../data/home_news_repository.dart';
import '../home_news_navigation.dart';
import '../providers/home_news_providers.dart';
import '../providers/home_news_today_providers.dart';

/// Every real visit to the main gets its own opportunity. Closing the popup
/// alone stays in this visit; returning from a destination starts another.
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
  late final HomeNewsPresentationCoordinator _coordinator;
  String? _observedOwner;
  bool _foreground = true;
  bool _wasVisible = false;
  bool _running = false;
  bool _presenting = false;
  bool _coveredByOwnFlow = false;
  bool _rebuildScheduled = false;
  int _revision = 0;
  int _visit = 0;
  int? _attemptedVisit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _coordinator = ref.read(homeNewsPresentationCoordinatorProvider);
    _coordinator.addListener(_scheduleRebuild);
  }

  @override
  void dispose() {
    _revision++;
    _coordinator.removeListener(_scheduleRebuild);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scheduleRebuild() {
    if (!mounted || _rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = state == AppLifecycleState.resumed;
    if (_foreground == next) return;
    _foreground = next;
    // A pause invalidates delayed reads even if no widget frame was rendered
    // while the app was backgrounded.
    if (!next) {
      _revision++;
      if (!_presenting) _wasVisible = false;
    }
    _scheduleRebuild();
  }

  bool get _visible =>
      widget.active &&
      _foreground &&
      TickerMode.of(context) &&
      ModalRoute.isCurrentOf(context) != false;

  bool _current(String owner, int revision) =>
      mounted &&
      _revision == revision &&
      _visible &&
      ref.read(homeNewsCurrentOwnerProvider) == owner &&
      ref.read(homeNewsRepositoryProvider).currentUserId == owner;

  bool get _guideReady {
    if (!widget.respectFirstVisitGuide) return true;
    // Persisted tutorial flags are not a visible overlay and must never
    // suppress this visit when its guide anchor has not mounted.
    return !ref.read(firstHomeGuideVisibleProvider);
  }

  bool get _recoveryReady =>
      ref.read(homeNewsRecoveryBlockProvider).asData?.value == false;

  Future<void> _attempt(String owner, int revision, int visit) async {
    final subscriptions = <ProviderSubscription>[];
    try {
      final delay = ref.read(homeNewsReadyDelayProvider);
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (!_current(owner, revision) || !_guideReady || !_recoveryReady) return;
      subscriptions.add(
        ref.listenManual(homeNewsExposureStateProvider, (_, __) {}),
      );
      ref.invalidate(homeNewsExposureStateProvider);
      final state = await ref.read(homeNewsExposureStateProvider.future);
      if (state == null ||
          state.hiddenForToday ||
          !_current(owner, revision) ||
          !_guideReady ||
          !_recoveryReady) {
        return;
      }
      subscriptions.add(
        ref.listenManual(homeNewsTodayHiddenProvider, (_, __) {}),
      );
      final hidden = await ref.read(homeNewsTodayHiddenProvider.future);
      if (hidden || !_current(owner, revision)) return;
      subscriptions.add(ref.listenManual(homeNewsCatalogProvider, (_, __) {}));
      final items = await ref.read(homeNewsCatalogProvider.future);
      if (items.isEmpty ||
          !_current(owner, revision) ||
          !_guideReady ||
          !_recoveryReady ||
          _coordinator.busy) {
        return;
      }
      // Enabled stories are shown on every entry. Participation, previous
      // impressions and the old daily/weekly counters do not suppress a visit.
      final claim = await ref
          .read(homeNewsRepositoryProvider)
          .claimDelivery(items.map((item) => item.id).toList());
      if (!claim.claimed ||
          !_current(owner, revision) ||
          !_guideReady ||
          !_recoveryReady ||
          _coordinator.busy) {
        return;
      }
      final accepted = items
          .where((item) => claim.campaignIds.contains(item.id))
          .toList(growable: false);
      if (accepted.isEmpty) return;
      _presenting = true;
      _coveredByOwnFlow = true;
      var destinationOpened = false;
      await openHomeNews(
        context,
        ref,
        accepted.first,
        automatic: true,
        carouselItems: accepted,
        deliveryId: claim.deliveryId,
        onDestinationOpened: () => destinationOpened = true,
      );
      if (destinationOpened) {
        // A real destination followed by back is a new main entry. Only the
        // popup's own dismissal is absorbed without showing it again.
        _coveredByOwnFlow = false;
        _wasVisible = false;
      }
    } catch (_) {
      // Connection failures never block an album. A later entry tries again.
    } finally {
      for (final subscription in subscriptions) subscription.close();
      if (mounted &&
          _visit == visit &&
          _current(owner, revision) &&
          (!_guideReady || !_recoveryReady || _coordinator.busy)) {
        // An overlay/recovery that appeared during an awaited request defers
        // this opportunity instead of consuming the main visit permanently.
        _attemptedVisit = null;
      }
      _presenting = false;
      _running = false;
      _scheduleRebuild();
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(homeNewsCurrentOwnerProvider);
    final visible = _visible;
    if (owner != _observedOwner) {
      _observedOwner = owner;
      _revision++;
      _wasVisible = false;
      _coveredByOwnFlow = false;
      _attemptedVisit = null;
    }
    // The popup covers the main route. Its own close is absorbed; a real
    // destination is converted into a new visit after its navigation returns.
    if (_coveredByOwnFlow && !_presenting) {
      if (visible) {
        // Route animations can restore isCurrent after the modal future ends.
        // Consume that restoration without mistaking it for an external visit.
        _wasVisible = true;
        _coveredByOwnFlow = false;
      } else if (!widget.active || !_foreground || !TickerMode.of(context)) {
        _wasVisible = false;
        _coveredByOwnFlow = false;
      }
    } else if (!_presenting && !_coveredByOwnFlow) {
      if (visible && !_wasVisible) {
        _visit++;
        _revision++;
        _attemptedVisit = null;
      } else if (!visible && _wasVisible) {
        _revision++;
      }
      _wasVisible = visible;
    }
    if (widget.respectFirstVisitGuide) {
      ref.watch(firstHomeGuideVisibleProvider);
    }
    final recovery = owner == null
        ? null
        : ref.watch(homeNewsRecoveryBlockProvider);
    if (owner != null &&
        visible &&
        !_running &&
        !_presenting &&
        !_coordinator.busy &&
        _guideReady &&
        recovery?.asData?.value == false &&
        _attemptedVisit != _visit) {
      final revision = _revision;
      final visit = _visit;
      _attemptedVisit = visit;
      _running = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_current(owner, revision)) {
          unawaited(_attempt(owner, revision, visit));
        } else {
          _running = false;
          _scheduleRebuild();
        }
      });
    }
    return widget.child;
  }
}
