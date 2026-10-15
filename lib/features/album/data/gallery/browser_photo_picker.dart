import 'browser_photo_files.dart';
import 'browser_photo_picker_stub.dart'
    if (dart.library.js_interop) 'browser_photo_picker_web.dart'
    as platform;
export 'browser_photo_files.dart';

Future<List<BrowserPhotoFile>> pickBrowserPhotoFiles({bool multiple = true}) =>
    platform.pickBrowserPhotoFiles(multiple: multiple);

BrowserPhotoDropSubscription listenBrowserPhotoDrop({
  required bool Function(double x, double y) hitTest,
  required void Function(List<BrowserPhotoFile> files) onFiles,
  required void Function(bool hovering) onHover,
}) => platform.listenBrowserPhotoDrop(
  hitTest: hitTest,
  onFiles: onFiles,
  onHover: onHover,
);
