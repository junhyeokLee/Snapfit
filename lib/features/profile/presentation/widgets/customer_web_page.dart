import 'package:flutter/material.dart';

import '../../../../shared/web/web_design.dart';

/// Secondary customer pages share website navigation and a desktop content
/// grid. Existing controllers, access checks and actions stay in their screen.
class CustomerWebPage extends StatelessWidget {
  const CustomerWebPage({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.description,
    this.sidebar,
    this.actions = const [],
    this.scrollBody = false,
    this.allowBack = true,
    this.onBack,
    this.showNavigation = true,
    this.section = WebSection.account,
  });

  final String title;
  final String? eyebrow, description;
  final Widget child;
  final Widget? sidebar;
  final List<Widget> actions;
  final bool scrollBody, allowBack, showNavigation;
  final VoidCallback? onBack;
  final WebSection section;

  @override
  Widget build(BuildContext context) => SnapFitWebShell(
    title: title,
    section: section,
    showNavigation: showNavigation,
    actions: [
      OutlinedButton.icon(
        onPressed: allowBack ? onBack ?? () => Navigator.maybePop(context) : null,
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('이전 화면'),
      ),
      ...actions,
    ],
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      WebPageHeading(title: title, eyebrow: eyebrow, description: description),
      const SizedBox(height: 28),
      Expanded(child: LayoutBuilder(builder: (context, bounds) {
        final content = WebSurface(
          child: scrollBody ? SingleChildScrollView(child: child) : child,
        );
        if (sidebar == null) return content;
        if (bounds.maxWidth < 900) {
          // Keep forms and list scrolling in one bounded content pane. The
          // same contextual guidance remains available below the heading.
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ConstrainedBox(constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(child: sidebar!)),
            const SizedBox(height: 20),
            Expanded(child: content),
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 280, child: SingleChildScrollView(child: sidebar!)),
          const SizedBox(width: 28),
          Expanded(child: content),
        ]);
      })),
    ]),
  );
}

class CustomerWebNote extends StatelessWidget {
  const CustomerWebNote({super.key, required this.title, required this.message,
    this.child});
  final String title, message;
  final Widget? child;
  @override
  Widget build(BuildContext context) => WebSurface(
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
        color: WebPalette.of(context).ink)),
      const SizedBox(height: 12),
      Text(message, style: TextStyle(fontSize: 13, height: 1.8,
        color: WebPalette.of(context).muted)),
      if (child != null) ...[const SizedBox(height: 20), child!],
    ]),
  );
}
