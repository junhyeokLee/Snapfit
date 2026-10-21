import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../../../core/templates/template_catalog_categories.dart';
import '../../../../point_shop/domain/point_shop_template_key.dart';
import '../../../../point_shop/data/point_shop_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../store/domain/entities/premium_template.dart';
import '../../../../store/domain/template_design_profile.dart';
import '../../../../store/presentation/widgets/library_design_tile.dart';
import '../../../../store/presentation/widgets/template_design_profile_summary.dart';
import 'creation_catalog_cover.dart';
import '../../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../../shared/widgets/catalog_filter_bar.dart';
import '../../../../../shared/widgets/catalog_search_disclosure.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart'
    show SnapFitRadius;
import 'creation_collection_showcase.dart';
import 'creation_workspace.dart';

class AiAlbumStartStep extends ConsumerStatefulWidget {
  final VoidCallback onAiStart;
  final VoidCallback onManualStart;
  final int aiPointCost;
  final String? freeDraftLabel;
  final bool isFirstAiDraftFree;
  final AsyncValue<List<PremiumTemplate>> templates;
  final ValueChanged<PremiumTemplate>? onTemplateSelected;
  final VoidCallback? onRetry;

  const AiAlbumStartStep({
    super.key,
    required this.onAiStart,
    required this.onManualStart,
    this.aiPointCost = 300,
    this.freeDraftLabel,
    this.isFirstAiDraftFree = false,
    this.templates = const AsyncData([]),
    this.onTemplateSelected,
    this.onRetry,
  });

  @override
  ConsumerState<AiAlbumStartStep> createState() => _AiAlbumStartStepState();
}

class _AiAlbumStartStepState extends ConsumerState<AiAlbumStartStep> {
  String _filter = '전체';
  String? _topic;
  bool _favoritesOnly = false;
  String _query = '';
  final _search = TextEditingController();
  final _catalogAnchor = GlobalKey();
  int? _inspectedTemplateId;

  void _openTemplate(PremiumTemplate template) {
    setState(() => _inspectedTemplateId = template.id);
    widget.onTemplateSelected?.call(template);
  }

