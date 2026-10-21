import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'experience_icon.dart';
import 'experience_style.dart';
import 'experience_form_style.dart';

/// Keeps the query mounted when collapsed, preserving each catalog's search.
class CatalogSearchDisclosure extends StatefulWidget {
  const CatalogSearchDisclosure({
    super.key,
    required this.child,
    required this.controller,
    this.leading,
    this.onClear,
    this.compactAction = false,
    this.initiallyExpanded = false,
  });
  final Widget child;
  final TextEditingController controller;
  final Widget? leading;
  final VoidCallback? onClear;
  final bool compactAction;
  final bool initiallyExpanded;

  @override
  State<CatalogSearchDisclosure> createState() =>
      _CatalogSearchDisclosureState();
}

class _CatalogSearchDisclosureState extends State<CatalogSearchDisclosure> {
  late bool _expanded = widget.initiallyExpanded;

  Widget _toggle(BuildContext context) => TextButton.icon(
    onPressed: () {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _expanded = !_expanded);
    },
    icon: _expanded
        ? const Icon(Icons.close, size: 20)
        : ExperienceIcon(
            'Search',
            size: 20,
            color: ExperienceFormStyle.ink(context),
          ),
    label: Text(
      _expanded ? '검색 접기' : '검색',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    style: TextButton.styleFrom(
      foregroundColor: ExperienceFormStyle.ink(context),
      textStyle: ExperienceStyle.text(13),
      minimumSize: const Size(48, 44),
    ),
  );

  @override
  Widget build(BuildContext context) => kIsWeb
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(height: 14),
            ],
            widget.child,
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (widget.leading != null)
                  Expanded(child: widget.leading!)
                else
                  const Spacer(),
                const SizedBox(width: 8),
                if (widget.compactAction)
                  Flexible(child: _toggle(context))
                else
                  _toggle(context),
              ],
            ),
            Offstage(
              offstage: !_expanded,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: widget.child,
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) =>
                  !_expanded && value.text.trim().isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '검색: ${value.text.trim()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ExperienceStyle.text(
                                12,
                                color: ExperienceFormStyle.muted(context),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '검색 지우기',
                            onPressed: () {
                              widget.controller.clear();
                              widget.onClear?.call();
                            },
                            icon: const Icon(Icons.close, size: 18),
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
}
