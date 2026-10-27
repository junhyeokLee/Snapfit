import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../core/templates/catalog_preview_assets.g.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../../shared/web/web_design.dart' show WebSection;
import '../../../../shared/widgets/catalog_artwork_hero.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../profile/presentation/widgets/customer_web_page.dart';
import '../../../store/domain/entities/premium_template.dart';
import '../../../store/presentation/views/template_detail_screen.dart';
import '../providers/home_news_providers.dart';

class MonthlyDesignsScreen extends ConsumerWidget {
  const MonthlyDesignsScreen({super.key});

  static const _description = '사진을 담고 싶은 디자인을 골라보세요.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designs = ref.watch(homeNewsDesignsProvider);
    Widget content() => designs.when(
      skipLoadingOnRefresh: false,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 72),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _DesignsMessage(
        title: '디자인을 불러오지 못했어요',
        action: TextButton.icon(
          onPressed: () => ref.invalidate(homeNewsDesignsProvider),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('다시 불러오기'),
        ),
      ),
      data: (templates) {
        final items = templates.take(3).toList(growable: false);
        if (items.isEmpty) {
          return const _DesignsMessage(title: '새로운 디자인을 준비하고 있어요');
        }
        return LayoutBuilder(
          builder: (context, bounds) {
            const gap = 24.0;
            final minimumWidth = math.max(
              280.0,
              MediaQuery.textScalerOf(context).scale(16) * 18,
            );
            final columns = kIsWeb
                ? ((bounds.maxWidth + gap) / (minimumWidth + gap))
                      .floor()
                      .clamp(1, 3)
                : 1;
            final width = (bounds.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 32,
              children: [
                for (final template in items)
                  SizedBox(
                    width: width,
                    child: _MonthlyDesignCard(
                      key: ValueKey(template.id),
                      template: template,
                      heroTag: (this, template.id),
                      onOpen: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            settings: kIsWeb
                                ? WebAppRouteSettings(
                                    WebAppLocation(
                                      WebAppPage.template,
                                      '${template.id}',
                                    ),
                                  )
                                : null,
                            builder: (_) => TemplateDetailScreen(
                              template: template,
                              heroTag: (this, template.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    if (kIsWeb) {
      return CustomerWebPage(
        title: '이달의 디자인',
        description: _description,
        section: WebSection.designs,
        scrollBody: true,
        child: content(),
      );
    }
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: const ExperienceHeader(
        title: '이달의 디자인',
        themeAware: true,
        showNotifications: false,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const PageStorageKey('monthly-designs-list'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _description,
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      secondary: true,
                    ).copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  content(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthlyDesignCard extends StatefulWidget {
  const _MonthlyDesignCard({
    super.key,
    required this.template,
    required this.heroTag,
    required this.onOpen,
  });

  final PremiumTemplate template;
  final Object heroTag;
  final Future<void> Function() onOpen;

  @override
  State<_MonthlyDesignCard> createState() => _MonthlyDesignCardState();
}

class _MonthlyDesignCardState extends State<_MonthlyDesignCard> {
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
    final template = widget.template;
    final asset = catalogPreviewAssets['template:${template.id}'];
    final subtitle = (template.subTitle ?? template.description ?? '').trim();
    final unavailableArtwork = ColoredBox(
      color: ExperienceFormStyle.surface(context),
      child: Center(
        child: Icon(
          Icons.auto_stories_outlined,
          size: 40,
          color: ExperienceFormStyle.muted(context),
        ),
      ),
    );
    return Material(
      key: ValueKey('monthly-design-${template.id}'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: _opening ? null : _open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: CatalogArtworkHero(
                  tag: widget.heroTag,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: asset != null
                          ? Image.asset(
                              asset,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => unavailableArtwork,
                            )
                          : template.coverImageUrl.trim().isNotEmpty
                          ? SnapfitImage(
                              urlOrGs: template.coverImageUrl,
                              fit: BoxFit.contain,
                              error: unavailableArtwork,
                            )
                          : unavailableArtwork,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 16, 2, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        template.title,
                        style: ExperienceFormStyle.text(
                          context,
                          20,
                          weight: FontWeight.w700,
                        ).copyWith(height: 1.4, letterSpacing: -.4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: ExperienceFormStyle.ink(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                  child: Text(
                    subtitle,
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      secondary: true,
                    ).copyWith(height: 1.65),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesignsMessage extends StatelessWidget {
  const _DesignsMessage({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 56),
    child: Column(
      children: [
        Icon(
          Icons.auto_stories_outlined,
          size: 36,
          color: ExperienceFormStyle.muted(context),
        ),
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
