import 'package:flutter/material.dart';

import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../shared/widgets/experience_style.dart'
    show ExperienceNavigationScope;
import '../../../../notification/presentation/views/notification_screen.dart';
import '../../../../moments/presentation/moments_navigation.dart';

/// Shared chrome stays mounted while the cover and collection trade places.
class HomeAlbumHeader extends StatelessWidget {
  const HomeAlbumHeader({
    super.key,
    required this.collection,
    this.onToggleView,
    this.onCreateAlbum,
    this.onResumeDraft,
    this.createButtonBuilder,
    this.showMomentsEntry = true,
  });

  final bool collection;
  final VoidCallback? onToggleView, onCreateAlbum, onResumeDraft;
  final Widget Function(Widget button)? createButtonBuilder;
  final bool showMomentsEntry;

  Widget _action({
    required Key key,
    required String tooltip,
    required Widget icon,
    required VoidCallback? onPressed,
  }) => IconButton(
    key: key,
    tooltip: tooltip,
    onPressed: onPressed,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    style: const ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    icon: icon,
  );

  Widget _createButton(BuildContext context) {
    final button = _action(
      key: const ValueKey('home-create-album'),
      tooltip: '새 앨범',
      onPressed: onCreateAlbum,
      icon: ExperienceIcon(
        'Plus',
        size: 22,
        color: ExperienceFormStyle.ink(context),
      ),
    );
    return createButtonBuilder?.call(button) ?? button;
  }

  double _textWidth(BuildContext context, String value, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  void _openNotifications(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<ExperienceNavigationScope>();
    if (scope != null && !Navigator.canPop(context)) {
      scope.onNavigate(3);
    } else {
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const NotificationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = ExperienceFormStyle.text(
      context,
      27,
      weight: FontWeight.w600,
    ).copyWith(height: 1.25, letterSpacing: -.8);
    final wordmarkStyle = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.1,
      color: ExperienceFormStyle.selectionInk(context),
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'snapfit',
          key: const ValueKey('home-bookshelf-wordmark'),
          semanticsLabel: 'snapfit',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: wordmarkStyle,
        ),
        const SizedBox(height: 3),
        Semantics(
          header: true,
          child: Text(
            '내 앨범',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMomentsEntry)
          _action(
            key: const ValueKey('home-moments-entry'),
            tooltip: '나의 기록',
            onPressed: () => openMoments(context),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 21),
          ),
        _action(
          key: const ValueKey('home-album-view-toggle'),
          tooltip: collection ? '표지로 보기' : '앨범 목록',
          onPressed: onToggleView,
          icon: ExperienceIcon(
            collection ? 'BookOpen' : 'LayoutGrid',
            size: 21,
          ),
        ),
        _createButton(context),
        _action(
          key: const ValueKey('home-album-notifications'),
          tooltip: '알림',
          onPressed: () => _openNotifications(context),
          icon: const ExperienceIcon('Bell', size: 21),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, bounds) {
              final titleWidth = _textWidth(context, '내 앨범', titleStyle);
              final wordmarkWidth = _textWidth(
                context,
                'snapfit',
                wordmarkStyle,
              );
              final labelWidth = titleWidth > wordmarkWidth
                  ? titleWidth
                  : wordmarkWidth;
              final actionsWidth = showMomentsEntry ? 176.0 : 132.0;
              // Large text gets its own readable line instead of shrinking the
              // title or bringing back a separate full-width journal banner.
              final stacked = labelWidth + actionsWidth + 8 > bounds.maxWidth;
              // Keep the action subtree mounted across rotation, including
              // the first-visit guide attached to the creation button.
              return SizedBox(
                width: bounds.maxWidth,
                child: Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: stacked ? bounds.maxWidth : labelWidth,
                      child: title,
                    ),
                    SizedBox(
                      width: stacked ? bounds.maxWidth : actionsWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: actions,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (onResumeDraft != null)
            TextButton.icon(
              key: const ValueKey('home-resume-draft'),
              onPressed: onResumeDraft,
              style: TextButton.styleFrom(
                foregroundColor: ExperienceFormStyle.selectionInk(context),
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              icon: const ExperienceIcon('History', size: 18),
              label: const Text('이어서 만들기'),
            ),
        ],
      ),
    );
  }
}
