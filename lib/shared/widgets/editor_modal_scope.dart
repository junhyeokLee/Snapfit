import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Identifies only popup routes opened from the same editing provider scope.
String editorModalRouteName(BuildContext context) =>
    'snapfit-editor-modal:${identityHashCode(ProviderScope.containerOf(context, listen: false))}';

RouteSettings editorModalRouteSettings(BuildContext context) =>
    RouteSettings(name: editorModalRouteName(context));
