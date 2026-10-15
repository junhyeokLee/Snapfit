import 'package:flutter/widgets.dart';

import 'web_unsaved_work_listener_stub.dart'
    if (dart.library.js_interop) 'web_unsaved_work_listener_web.dart';

/// A browser refresh/close cannot serialize unsaved local photo files. Warn
/// through the browser's own leave-page prompt while the editor is dirty.
class WebUnsavedWorkGuard extends StatefulWidget {
  const WebUnsavedWorkGuard({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
  });
  final bool Function() hasUnsavedChanges;
  final Widget child;
  @override
  State<WebUnsavedWorkGuard> createState() => _WebUnsavedWorkGuardState();
}

class _WebUnsavedWorkGuardState extends State<WebUnsavedWorkGuard> {
  late final VoidCallback _stop;
  @override
  void initState() {
    super.initState();
    _stop = listenForUnsavedWebWork(() => widget.hasUnsavedChanges());
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
