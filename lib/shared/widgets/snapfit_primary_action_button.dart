import 'package:flutter/material.dart';

import '../../core/constants/snapfit_colors.dart';
import '../../core/theme/snapfit_design_tokens.dart';

/// 스냅핏 디자인 시스템 기준 Primary Action 버튼
///
/// 긴 버튼 이름과 큰 글자에서도 높이를 늘려 주요 동작을 읽을 수 있게 한다.
class SnapFitPrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const SnapFitPrimaryActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;
    final effectiveOnPressed = enabled ? onPressed : null;
    final scheme = Theme.of(context).colorScheme;
    final foreground = enabled
        ? scheme.onPrimary
        : SnapFitColors.textSecondaryOf(context);

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SnapFitType.style(
              14,
              weight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      liveRegion: isLoading,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            disabledBackgroundColor: SnapFitColors.surfaceOf(context),
            disabledForegroundColor: SnapFitColors.textSecondaryOf(context),
            elevation: 0,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            tapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
            animationDuration: SnapFitMotion.duration(
              context,
              SnapFitMotion.fast,
            ),
            shape: const StadiumBorder(),
          ),
          child: content,
        ),
      ),
    );
  }
}
