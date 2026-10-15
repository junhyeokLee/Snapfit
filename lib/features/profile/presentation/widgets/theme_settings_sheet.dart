import 'package:flutter/material.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';

class ThemeSettingsSheet extends StatefulWidget {
  const ThemeSettingsSheet({
    super.key,
    required this.selected,
    required this.onSelected,
    this.onClose,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;
  final VoidCallback? onClose;

  @override
  State<ThemeSettingsSheet> createState() => _ThemeSettingsSheetState();
}

class _ThemeSettingsSheetState extends State<ThemeSettingsSheet> {
  bool _finishing = false;

  void _select(ThemeMode mode) {
    if (!mounted || _finishing || ModalRoute.of(context)?.isCurrent == false)
      return;
    if (ModalRoute.of(context) is PopupRoute) setState(() => _finishing = true);
    widget.onSelected(mode);
  }

  void _close() {
    if (!mounted || _finishing || ModalRoute.of(context)?.isCurrent == false)
      return;
    if (ModalRoute.of(context) is PopupRoute) setState(() => _finishing = true);
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (ModalRoute.of(context) is PopupRoute) {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final closable =
        widget.onClose != null || ModalRoute.of(context) is PopupRoute;
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, compact ? 12 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '화면 테마',
                      style: ExperienceFormStyle.text(
                        context,
                        20,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (closable)
                    IconButton(
                      key: const ValueKey('theme-close'),
                      tooltip: '화면 테마 닫기',
                      onPressed: _finishing ? null : _close,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              SizedBox(height: compact ? 8 : 12),
              Flexible(
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final light = _option(
                        context,
                        ThemeMode.light,
                        '라이트',
                        Icons.light_mode_outlined,
                        compact: compact,
                      );
                      final dark = _option(
                        context,
                        ThemeMode.dark,
                        '다크',
                        Icons.dark_mode_outlined,
                        compact: compact,
                      );
                      return box.maxWidth >= 400 &&
                              MediaQuery.orientationOf(context) ==
                                  Orientation.landscape
                          ? Row(
                              key: const ValueKey('theme-wide-options'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: light),
                                const SizedBox(width: 12),
                                Expanded(child: dark),
                              ],
                            )
                          : Column(
                              children: [
                                light,
                                const SizedBox(height: 12),
                                dark,
                              ],
                            );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context,
    ThemeMode mode,
    String label,
    IconData icon, {
    required bool compact,
  }) {
    final active = widget.selected == mode;
    final dark = mode == ThemeMode.dark;
    final colors = [
      dark ? SnapFitColors.deepCharcoal : SnapFitColors.pureWhite,
      dark ? SnapFitColors.surfaceDark : SnapFitColors.surfaceLight,
      SnapFitColors.accent,
    ];
    return Semantics(
      selected: active,
      child: Material(
        color: active
            ? ExperienceFormStyle.selection(context)
            : SnapFitColors.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: active
                ? ExperienceStyle.accent
                : ExperienceFormStyle.line(context),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('theme-option-${mode.name}'),
          onTap: _finishing ? null : () => _select(mode),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: compact ? 8 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: ExperienceFormStyle.ink(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: ExperienceFormStyle.text(
                            context,
                            15,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        active
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 22,
                        color: active
                            ? ExperienceStyle.accent
                            : ExperienceFormStyle.muted(context),
                      ),
                    ],
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 12),
                    ExcludeSemantics(
                      child: Row(
                        children: [
                          for (final color in colors)
                            Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  border: Border.all(
                                    color: ExperienceFormStyle.line(context),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
