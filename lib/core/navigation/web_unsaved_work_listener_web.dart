import 'dart:js_interop';
import 'package:web/web.dart' as web;

void Function() listenForUnsavedWebWork(bool Function() hasChanges) {
  final listener = ((web.BeforeUnloadEvent event) {
    if (!hasChanges()) return;
    event.preventDefault();
    event.returnValue = '';
  }).toJS;
  web.window.addEventListener('beforeunload', listener);
  return () => web.window.removeEventListener('beforeunload', listener);
}
