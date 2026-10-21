import 'dart:async';

import 'package:flutter/material.dart';

/// Keeps visual counts current while announcing the final search result once
/// typing or repeated filter changes have paused. It never moves input focus.
class CatalogResultStatus extends StatefulWidget {
  const CatalogResultStatus({
    super.key,
    required this.label,
    this.semanticLabel,
    this.debounceToken,
    this.style,
  });

  final String label;
  final String? semanticLabel;
  // The query or filters can change without changing the result count.
  final Object? debounceToken;
  final TextStyle? style;

  @override
  State<CatalogResultStatus> createState() => _CatalogResultStatusState();
}

class _CatalogResultStatusState extends State<CatalogResultStatus> {
  Timer? _announcement;
  late String _announcedLabel = widget.semanticLabel ?? widget.label;

  @override
  void didUpdateWidget(CatalogResultStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextLabel = widget.semanticLabel ?? widget.label;
    if (nextLabel == (oldWidget.semanticLabel ?? oldWidget.label) &&
        widget.debounceToken == oldWidget.debounceToken) {
      return;
    }
    _announcement?.cancel();
    if (nextLabel == _announcedLabel) return;
    _announcement = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _announcedLabel = nextLabel);
    });
  }

  @override
  void dispose() {
    _announcement?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('catalog-result-announcement'),
    container: true,
    liveRegion: true,
    label: _announcedLabel,
    child: ExcludeSemantics(child: Text(widget.label, style: widget.style)),
  );
}
