import 'package:flutter/widgets.dart';

import '../../../../core/constants/cover_size.dart';

/// The document, saved layer JSON and print renderer all use this coordinate
/// space. The measured canvas is only a viewport and never an insertion size.
Size editorReferenceCanvasSize(CoverSize cover) {
  final ratio = cover.ratio;
  if (!ratio.isFinite || ratio <= 0) {
    throw ArgumentError.value(ratio, 'cover.ratio');
  }
  return Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
}
