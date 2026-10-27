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
import '../../moments/presentation/views/monthly_moment_preview_screen.dart';
import '../../referral/presentation/views/referral_screen.dart';
import '../domain/home_news.dart';
import 'providers/home_news_providers.dart';
import 'views/monthly_designs_screen.dart';
import 'widgets/home_news_sheet.dart';

bool _current(WidgetRef ref, String owner) =>
    ref.context.mounted &&
    ref.read(homeNewsCurrentOwnerProvider) == owner &&
    ref.read(homeNewsRepositoryProvider).currentUserId == owner;

/// Manual replay does not claim an automatic slot. Automatic callers reserve
/// the server slot immediately before invoking this shared presentation path.
Future<void> openHomeNews(
  BuildContext context,
  WidgetRef ref,
  HomeNewsItem item, {
  bool automatic = false,
  List<HomeNewsItem>? carouselItems,
  String? deliveryId,
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
    switch (item.kind) {
      case HomeNewsKind.monthlyDesign:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const MonthlyDesignsScreen()),
        );
      case HomeNewsKind.attendance:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            settings: const WebAppRouteSettings(WebAppLocation.attendance),
            builder: (_) => const AttendanceScreen(),
          ),
        );
      case HomeNewsKind.referral:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            settings: const WebAppRouteSettings(WebAppLocation.referral),
            builder: (_) => const ReferralScreen(),
          ),
        );
      case HomeNewsKind.monthReview:
        // Re-read the month before previewing: another device might already
        // have made its album. Existing IDs preserve duplicate-import guards.
        final journal = await ref.refresh(
          momentsMonthProvider(item.month).future,
        );
        if (!_current(ref, owner) || origin?.isCurrent == false) return;
        if (journal.records.every((record) => record.photos.isEmpty)) {
          await openMoments(context);
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => MonthlyMomentPreviewScreen(
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
            ),
          ),
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
