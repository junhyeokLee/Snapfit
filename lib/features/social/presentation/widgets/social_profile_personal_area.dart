import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../album/domain/entities/album.dart';
import '../../../album/presentation/viewmodels/home_view_model.dart';
import '../../../album/presentation/views/album_category_screen.dart';
import '../../../attendance/presentation/widgets/attendance_entry_card.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../billing/domain/entities/storage_quota.dart';
import '../../../profile/domain/order_visibility_owner.dart';
import '../../../profile/presentation/views/billing_management_screen.dart';
import '../../../profile/presentation/widgets/my_point_balance_card.dart';
import '../../../referral/presentation/widgets/referral_entry_card.dart';
import '../../../store/presentation/views/material_catalog_screen.dart';
import '../providers/social_providers.dart';
import '../views/social_saved_works_screen.dart';
import 'my_moment_archive.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// Personal records remain usable without creating a public profile first.
/// Verified owners see their private archive before account controls. The
/// supplied public gallery is only the safe fallback for a mismatched identity.
class SocialProfilePersonalArea extends ConsumerStatefulWidget {
  const SocialProfilePersonalArea({
    super.key,
    required this.ownerId,
    required this.publicHeader,
    this.gallery,
    this.onOpenPublicProfile,
  });

  final String ownerId;
  final Widget publicHeader;
  final Widget? gallery;
  final VoidCallback? onOpenPublicProfile;

  @override
  ConsumerState<SocialProfilePersonalArea> createState() =>
      _SocialProfilePersonalAreaState();
}

