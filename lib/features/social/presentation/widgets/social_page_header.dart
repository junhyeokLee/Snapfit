import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import 'social_widgets.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// One local toolbar below the shared browser frame, also used by the app.
class SocialPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const SocialPageHeader({
    super.key,
    required this.title,
    this.back = true,
    this.actions = const [],
  });

  final String title;
  final bool back;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return ExperienceHeader(
        title: title,
        back: back,
        showNotifications: false,
        showDivider: false,
        actions: actions,
      );
    }
    return Material(
      color: SocialStyle.background(context),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: WebPageLayout.horizontalInset(
            MediaQuery.sizeOf(context).width,
          ),
        ),
        child: Row(
          children: [
            if (back) ...[
              IconButton(
                tooltip: '뒤로가기',
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    WebNavigationScope.maybeOf(
                      context,
                    )?.onNavigate(WebSection.feed);
                  }
                },
                icon: const ExperienceIcon('ArrowLeft', size: 22),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: ExperienceFormStyle.text(
                      context,
                      22,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
