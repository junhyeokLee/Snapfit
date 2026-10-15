import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'experience_icon.dart';
import '../../features/notification/presentation/views/notification_screen.dart';
import '../../core/constants/snapfit_colors.dart';
import '../../core/theme/snapfit_theme.dart';

/// Customer screens matched to snapfit-experience-design.html; not the home book stage.
abstract final class ExperienceStyle {
  static const ink = Color(0xFF222A2B);
  static const muted = Color(0xFF778080);
  static const line = Color(0xFFE6EBEA);
  static const wash = Color(0xFFF3F6F5);
  static const accent = Color(0xFF08B8D0);
  static TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    fontFamily: 'NotoSans',
    fontSize: size,
    fontWeight: weight,
    letterSpacing: 0,
    height: 1.5,
    color: color ?? ink,
  );
  static ButtonStyle get primary => FilledButton.styleFrom(
    backgroundColor: accent,
    foregroundColor: const Color(0xFF063740),
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    textStyle: text(14, weight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  );
}

class ExperienceNavigationScope extends InheritedWidget {
  const ExperienceNavigationScope({
    super.key,
    required this.onNavigate,
    required this.onBack,
    required super.child,
  });
  final ValueChanged<int> onNavigate;
  final VoidCallback onBack;
  static ExperienceNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ExperienceNavigationScope>();
  @override
  bool updateShouldNotify(ExperienceNavigationScope oldWidget) => true;
}

class ExperienceHeader extends StatelessWidget implements PreferredSizeWidget {
  const ExperienceHeader({
    super.key,
    required this.title,
    this.brand = false,
    this.actions = const [],
    this.back = true,
    this.themeAware = true,
    this.onBack,
    this.showNotifications = true,
  });
  final String title;
  final bool brand, back, themeAware;
  final VoidCallback? onBack;
  final bool showNotifications;
  final List<Widget> actions;
  @override
  Size get preferredSize => const Size.fromHeight(60);
  @override
  Widget build(BuildContext context) {
    final scope = ExperienceNavigationScope.maybeOf(context);
    final background = themeAware
        ? SnapFitColors.backgroundOf(context)
        : Colors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SnapFitTheme.systemOverlayStyle(
        context,
        background: background,
      ).copyWith(statusBarColor: background),
      child: Material(
        color: themeAware ? SnapFitColors.backgroundOf(context) : Colors.white,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: themeAware
                      ? SnapFitColors.overlayLightOf(context)
                      : ExperienceStyle.line,
                ),
              ),
            ),
            child: Row(
              children: [
                if (!brand && back) ...[
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      tooltip: '뒤로가기',
                      onPressed: () {
                        if (onBack != null) {
                          onBack!();
                          return;
                        }
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          scope?.onBack();
                        }
                      },
                      icon: ExperienceIcon(
                        'ArrowLeft',
                        color: themeAware
                            ? SnapFitColors.textPrimaryOf(context)
                            : ExperienceStyle.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: brand
                      ? Text.rich(
                          TextSpan(children: [const TextSpan(text: '스토어')]),
                          style: ExperienceStyle.text(
                            22,
                            weight: FontWeight.w600,
                            color: themeAware
                                ? SnapFitColors.textPrimaryOf(context)
                                : null,
                          ),
                        )
                      : Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ExperienceStyle.text(
                            22,
                            weight: FontWeight.w600,
                            color: themeAware
                                ? SnapFitColors.textPrimaryOf(context)
                                : null,
                          ),
                        ),
                ),
                ...actions,
                if (showNotifications)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      tooltip: '알림',
                      onPressed: () {
                        if (scope != null && !Navigator.canPop(context)) {
                          scope.onNavigate(3);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationScreen(),
                            ),
                          );
                        }
                      },
                      icon: ExperienceIcon(
                        'Bell',
                        color: themeAware
                            ? SnapFitColors.textPrimaryOf(context)
                            : ExperienceStyle.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExperienceRow extends StatelessWidget {
  const ExperienceRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.themeAware = true,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool themeAware;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 19),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: themeAware
                ? SnapFitColors.overlayLightOf(context)
                : ExperienceStyle.line,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: themeAware
                ? SnapFitColors.textPrimaryOf(context)
                : ExperienceStyle.ink,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ExperienceStyle.text(
                    14,
                    weight: FontWeight.w600,
                    color: themeAware
                        ? SnapFitColors.textPrimaryOf(context)
                        : null,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: ExperienceStyle.text(
                      12,
                      color: themeAware
                          ? SnapFitColors.textSecondaryOf(context)
                          : ExperienceStyle.muted,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: themeAware
                ? SnapFitColors.textSecondaryOf(context)
                : ExperienceStyle.muted,
          ),
        ],
      ),
    ),
  );
}
