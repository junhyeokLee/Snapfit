import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/page_templates.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/web/web_design.dart';
import 'page_layout_catalog.dart';
import '../../../../../shared/widgets/experience_icon.dart';

class PageTemplatePicker extends StatelessWidget {
  const PageTemplatePicker({super.key, required this.onSelect});
  final ValueChanged<PageTemplate> onSelect;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<PageTemplate> onSelect,
  }) {
    if (kIsWeb) {
      return showWebAwareDialog<void>(
        context: context,
        useRootNavigator: false,
        maxWidth: 960,
        maxHeight: 740,
        builder: (dialogContext) => PageTemplatePicker(
          onSelect: (template) {
            onSelect(template);
            Navigator.pop(dialogContext);
          },
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PageTemplatePicker(
        onSelect: (template) {
          onSelect(template);
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * .90).clamp(0.0, 900.0);
    return Container(
      height: kIsWeb ? double.infinity : height,
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!kIsWeb) ...[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SnapFitColors.overlayStrongOf(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '페이지 레이아웃',
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '레이아웃 닫기',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const ExperienceIcon('X', size: 20),
                  ),
                ],
              ),
            ),
            Expanded(child: PageLayoutCatalog(onSelect: onSelect)),
          ],
        ),
      ),
    );
  }
}

/// Retained for existing callers; preview geometry is shared with the editor.
class TemplatePreviewCanvas extends StatelessWidget {
  const TemplatePreviewCanvas({
    super.key,
    required this.template,
    this.width = 88,
    this.height = 118,
  });
  final PageTemplate template;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: PageLayoutPreview(template: template),
  );
}
