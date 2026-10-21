import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../shared/widgets/experience_style.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart';

/// 홈 화면 하단 네비게이션 바
class HomeBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hasUnreadNotification;
  final bool rail;

  const HomeBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.hasUnreadNotification = false,
    this.rail = false,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _experienceNavigation(context, constraints),
  );

  Widget _experienceNavigation(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final selectedIndex = currentIndex == 5
        ? 2
        : currentIndex == 1
        ? 0
        : currentIndex;
    const destinations = [
      (0, '내 앨범', 'BookOpen'),
      (2, '스토어', 'Layers2'),
      (6, '내 디자인', 'Bookmark'),
      (4, '마이', 'UserRound'),
    ];
    final scaledLabel = MediaQuery.textScalerOf(context).scale(12);
    final railWidth = math.max(86.0, scaledLabel * 3 + 20);
    final navigationWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width;
    final labelWidth = rail
        ? railWidth
        : math.max(1.0, (navigationWidth - 24) / destinations.length);
    var labelHeight = 0.0;
    for (final (_, label, _) in destinations) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: ExperienceStyle.text(12, weight: FontWeight.w600),
        ),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout(maxWidth: labelWidth);
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    final itemHeight = math.max(56.0, (36 + labelHeight).ceilToDouble());
    final duration = SnapFitMotion.duration(context, SnapFitMotion.fast);
    final items = [
      for (final (index, label, icon) in destinations)
        Semantics(
          selected: selectedIndex == index,
          button: true,
          label: label,
          excludeSemantics: true,
          onTap: () => onTap(index),
          child: InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(SnapFitRadius.md),
            child: SizedBox(
              height: itemHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 29,
                    child: AnimatedContainer(
                      key: ValueKey('home-navigation-indicator-$index'),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: selectedIndex == index
                            ? ExperienceFormStyle.selection(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(SnapFitRadius.pill),
                      ),
                      child: Center(
                        child: ExperienceIcon(
                          icon,
                          color: selectedIndex == index
                              ? ExperienceFormStyle.selectionInk(context)
                              : ExperienceFormStyle.muted(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    style: ExperienceStyle.text(
                      12,
                      weight: selectedIndex == index
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selectedIndex == index
                          ? ExperienceFormStyle.selectionInk(context)
                          : ExperienceFormStyle.muted(context),
                    ),
                    child: Text(label, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
    final dark = SnapFitColors.isDark(context);
    final bg = SnapFitColors.backgroundOf(context);
    final safeContent = SafeArea(
      top: rail,
      child: rail
          ? SizedBox(
              width: railWidth,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 500;
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: compact ? 8 : 26),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: TextButton(
                            onPressed: () => onTap(2),
                            child: Text(
                              'sf.',
                              style: ExperienceStyle.text(
                                23,
                                weight: FontWeight.w800,
                                color: ExperienceFormStyle.selectionInk(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 25),
                        for (final item in items)
                          Padding(
                            padding: EdgeInsets.only(bottom: compact ? 4 : 25),
                            child: item,
                          ),
                      ],
                    ),
                  );
                },
              ),
            )
          : SizedBox(
              height: itemHeight + 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [for (final item in items) Expanded(child: item)],
                ),
              ),
            ),
    );
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          key: const ValueKey('home-navigation-surface'),
          color: bg.withValues(alpha: dark ? 0.82 : 0.86),
          child: Container(
            decoration: BoxDecoration(
              border: rail
                  ? Border(
                      right: BorderSide(
                        color: ExperienceFormStyle.line(context),
                      ),
                    )
                  : null,
              boxShadow: rail ? null : SnapFitShadow.navBar(dark),
            ),
            child: safeContent,
          ),
        ),
      ),
    );
  }
}
