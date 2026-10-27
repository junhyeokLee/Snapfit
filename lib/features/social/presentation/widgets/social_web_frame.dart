import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../shared/web/web_design.dart';
import 'social_theme.dart';

export '../../../../shared/web/web_design.dart' show WebSection;

/// Keeps browser destinations available around the social screen's local
/// toolbar. This adds no Navigator: login returns and browser history continue
/// to be owned by the existing WebNavigationScope and WebAppRouter.
class SocialWebFrame extends StatelessWidget {
  const SocialWebFrame({
    super.key,
    required this.child,
    this.section = WebSection.feed,
  });

  final Widget child;
  final WebSection section;

  @override
  Widget build(BuildContext context) => Theme(
    data: SocialTheme.from(Theme.of(context)),
    child: kIsWeb
        ? SnapFitWebShell(section: section, workspace: true, child: child)
        : child,
  );
}
