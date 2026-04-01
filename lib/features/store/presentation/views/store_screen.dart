import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/layer_export_mapper.dart';
import '../../data/api/template_provider.dart';
import '../../domain/entities/premium_template.dart';
import '../providers/store_filter_provider.dart';
import '../widgets/template_page_renderer.dart';
import 'template_detail_screen.dart';

String _storeCoverPreviewUrl(PremiumTemplate template) {
  final cover = template.coverImageUrl.trim();
  if (cover.isNotEmpty) return cover;
  final previews = template.previewImages
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
  if (previews.isNotEmpty) return previews.first;
  return '';
}

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  static const List<String> _categories = ['전체', '여행', '가족', '연인', '졸업', '레트로'];
  static const int _newBadgeCount = 1;
  DateTime? _lastAutoRefreshRequestAt;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _allTemplatesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 520;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(storeTemplateFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(storeTemplateFeedProvider);
    final filterState = ref.watch(storeFilterProvider);
    final filterNotifier = ref.read(storeFilterProvider.notifier);

    // 화면이 다시 노출될 때 서버 최신 템플릿으로 자연스럽게 동기화한다.
    if (!feedState.isInitialLoading && !feedState.isLoadingMore) {
      final now = DateTime.now();
      final shouldThrottle =
          _lastAutoRefreshRequestAt != null &&
          now.difference(_lastAutoRefreshRequestAt!) <
              const Duration(seconds: 10);
      if (!shouldThrottle) {
        final isStale =
            feedState.lastSyncedAt == null ||
            now.difference(feedState.lastSyncedAt!) >=
                const Duration(seconds: 45);
        if (isStale) {
          _lastAutoRefreshRequestAt = now;
          Future.microtask(() {
            ref.read(storeTemplateFeedProvider.notifier).refreshIfStale();
          });
        }
      }
    }

    if (_searchController.text != filterState.query) {
      _searchController.value = TextEditingValue(
        text: filterState.query,
        selection: TextSelection.collapsed(offset: filterState.query.length),
      );
    }

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      body: SafeArea(
        child: Builder(
          builder: (_) {
            if (feedState.isInitialLoading && feedState.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (feedState.items.isEmpty) {
              return _StoreErrorView(
                onRetry: () =>
                    ref.read(storeTemplateFeedProvider.notifier).refresh(),
              );
            }
            final templates = feedState.items;
            final filtered = _filterTemplates(templates, filterState);
            final latestTopIds = _resolveLatestTopIds(filtered);
            final weeklyBest = _resolveWeeklyBest(filtered, latestTopIds);
            final sorted = _sortTemplates(filtered, filterState);

            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(storeTemplateFeedProvider.notifier).refresh(),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _TopBar(onFilterTap: _openSortFilterSheet),
                        const SizedBox(height: 18),
                        _SearchField(
                          controller: _searchController,
                          onChanged: (value) {
                            final next = value.trim();
                            if (next == filterState.query) return;
                            filterNotifier.setQuery(next);
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 42,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              final selected =
                                  category == filterState.selectedCategory;
                              return _CategoryChip(
                                label: category,
                                selected: selected,
                                onTap: () {
                                  if (selected) return;
                                  filterNotifier.setCategory(category);
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 28),
                        _WeeklyHeader(
                          onMoreTap: weeklyBest.length > 2
                              ? () {
                                  if (filterState.selectedCategory != '전체') {
                                    filterNotifier.setCategory('전체');
                                  }
                                  _scrollToAllTemplates();
                                }
                              : null,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 246,
                          child: weeklyBest.isEmpty
                              ? const _EmptyState(message: '추천 템플릿을 준비 중입니다.')
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: weeklyBest.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 14),
                                  itemBuilder: (context, index) {
                                    final template = weeklyBest[index];
                                    return _WeeklyTemplateCard(
                                      template: template,
                                      isNew: latestTopIds.contains(template.id),
                                      onTap: () => _openDetail(template),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 28),
                        _AllTemplatesHeader(
                          sortLatest: filterState.sortLatest,
                          onSortChanged: (latest) {
                            filterNotifier.setSortLatest(latest);
                          },
                        ),
                        const SizedBox(height: 14),
                      ]),
                    ),
                  ),
                  SliverPadding(
                    key: _allTemplatesKey,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: sorted.isEmpty
                        ? const SliverToBoxAdapter(
                            child: _EmptyState(message: '조건에 맞는 템플릿이 없습니다.'),
                          )
                        : SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.62,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final template = sorted[index];
                              return _TemplateGridCard(
                                template: template,
                                onTap: () => _openDetail(template),
                              );
                            }, childCount: sorted.length),
                          ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Center(
                        child: feedState.isLoadingMore
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : (feedState.hasNext
                                  ? const SizedBox.shrink()
                                  : const SizedBox.shrink()),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: SnapFitColors.accent,
        elevation: 4,
        onPressed: _openSortFilterSheet,
        child: const Icon(Icons.tune_rounded, color: Colors.white),
      ),
    );
  }

  Set<int> _resolveLatestTopIds(List<PremiumTemplate> templates) {
    final serverNewIds = templates
        .where((template) => template.isNew)
        .map((template) => template.id)
        .toSet();
    if (serverNewIds.isNotEmpty) {
      return serverNewIds;
    }
    final copied = [...templates];
    copied.sort((a, b) => b.id.compareTo(a.id));
    return copied.take(_newBadgeCount).map((e) => e.id).toSet();
  }

  List<PremiumTemplate> _resolveWeeklyBest(
    List<PremiumTemplate> templates,
    Set<int> latestTopIds,
  ) {
    final copied = [...templates];
    copied.sort((a, b) {
      final scoreA = _weeklyScore(a, latestTopIds.contains(a.id));
      final scoreB = _weeklyScore(b, latestTopIds.contains(b.id));
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) return byScore;
      return b.id.compareTo(a.id);
    });
    return copied.take(8).toList();
  }

  int _weeklyScore(PremiumTemplate template, bool isNew) {
    if (template.weeklyScore > 0) {
      return template.weeklyScore + (isNew ? 40 : 0);
    }
    final bestBonus = template.isBest ? 120 : 0;
    final newBonus = isNew ? 60 : 0;
    return (template.likeCount * 10) +
        (template.userCount * 3) +
        bestBonus +
        newBonus;
  }

  List<PremiumTemplate> _sortTemplates(
    List<PremiumTemplate> templates,
    StoreFilterState filterState,
  ) {
    final copied = [...templates];
    copied.sort((a, b) {
      if (filterState.sortLatest) {
        return b.id.compareTo(a.id);
      }
      final byLike = b.likeCount.compareTo(a.likeCount);
      if (byLike != 0) return byLike;
      return b.id.compareTo(a.id);
    });
    return copied;
  }

  List<PremiumTemplate> _filterTemplates(
    List<PremiumTemplate> templates,
    StoreFilterState filterState,
  ) {
    final query = filterState.query.toLowerCase();

    return templates.where((template) {
      final category = _inferCategory(template);
      if (filterState.selectedCategory != '전체' &&
          category != filterState.selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;

      final haystack = [
        template.title,
        template.subTitle,
        template.description,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  String _inferCategory(PremiumTemplate template) {
    final serverCategory = template.category?.trim();
    if (serverCategory != null && serverCategory.isNotEmpty) {
      return serverCategory;
    }
    final content = [
      template.title,
      template.subTitle,
      template.description,
    ].whereType<String>().join(' ').toLowerCase();

    if (_containsAny(content, const [
      '졸업',
      '입학',
      '학교',
      'graduation',
      'school',
    ])) {
      return '졸업';
    }
    if (_containsAny(content, const ['가족', '패밀리', 'family', 'kids'])) {
      return '가족';
    }
    if (_containsAny(content, const [
      '연인',
      '커플',
      '웨딩',
      'love',
      'ring',
      'proposal',
    ])) {
      return '연인';
    }
    if (_containsAny(content, const ['레트로', '빈티지', 'vintage', 'retro'])) {
      return '레트로';
    }
    return '여행';
  }

  bool _containsAny(String source, List<String> needles) {
    for (final needle in needles) {
      if (source.contains(needle)) return true;
    }
    return false;
  }

  void _openDetail(PremiumTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateDetailScreen(template: template),
      ),
    );
  }

  void _scrollToAllTemplates() {
    final targetContext = _allTemplatesKey.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _openSortFilterSheet() {
    final notifier = ref.read(storeFilterProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, sheetRef, _) {
            final sheetState = sheetRef.watch(storeFilterProvider);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '정렬 방식',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: SnapFitColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SheetOptionButton(
                            label: '최신순',
                            selected: sheetState.sortLatest,
                            onTap: () {
                              notifier.setSortLatest(true);
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SheetOptionButton(
                            label: '인기순',
                            selected: !sheetState.sortLatest,
                            onTap: () {
                              notifier.setSortLatest(false);
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '카테고리',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: SnapFitColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final selected =
                            sheetState.selectedCategory == category;
                        return _BottomCategoryChip(
                          label: category,
                          selected: selected,
                          onTap: () {
                            notifier.setCategory(category);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onFilterTap;

  const _TopBar({required this.onFilterTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '템플릿 스토어',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
        ),
        IconButton(
          onPressed: onFilterTap,
          icon: Icon(
            Icons.filter_alt_outlined,
            size: 26,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          color: SnapFitColors.textPrimaryOf(context),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          icon: Icon(
            Icons.search,
            size: 23,
            color: SnapFitColors.textSecondaryOf(context),
          ),
          hintText: '원하는 테마를 검색해보세요',
          hintStyle: TextStyle(
            color: SnapFitColors.textMutedOf(context),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? SnapFitColors.accent
          : SnapFitColors.overlayLightOf(context),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark
                        ? SnapFitColors.textPrimaryOf(context)
                        : SnapFitColors.textSecondaryOf(context)),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyHeader extends StatelessWidget {
  final VoidCallback? onMoreTap;

  const _WeeklyHeader({this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WEEKLY BEST',
          style: TextStyle(
            color: SnapFitColors.accent,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '금주의 인기 템플릿',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
            ),
            TextButton(
              onPressed: onMoreTap,
              style: TextButton.styleFrom(
                foregroundColor: SnapFitColors.textPrimaryOf(context),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '더보기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeeklyTemplateCard extends StatelessWidget {
  final PremiumTemplate template;
  final bool isNew;
  final VoidCallback onTap;

  const _WeeklyTemplateCard({
    required this.template,
    required this.isNew,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.74,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.55,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _StoreTemplateCoverPreview(template: template),
                      if (isNew)
                        const Positioned(
                          top: 12,
                          left: 12,
                          child: _MiniBadge(label: 'NEW'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              template.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              template.subTitle ?? template.description ?? '감성을 담은 템플릿',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: SnapFitColors.textSecondaryOf(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllTemplatesHeader extends StatelessWidget {
  final bool sortLatest;
  final ValueChanged<bool> onSortChanged;

  const _AllTemplatesHeader({
    required this.sortLatest,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '모든 템플릿',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
        ),
        _SortToggle(
          leftLabel: '최신순',
          rightLabel: '인기순',
          leftSelected: sortLatest,
          onLeftTap: () => onSortChanged(true),
          onRightTap: () => onSortChanged(false),
        ),
      ],
    );
  }
}

class _SortToggle extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;

  const _SortToggle({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onLeftTap,
    required this.onRightTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? SnapFitColors.surfaceOf(context)
            : SnapFitColors.overlayLightOf(context),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _SortSegment(
            label: leftLabel,
            selected: leftSelected,
            onTap: onLeftTap,
          ),
          _SortSegment(
            label: rightLabel,
            selected: !leftSelected,
            onTap: onRightTap,
          ),
        ],
      ),
    );
  }
}

class _SortSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? SnapFitColors.backgroundOf(context)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected && isDark
              ? Border.all(color: SnapFitColors.overlayMediumOf(context))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected
                ? SnapFitColors.textPrimaryOf(context)
                : SnapFitColors.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }
}

class _TemplateGridCard extends StatelessWidget {
  final PremiumTemplate template;
  final VoidCallback onTap;

  const _TemplateGridCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = template.isPremium ? 'PREMIUM' : 'FREE';
    final labelColor = template.isPremium
        ? SnapFitColors.accent
        : SnapFitColors.textSecondaryOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _StoreTemplateCoverPreview(template: template),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withValues(alpha: 0.62)
                            : Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${template.likeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            template.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetOptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? SnapFitColors.accent
              : (isDark
                    ? SnapFitColors.surfaceOf(context)
                    : SnapFitColors.overlayLightOf(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark
                      ? SnapFitColors.textPrimaryOf(context)
                      : SnapFitColors.textSecondaryOf(context)),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _BottomCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? SnapFitColors.accent.withOpacity(0.14)
              : SnapFitColors.overlayLightOf(context),
          border: Border.all(
            color: selected
                ? SnapFitColors.accent
                : (isDark
                      ? SnapFitColors.overlayStrongOf(context)
                      : SnapFitColors.overlayMediumOf(context)),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected
                ? SnapFitColors.accent
                : (isDark
                      ? SnapFitColors.textPrimaryOf(context)
                      : SnapFitColors.textSecondaryOf(context)),
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;

  const _MiniBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SnapFitColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StoreErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _StoreErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '템플릿을 불러오지 못했어요.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          color: SnapFitColors.textSecondaryOf(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StoreTemplateCoverPreview extends StatelessWidget {
  final PremiumTemplate template;

  const _StoreTemplateCoverPreview({required this.template});

  @override
  Widget build(BuildContext context) {
    final parsed = _parseFirstPage(template);
    if (parsed != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final targetAspect = parsed.$2;
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          final drawWidth = math.min(maxWidth, maxHeight * targetAspect);
          final drawHeight = drawWidth / targetAspect;
          return Container(
            color: SnapFitColors.overlayLightOf(context),
            alignment: Alignment.center,
            child: SizedBox(
              width: drawWidth,
              height: drawHeight,
              child: TemplatePageRenderer(
                layers: parsed.$1,
                width: drawWidth,
                height: drawHeight,
                designCanvasSize: parsed.$3,
              ),
            ),
          );
        },
      );
    }
    return _NetworkImage(
      url: _storeCoverPreviewUrl(template),
      variant: ImageVariant.thumb,
    );
  }
}

(List<LayerModel>, double, Size)? _parseFirstPage(PremiumTemplate template) {
  final raw = template.templateJson;
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final metadata = (data['metadata'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final pages = data['pages'];
    if (pages is! List || pages.isEmpty) return null;
    final page = pages.first;
    if (page is! Map<String, dynamic>) return null;
    final layersJson = page['layers'];
    if (layersJson is! List || layersJson.isEmpty) return null;

    final designWidth = (metadata['designWidth'] as num?)?.toDouble() ?? 1080.0;
    final designHeight =
        (metadata['designHeight'] as num?)?.toDouble() ?? 1440.0;
    final canvasSize = Size(designWidth, designHeight);
    final layers = layersJson
        .whereType<Map<String, dynamic>>()
        .map((layer) => LayerExportMapper.fromJson(layer, canvasSize: canvasSize))
        .toList(growable: false);
    if (layers.isEmpty) return null;
    final aspect = (designWidth / designHeight).clamp(0.6, 1.8);
    return (layers, aspect, canvasSize);
  } catch (_) {
    return null;
  }
}

class _NetworkImage extends StatelessWidget {
  final String url;
  final ImageVariant variant;

  const _NetworkImage({required this.url, this.variant = ImageVariant.thumb});

  @override
  Widget build(BuildContext context) {
    final transformed = imageUrlByVariant(url, variant: variant);
    return Image.network(
      transformed,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Container(
        color: SnapFitColors.overlayLightOf(context),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: SnapFitColors.textMutedOf(context),
        ),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: SnapFitColors.overlayLightOf(context),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}
