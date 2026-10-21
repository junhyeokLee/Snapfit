import 'package:flutter/material.dart';

import '../../../../../shared/web/web_design.dart';

/// Loading messages can wrap at the browser's chosen text scale.
class WebCatalogFooter extends StatelessWidget {
  const WebCatalogFooter({
    super.key,
    required this.loading,
    required this.visible,
    required this.total,
    required this.onMore,
    this.noun = '항목',
  });
  final bool loading;
  final int visible, total;
  final VoidCallback onMore;
  final String noun;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 56),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: loading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text('$noun을 더 불러오고 있어요', textAlign: TextAlign.center),
                ),
              ],
            )
          : visible < total
          ? Center(
              child: TextButton(
                onPressed: onMore,
                child: Text(
                  '더 보기 · $visible / $total',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Center(
              child: Text(
                '$total개 $noun을 모두 확인했어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: WebPalette.of(context).muted,
                ),
              ),
            ),
    ),
  );
}
