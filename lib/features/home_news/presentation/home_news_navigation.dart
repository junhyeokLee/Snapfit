import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/web_app_location.dart';
import '../../../core/utils/context_extensions.dart';
import '../../album/presentation/viewmodels/home_view_model.dart';
import '../../album/presentation/widgets/home/home_album_actions.dart';
import '../../attendance/presentation/views/attendance_screen.dart';
import '../../moments/presentation/providers/moments_providers.dart';
import '../../moments/presentation/moments_navigation.dart';
import '../data/home_news_repository.dart';
import '../data/home_news_today_store.dart';
import '../../moments/presentation/views/monthly_moment_preview_screen.dart';
import '../../referral/presentation/views/referral_screen.dart';
import '../domain/home_news.dart';
import 'providers/home_news_providers.dart';
import 'providers/home_news_today_providers.dart';
import 'views/monthly_designs_screen.dart';
import 'widgets/home_news_sheet.dart';
import '../../../shared/widgets/snapfit_motion.dart';

bool _current(WidgetRef ref, String owner) =>
    ref.context.mounted &&
    ref.read(homeNewsCurrentOwnerProvider) == owner &&
    ref.read(homeNewsRepositoryProvider).currentUserId == owner;

/// Every home visit can open enabled news. Manual replay remains available
/// after hiding today; only the explicit text action saves that preference.
Future<void> openHomeNews(
  BuildContext context,
  WidgetRef ref,
  HomeNewsItem item, {
  bool automatic = false,
  List<HomeNewsItem>? carouselItems,
  String? deliveryId,
  VoidCallback? onDestinationOpened,
}) async {
  final owner = ref.read(homeNewsCurrentOwnerProvider);
  final coordinator = ref.read(homeNewsPresentationCoordinatorProvider);
  if (owner == null || coordinator.busy || !_current(ref, owner)) return;
  final origin = ModalRoute.of(context);
  coordinator.busy = true;
  // Keep auto-disposed requests alive while the modal route is on top.
  final subscriptions = <ProviderSubscription>[
    ref.listenManual(homeNewsExposureStateProvider, (_, __) {}),
    ref.listenManual(homeNewsCatalogProvider, (_, __) {}),
  ];
  try {
    var items = carouselItems ?? [item];
    if (!automatic) {
      ref.invalidate(homeNewsExposureStateProvider);
      final current = await ref.read(homeNewsCatalogProvider.future);
      if (!_current(ref, owner) || origin?.isCurrent == false) return;
      final available = current
          .where((value) => value.id == item.id)
          .firstOrNull;
      if (available == null) {
        context.showErrorSnack('이미 참여했거나 종료된 소식이에요.');
        return;
      }
      item = available;
      items = current;
    }
    final presentationState = await ref.read(
      homeNewsExposureStateProvider.future,
    );
    if (presentationState == null ||
        !_current(ref, owner) ||
        origin?.isCurrent == false)
      return;
    final elapsed = Stopwatch()..start();
    var lastViewed = item;
    var tracking = Future<void>.value();
    final viewed = <String>{};
    final repository = ref.read(homeNewsRepositoryProvider);
    final selected = await showHomeNewsCarousel(
      context,
      items,
      initialIndex: items.indexWhere((value) => value.id == item.id),
      onItemViewed: (visible) {
        if (!_current(ref, owner)) return;
        lastViewed = visible;
        if (automatic && deliveryId != null && viewed.add(visible.id)) {
          // Preserve swipe order so a fast tap cannot reach interaction before
          // the server has stored that page's actual impression.
          tracking = tracking
              .then((_) async {
                if (!_current(ref, owner)) return;
                await repository.recordDeliveryView(deliveryId, visible.id);
              })
              .catchError((Object _) {});
        }
      },
      contentWrapper: (child) => _NewsOwnerBoundary(owner: owner, child: child),
    );
    if (!_current(ref, owner) || origin?.isCurrent == false) return;
    if (selected?.hideForToday == true) {
      final store = ref.read(homeNewsTodayStoreProvider);
      final until = homeNewsNextKoreanMidnight(
        presentationState.serverNow.add(elapsed.elapsed),
      );
      // Remember synchronously before releasing the modal's coordinator.
      store.rememberUntil(owner, until);
      ref.invalidate(homeNewsTodayHiddenProvider);
      final localSave = store
          .persistUntil(owner, until)
          .timeout(const Duration(seconds: 2))
          .catchError((Object _) {});
      unawaited(
        repository
            .hideForToday()
            .then((confirmed) async {
              if (!_current(ref, owner)) return;
              final confirmedUntil = confirmed.hiddenUntil;
              if (confirmed.hiddenForToday && confirmedUntil != null) {
                store.rememberUntil(owner, confirmedUntil);
                await store.persistUntil(owner, confirmedUntil);
              }
              if (_current(ref, owner)) {
                ref.invalidate(homeNewsExposureStateProvider);
                ref.invalidate(homeNewsTodayHiddenProvider);
              }
            })
            .catchError((Object _) {}),
      );
      await localSave;
      return;
    }
    item = selected?.item ?? lastViewed;
    final interactionItem = item;
    final interaction = selected?.action == true
        ? HomeNewsInteraction.click
        : HomeNewsInteraction.dismiss;
    // Analytics preserves view-before-click ordering without delaying closing
    // or navigating on a slow network.
    unawaited(
      tracking
          .then((_) async {
            if (!_current(ref, owner)) return;
            await repository.recordInteraction(interactionItem.id, interaction);
          })
          .catchError((Object _) {}),
    );
    if (selected?.action != true) return;
    // Recheck remote switches and dates at the point of navigation too.
    ref.invalidate(homeNewsExposureStateProvider);
    final fresh = await ref.read(homeNewsCatalogProvider.future);
    if (!_current(ref, owner) || origin?.isCurrent == false) return;
    final available = fresh.where((value) => value.id == item.id).firstOrNull;
    if (available == null) {
      context.showErrorSnack('종료된 소식이에요. 다른 소식을 확인해 주세요.');
      return;
    }
    item = available;
    Future<void> pushDestination(Route<void> route) async {
      onDestinationOpened?.call();
      await Navigator.of(context).push<void>(route);
    }

    switch (item.kind) {
      case HomeNewsKind.monthlyDesign:
        await pushDestination(
          snapFitRoute(page: const MonthlyDesignsScreen()),
        );
      case HomeNewsKind.attendance:
        await pushDestination(
          snapFitRoute(page: const AttendanceScreen(), settings: const WebAppRouteSettings(WebAppLocation.attendance)),
        );
      case HomeNewsKind.referral:
        await pushDestination(
          snapFitRoute(page: const ReferralScreen(), settings: const WebAppRouteSettings(WebAppLocation.referral)),
        );
      case HomeNewsKind.monthReview:
        // Re-read the month before previewing: another device might already
        // have made its album. Existing IDs preserve duplicate-import guards.
        final journal = await ref.refresh(
          momentsMonthProvider(item.month).future,
        );
        if (!_current(ref, owner) || origin?.isCurrent == false) return;
        if (journal.records.every((record) => record.photos.isEmpty)) {
          onDestinationOpened?.call();
          await openMoments(context);
          return;
        }
        await pushDestination(
          snapFitRoute(page: MonthlyMomentPreviewScreen(
              month: journal.month,
              records: journal.records,
              today: journal.today,
              existingAlbumId: journal.monthlyAlbumId,
              importedPhotoIds: journal.monthlyAlbumPhotoIds,
              onAlbumCreated: (album) async {
                if (!_current(ref, owner) || album.userId != owner) return;
                ref.invalidate(homeViewModelProvider);
                await HomeAlbumActions.onEditSelected(
                  context,
                  ref,
                  album,
                  startAtFirstIncompletePage: true,
                );
              },
            )),
        );
    }
  } catch (_) {
    if (_current(ref, owner) && origin?.isCurrent != false) {
      context.showErrorSnack('소식을 열지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  } finally {
    for (final subscription in subscriptions) subscription.close();
    coordinator.busy = false;
    if (ref.context.mounted &&
        ref.read(homeNewsCurrentOwnerProvider) == owner) {
      ref.invalidate(homeNewsExposureStateProvider);
    }
  }
}

/// Private month photographs disappear in the very frame an account changes.
/// Removing this known route leaves unrelated routes above it undisturbed.
class _NewsOwnerBoundary extends ConsumerStatefulWidget {
  const _NewsOwnerBoundary({required this.owner, required this.child});
  final String owner;
  final Widget child;
  @override
  ConsumerState<_NewsOwnerBoundary> createState() => _NewsOwnerBoundaryState();
}

class _NewsOwnerBoundaryState extends ConsumerState<_NewsOwnerBoundary> {
  bool _removing = false;
  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(homeNewsCurrentOwnerProvider);
    if (owner == widget.owner) return widget.child;
    if (!_removing) {
      _removing = true;
      final route = ModalRoute.of(context);
      final navigator = Navigator.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && route?.isActive == true) {
          navigator.removeRoute(route!);
        }
      });
    }
    return const SizedBox.shrink();
  }
}
