import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/web/web_design.dart';

Future<bool> showTemplateApplyPreview(
  BuildContext context, {
  required String title,
  required Widget preview,
  required bool replacesContent,
}) async {
  if (kIsWeb) {
    return await showWebAwareDialog<bool>(
          context: context,
          useRootNavigator: false,
          maxWidth: 900,
          maxHeight: 740,
          builder: (dialogContext) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text('현재 쪽에 적용하기 전에 구성을 확인하세요.'),
                trailing: IconButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  tooltip: '미리보기 닫기',
                  icon: const Icon(Icons.close, size: 20),
                ),
              ),
              Divider(height: 1, color: WebPalette.of(context).line),
              Expanded(
                child: ColoredBox(
                  color: WebPalette.of(context).canvas,
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Center(child: RepaintBoundary(child: preview)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (replacesContent) ...[
                      Text(
                        '적용하면 현재 쪽의 사진과 문구가 교체됩니다.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: WebPalette.of(context).muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('취소'),
                        ),
                        FilledButton(
                          key: const ValueKey('confirm-template-apply'),
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('현재 쪽에 적용'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 760),
        backgroundColor: SnapFitColors.surfaceOf(context),
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: constraints.maxHeight * .92,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ExperienceFormStyle.text(
                              context,
                              16,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '미리보기 닫기',
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close, size: 22),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: ExperienceFormStyle.surface(context),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(child: RepaintBoundary(child: preview)),
                      ),
                    ),
                  ),
                  if (replacesContent)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text(
                        '현재 쪽의 사진과 문구가 교체됩니다.',
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('confirm-template-apply'),
                        style: ExperienceFormStyle.primary(context),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('현재 쪽에 적용'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ) ??
      false;
}
