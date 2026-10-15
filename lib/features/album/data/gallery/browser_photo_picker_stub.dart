import 'browser_photo_files.dart';

Future<List<BrowserPhotoFile>> pickBrowserPhotoFiles({
  bool multiple = true,
}) async => const [];

BrowserPhotoDropSubscription listenBrowserPhotoDrop({
  required bool Function(double x, double y) hitTest,
  required void Function(List<BrowserPhotoFile> files) onFiles,
  required void Function(bool hovering) onHover,
}) => _NoDrop();

class _NoDrop implements BrowserPhotoDropSubscription {
  @override
  void dispose() {}
}