class _SocialProfilePersonalAreaState
    extends ConsumerState<SocialProfilePersonalArea> {
  int _revision = 0;
  int? _openingAlbumsRevision;

  bool _current(int revision) =>
      mounted &&
      revision == _revision &&
      ref.read(socialCurrentUserIdProvider) == widget.ownerId &&
      ref.read(authViewModelProvider).asData?.value?.id == widget.ownerId &&
      ref.read(visibleOrderOwnerProvider) == widget.ownerId;

  void _push(Widget page, int revision, [WebAppLocation? location]) {
    if (!_current(revision)) return;
    Navigator.of(context).push<void>(
      snapFitRoute(
        page: page,
        settings: kIsWeb && location != null
            ? WebAppRouteSettings(location)
            : null,
      ),
    );
  }

  Future<void> _points(int revision, {bool history = false}) async {
    if (!_current(revision)) return;
    await Navigator.of(context).push<void>(
      snapFitRoute(
        page: BillingManagementScreen(initialPointsTabIndex: history ? 1 : 0),
      ),
    );
    if (!_current(revision)) return;
    ref.invalidate(myPointBalanceProvider);
    ref.invalidate(myPointLedgerProvider);
    ref.invalidate(pointLedgerHistoryProvider);
  }

  Future<void> _albums(int revision, {bool shared = false}) async {
    if (!_current(revision) || _openingAlbumsRevision == revision) return;
    _openingAlbumsRevision = revision;
    try {
      // 실패한 목록을 다시 누르면 이전 오류를 반복하지 않고 새로 요청한다.
      final albumsState = ref.read(homeViewModelProvider);
      if (albumsState.hasError && !albumsState.isLoading) {
        ref.invalidate(homeViewModelProvider);
      }
      final albums = await ref
          .read(homeViewModelProvider.future)
          .timeout(const Duration(seconds: 20));
      if (!_current(revision)) return;
      final visible = shared
          ? albums
                .where(
                  (album) =>
                      album.userId.trim().isNotEmpty &&
                      album.userId != widget.ownerId,
                )
                .toList()
          : albums;
      _push(
        AlbumCategoryScreen(
          category: shared ? AlbumCategory.shared : AlbumCategory.recent,
          initialAlbums: visible,
          currentUserId: widget.ownerId,
        ),
        revision,
      );
    } catch (_) {
      if (!_current(revision)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('앨범 목록을 불러오지 못했어요. 다시 시도해 주세요.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          action: SnackBarAction(
            label: '다시 시도',
            onPressed: () {
              if (!_current(revision)) return;
              ref.invalidate(homeViewModelProvider);
              _albums(revision, shared: shared);
            },
          ),
        ),
      );
    } finally {
      if (_openingAlbumsRevision == revision) _openingAlbumsRevision = null;
    }
  }

  @override
  void didUpdateWidget(covariant SocialProfilePersonalArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) _revision++;
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(socialCurrentUserIdProvider);
    final account = ref.watch(authViewModelProvider).asData?.value;
    final visibleOwner = ref.watch(visibleOrderOwnerProvider);
    ref.listen<String?>(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next) _revision++;
    });
    ref.listen<String?>(
      authViewModelProvider.select((auth) => auth.asData?.value?.id),
      (previous, next) {
        if (previous != next) _revision++;
      },
    );
    ref.listen<String?>(visibleOrderOwnerProvider, (previous, next) {
      if (previous != next) _revision++;
    });
    final revision = _revision;
    final private =
        actor == widget.ownerId &&
        account?.id == widget.ownerId &&
        visibleOwner == widget.ownerId;
    if (!private) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.publicHeader,
          if (widget.gallery != null) ...[
            const SizedBox(height: 28),
            widget.gallery!,
          ],
        ],
      );
    }
    final albums = ref.watch(homeViewModelProvider);
    // 갱신 중 유지된 데이터는 사용하되, 확인 전·실패를 빈 앨범으로 표시하지 않는다.
    final items = albums.hasValue ? albums.requireValue : const <Album>[];
    final shared = items
        .where(
          (album) =>
              album.userId.trim().isNotEmpty && album.userId != widget.ownerId,
        )
        .toList();
    final albumsFailed = albums.hasError && !albums.isLoading;
    // 계정 교체 시 보안을 위해 비운 임시 []도 로딩·오류에 남을 수 있다.
    final sharedSummary = albumsFailed
        ? '확인 실패 · 다시 시도'
        : !albums.hasValue || (albums.isLoading && items.isEmpty)
        ? '앨범을 확인하고 있어요'
        : '${shared.length}개의 함께 만든 앨범';
    final quota = ref.watch(myStorageQuotaProvider);
    final wallet = MyPointBalanceCard(
      compact: true,
      ownerId: widget.ownerId,
      onCharge: () => _points(revision),
      onHistory: () => _points(revision, history: true),
    );
    return Column(
      key: ValueKey('social-profile-private-${widget.ownerId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.publicHeader,
        const SizedBox(height: 22),
        MyMomentArchive(
          key: ValueKey('personal-moment-archive-${widget.ownerId}'),
          ownerId: widget.ownerId,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, bounds) {
            final public = widget.onOpenPublicProfile == null
                ? null
                : TextButton.icon(
                    key: const ValueKey('profile-open-public'),
                    onPressed: widget.onOpenPublicProfile,
                    icon: const ExperienceIcon('Globe', size: 17),
                    label: const Text('공개 프로필'),
                  );
            if (public == null) return wallet;
            if (MediaQuery.textScalerOf(context).scale(1) > 1.4) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  wallet,
                  Align(alignment: Alignment.centerLeft, child: public),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: wallet),
                const SizedBox(width: 8),
                public,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, bounds) {
            final stack = MediaQuery.textScalerOf(context).scale(1) > 1.4;
            final width = stack ? bounds.maxWidth : (bounds.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in [
                  (
                    'albums',
                    '내 앨범',
                    Icons.auto_stories_outlined,
                    () => _albums(revision),
                  ),
                  (
                    'library',
                    '내 보관함',
                    Icons.collections_bookmark_outlined,
                    () => _push(
                      const MaterialCatalogScreen(library: true),
                      revision,
                      WebAppLocation.library,
                    ),
                  ),
                ])
                  SizedBox(
                    width: width,
                    child: OutlinedButton(
                      key: ValueKey('profile-shortcut-${entry.$1}'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        side: BorderSide(
                          color: ExperienceFormStyle.line(context),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: entry.$4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(entry.$3, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              entry.$2,
                              textAlign: TextAlign.center,
                              style: ExperienceFormStyle.text(
                                context,
                                13,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        Divider(color: ExperienceFormStyle.line(context)),
        const SizedBox(height: 20),
        Text(
          '나만 보는 활동',
          style: ExperienceFormStyle.text(context, 18, weight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ListTile(
          key: const ValueKey('profile-shared-albums'),
          contentPadding: EdgeInsets.zero,
          leading: const ExperienceIcon('Users2'),
          title: const Text('공유된 앨범'),
          subtitle: Text(sharedSummary),
          trailing: Icon(albumsFailed ? Icons.refresh : Icons.chevron_right),
          onTap: () => _albums(revision, shared: true),
        ),
        _storage(quota, revision),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, bounds) {
            final width = bounds.maxWidth >= 760
                ? (bounds.maxWidth - 20) / 2
                : bounds.maxWidth;
            return Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                SizedBox(width: width, child: const AttendanceEntryCard()),
                SizedBox(width: width, child: const ReferralEntryCard()),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const ExperienceIcon('Bookmark'),
          title: const Text('저장한 기록·앨범'),
          trailing: const ExperienceIcon('ChevronRight'),
          onTap: () => _push(const SocialSavedWorksScreen(), revision),
        ),
      ],
    );
  }

  Widget _storage(
    AsyncValue<StorageQuotaStatus> quota,
    int revision,
  ) => ExpansionTile(
    key: const PageStorageKey('profile-storage'),
    tilePadding: EdgeInsets.zero,
    leading: const Icon(Icons.cloud_outlined),
    title: const Text('내 저장 공간'),
    childrenPadding: const EdgeInsets.only(bottom: 12),
    children: [
      quota.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => TextButton(
          onPressed: () {
            if (_current(revision)) ref.invalidate(myStorageQuotaProvider);
          },
          child: const Text('저장 공간 다시 확인'),
        ),
        data: (value) {
          if (value.userId != widget.ownerId) {
            return TextButton(
              onPressed: () {
                if (_current(revision)) ref.invalidate(myStorageQuotaProvider);
              },
              child: const Text('저장 공간 다시 확인'),
            );
          }
          String gigabytes(int bytes) =>
              (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${gigabytes(value.usedBytes)} GB / ${gigabytes(value.hardLimitBytes)} GB 사용',
                style: ExperienceFormStyle.text(context, 13, secondary: true),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: value.hardLimitBytes > 0
                    ? (value.usedBytes / value.hardLimitBytes).clamp(0.0, 1.0)
                    : 0,
              ),
            ],
          );
        },
      ),
    ],
  );
}
