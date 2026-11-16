import 'package:flutter/material.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart'
    show SnapFitMotion, SnapFitRadius;
import '../../../../../shared/widgets/experience_form_style.dart';

class PrintCoverTypePicker extends StatelessWidget {
  const PrintCoverTypePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final PrintCoverType selected;
  final ValueChanged<PrintCoverType> onSelected;

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '커버 종류 안내',
          style: ExperienceFormStyle.text(
            dialogContext,
            18,
            weight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final type in PrintCoverType.values) ...[
                Text(
                  type.label,
                  style: ExperienceFormStyle.text(
                    dialogContext,
                    14,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  type == PrintCoverType.soft
                      ? '일반 책이나 잡지에 사용하는 종이 표지예요.'
                      : '인쇄한 종이를 하드보드에 붙인 표지로, 오래 간직하는 책에 사용해요.',
                  style: ExperienceFormStyle.text(
                    dialogContext,
                    13,
                    secondary: true,
                  ).copyWith(height: 1.5),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                '선택한 커버는 앨범 주문 시 적용돼요.',
                style: ExperienceFormStyle.text(
                  dialogContext,
                  13,
                  secondary: true,
                ).copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = ExperienceFormStyle.ink(context);
    return LayoutBuilder(
      builder: (context, box) {
        // 설명을 축소하지 않고 좁은 화면과 큰 글자에서 카드 전체를 세로로 배치한다.
        final vertical =
            box.maxWidth <
            300 * MediaQuery.textScalerOf(context).scale(13) / 13;
        final width = vertical ? box.maxWidth : (box.maxWidth - 8) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in PrintCoverType.values)
                  SizedBox(
                    width: width,
                    child: Semantics(
                      button: true,
                      selected: selected == type,
                      inMutuallyExclusiveGroup: true,
                      label: type.label,
                      value: type == PrintCoverType.soft
                          ? '유연한 종이 표지, 일반 책·잡지 같은 형태'
                          : '단단한 보드 표지, 오래 간직하기 좋은 형태',
                      excludeSemantics: true,
                      onTap: () => onSelected(type),
                      child: Material(
                        animationDuration: SnapFitMotion.duration(
                          context,
                          SnapFitMotion.fast,
                        ),
                        color: selected == type
                            ? ExperienceFormStyle.selection(context)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SnapFitRadius.md),
                          side: BorderSide(
                            color: selected == type
                                ? ExperienceFormStyle.selectionInk(context)
                                : ExperienceFormStyle.line(context),
                            width: selected == type ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          key: ValueKey('print-cover-${type.name}'),
                          onTap: () => onSelected(type),
                          borderRadius: BorderRadius.circular(SnapFitRadius.md),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                        'assets/print/cover_types/supplier_${type.name}.png',
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.contain,
                                        excludeFromSemantics: true,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        type.label,
                                        style: ExperienceFormStyle.text(
                                          context,
                                          14,
                                          weight: FontWeight.w600,
                                          color: ink,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ExcludeSemantics(
                                      child: Icon(
                                        selected == type
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        key: selected == type
                                            ? ValueKey(
                                                'print-cover-selected-${type.name}',
                                              )
                                            : null,
                                        size: 16,
                                        color: selected == type
                                            ? ExperienceFormStyle.selectionInk(
                                                context,
                                              )
                                            : ink.withValues(alpha: .45),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  type == PrintCoverType.soft
                                      ? '유연한 종이 표지'
                                      : '단단한 보드 표지',
                                  style: ExperienceFormStyle.text(
                                    context,
                                    13,
                                    secondary: true,
                                  ).copyWith(height: 1.5),
                                ),
                                Text(
                                  type == PrintCoverType.soft
                                      ? '일반 책·잡지 같은 형태'
                                      : '오래 간직하기 좋은 형태',
                                  style: ExperienceFormStyle.text(
                                    context,
                                    13,
                                    secondary: true,
                                  ).copyWith(height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('print-cover-details'),
                onPressed: () => _showDetails(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  foregroundColor: ExperienceFormStyle.selectionInk(context),
                  textStyle: ExperienceFormStyle.text(context, 13),
                ),
                child: const Text('자세히 보기'),
              ),
            ),
          ],
        );
      },
    );
  }
}
