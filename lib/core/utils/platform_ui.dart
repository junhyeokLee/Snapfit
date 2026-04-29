import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

IconData platformBackIcon() {
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return Icons.arrow_back_ios_new;
  }
  return Icons.arrow_back;
}

ScrollPhysics platformScrollPhysics({bool alwaysScrollable = false}) {
  final platform = defaultTargetPlatform;
  final parent = (platform == TargetPlatform.iOS ||
          platform == TargetPlatform.macOS)
      ? const BouncingScrollPhysics()
      : const ClampingScrollPhysics();
  if (alwaysScrollable) {
    return AlwaysScrollableScrollPhysics(parent: parent);
  }
  return parent;
}
