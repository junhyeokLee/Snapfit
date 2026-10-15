import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'browser_photo_files.dart';

List<BrowserPhotoFile> _files(web.FileList? list) => [
  if (list != null)
    for (var i = 0; i < list.length; i++)
      if (list.item(i) case final file?)
        BrowserPhotoFile(
          name: file.name,
          size: file.size,
          modifiedAt: DateTime.fromMillisecondsSinceEpoch(file.lastModified),
          readBytes: () async =>
              (await file.arrayBuffer().toDart).toDart.asUint8List(),
        ),
];

Future<List<BrowserPhotoFile>> pickBrowserPhotoFiles({
  bool multiple = true,
}) async {
  final input = web.HTMLInputElement()
    ..id = 'snapfit-browser-photo-input'
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp'
    ..multiple = multiple;
  input.setAttribute('aria-label', '앨범에 넣을 사진 파일 선택');
  input.style.display = 'none';
  final result = Completer<List<BrowserPhotoFile>>();
  Timer? focusCheck;
  final changed = ((web.Event _) {
    if (!result.isCompleted) result.complete(_files(input.files));
  }).toJS;
  final canceled = ((web.Event _) {
    if (!result.isCompleted) result.complete(const []);
  }).toJS;
  final focused = ((web.Event _) {
    focusCheck?.cancel();
    focusCheck = Timer(const Duration(milliseconds: 600), () {
      if (!result.isCompleted) result.complete(_files(input.files));
    });
  }).toJS;
  input.addEventListener('change', changed);
  input.addEventListener('cancel', canceled);
  web.window.addEventListener('focus', focused);
  web.document.body!.appendChild(input);
  try {
    input.click();
    return await result.future;
  } finally {
    input.removeEventListener('change', changed);
    input.removeEventListener('cancel', canceled);
    web.window.removeEventListener('focus', focused);
    focusCheck?.cancel();
    input.remove();
  }
}

BrowserPhotoDropSubscription listenBrowserPhotoDrop({
  required bool Function(double x, double y) hitTest,
  required void Function(List<BrowserPhotoFile> files) onFiles,
  required void Function(bool hovering) onHover,
}) => _BrowserDrop(hitTest, onFiles, onHover);

class _BrowserDrop implements BrowserPhotoDropSubscription {
  _BrowserDrop(this.hitTest, this.onFiles, this.onHover) {
    over = ((web.Event raw) {
      final event = raw as web.DragEvent;
      event.preventDefault();
      final inside = hitTest(
        event.clientX.toDouble(),
        event.clientY.toDouble(),
      );
      onHover(inside);
      if (inside && event.dataTransfer != null)
        event.dataTransfer!.dropEffect = 'copy';
    }).toJS;
    leave = ((web.Event _) => onHover(false)).toJS;
    drop = ((web.Event raw) {
      final event = raw as web.DragEvent;
      event.preventDefault();
      onHover(false);
      if (hitTest(event.clientX.toDouble(), event.clientY.toDouble())) {
        onFiles(_files(event.dataTransfer?.files));
      }
    }).toJS;
    web.document.addEventListener('dragover', over);
    web.document.addEventListener('dragleave', leave);
    web.document.addEventListener('drop', drop);
  }
  final bool Function(double x, double y) hitTest;
  final void Function(List<BrowserPhotoFile>) onFiles;
  final void Function(bool) onHover;
  late final JSFunction over, leave, drop;
  @override
  void dispose() {
    web.document.removeEventListener('dragover', over);
    web.document.removeEventListener('dragleave', leave);
    web.document.removeEventListener('drop', drop);
  }
}
