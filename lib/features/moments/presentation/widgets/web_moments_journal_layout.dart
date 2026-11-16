import 'package:flutter/material.dart';

import 'moments_widgets.dart';

/// Records keep the largest surface; progress and the growing book sit beside
/// them on wide screens. Compact screens keep month tools together before the
/// continuous record timeline rather than inserting them between photographs.
class WebMomentsJournalLayout extends StatelessWidget {
  const WebMomentsJournalLayout({
    super.key,
    required this.monthNavigation,
    required this.records,
    required this.weekly,
    this.recap,
    this.album,
  });

  final Widget monthNavigation, weekly;
  final List<Widget> records;
  final Widget? recap, album;

  Widget _rail({bool includeWeekly = true}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (includeWeekly) weekly,
      if (recap != null) ...[const SizedBox(height: 16), recap!],
      if (album != null) ...[const SizedBox(height: 16), album!],
      const SizedBox(height: 24),
      const MomentPrivateNote(),
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide =
          bounds.maxWidth >= 880 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.4;
      if (!wide) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            weekly,
            const SizedBox(height: 20),
            monthNavigation,
            const SizedBox(height: 12),
            if (recap != null || album != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (recap != null) recap!,
                  if (album != null) album!,
                ],
              ),
              const SizedBox(height: 18),
            ],
            ...records,
            const SizedBox(height: 20),
            const MomentPrivateNote(),
          ],
        );
      }
      return Row(
        key: const ValueKey('moments-desktop-columns'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                monthNavigation,
                const SizedBox(height: 12),
                ...records,
              ],
            ),
          ),
          const SizedBox(width: 36),
          SizedBox(width: 300, child: _rail()),
        ],
      );
    },
  );
}
