import 'package:flutter/material.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// Presentation only: values, prices and availability come from the account/store.
class PointWalletCard extends StatelessWidget {
  const PointWalletCard({
    super.key,
    required this.value,
    this.label = '사용 가능한 포인트',
    this.compact = false,
    this.footnote,
    this.onRetry,
  });

  final String value;
  final String label;
  final bool compact;
  final String? footnote;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final showArtwork =
          bounds.maxWidth >= 280 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.5;
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: SnapFitColors.actionAccent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            if (showArtwork)
              Positioned(
                right: 14,
                top: 16,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: -.24,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .12),
                            width: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(compact ? 18 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: SnapFitType.style(
                      12,
                      color: Colors.white,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.only(right: showArtwork ? 54 : 0),
                    // 금액과 단위가 따로 줄 바뀌거나 잘리지 않도록 함께 맞춘다.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: SnapFitType.style(
                          compact ? 28 : 34,
                          color: Colors.white,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                      ),
                      child: const Text('잔액 다시 확인'),
                    ),
                  if (footnote != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      footnote!,
                      style: SnapFitType.style(12, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class PointPackOption extends StatelessWidget {
  const PointPackOption({
    super.key,
    this.tapKey,
    required this.points,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final Key? tapKey;
  final int points;
  final String price;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = ExperienceFormStyle.ink(context);
    final brand = ExperienceFormStyle.selectionInk(context);
    final number = points.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return Semantics(
      button: true,
      selected: selected,
      checked: selected,
      enabled: onTap != null,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: SnapFitMotion.duration(context, SnapFitMotion.fast),
        decoration: BoxDecoration(
          color: selected
              ? ExperienceFormStyle.selection(context)
              : SnapFitColors.backgroundOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? brand : ExperienceFormStyle.line(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: tapKey,
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final stacked =
                      bounds.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.4;
                  final amount = Text(
                    '$number P',
                    style: SnapFitType.style(
                      21,
                      weight: FontWeight.w700,
                      color: ink,
                    ),
                  );
                  final cost = Text(
                    price,
                    semanticsLabel: '결제 금액 $price',
                    style: SnapFitType.style(
                      16,
                      weight: FontWeight.w600,
                      color: ink,
                    ),
                  );
                  return Row(
                    children: [
                      ExcludeSemantics(
                        child: AnimatedContainer(
                          duration: SnapFitMotion.duration(
                            context,
                            SnapFitMotion.fast,
                          ),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? SnapFitColors.actionAccent
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? SnapFitColors.actionAccent
                                  : ExperienceFormStyle.muted(
                                      context,
                                    ).withValues(alpha: .85),
                              width: 1.5,
                            ),
                          ),
                          child: selected
                              ? const ExperienceIcon('Check', size: 15, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: stacked
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  amount,
                                  const SizedBox(height: 3),
                                  cost,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: amount),
                                  const SizedBox(width: 8),
                                  cost,
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