  void _browseTemplates() {
    final target = _catalogAnchor.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _clearFilters() => setState(() {
    _favoritesOnly = false;
    _filter = '전체';
    _topic = null;
    _query = '';
    _search.clear();
  });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CatalogFavoritesBuilder(builder: _buildCatalog);

  Widget _buildCatalog(BuildContext context, CatalogFavorites favorites) {
    final muted = ExperienceFormStyle.muted(context);
    final catalog = ref.watch(pointShopCatalogProvider);
    final owned =
        ref.watch(ownedPointShopKeysProvider).asData?.value ?? <String>{};
    final products = {
      for (final product in catalog.asData?.value ?? const [])
        product.productKey: product,
    };
    final topics = orderedTemplateTopics(
      (widget.templates.asData?.value ?? const <PremiumTemplate>[]).map(
        (template) => template.category?.trim() ?? '',
      ),
    );
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = kIsWeb
              ? constraints.maxWidth >= 1100
                    ? 5
                    : constraints.maxWidth >= 760
                    ? 4
                    : constraints.maxWidth >= 540
                    ? 3
                    : 2
              : constraints.maxWidth >= 720
              ? 4
              : 2;
          final previewHeight =
              ((constraints.maxWidth - 48 - 16 * (columns - 1)) / columns * 1.2)
                  .clamp(168.0, 252.0);
          return CustomScrollView(
            key: const PageStorageKey('albumCreationHub'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kIsWeb ? '어떻게 시작할까요?' : '새 앨범',
                        style: ExperienceFormStyle.text(
                          context,
                          22,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        key: const ValueKey('creation-ai-conditions'),
                        container: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isFirstAiDraftFree
                                  ? '첫 AI 템플릿 1회 무료 · 이후 현재 구성 기준 ${widget.aiPointCost}P'
                                  : 'AI 템플릿 · 현재 구성 ${widget.aiPointCost}P',
                              style: ExperienceFormStyle.text(
                                context,
                                12,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '쪽수에 따라 달라져요. 최종 포인트는 생성 전에 확인해요.',
                              style: ExperienceFormStyle.text(
                                context,
                                12,
                                secondary: true,
                              ),
                            ),
                            if (widget.freeDraftLabel?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.freeDraftLabel!,
                                style: ExperienceFormStyle.text(
                                  context,
                                  12,
                                  secondary: true,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, area) {
                          final wide =
                              area.maxWidth >=
                                  720 *
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(12) /
                                      12 &&
                              MediaQuery.orientationOf(context) ==
                                  Orientation.landscape;
                          final featured =
                              widget.templates.asData?.value.firstOrNull;
                          final showArtwork =
                              _query.isEmpty &&
                              _filter == '전체' &&
                              _topic == null &&
                              !_favoritesOnly;
                          final artwork = featured == null
                              ? CreationBlankBook(cover: defaultCoverSize)
                              : CreationCollectionShowcase(
                                  template: featured,
                                  editorial: !kIsWeb,
                                  showTitle: true,
                                  onOpen: widget.onTemplateSelected == null
                                      ? null
                                      : () => widget.onTemplateSelected!(
                                          featured,
                                        ),
                                );
                          final manual = _StartAction(
                            title: '직접 만들기',
                            icon: Icons.add,
                            onTap: widget.onManualStart,
                          );
                          final ai = _StartAction(
                            title: 'AI 템플릿',
                            icon: Icons.auto_awesome_outlined,
                            ai: true,
                            onTap: widget.onAiStart,
                          );
                          final choices = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              manual,
                              Divider(
                                height: 1,
                                color: ExperienceFormStyle.line(context),
                              ),
                              ai,
                              Divider(
                                height: 1,
                                color: ExperienceFormStyle.line(context),
                              ),
                              _StartAction(
                                title: '템플릿 고르기',
                                icon: Icons.collections_bookmark_outlined,
                                onTap: _browseTemplates,
                              ),
                            ],
                          );
                          final quickChoices = LayoutBuilder(
                            builder: (context, choicesArea) {
                              final scale =
                                  MediaQuery.textScalerOf(context).scale(12) /
                                  12;
                              final minimum = (kIsWeb ? 240 : 92) * scale;
                              final horizontal =
                                  choicesArea.maxWidth >= minimum * 3 + 16;
                              final captionHeight = horizontal
                                  ? _CreationMethodExample.captionHeight(
                                      context,
                                      (choicesArea.maxWidth - 16) / 3 -
                                          (kIsWeb ? 48 : 8),
                                    )
                                  : null;
                              final actions = [
                                _StartAction(
                                  title: '직접 만들기',
                                  icon: Icons.add,
                                  compact: true,
                                  exampleCaptionHeight: captionHeight,
                                  onTap: widget.onManualStart,
                                ),
                                _StartAction(
                                  title: 'AI 템플릿',
                                  icon: Icons.auto_awesome_outlined,
                                  compact: true,
                                  exampleCaptionHeight: captionHeight,
                                  ai: true,
                                  onTap: widget.onAiStart,
                                ),
                                _StartAction(
                                  title: '템플릿 고르기',
                                  icon: Icons.collections_bookmark_outlined,
                                  compact: true,
                                  exampleCaptionHeight: captionHeight,
                                  onTap: _browseTemplates,
                                ),
                              ];
                              if (!horizontal) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < actions.length;
                                      i++
                                    ) ...[
                                      if (i > 0) const SizedBox(height: 8),
                                      actions[i],
                                    ],
                                  ],
                                );
                              }
                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < actions.length;
                                      i++
                                    ) ...[
                                      if (i > 0) const SizedBox(width: 8),
                                      Expanded(child: actions[i]),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                          return Column(
                            children: [
                              if (kIsWeb)
                                quickChoices
                              else if (!showArtwork)
                                quickChoices
                              else if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: SizedBox(
                                        height: 204,
                                        child: artwork,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(flex: 5, child: choices),
                                  ],
                                )
                              else ...[
                                quickChoices,
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: constraints.maxHeight < 600
                                      ? 230
                                      : 290,
                                  child: artwork,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      CatalogSearchDisclosure(
                        key: _catalogAnchor,
                        controller: _search,
                        onClear: () => setState(() => _query = ''),
                        leading: Text(
                          '템플릿',
                          style: ExperienceFormStyle.text(
                            context,
                            16,
                            weight: FontWeight.w600,
                          ),
                        ),
                        child: TextField(
                          controller: _search,
                          onChanged: (value) => setState(
                            () => _query = value.trim().toLowerCase(),
                          ),
                          style: ExperienceFormStyle.text(context, 14),
                          decoration: ExperienceFormStyle.input(
                            context,
                            hint: '여행, 웨딩, 일상 검색',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (topics.isNotEmpty) ...[
                        SingleChildScrollView(
                          key: const ValueKey('creation-topic-filters'),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final topic in [null, ...topics])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    key: ValueKey(
                                      'creation-topic-${topic ?? 'all'}',
                                    ),
                                    label: Text(topic ?? '모든 주제'),
                                    selected: _topic == topic,
                                    onSelected: (_) =>
                                        setState(() => _topic = topic),
                                    showCheckmark: false,
                                    selectedColor:
                                        ExperienceFormStyle.selection(context),
                                    backgroundColor:
                                        ExperienceFormStyle.surface(context),
                                    side: BorderSide.none,
                                    labelStyle:
                                        ExperienceFormStyle.text(
                                          context,
                                          12,
                                        ).copyWith(
                                          color: _topic == topic
                                              ? ExperienceFormStyle.selectionInk(
                                                  context,
                                                )
                                              : muted,
                                        ),
                                    shape: const StadiumBorder(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      CatalogFilterBar(
                        price: _filter,
                        enabled: catalog.hasValue,
                        onPriceChanged: (value) =>
                            setState(() => _filter = value),
                        favoritesOnly: _favoritesOnly,
                        onFavoritesChanged: () =>
                            setState(() => _favoritesOnly = !_favoritesOnly),
                      ),
                    ],
                  ),
                ),
              ),
              widget.templates.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text('템플릿을 불러오지 못했어요', style: TextStyle(color: muted)),
                        TextButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 불러오기'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (templates) {
                  final visible = favorites.arrange(
                    templates.where((template) {
                      if (_topic != null &&
                          template.category?.trim() != _topic) {
                        return false;
                      }
                      final product = products[pointShopTemplateKey(template)];
                      final isFree = product == null
                          ? !template.isPremium
                          : product.isActive && product.pointPrice == 0;
                      if (_filter == '무료' && !isFree) return false;
                      if (_filter == '유료' && isFree) return false;
                      return '${template.title} ${template.category ?? ''} ${(template.tags ?? []).join(' ')}'
                          .toLowerCase()
                          .contains(_query);
                    }),
                    (t) => CatalogFavoriteKeys.template(t.id),
                    onlyFavorites: _favoritesOnly,
                  );
                  if (visible.isEmpty && _favoritesOnly)
                    return SliverToBoxAdapter(
                      child: CatalogFavoritesEmpty(onShowAll: _clearFilters),
                    );
                  if (visible.isEmpty)
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.collections_bookmark_outlined,
                              size: 32,
                              color: muted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              templates.isEmpty ? '등록된 템플릿이 없어요' : '검색 결과가 없어요',
                              style: TextStyle(color: muted),
                            ),
                            if (templates.isNotEmpty)
                              TextButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('전체 템플릿 보기'),
                              ),
                          ],
                        ),
                      ),
                    );
                  final inspected = visible
                      .where((template) => template.id == _inspectedTemplateId)
                      .firstOrNull;
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: inspected == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  0,
                                  24,
                                  16,
                                ),
                                child: TemplateDesignProfileSummary(
                                  key: const ValueKey(
                                    'creation-inspected-profile',
                                  ),
                                  heading: '최근 살펴본 디자인 · ${inspected.title}',
                                  profile: TemplateDesignProfile.of(inspected),
                                ),
                              ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 24,
                                mainAxisExtent: LibraryDesignTile.extent(
                                  previewHeight,
                                  MediaQuery.textScalerOf(context),
                                ),
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final template = visible[index];
                            final productKey = pointShopTemplateKey(template);
                            return LibraryDesignTile(
                              key: ValueKey('creation-template-${template.id}'),
                              productKey: productKey,
                              title: template.title,
                              type: '템플릿',
                              previewHeight: previewHeight,
                              owned: owned.contains(productKey),
                              template: template,
                              favoriteKey: CatalogFavoriteKeys.template(
                                template.id,
                              ),
                              onOpen: () => _openTemplate(template),
                              preview: CreationCatalogCover(
                                template: template,
                                useThumbnail: true,
                                showBookMaterial: true,
                              ),
                            );
                          }, childCount: visible.length),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StartAction extends StatelessWidget {
  const _StartAction({
    required this.title,
    required this.icon,
    required this.onTap,
    this.ai = false,
    this.compact = false,
    this.exampleCaptionHeight,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool ai, compact;
  final double? exampleCaptionHeight;

  _CreationMethod get _method => ai
      ? _CreationMethod.ai
      : icon == Icons.add
      ? _CreationMethod.manual
      : _CreationMethod.template;

  String get _description => ai
      ? '원하는 분위기로 디자인을 만들어요. 사진은 이후 직접 추가해요.'
      : icon == Icons.add
      ? '빈 앨범에서 사진과 글을 직접 배치해요.'
      : '표지와 내지 디자인을 골라 시작해요.';

  String get _compactDescription => ai
      ? '분위기로 생성'
      : icon == Icons.add
      ? '빈 앨범부터'
      : '디자인 선택';

  @override
  Widget build(BuildContext context) => !kIsWeb && compact
      ? Semantics(
          button: true,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(SnapFitRadius.md),
            child: InkWell(
              key: ValueKey('creation-method-${_method.name}'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(SnapFitRadius.md),
              child: Container(
                constraints: const BoxConstraints(minHeight: 80),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ExperienceFormStyle.line(context),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    _CreationMethodExample(
                      method: _method,
                      alignedCaptionHeight: exampleCaptionHeight,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _compactDescription,
                      textAlign: TextAlign.center,
                      style: ExperienceFormStyle.text(
                        context,
                        11,
                        secondary: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
      : kIsWeb
      ? Material(
          color: WebPalette.of(context).surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SnapFitRadius.lg),
            side: BorderSide(color: WebPalette.of(context).line),
          ),
          child: InkWell(
            key: ValueKey('creation-method-${_method.name}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(SnapFitRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CreationMethodExample(
                    method: _method,
                    alignedCaptionHeight: exampleCaptionHeight,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: WebPalette.of(context).ink,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 19,
                        color: WebPalette.of(context).brandInk,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: WebPalette.of(context).muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      : Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SnapFitRadius.md),
          ),
          child: InkWell(
            key: ValueKey('creation-method-${_method.name}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(SnapFitRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 104,
                      child: _CreationMethodExample(method: _method),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: ExperienceFormStyle.text(
                              context,
                              14,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _description,
                            style: ExperienceFormStyle.text(
                              context,
                              12,
                              secondary: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ExperienceIcon(
                      'ArrowRight',
                      size: 17,
                      color: ExperienceFormStyle.muted(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
}

enum _CreationMethod { manual, ai, template }

/// Small interface diagrams, independent of published artwork and AI output.
class _CreationMethodExample extends StatelessWidget {
  const _CreationMethodExample({
    required this.method,
    this.alignedCaptionHeight,
  });
  final _CreationMethod method;
  final double? alignedCaptionHeight;

  static String _label(_CreationMethod method) => switch (method) {
    _CreationMethod.manual => '직접 배치 예시',
    _CreationMethod.ai => 'AI 디자인 예시',
    _CreationMethod.template => '기존 디자인 시작 예시',
  };

  // Only a horizontal group shares caption space. Measure the real strings,
  // including wrapping and text scaling, rather than clipping a fixed height.
  static double captionHeight(BuildContext context, double width) {
    final style = DefaultTextStyle.of(
      context,
    ).style.merge(ExperienceFormStyle.text(context, 11, secondary: true));
    var tallest = 0.0;
    for (final method in _CreationMethod.values) {
      var height = 0.0;
      for (final text in [
        _label(method),
        if (method == _CreationMethod.ai) '실제 결과는 달라요',
      ]) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        )..layout(maxWidth: width);
        height += painter.height;
        painter.dispose();
      }
      if (height > tallest) tallest = height;
    }
    return tallest.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final description = switch (method) {
      _CreationMethod.manual => '빈 앨범에서 사진 자리와 글을 직접 배치한 예시',
      _CreationMethod.ai => 'AI 디자인 구성 예시. 사진은 이후 직접 추가해요. 실제 결과는 달라요.',
      _CreationMethod.template => '준비된 디자인을 선택해 사진을 넣기 전의 예시',
    };
    return Semantics(
      key: ValueKey('creation-example-${method.name}'),
      image: true,
      label: description,
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              width: double.infinity,
              child: CustomPaint(
                painter: _CreationMethodPainter(
                  method: method,
                  paper: ExperienceFormStyle.surface(context),
                  line: ExperienceFormStyle.line(context),
                  ink: ExperienceFormStyle.selectionInk(context),
                  fill: ExperienceFormStyle.selection(context),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: alignedCaptionHeight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _label(method),
                    textAlign: TextAlign.center,
                    style: ExperienceFormStyle.text(
                      context,
                      11,
                      secondary: true,
                    ),
                  ),
                  if (method == _CreationMethod.ai)
                    Text(
                      '실제 결과는 달라요',
                      textAlign: TextAlign.center,
                      style: ExperienceFormStyle.text(
                        context,
                        11,
                        secondary: true,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreationMethodPainter extends CustomPainter {
  const _CreationMethodPainter({
    required this.method,
    required this.paper,
    required this.line,
    required this.ink,
    required this.fill,
  });
  final _CreationMethod method;
  final Color paper, line, ink, fill;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / 160).clamp(0.1, 1.0);
    canvas.translate((size.width - 160 * scale) / 2, (64 - 64 * scale) / 2);
    canvas.scale(scale);
    switch (method) {
      case _CreationMethod.manual:
        _book(canvas, const Rect.fromLTWH(1, 13, 52, 40));
        _stroke(canvas, const Offset(63, 33), const Offset(77, 33));
        _stroke(canvas, const Offset(72, 28), const Offset(77, 33));
        _stroke(canvas, const Offset(72, 38), const Offset(77, 33));
        _book(canvas, const Rect.fromLTWH(88, 6, 70, 54));
        _photo(canvas, const Rect.fromLTWH(94, 13, 24, 24));
        _text(canvas, 94, 43, 23);
        _text(canvas, 129, 15, 21);
        _photo(canvas, const Rect.fromLTWH(129, 26, 23, 26));
        for (final point in const [Offset(94, 13), Offset(118, 37)]) {
          canvas.drawCircle(point, 2, Paint()..color = ink);
        }
      case _CreationMethod.ai:
        _book(canvas, const Rect.fromLTWH(25, 4, 112, 56));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(31, 10, 44, 44),
            const Radius.circular(2),
          ),
          Paint()..color = fill,
        );
        _text(canvas, 36, 18, 30);
        _text(canvas, 36, 24, 20);
        _photo(canvas, const Rect.fromLTWH(36, 32, 33, 17));
        _photo(canvas, const Rect.fromLTWH(87, 10, 43, 27));
        _text(canvas, 87, 44, 36);
        _text(canvas, 87, 50, 23);
      case _CreationMethod.template:
        _book(canvas, const Rect.fromLTWH(37, 2, 104, 50));
        _book(canvas, const Rect.fromLTWH(29, 7, 104, 50));
        _book(canvas, const Rect.fromLTWH(20, 12, 104, 50));
        canvas.drawRect(
          const Rect.fromLTWH(26, 18, 40, 8),
          Paint()..color = fill,
        );
        _photo(canvas, const Rect.fromLTWH(26, 32, 40, 22));
        _text(canvas, 78, 20, 38);
        _photo(canvas, const Rect.fromLTWH(78, 29, 38, 18));
        _text(canvas, 78, 54, 28);
        canvas.drawCircle(const Offset(137, 47), 10, Paint()..color = ink);
        final check = Path()
          ..moveTo(132, 47)
          ..lineTo(136, 51)
          ..lineTo(143, 43);
        canvas.drawPath(
          check,
          Paint()
            ..color = paper
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  void _book(Canvas canvas, Rect rect) {
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(shape, Paint()..color = paper);
    canvas.drawRRect(
      shape,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _stroke(
      canvas,
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      color: line,
    );
  }

  void _photo(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = fill.withValues(alpha: 0.65));
    canvas.drawRect(
      rect,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    final landscape = Path()
      ..moveTo(rect.left + 3, rect.bottom - 4)
      ..lineTo(rect.left + rect.width * 0.4, rect.top + rect.height * 0.5)
      ..lineTo(rect.left + rect.width * 0.65, rect.bottom - 5)
      ..lineTo(rect.right - 3, rect.top + rect.height * 0.35);
    canvas.drawPath(
      landscape,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  void _text(Canvas canvas, double x, double y, double width) =>
      _stroke(canvas, Offset(x, y), Offset(x + width, y), color: ink);

  void _stroke(Canvas canvas, Offset from, Offset to, {Color? color}) =>
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = color ?? ink
          ..strokeWidth = 1.2,
      );

  @override
  bool shouldRepaint(_CreationMethodPainter old) =>
      old.method != method ||
      old.paper != paper ||
      old.line != line ||
      old.ink != ink ||
      old.fill != fill;
}
