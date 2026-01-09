import 'package:flutter/material.dart';

/// 스크롤 글로우 제거
class NoGlow extends ScrollBehavior {
  const NoGlow();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
