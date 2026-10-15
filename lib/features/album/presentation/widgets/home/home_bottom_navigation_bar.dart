import 'package:flutter/material.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../shared/widgets/experience_style.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../core/constants/snapfit_colors.dart';

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
  Widget build(BuildContext context) => _experienceNavigation(context);

  Widget _experienceNavigation(BuildContext context) {
    final selectedIndex = currentIndex == 5
        ? 2
        : currentIndex == 1
        ? 0
        : currentIndex;
    const destinations = [
      (0, '홈', 'House'),
      (2, '스토어', 'Layers2'),
      (6, '보관함', 'Bookmark'),
      (4, '마이', 'UserRound'),
    ];
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
            child: SizedBox(
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 29,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: rail && selectedIndex == index
                            ? ExperienceFormStyle.selection(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
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
                  Text(
                    label,
                    style: ExperienceStyle.text(
                      12,
                      weight: selectedIndex == index
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selectedIndex == index
                          ? ExperienceFormStyle.selectionInk(context)
                          : ExperienceFormStyle.muted(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
    return Material(
      key: const ValueKey('home-navigation-surface'),
      color: SnapFitColors.backgroundOf(context),
      child: Container(
        decoration: BoxDecoration(
          border: rail
              ? Border(
                  right: BorderSide(color: ExperienceFormStyle.line(context)),
                )
              : Border(
                  top: BorderSide(color: ExperienceFormStyle.line(context)),
                ),
        ),
        child: SafeArea(
          top: rail,
          child: rail
              ? SizedBox(
                  width: 86,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 500;
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: compact ? 8 : 26),
                            SizedBox(
                              height: 42,
                              child: TextButton(
                                onPressed: () => onTap(0),
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
                                padding: EdgeInsets.only(
                                  bottom: compact ? 4 : 25,
                                ),
                                child: item,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              : SizedBox(
                  height: 68,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        for (final item in items) Expanded(child: item),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
