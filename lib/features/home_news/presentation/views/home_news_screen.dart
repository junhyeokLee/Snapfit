import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../../shared/web/web_design.dart' show WebSection;
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../profile/presentation/widgets/customer_web_page.dart';
import '../../domain/home_news.dart';
import '../home_news_navigation.dart';
import '../providers/home_news_providers.dart';

/// A manual catalogue: opening it never consumes an automatic home impression.
class HomeNewsScreen extends ConsumerWidget {
  const HomeNewsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(homeNewsExposureStateProvider);
    ref.invalidate(homeNewsCatalogProvider);
    try {
      await ref.read(homeNewsCatalogProvider.future);
    } catch (_) {
      // The page's AsyncValue displays the recoverable loading error.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(homeNewsCatalogProvider);
    Widget body() => catalog.when(
      skipLoadingOnRefresh: false,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 72),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _NewsEmptyState(
        icon: Icons.refresh_rounded,
        title: '새 소식을 불러오지 못했어요',
        action: TextButton.icon(
          onPressed: () => _refresh(ref),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('다시 불러오기'),
        ),
      ),
      data: (items) => items.isEmpty
          ? const _NewsEmptyState(
              icon: Icons.auto_awesome_outlined,
              title: '새로운 소식을 준비하고 있어요',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const SizedBox(height: 16),
                  _NewsCard(
                    key: ValueKey(items[index].id),
                    item: items[index],
                    onOpen: () async {
                      await openHomeNews(context, ref, items[index]);
                    },
                  ),
                ],
              ],
            ),
    );

    if (kIsWeb) {
      return CustomerWebPage(
        title: '혜택·새 소식',
        section: WebSection.albums,
        actions: [
          OutlinedButton.icon(
            onPressed: catalog.isLoading ? null : () => _refresh(ref),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('새로고침'),
          ),
        ],
        scrollBody: true,
        child: body(),
      );
    }

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: ExperienceHeader(
        title: '혜택·새 소식',
        themeAware: true,
        showNotifications: false,
        actions: [
          IconButton(
            tooltip: '새 소식 새로고침',
            onPressed: catalog.isLoading ? null : () => _refresh(ref),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            key: const PageStorageKey('home-news-list'),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: body(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsCard extends StatefulWidget {
  const _NewsCard({super.key, required this.item, required this.onOpen});

  final HomeNewsItem item;
  final Future<void> Function() onOpen;

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.onOpen();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final label = switch (item.kind) {
      HomeNewsKind.monthlyDesign => '이달의 디자인',
      HomeNewsKind.attendance => '출석 혜택',
      HomeNewsKind.referral => '친구 초대',
      HomeNewsKind.monthReview => '${item.month.month}월 돌아보기',
    };
    Widget information() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ExperienceFormStyle.text(
            context,
            12,
            weight: FontWeight.w600,
            color: ExperienceFormStyle.selectionInk(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.title,
          style: ExperienceFormStyle.text(
            context,
            20,
            weight: FontWeight.w700,
          ).copyWith(height: 1.4, letterSpacing: -.5),
        ),
        const SizedBox(height: 8),
        Text(
          item.subtitle,
          style: ExperienceFormStyle.text(
            context,
            14,
            secondary: true,
          ).copyWith(height: 1.6),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                item.actionLabel,
                style: ExperienceFormStyle.text(
                  context,
                  14,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_opening)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: ExperienceFormStyle.ink(context),
              ),
          ],
        ),
      ],
    );

    return Material(
      key: ValueKey('home-news-list-${item.id}'),
      color: ExperienceFormStyle.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: ExperienceFormStyle.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: _opening ? null : _open,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final sideBySide =
                    bounds.maxWidth >= 480 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 24;
                final preview = _NewsPreview(item: item);
                if (sideBySide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 160, child: preview),
                      const SizedBox(width: 28),
                      Expanded(child: information()),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    preview,
                    const SizedBox(height: 20),
                    information(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsPreview extends StatelessWidget {
  const _NewsPreview({required this.item});

  final HomeNewsItem item;

  @override
  Widget build(BuildContext context) {
    if (item.covers.isNotEmpty) {
      return ExcludeSemantics(
        child: SizedBox(
          height: 128,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final cover in item.covers.take(3)) ...[
                if (cover != item.covers.first) const SizedBox(width: 10),
                Flexible(
                  child: AspectRatio(
                    aspectRatio: cover.ratio.isFinite && cover.ratio > 0
                        ? cover.ratio
                        : 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SnapfitImage(
                        urlOrGs: cover.url,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final icon = switch (item.kind) {
      HomeNewsKind.monthlyDesign => Icons.auto_stories_outlined,
      HomeNewsKind.attendance => Icons.event_available_rounded,
      HomeNewsKind.referral => Icons.people_outline_rounded,
      HomeNewsKind.monthReview => Icons.photo_library_outlined,
    };
    return ExcludeSemantics(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: ExperienceFormStyle.selection(context),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            icon,
            size: 32,
            color: ExperienceFormStyle.selectionInk(context),
          ),
        ),
      ),
    );
  }
}

class _NewsEmptyState extends StatelessWidget {
  const _NewsEmptyState({required this.icon, required this.title, this.action});

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 56),
    child: Column(
      children: [
        Icon(icon, size: 36, color: ExperienceFormStyle.muted(context)),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: ExperienceFormStyle.text(context, 16, weight: FontWeight.w600),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}
