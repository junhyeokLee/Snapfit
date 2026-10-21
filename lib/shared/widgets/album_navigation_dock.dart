import 'package:flutter/material.dart';

import 'album_stage_style.dart';
import 'experience_icon.dart';

/// Shared, content-first navigation for the shelf and the open album.
class AlbumNavigationDock extends StatelessWidget {
  const AlbumNavigationDock({
    super.key,
    required this.primary,
    required this.onPrevious,
    required this.onNext,
    this.previousLabel = '이전 페이지',
    this.nextLabel = '다음 페이지',
    this.height = 48,
  });

  final Widget primary;
  final VoidCallback? onPrevious, onNext;
  final String previousLabel, nextLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget arrow(bool previous) {
      final onTap = previous ? onPrevious : onNext;
      final label = previous ? previousLabel : nextLabel;
      return Semantics(
        label: label,
        button: true,
        enabled: onTap != null,
        excludeSemantics: true,
        onTap: onTap,
        child: IconButton(
          tooltip: label,
          onPressed: onTap,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: Transform.flip(
            flipX: previous,
            child: ExperienceIcon(
              'ChevronRight',
              size: 23,
              color: AlbumStageStyle.ink(
                context,
              ).withValues(alpha: onTap == null ? .24 : 1),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(child: Center(child: arrow(true))),
          Expanded(flex: 2, child: Center(child: primary)),
          Expanded(child: Center(child: arrow(false))),
        ],
      ),
    );
  }
}
