import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Immutable transport views of one completed PDF. Splitting never encodes,
/// compresses, resizes, or copies its artwork bytes.
class PrintPdfUploadPlan {
  PrintPdfUploadPlan(this.bytes)
    : parts = bytes.length <= maximumStorageObjectBytes
          ? const []
          : List.unmodifiable([
              for (var offset = 0; offset < bytes.length; offset += partBytes)
                Uint8List.sublistView(
                  bytes,
                  offset,
                  offset + partBytes < bytes.length
                      ? offset + partBytes
                      : bytes.length,
                ),
            ]);

  static const maximumStorageObjectBytes = 50000000;
  static const partBytes = 16000000;
  static const maximumCoverBytes = 150000000;
  static const maximumInteriorBytes = 500000000;

  final Uint8List bytes;
  final List<Uint8List> parts;
  bool get isMultipart => parts.isNotEmpty;

  late final Map<String, dynamic> declaration = Map.unmodifiable({
    'bytes': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
    if (isMultipart)
      'parts': List.unmodifiable([
        for (final part in parts)
          Map<String, dynamic>.unmodifiable({
            'bytes': part.length,
            'sha256': sha256.convert(part).toString(),
          }),
      ]),
  });
}
