import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/catalog_result_status.dart';
import '../../../album/data/bundled_creation_templates.dart';
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../../../commerce/presentation/public_commerce_screen.dart';
import '../../../auth/presentation/providers/public_template_return_intent.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/public_discovery_ordering.dart';
import '../../domain/template_design_profile.dart';
import '../widgets/template_design_comparison.dart';
import '../widgets/public_catalog_empty_state.dart';
import '../widgets/public_template_information.dart';
import 'template_detail_screen.dart';

/// A read-only introduction backed exclusively by the published bundled catalog.
/// Browsing never creates an anonymous account or requests customer data.
class PublicDiscoveryScreen extends StatefulWidget {
  const PublicDiscoveryScreen({super.key, this.catalogOnly = false});
  final bool catalogOnly;

  @override
  State<PublicDiscoveryScreen> createState() => _PublicDiscoveryScreenState();
}

class _PublicDiscoveryScreenState extends State<PublicDiscoveryScreen> {
  final _search = TextEditingController();
  final _discoveryCatalog = orderPublicDiscoveryTemplates(
    publishedCreationTemplates,
  );
  String _category = '전체';
  int _limit = 12;
  TemplateDesignComparisonSelection _comparison =
      const TemplateDesignComparisonSelection.empty();

  void _toggleComparison(PremiumTemplate template) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_comparison.contains(template.id)) {
      setState(() => _comparison = _comparison.remove(template.id));
    } else if (_comparison.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(TemplateDesignComparisonSelection.limitMessage),
        ),
      );
    } else {
      setState(() => _comparison = _comparison.add(template.id));
    }
  }

  Widget _withComparison(Widget content) {
    final selected = [
      for (final id in _comparison.ids)
        ...publishedCreationTemplates
            .where((template) => template.id == id)
            .take(1),
    ];
    void remove(PremiumTemplate template) =>
        setState(() => _comparison = _comparison.remove(template.id));
    void clear() => setState(() => _comparison = _comparison.clear());
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        children: [
          Expanded(child: content),
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: bounds.hasBoundedHeight
                    ? bounds.maxHeight * .4
                    : 240,
              ),
              child: TemplateDesignComparisonTray(
                designs: selected,
                onRemove: remove,
                onClear: clear,
                onCompare: () => showTemplateDesignComparison(
                  context,
                  designs: selected,
                  onRemove: remove,
                  onClear: clear,
                  onOpen: _preview,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _login() {
    FocusManager.instance.primaryFocus?.unfocus();
    final navigation = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
    if (kIsWeb && navigation != null) {
      navigation(WebAppLocation.login);
    } else {
      if (!kIsWeb) {
        ProviderScope.containerOf(
          context,
          listen: false,
        ).read(publicTemplateReturnIntentProvider.notifier).clear();
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _preview(PremiumTemplate template) {
    FocusManager.instance.primaryFocus?.unfocus();
    final location = WebAppLocation(WebAppPage.template, '${template.id}');
    final navigation = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
    if (kIsWeb && navigation != null) {
      navigation(location);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: kIsWeb ? WebAppRouteSettings(location) : null,
        builder: (_) =>
            TemplateDetailScreen(template: template, guestPreview: true),
      ),
    );
  }

  void _resetFilters() => setState(() {
    _search.clear();
    _category = '전체';
    _limit = 12;
  });

  void _selectSuggestedCategory(String category) => setState(() {
    _search.clear();
    _category = category;
    _limit = 12;
  });

  Widget _categoryFilter(List<String> categories, {required bool compact}) {
    final choices = [
      for (final category in categories)
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 4),
          child: ChoiceChip(
            label: Text(category),
            selected: _category == category,
            onSelected: (_) => setState(() {
              _category = category;
              _limit = 12;
            }),
          ),
        ),
    ];
    return compact
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: choices),
          )
        : Wrap(children: choices);
  }

  @override
  Widget build(BuildContext context) {
    final palette = WebPalette.of(context);
    final query = _search.text.trim().toLowerCase();
    final templates = _discoveryCatalog
        .where((template) {
          final matchesQuery =
              query.isEmpty ||
              '${template.title} ${template.description ?? ''} ${template.tags?.join(' ') ?? ''}'
                  .toLowerCase()
                  .contains(query);
          return matchesQuery &&
              (_category == '전체' || template.category == _category);
        })
        .toList(growable: false);
    final categories = <String>{
      '전체',
      for (final template in publishedCreationTemplates)
        if (template.category?.isNotEmpty == true) template.category!,
    }.toList();
    final suggestedCategories = categories
        .where((category) => category != '전체' && category != _category)
        .take(3)
        .toList(growable: false);
    return SnapFitWebShell(
      showNavigation: false,
      actions: [
        if (!kIsWeb)
          IconButton(
            tooltip: '로그인으로 돌아가기',
            onPressed: _login,
            icon: const Icon(Icons.close),
          ),
        TextButton(
          onPressed: () =>
              openPublicCommerce(context, WebAppLocation.printProducts),
          child: const Text('인쇄 상품·가격'),
        ),
        FilledButton(
          key: const ValueKey('discovery-login'),
          onPressed: _login,
          child: const Text('로그인하고 시작'),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, bounds) {
          final columns = bounds.maxWidth >= 1000
              ? 4
              : bounds.maxWidth >= 680
              ? 3
              : bounds.maxWidth >= 460
              ? 2
              : 1;
          final width = (bounds.maxWidth - (columns - 1) * 20) / columns;
          return _withComparison(
            CustomScrollView(
              key: const ValueKey('public-discovery-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                if (!widget.catalogOnly)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '사진과 이야기가 한 권의 책으로',
                            style: TextStyle(
                              fontSize: bounds.maxWidth < 600 ? 28 : 40,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '디자인을 고르고 사진과 글을 더해 나만의 앨범을 만드세요.\n로그인 전에 표지와 내지를 자유롭게 둘러볼 수 있어요.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: palette.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final label in [
                                '1  디자인 선택',
                                '2  사진과 글 편집',
                                '3  저장하고 인쇄 검토',
                              ])
                                Chip(label: Text(label)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '디자인 둘러보기',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('discovery-search'),
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        onChanged: (_) => setState(() => _limit = 12),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          labelText: '주제나 디자인 이름으로 검색',
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  key: const ValueKey('discovery-search-clear'),
                                  tooltip: '검색어 지우기',
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _limit = 12;
                                  }),
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _categoryFilter(
                        categories,
                        compact: bounds.maxWidth < 600,
                      ),
                      const SizedBox(height: 16),
                      CatalogResultStatus(
                        label: '${templates.length}개의 디자인',
                        debounceToken: (_search.text, _category),
                        semanticLabel: publishedCreationTemplates.isEmpty
                            ? '둘러볼 디자인을 준비하고 있어요.'
                            : '${_category == '전체' ? '전체 주제' : '$_category 주제'}, '
                                  '${query.isEmpty ? '' : '검색 결과, '}'
                                  '${templates.length}개의 디자인'
                                  '${templates.isEmpty ? '. 검색·주제를 초기화하거나 다른 주제를 선택해 보세요.' : ''}',
                        style: TextStyle(color: palette.muted),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                if (templates.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: PublicCatalogEmptyState(
                        catalogEmpty: publishedCreationTemplates.isEmpty,
                        suggestedCategories: suggestedCategories,
                        onReset: _resetFilters,
                        onCategorySelected: _selectSuggestedCategory,
                      ),
                    ),
                  ),
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 24,
                    mainAxisExtent:
                        width +
                        MediaQuery.textScalerOf(context).scale(15) * 3 +
                        MediaQuery.textScalerOf(context).scale(12) * 9 +
                        MediaQuery.textScalerOf(context).scale(12) * 2 +
                        48 +
                        28,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final template = templates[index];
                    return Material(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('discovery-template-${template.id}'),
                        onTap: () => _preview(template),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: CreationCatalogCover(
                                  template: template,
                                  useThumbnail: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                template.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${template.category ?? '앨범'} · 표지와 내지 보기',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                PublicTemplateFacts.fromTemplate(
                                  template,
                                ).compactLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              PublicTemplatePriceLabel(template: template),
                              const SizedBox(height: 4),
                              Text(
                                TemplateDesignProfile.of(
                                  template,
                                ).compositionLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Semantics(
                                  toggled: _comparison.contains(template.id),
                                  label: '${template.title} 비교',
                                  child: OutlinedButton.icon(
                                    key: ValueKey(
                                      'discovery-compare-${template.id}',
                                    ),
                                    onPressed: () =>
                                        _toggleComparison(template),
                                    icon: Icon(
                                      _comparison.contains(template.id)
                                          ? Icons.check
                                          : Icons.compare_arrows,
                                      size: 16,
                                    ),
                                    label: const Text('비교'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }, childCount: templates.length.clamp(0, _limit)),
                ),
                if (templates.length > _limit)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: OutlinedButton(
                        onPressed: () => setState(() => _limit += 12),
                        child: const Text('디자인 더 보기'),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: PublicCommerceFooter(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
