import 'package:flutter/material.dart';

import '../../../../shared/web/web_design.dart';

/// Customer forms use one page scroll, while history panes keep their own
/// bounded list. Supporting information sits beside the task on desktop.
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
        onPressed: allowBack
            ? onBack ?? () => Navigator.maybePop(context)
            : null,
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('이전'),
      ),
      ...actions,
    ],
    child: LayoutBuilder(
      builder: (context, bounds) {
        final heading = WebPageHeading(
          title: title,
          eyebrow: eyebrow,
          description: description,
        );
        final content = WebSurface(child: child);
        if (scrollBody) {
          return SingleChildScrollView(
            key: const ValueKey('customer-web-page-scroll'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 24),
                CustomerWebColumns(primary: content, secondary: sidebar),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
        return NestedScrollView(
          key: const ValueKey('customer-web-bounded-page'),
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: 24),
                  if (sidebar != null && bounds.maxWidth < 940) ...[
                    WebSurface(
                      padding: EdgeInsets.zero,
                      child: ExpansionTile(
                        key: const ValueKey('customer-web-context-toggle'),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          12,
                        ),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: const Text('요약 및 안내'),
                        children: [sidebar!],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ],
          body: bounds.maxWidth >= 940 && sidebar != null
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 300,
                      child: SingleChildScrollView(child: sidebar!),
                    ),
                  ],
                )
              : content,
        );
      },
    ),
  );
}

/// A task and its summary share a reading order, including narrow browsers.
class CustomerWebColumns extends StatelessWidget {
  const CustomerWebColumns({
    super.key,
    required this.primary,
    this.secondary,
    this.summaryWidth = 320,
    this.breakpoint = 940,
  });
  final Widget primary;
  final Widget? secondary;
  final double summaryWidth, breakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (secondary == null) return primary;
      if (bounds.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, const SizedBox(height: 20), secondary!],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: primary),
          const SizedBox(width: 24),
          SizedBox(width: summaryWidth, child: secondary!),
        ],
      );
    },
  );
}

class CustomerWebNote extends StatelessWidget {
  const CustomerWebNote({
    super.key,
    required this.title,
    required this.message,
    this.child,
  });
  final String title, message;
  final Widget? child;
  @override
  Widget build(BuildContext context) => WebSurface(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: WebPalette.of(context).ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: TextStyle(
            fontSize: 13,
            height: 1.65,
            color: WebPalette.of(context).muted,
          ),
        ),
        if (child != null) ...[const SizedBox(height: 20), child!],
      ],
    ),
  );
}
