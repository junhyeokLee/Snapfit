import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../../../core/templates/catalog_preview_assets.g.dart';
import '../../../album/data/album_creation_draft_store.dart';
import '../../../album/data/bundled_creation_templates.dart';
import '../../../album/presentation/viewmodels/home_view_model.dart';
import '../../../attendance/domain/attendance_status.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../moments/domain/moment_record.dart';
import '../../../moments/presentation/providers/moments_providers.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../profile/domain/order_visibility_owner.dart';
import '../../../referral/domain/referral_status.dart';
import '../../../referral/presentation/providers/referral_providers.dart';
import '../../../store/domain/entities/premium_template.dart';
import '../../data/home_news_repository.dart';
import '../../domain/home_news.dart';

final homeNewsRepositoryProvider = Provider<HomeNewsRepository>((ref) {
  final repository = SupabaseHomeNewsRepository(
    ref.watch(supabaseClientProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final homeNewsAuthSessionProvider = StreamProvider<String?>((ref) async* {
  final repository = ref.watch(homeNewsRepositoryProvider);
  yield repository.currentUserId;
  yield* repository.authChanges;
});

/// A retained profile cannot authorize a notice or a private photograph.
final homeNewsCurrentOwnerProvider = Provider<String?>((ref) {
  final profile = ref.watch(authViewModelProvider);
  final visible = ref.watch(visibleOrderOwnerProvider);
  if (profile.isLoading || profile.hasError || visible == null) return null;
  try {
    final observed = ref.watch(homeNewsAuthSessionProvider);
    final repository = ref.watch(homeNewsRepositoryProvider);
    return observed.asData?.value == visible &&
            repository.currentUserId == visible
        ? visible
        : null;
  } catch (_) {
    // No connected SDK means there is no personal delivery capability.
    return null;
  }
});

final homeNewsExposureStateProvider =
    FutureProvider.autoDispose<HomeNewsExposureState?>((ref) async {
      final owner = ref.watch(homeNewsCurrentOwnerProvider);
      if (owner == null) return null;
      final repository = ref.watch(homeNewsRepositoryProvider);
      final state = await repository.getExposureState();
      return ref.mounted &&
              ref.read(homeNewsCurrentOwnerProvider) == owner &&
              repository.currentUserId == owner
          ? state
          : null;
    });

/// Published artwork only. A catalog outage never becomes an invented offer.
final homeNewsDesignsProvider =
    FutureProvider.autoDispose<List<PremiumTemplate>>((ref) async {
      final state = await ref.watch(homeNewsExposureStateProvider.future);
      if (state == null || !ref.mounted) return const [];
      final products = await ref.watch(pointShopCatalogProvider.future);
      if (!ref.mounted) return const [];
      final active = {
        for (final product in products)
          if (product.isActive &&
              product.pointPrice != null &&
              product.pointPrice! >= 0)
            product.productKey,
      };
      final available = publishedCreationTemplates
          .where(
            (template) =>
                active.contains(pointShopTemplateKey(template)) &&
                catalogPreviewAssets.containsKey('template:${template.id}'),
          )
          .toList(growable: false);
      if (available.isEmpty) return const [];
      // The first edition is curated explicitly; later months rotate the
      // published selection without labelling existing designs as new releases.
      if (state.serverDate.year == 2026 && state.serverDate.month == 10) {
        final curated = [
          for (final id in [-9471, -9441, -9461])
            ...available.where((template) => template.id == id),
        ];
        if (curated.isNotEmpty) return List.unmodifiable(curated);
      }
      final start = (state.serverDate.year * 12 + state.serverDate.month) * 3;
      return List.unmodifiable([
        for (var index = 0; index < 3 && index < available.length; index++)
          available[(start + index) % available.length],
      ]);
    });

bool isHomeNewsMonthEnd(DateTime date) => !date.isBefore(
  DateTime.utc(date.year, date.month + 1).subtract(const Duration(days: 7)),
);

Future<T?> _optional<T>(Future<T> request) async {
  try {
    return await request.timeout(const Duration(seconds: 10));
  } catch (_) {
    return null;
  }
}

/// Enabled stories remain browsable together, even after a benefit is used.
/// Automatic delivery separately requires an eligible, unseen starting story.
final homeNewsCatalogProvider = FutureProvider.autoDispose<List<HomeNewsItem>>((
  ref,
) async {
  final owner = ref.watch(homeNewsCurrentOwnerProvider);
  if (owner == null) return const [];
  final state = await ref.watch(homeNewsExposureStateProvider.future);
  if (state == null || !ref.mounted) return const [];
  bool active(HomeNewsKind kind) =>
      state.campaignFor(kind)?.isActiveAt(state.serverNow) == true;
  final month = DateTime.utc(state.serverDate.year, state.serverDate.month);
  final monthEnd = isHomeNewsMonthEnd(state.serverDate);
  final (designs, attendanceResult, referral, journalResult) = await (
    active(HomeNewsKind.monthlyDesign)
        ? _optional(ref.watch(homeNewsDesignsProvider.future))
        : Future<List<PremiumTemplate>?>.value(),
    active(HomeNewsKind.attendance)
        ? _optional(ref.watch(attendanceStatusProvider.future))
        : Future<AttendanceStatus?>.value(),
    active(HomeNewsKind.referral)
        ? _optional(ref.watch(referralStatusProvider.future))
        : Future<ReferralStatus?>.value(),
    active(HomeNewsKind.monthReview) && monthEnd
        ? _optional(ref.watch(momentsMonthProvider(month).future))
        : Future<MomentJournal?>.value(),
  ).wait;
  if (!ref.mounted || ref.read(homeNewsCurrentOwnerProvider) != owner) {
    return const [];
  }
  // A late day/month response must not advertise a stale reward or photograph.
  final attendance = attendanceResult?.serverDate == state.serverDate
      ? attendanceResult
      : null;
  final journal = journalResult?.month == month ? journalResult : null;
  final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
  final photos =
      journal?.records.expand((record) => record.photos).toList() ??
      const <MomentPhoto>[];
  final reviewReady = photos.isNotEmpty;
  final checked = attendance?.checkedInToday == true;
  final attendanceReady = attendance != null && !checked;
  final referralReady = referral != null && referral.remaining > 0;
  final items = <HomeNewsItem>[
    if (active(HomeNewsKind.monthReview))
      HomeNewsItem(
        id: 'month-review:$monthKey',
        kind: HomeNewsKind.monthReview,
        title: reviewReady
            ? '${month.month}월의 순간을,\n나의 한 권으로'
            : '한 장씩 남기면,\n한 달이 모여요',
        subtitle: reviewReady
            ? '이번 달 남긴 사진 ${photos.length}장을 앨범으로 모아보세요.'
            : '오늘의 사진과 짧은 기록으로 이번 달의 앨범을 시작해보세요.',
        actionLabel: reviewReady
            ? (journal?.monthlyAlbumId == null ? '이번 달 앨범 만들기' : '이번 달 앨범 보기')
            : '나의 기록 시작하기',
        month: month,
        autoEligible:
            monthEnd && reviewReady && journal?.monthlyAlbumId == null,
        covers: [
          for (final photo in photos.take(3))
            HomeNewsCover(
              url: photo.url.isNotEmpty ? photo.url : photo.storageUri,
              ratio: photo.width > 0 && photo.height > 0
                  ? photo.width / photo.height
                  : 1,
            ),
        ],
      ),
    if (active(HomeNewsKind.monthlyDesign) && designs?.isNotEmpty == true)
      HomeNewsItem(
        id: 'monthly-design:$monthKey',
        kind: HomeNewsKind.monthlyDesign,
        title: '사진을 담고 싶은,\n${month.month}월의 디자인',
        subtitle: '이번 달의 순간에 어울리는 앨범을 만나보세요.',
        actionLabel: '이달의 디자인 보기',
        month: month,
        covers: [
          for (final template in designs!)
            HomeNewsCover(
              url: 'asset:${catalogPreviewAssets['template:${template.id}']}',
              ratio: 1,
            ),
        ],
      ),
    if (active(HomeNewsKind.attendance))
      HomeNewsItem(
        id: 'attendance-benefit:v1',
        kind: HomeNewsKind.attendance,
        title: checked ? '오늘도 남긴 발걸음,\n출석을 이어가요' : '오늘의 출석에,\n작은 포인트 선물',
        subtitle: checked
            ? '오늘의 출석을 완료했어요. 내 출석 기록을 확인해보세요.'
            : attendanceReady
            ? '오늘 출석하면 ${attendance.todayReward}P를 받을 수 있어요.'
            : '출석 화면에서 오늘의 혜택과 내 기록을 확인해보세요.',
        actionLabel: checked ? '출석 기록 보기' : '출석체크 하러 가기',
        month: month,
        autoEligible: !state.hasAttendanceEver && attendanceReady,
        rewardPoints: attendanceReady ? attendance.todayReward : null,
      ),
    if (active(HomeNewsKind.referral))
      HomeNewsItem(
        id: 'referral-benefit:v1',
        kind: HomeNewsKind.referral,
        title: '좋아하는 사람과,\n스냅핏을 나눠요',
        subtitle: referralReady
            ? '친구가 내 초대 코드를 등록하면 ${referral.inviterPoints}P를 받아요.'
            : referral != null && referral.remaining == 0
            ? '이번 달 초대 보상을 모두 받았어요. 내 초대 현황을 확인해보세요.'
            : '내 초대 코드와 친구 초대 혜택을 확인해보세요.',
        actionLabel: '친구 초대 혜택 보기',
        month: month,
        autoEligible:
            !state.hasReferralReward &&
            referralReady &&
            referral.invitedCount == 0,
        rewardPoints: referralReady ? referral.inviterPoints : null,
      ),
  ];
  items.sort((a, b) {
    final order = (state.campaignFor(a.kind)?.sortOrder ?? a.kind.index)
        .compareTo(state.campaignFor(b.kind)?.sortOrder ?? b.kind.index);
    return order != 0 ? order : a.kind.name.compareTo(b.kind.name);
  });
  return List.unmodifiable(items);
});

/// A pending local recovery takes priority over an optional announcement.
/// Loading the library also finishes before any automatic notice is considered.
final homeNewsRecoveryBlockProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final owner = ref.watch(homeNewsCurrentOwnerProvider);
  if (owner == null) return true;
  try {
    final (creation, moments, _) = await (
      ref.watch(albumCreationDraftProvider.future),
      ref.watch(momentDraftSummariesForOwnerProvider(owner).future),
      ref.watch(homeViewModelProvider.future),
    ).wait;
    return !ref.mounted || creation != null || moments.isNotEmpty;
  } catch (_) {
    return true;
  }
});

class HomeNewsSessionGuard {
  final _attempted = <String>{};
  bool begin(String owner) => _attempted.add(owner);
}

final homeNewsSessionGuardProvider = Provider((_) => HomeNewsSessionGuard());
final homeNewsReadyDelayProvider = Provider(
  (_) => const Duration(milliseconds: 900),
);

class HomeNewsPresentationCoordinator {
  bool busy = false;
}

final homeNewsPresentationCoordinatorProvider = Provider(
  (_) => HomeNewsPresentationCoordinator(),
);
