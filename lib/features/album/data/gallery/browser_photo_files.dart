import 'dart:typed_data';

class BrowserPhotoFile {
  const BrowserPhotoFile({
    required this.name,
    required this.size,
    required this.readBytes,
    this.modifiedAt,
  });
  final String name;
  final int size;
  final DateTime? modifiedAt;
  final Future<Uint8List> Function() readBytes;
}

abstract class BrowserPhotoDropSubscription {
  void dispose();
}
