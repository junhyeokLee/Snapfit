import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/profile/data/print_pdf_upload_plan.dart';

class _DigestSink implements Sink<Digest> {
  final values = <Digest>[];
  @override
  void add(Digest data) => values.add(data);
  @override
  void close() {}
}

void main() {
  test('a 50 MB PDF retains the direct upload contract', () {
    final bytes = Uint8List(50000000);
    final plan = PrintPdfUploadPlan(bytes);
    expect(plan.isMultipart, isFalse);
    expect(plan.parts, isEmpty);
    expect(plan.declaration.keys, ['bytes', 'sha256']);
    expect(plan.declaration['bytes'], bytes.length);
  });

  test('one byte over the storage object limit uses bounded original views', () {
    final bytes = Uint8List(50000001);
    bytes[16000000] = 137;
    bytes.last = 219;
    final plan = PrintPdfUploadPlan(bytes);
    expect(plan.parts.map((part) => part.length), [
      16000000,
      16000000,
      16000000,
      2000001,
    ]);
    expect(plan.parts[1].first, 137);
    expect(plan.parts.last.last, 219);
    // A view keeps the original storage and offset; no second full PDF exists.
    expect(plan.parts[1].offsetInBytes, bytes.offsetInBytes + 16000000);
    bytes[16000000] = 42;
    expect(plan.parts[1].first, 42);
    expect(plan.declaration['sha256'], sha256.convert(bytes).toString());
  });

  final fixture = File(
    Platform.environment['SNAPFIT_PREPAYMENT_80_FIXTURE'] ??
        'output/pdf/print-worker-hard300-80-fixture-2026-10-14/interior.pdf',
  );
  test(
    'actual 80 page JPEG95 PDF survives part transport byte for byte',
    () async {
      final original = await fixture.readAsBytes();
      expect(original.length, greaterThan(50000000));
      expect(original.length, lessThanOrEqualTo(500000000));
      final plan = PrintPdfUploadPlan(original);
      expect(plan.isMultipart, isTrue);
      final combinedHash = _DigestSink();
      final sink = sha256.startChunkedConversion(combinedHash);
      var offset = 0;
      final declaredParts = plan.declaration['parts'] as List;
      for (var index = 0; index < plan.parts.length; index++) {
        final part = plan.parts[index];
        expect(part.offsetInBytes, original.offsetInBytes + offset);
        expect(part.length, lessThanOrEqualTo(16000000));
        expect(declaredParts[index]['bytes'], part.length);
        expect(declaredParts[index]['sha256'], sha256.convert(part).toString());
        sink.add(part);
        offset += part.length;
      }
      sink.close();
      expect(offset, original.length);
      expect(combinedHash.values.single.toString(), plan.declaration['sha256']);
      expect(combinedHash.values.single, sha256.convert(original));
    },
    skip: !fixture.existsSync()
        ? 'Set SNAPFIT_PREPAYMENT_80_FIXTURE to the actual generated 80 page PDF.'
        : false,
  );
}
