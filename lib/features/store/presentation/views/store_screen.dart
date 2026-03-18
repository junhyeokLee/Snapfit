import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../data/api/template_provider.dart';
import '../../domain/entities/premium_template.dart';
import 'template_detail_screen.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  static const List<String> _categories = ['전체', '여행', '가족', '연인', '졸업', '레트로'];
  static const int _newBadgeCount = 1;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _allTemplatesKey = GlobalKey();
  String _selectedCategory = '전체';
  bool _sortLatest = true;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templateListProvider);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      body: SafeArea(
        child: templatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => _StoreErrorView(
            onRetry: () => ref.invalidate(templateListProvider),
          ),
          data: (templates) {
            final filtered = _filterTemplates(templates);
            final latestTopIds = _resolveLatestTopIds(filtered);
            final weeklyBest = _resolveWeeklyBest(filtered, latestTopIds);
            final sorted = _sortTemplates(filtered);

            return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _TopBar(onFilterTap: _openSortFilterSheet),
                      const SizedBox(height: 18),
                      _SearchField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
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
                            final selected = category == _selectedCategory;
                            return _CategoryChip(
                              label: category,
                              selected: selected,
                              onTap: () {
                                if (selected) return;
                                setState(() => _selectedCategory = category);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                      _WeeklyHeader(
                        onMoreTap: weeklyBest.length > 2
                            ? () {
                                if (_selectedCategory != '전체') {
                                  setState(() => _selectedCategory = '전체');
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
                        sortLatest: _sortLatest,
                        onSortChanged: (latest) {
                          if (_sortLatest == latest) return;
                          setState(() => _sortLatest = latest);
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
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF07B8DE),
        elevation: 4,
        onPressed: _openSortFilterSheet,
        child: const Icon(Icons.tune_rounded, color: Colors.white),
      ),
    );
  }

  Set<int> _resolveLatestTopIds(List<PremiumTemplate> templates) {
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
    final bestBonus = template.isBest ? 120 : 0;
    final newBonus = isNew ? 60 : 0;
    return (template.likeCount * 10) +
        (template.userCount * 3) +
        bestBonus +
        newBonus;
  }

  List<PremiumTemplate> _sortTemplates(List<PremiumTemplate> templates) {
    final copied = [...templates];
    copied.sort((a, b) {
      if (_sortLatest) {
        return b.id.compareTo(a.id);
      }
      final byLike = b.likeCount.compareTo(a.likeCount);
      if (byLike != 0) return byLike;
      return b.id.compareTo(a.id);
    });
    return copied;
  }

  List<PremiumTemplate> _filterTemplates(List<PremiumTemplate> templates) {
    final query = _searchController.text.trim().toLowerCase();

    return templates.where((template) {
      final category = _inferCategory(template);
      if (_selectedCategory != '전체' && category != _selectedCategory) {
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                        selected: _sortLatest,
                        onTap: () {
                          setState(() => _sortLatest = true);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SheetOptionButton(
                        label: '인기순',
                        selected: !_sortLatest,
                        onTap: () {
                          setState(() => _sortLatest = false);
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
                    final selected = _selectedCategory == category;
                    return _BottomCategoryChip(
                      label: category,
                      selected: selected,
                      onTap: () {
                        setState(() => _selectedCategory = category);
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
          ? const Color(0xFF08B8DF)
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
            color: Color(0xFF07A9CD),
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
                      _NetworkImage(url: template.coverImageUrl),
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
        ? const Color(0xFF0596C8)
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
                  _NetworkImage(url: template.coverImageUrl),
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
                            '+${template.likeCount}',
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
              ? const Color(0xFF08B8DF)
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
              ? const Color(0xFF08B8DF).withOpacity(0.14)
              : SnapFitColors.overlayLightOf(context),
          border: Border.all(
            color: selected
                ? const Color(0xFF08B8DF)
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
                ? const Color(0xFF08B8DF)
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
        color: const Color(0xFF08B8DF),
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

class _NetworkImage extends StatelessWidget {
  final String url;

  const _NetworkImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
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
