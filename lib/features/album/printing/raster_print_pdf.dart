import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as bitmap;
import 'srgb_profile.dart';

/// PDF 1.4 writer for opaque 300 dpi sRGB page artwork, JPEG quality 95.
/// Flutter has already composited text, clips, frames and transparency exactly.
/// No PDF/X or CMYK claim is made. RGB suits the vendor's photographic paper;
/// sRGB is our output standard, with colour appearance checked in our sample.
class RasterPrintPdf {
  final List<_RasterPage> _pages = [];
  int _encodedBytes = 0;
  int get pageCount => _pages.length;

  /// Reuses an already-encoded blank page while preserving physical page count.
  void repeatLastPage() {
    if (_pages.isEmpty) throw StateError('print_pdf_empty');
    _encodedBytes += _pages.last.rgb.length;
    if (_encodedBytes > 90 * 1024 * 1024) {
      throw StateError('print_pdf_exceeds_90mb_limit');
    }
    _pages.add(_pages.last);
  }

  Future<void> addPage(
    Image image, {
    required Size sizeMm,
    Rect? trimMm,
  }) async {
    final rgba = (await image.toByteData(
      format: ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    final jpeg = await compute(_encodeJpeg, (
      rgba: rgba,
      width: image.width,
      height: image.height,
    ));
    _encodedBytes += jpeg.length;
    if (_encodedBytes > 90 * 1024 * 1024) {
      throw StateError('print_pdf_exceeds_90mb_limit');
    }
    _pages.add(_RasterPage(image.width, image.height, jpeg, sizeMm, trimMm));
  }

  Uint8List save() {
    if (_pages.isEmpty) throw StateError('print_pdf_empty');
    final out = BytesBuilder(copy: false);
    final offsets = <int>[0];
    void write(String value) => out.add(ascii.encode(value));
    void object(int id, String dictionary, [Uint8List? stream]) {
      offsets.add(out.length);
      write('$id 0 obj\n$dictionary');
      if (stream != null) {
        write('\nstream\n');
        out.add(stream);
        write('\nendstream');
      }
      write('\nendobj\n');
    }

    String number(double value) => value.toStringAsFixed(5);
    double pt(double mm) => mm * 72 / 25.4;
    write('%PDF-1.4\n%SNAPFIT-RASTER\n');
    object(1, '<< /Type /Catalog /Pages 2 0 R >>');
    object(
      2,
      '<< /Type /Pages /Count ${_pages.length} /Kids [${List.generate(_pages.length, (i) => '${3 + i * 3} 0 R').join(' ')}] >>',
    );
    final profileId = 3 + _pages.length * 3;
    for (int index = 0; index < _pages.length; index++) {
      final page = _pages[index];
      final id = 3 + index * 3;
      final w = number(pt(page.sizeMm.width)),
          h = number(pt(page.sizeMm.height));
      final trim = page.trimMm;
      final trimBox = trim == null
          ? ''
          : '/TrimBox [${number(pt(trim.left))} '
                '${number(pt(page.sizeMm.height - trim.bottom))} ${number(pt(trim.right))} '
                '${number(pt(page.sizeMm.height - trim.top))}]';
      object(
        id,
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $w $h] '
        '/BleedBox [0 0 $w $h] $trimBox /Resources << /XObject << /Im0 ${id + 1} 0 R >> >> '
        '/Contents ${id + 2} 0 R >>',
      );
      object(
        id + 1,
        '<< /Type /XObject /Subtype /Image /Width ${page.width} '
        '/Height ${page.height} /ColorSpace [/ICCBased $profileId 0 R] /BitsPerComponent 8 '
        '/Filter /DCTDecode /Length ${page.rgb.length} >>',
        page.rgb,
      );
      final content = Uint8List.fromList(
        ascii.encode('q\n$w 0 0 $h 0 0 cm\n/Im0 Do\nQ\n'),
      );
      object(id + 2, '<< /Length ${content.length} >>', content);
    }
    final profile = printSrgbProfile;
    object(
      profileId,
      '<< /N 3 /Alternate /DeviceRGB /Length ${profile.length} >>',
      profile,
    );
    final xref = out.length;
    write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    write(
      'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
    );
    return out.takeBytes();
  }
}

Uint8List _encodeJpeg(({Uint8List rgba, int width, int height}) data) {
  final image = bitmap.Image.fromBytes(
    width: data.width,
    height: data.height,
    bytes: data.rgba.buffer,
    numChannels: 4,
  );
  return bitmap.encodeJpg(image, quality: 95);
}

class _RasterPage {
  _RasterPage(this.width, this.height, this.rgb, this.sizeMm, this.trimMm);
  final int width, height;
  final Uint8List rgb;
  final Size sizeMm;
  final Rect? trimMm;
}
