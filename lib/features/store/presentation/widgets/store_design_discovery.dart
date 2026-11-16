import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../domain/entities/premium_template.dart';
import 'store_style_gallery.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// Search and visual choices lead directly into the products, without another
/// introductory panel competing with the covers.
class StoreDesignDiscovery extends StatelessWidget {
  const StoreDesignDiscovery({
    super.key,
    required this.controller,
    required this.styleId,
    required this.onStyleChanged,
    required this.templates,
    this.topics,
    this.featured,
    this.showSearch = true,
    this.autofocus = false,
    this.resultLimit,
  });

  final TextEditingController controller;
  final String? styleId;
  final ValueChanged<String?> onStyleChanged;
  final List<PremiumTemplate> templates;
  final Widget? topics;
  final Widget? featured;
  final bool showSearch, autofocus;
  final int? resultLimit;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('store-design-discovery'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showSearch)
        TextField(
          key: const ValueKey('store-discovery-search'),
          controller: controller,
          autofocus: autofocus,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: ExperienceFormStyle.text(context, 14),
          decoration:
              ExperienceFormStyle.input(
                context,
                hint: '여행 · 첫돌 · 강아지 산책',
              ).copyWith(
                prefixIcon: const ExperienceIcon('Search', size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: '검색 지우기',
                          onPressed: controller.clear,
                          icon: const ExperienceIcon('X', size: 19),
                        ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
        ),
      if (topics != null) ...[const SizedBox(height: 10), topics!],
      if (featured != null) featured!,
      const SizedBox(height: 14),
      StoreStyleGallery(
        templates: templates,
        styleId: styleId,
        onStyleChanged: onStyleChanged,
        resultLimit: resultLimit,
      ),
    ],
  );
}
