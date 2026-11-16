import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../album/printing/print_album_document.dart';
import '../../album/printing/print_image_header.dart';
import '../../social/data/social_album_snapshot.dart';
import '../domain/moment_photo_design.dart';
import '../domain/moment_photo_format.dart';
import '../domain/moment_record.dart';
import 'moment_photo_codec.dart';

/// Only the selected, flattened artwork crosses the platform share boundary.
/// No private storage URI, signed URL, caption or editable document is exposed.
class MomentShareImage {
  const MomentShareImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width, height;
  String get mimeType => 'image/png';
  String get fileName => 'snapfit-moment.png';
  double get aspectRatio => width / height;
}

class MomentShareExportCancelled implements Exception {
  const MomentShareExportCancelled();
}

class MomentShareExportBusy implements Exception {
  const MomentShareExportBusy();
}

/// Creates one image from saved layers, independently of the mounted feed and
/// its loading indicators. Uses the existing native/web print renderer, which
/// prepares fonts and original pixels before painting and disposes each image.
class MomentPhotoShareExporter {
  MomentPhotoShareExporter({SocialSnapshotRenderer? renderer})
    : _renderer = renderer ?? SocialSnapshotRenderer();

  final SocialSnapshotRenderer _renderer;
  static bool _exporting = false;
  static const maximumOutputEdge = 1440;
  static const maximumOutputBytes = 8 * 1024 * 1024;
  static const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

  /// The host passes its mounted/owner/revision guard. A cancelled export keeps
  /// its temporary render resources until cleanup, but never delivers an image
  /// or lets a second render overlap it. The host opens its share UI afterwards.
  Future<MomentShareImage> export({
    required MomentPhoto photo,
    required ThemeData theme,
    bool Function()? isActive,
  }) async {
    void check() {
      if (isActive != null && !isActive()) {
        throw const MomentShareExportCancelled();
      }
    }

    check();
    if (_exporting) throw const MomentShareExportBusy();
    _exporting = true;
    try {
      // Old unformatted photos use the same complete-photo square composition
      // as the journal. Existing legacy canvases are used exactly as saved.
      final design = photo.design ?? _defaultDesign(photo);
      final page = PrintAlbumPage(
        index: 0,
        isCover: false,
        canvasSize: design.canvasSize,
        layers: design.layersForPhoto(photo.storageUri),
        backgroundColor: design.backgroundColor,
      );
      await _renderer.prepareFonts([page]);
      check();
      var png = await _renderer.renderPage(page, theme: theme, watermark: true);
      check();
      var size = _validate(png, design);
      // RepaintBoundary rounds its physical extent up. A fractional saved
      // canvas can produce one extra edge pixel; bound only that rounding case
      // without decoding the usual output a second time.
      if (math.max(size.width, size.height) > maximumOutputEdge) {
        final normalized = await prepareMomentPhoto(
          png,
          maxEdge: maximumOutputEdge,
          maxOutputBytes: maximumOutputBytes,
        );
        check();
        png = normalized.bytes;
        size = _validate(png, design);
      }
      check();
      return MomentShareImage(
        bytes: png,
        width: size.width.toInt(),
        height: size.height.toInt(),
      );
    } finally {
      _exporting = false;
    }
  }

  static MomentPhotoDesign _defaultDesign(MomentPhoto photo) {
    if (photo.width <= 0 || photo.height <= 0) {
      throw const FormatException('사진 크기를 확인하지 못했어요. 기록을 다시 열어 주세요.');
    }
    return newMomentPhotoDesign(
      photoSize: Size(photo.width.toDouble(), photo.height.toDouble()),
      photoSource: photo.storageUri,
    );
  }

  static Size _validate(Uint8List png, MomentPhotoDesign design) {
    if (png.length < 24 || png.length > maximumOutputBytes) _invalid();
    for (var index = 0; index < _pngSignature.length; index++) {
      if (png[index] != _pngSignature[index]) _invalid();
    }
    final size = printEncodedImageSize(png);
    if (size.width > maximumOutputEdge + 1 ||
        size.height > maximumOutputEdge + 1 ||
        (size.width - size.height * design.aspectRatio).abs() >
            1 + design.aspectRatio) {
      _invalid();
    }
    return size;
  }

  static Never _invalid() =>
      throw const FormatException('공유할 사진을 준비하지 못했어요. 다시 시도해 주세요.');
}
