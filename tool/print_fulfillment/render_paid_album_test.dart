import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';

import '../print_samples/redprinting_soft_sample.dart';

class _RealHttp extends HttpOverrides {}

/// Low-entropy artwork checks 80 real pages without changing 300dpi/JPEG95.
/// The original dense test card remains available for the 90MiB limit fixture.
Future<Uint8List> compactWorkerTestCard() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xfff6f3eb), ui.BlendMode.src);
  final paint = ui.Paint();
  const colors = [
    ui.Color(0xffbc354a),
    ui.Color(0xff327665),
    ui.Color(0xff3061a5),
    ui.Color(0xffe1a348),
  ];
  for (var index = 0; index < colors.length; index++) {
    paint.color = colors[index];
    canvas.drawRect(ui.Rect.fromLTWH(240 + index * 1080, 240, 960, 720), paint);
  }
  const gradient = ui.Rect.fromLTWH(240, 1140, 4320, 1260);
  paint.shader = ui.Gradient.linear(gradient.topLeft, gradient.bottomRight, [
    const ui.Color(0xff263646),
    const ui.Color(0xffb4dad2),
  ]);
  canvas.drawRect(gradient, paint);
  paint.shader = null;
  paint.color = const ui.Color(0xfff6f3eb);
  canvas.drawCircle(const ui.Offset(2400, 1770), 390, paint);
  paint.color = const ui.Color(0xff263646);
  paint.style = ui.PaintingStyle.stroke;
  paint.strokeWidth = 8;
  canvas.drawRect(const ui.Rect.fromLTWH(120, 120, 4560, 3360), paint);
  for (var index = 0; index <= 12; index++) {
    canvas.drawLine(
      ui.Offset(240 + index * 360, 2640),
      ui.Offset(240 + index * 360, 3240),
      paint,
    );
  }
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(4800, 3600);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

/// Synthetic software fixtures are never supplier or physical-sample approval.
Map<String, dynamic> syntheticWorkerFixture(String scenario, String source) {
  if (scenario != 'SOFT_20' && scenario != 'HARD_80') {
    throw StateError('print_fixture_scenario_invalid');
  }
  final snapshot =
      (jsonDecode(
                jsonEncode(
                  softSampleAlbumSnapshot(),
                ).replaceAll(sampleTestCardSource, source),
              )
              as Map)
          .cast<String, dynamic>();
  final hard = scenario == 'HARD_80';
  final product = PrintProduct.forId(
    hard ? 'REDP_300_HARD' : 'REDP_200X150_SOFT',
  )!.toJson();
  snapshot['printProduct'] = product;
  final album = (snapshot['album'] as Map).cast<String, dynamic>();
  final cover = (album['cover_layers_json'] as Map).cast<String, dynamic>();
  cover['printProduct'] = product;
  if (hard) {
    album['ratio'] = 1;
    final originals = (cover['pages'] as List).cast<Map>();
    final pages = <Map<String, dynamic>>[];
    for (var index = 0; index <= 80; index++) {
      final original = originals[index == 0 ? 0 : 1 + (index - 1) % 20];
      final page = (jsonDecode(jsonEncode(original)) as Map)
          .cast<String, dynamic>();
      page['index'] = index;
      for (final rawLayer in page['layers'] as List) {
        final layer = rawLayer as Map;
        final id = layer['id'].toString();
        layer['id'] = 'fixture-$index-$id';
        final payload = layer['payload'] as Map;
        final text = payload['text'];
        if (text is String) {
          payload['text'] = text
              .replaceAll('200×150mm', '300×300mm')
              .replaceAll('소프트커버', '하드커버')
              .replaceAll('20쪽', '80쪽')
              .replaceAll('1-20', '1-80');
          if (id.endsWith('-footer')) {
            payload['text'] = '스냅핏 합성 개발 검수 · $index / 80';
          } else if (id.endsWith('-heading') && index > 0) {
            payload['text'] =
                '${index.toString().padLeft(2, '0')}  '
                '${text.replaceFirst(RegExp(r'^\d+\s+'), '')}';
          }
        }
      }
      pages.add(page);
    }
    cover['pages'] = pages;
  }
  final spec = <String, dynamic>{
    ...softSampleSpec().data,
    'verified': true,
    'specVersion': hard
        ? 'LOCAL_STUB_HARD300_80_V1'
        : 'LOCAL_STUB_APPROVED_SOFT20_V1',
    'id': product['id'],
    'coverType': hard ? 'HARD' : 'SOFT',
    'layoutFit': 'contain',
    'minInteriorPages': 20,
    'maxInteriorPages': 80,
    'pageMultiple': 2,
    'pageCount': hard ? 80 : 20,
    'spineMm': hard ? 29.2 : 7.22,
    'geometrySource': 'LOCAL FIXTURE ONLY; no vendor sample approval',
    if (hard)
      'interior': {'trimWidthMm': 300, 'trimHeightMm': 300, 'bleedMm': 5},
    if (hard)
      'cover': {
        'construction': 'casewrap',
        'bleedMm': 20,
        'widthMm': 681.2,
        'heightMm': 346,
        'back': {'xMm': 20, 'yMm': 20, 'widthMm': 306, 'heightMm': 306},
        'front': {'xMm': 355.2, 'yMm': 20, 'widthMm': 306, 'heightMm': 306},
        'trim': {'xMm': 20, 'yMm': 20, 'widthMm': 641.2, 'heightMm': 306},
      },
  };
  return {
    'snapshot': snapshot,
    'spec': spec,
    'sourceUrls': <String, String>{},
    'sourceFingerprint': 'fixture-derived-by-server-test',
    'fixtureScenario': scenario,
    'fixtureOnly': true,
    'productionApproved': false,
  };
}

bool _bundleArtwork(String source) {
  final path = source.startsWith('asset:') ? source.substring(6) : source;
  return RegExp(
        r'^assets/(?:cover|sticker|templates|frame_preview|catalog_thumbnails)/[A-Za-z0-9_./ -]+\.(?:png|jpe?g|webp)$',
        caseSensitive: false,
      ).hasMatch(path) &&
      !path
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..') &&
      !path.contains(r'\');
}

/// A local engine process renders only the server-frozen purchased document.
/// It never receives Supabase/PortOne/Redprinting credentials. Its signed URL
/// map is temporary and may address only this project's private album artwork.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('render immutable paid album with the actual app canvas', (
    tester,
  ) async {
    await tester.runAsync(() async {
      try {
        final fixture =
            Platform.environment['SNAPFIT_WORKER_FIXTURE'] == 'true';
        final outputPath = Platform.environment['SNAPFIT_RENDER_OUTPUT'];
        if (outputPath == null || !outputPath.startsWith('/')) {
          throw StateError('print_renderer_output_required');
        }
        final output = Directory(outputPath);
        if (!output.existsSync())
          throw StateError('print_renderer_output_required');
        Map<String, dynamic> input;
        const fixtureArtworkSource =
            'supabase://album-assets/11111111-1111-4111-8111-111111111111/generated-test-card.png';
        if (fixture) {
          input = syntheticWorkerFixture(
            Platform.environment['SNAPFIT_WORKER_FIXTURE_SCENARIO'] ??
                'SOFT_20',
            fixtureArtworkSource,
          );
          final artwork =
              Platform.environment['SNAPFIT_WORKER_FIXTURE_ARTWORK'] ??
              (input['fixtureScenario'] == 'HARD_80' ? 'compact' : 'standard');
          if (artwork != 'compact' && artwork != 'standard') {
            throw StateError('print_fixture_artwork_invalid');
          }
          input['fixtureArtwork'] = artwork;
        } else {
          final path = Platform.environment['SNAPFIT_RENDER_INPUT'];
          if (path == null || !path.startsWith('/')) {
            throw StateError('print_renderer_input_required');
          }
          final file = File(path);
          if (file.lengthSync() > 30 * 1024 * 1024) {
            throw StateError('print_renderer_input_too_large');
          }
          input = (jsonDecode(file.readAsStringSync()) as Map)
              .cast<String, dynamic>();
        }
        final snapshot = (input['snapshot'] as Map).cast<String, dynamic>();
        final spec = PrintVendorSpec.fromJson(
          (input['spec'] as Map).cast<String, dynamic>(),
        );
        final urls = (input['sourceUrls'] as Map).cast<String, String>();
        final signedValues = urls.values.toSet();
        final origin = fixture
            ? null
            : Uri.parse(input['supabaseOrigin'] as String);
        if (!fixture &&
            (origin!.scheme != 'https' ||
                !RegExp(r'^[a-z0-9]+\.supabase\.co$').hasMatch(origin.host) ||
                origin.hasPort ||
                origin.userInfo.isNotEmpty)) {
          throw StateError('print_renderer_origin_invalid');
        }
        final card = fixture
            ? input['fixtureArtwork'] == 'compact'
                  ? await compactWorkerTestCard()
                  : await generatedSampleTestCard()
            : null;
        var downloaded = 0;
        final started = DateTime.now();
        final result = await HttpOverrides.runWithHttpOverrides(() async {
          final client = HttpClient()
            ..connectionTimeout = const Duration(seconds: 15);
          try {
            return await AlbumPrintExporter(
              loadOnlyUsedFonts: true,
              assetLoader: (source) async {
                if (fixture) {
                  if (source != fixtureArtworkSource) {
                    throw StateError('print_fixture_asset_not_allowed');
                  }
                  return card!;
                }
                if (_bundleArtwork(source)) {
                  final path = source.startsWith('asset:')
                      ? source.substring(6)
                      : source;
                  final data = await rootBundle.load(path);
                  return data.buffer.asUint8List(
                    data.offsetInBytes,
                    data.lengthInBytes,
                  );
                }
                if (!signedValues.contains(source)) {
                  throw StateError('print_renderer_asset_not_allowed');
                }
                final uri = Uri.parse(source);
                if (uri.scheme != 'https' ||
                    uri.host != origin!.host ||
                    uri.hasPort ||
                    uri.userInfo.isNotEmpty ||
                    !uri.path.startsWith(
                      '/storage/v1/object/sign/album-assets/',
                    ) ||
                    uri.queryParameters['token']?.isEmpty != false) {
                  throw StateError('print_renderer_asset_not_allowed');
                }
                final request = await client.getUrl(uri);
                request.followRedirects = false;
                final response = await request.close().timeout(
                  const Duration(seconds: 30),
                );
                if (response.statusCode != 200 ||
                    response.contentLength > 60 * 1024 * 1024) {
                  throw StateError('print_renderer_asset_download_failed');
                }
                final bytes = BytesBuilder(copy: false);
                await for (final chunk in response.timeout(
                  const Duration(seconds: 45),
                )) {
                  downloaded += chunk.length;
                  bytes.add(chunk);
                  if (bytes.length > 60 * 1024 * 1024 ||
                      downloaded > 1024 * 1024 * 1024) {
                    throw StateError('print_renderer_asset_limit');
                  }
                }
                return bytes.takeBytes();
              },
            ).generate(snapshot: snapshot, spec: spec, sourceUrls: urls);
          } finally {
            client.close(force: true);
          }
        }, _RealHttp());
        if (fixture) {
          File('${output.path}/fixture-render-metrics.json').writeAsStringSync(
            jsonEncode({
              'fixtureOnly': true,
              'scenario': input['fixtureScenario'],
              'artworkProfile': input['fixtureArtwork'],
              'pageCount': result.interiorPageCount,
              'sourceInteriorPages': result.report['sourceInteriorPages'],
              'blankPagesAdded': result.report['blankPagesAdded'],
              'elapsedMs': DateTime.now().difference(started).inMilliseconds,
              'coverBytes': result.coverPdf.length,
              'interiorBytes': result.interiorPdf.length,
              'maximumFileBytes': 100 * 1024 * 1024,
              'productionApproved': false,
              'physicalSampleValidated': false,
            }),
            flush: true,
          );
        }
        if (result.coverPdf.length > 100 * 1024 * 1024 ||
            result.interiorPdf.length > 100 * 1024 * 1024) {
          throw StateError('print_pdf_too_large');
        }
        File(
          '${output.path}/cover.pdf',
        ).writeAsBytesSync(result.coverPdf, flush: true);
        File(
          '${output.path}/interior.pdf',
        ).writeAsBytesSync(result.interiorPdf, flush: true);
        File('${output.path}/manifest.json').writeAsStringSync(
          jsonEncode({
            ...result.report,
            'sourceFingerprint': input['sourceFingerprint'],
          }),
          flush: true,
        );
        if (fixture) {
          File('${output.path}/fixture.json').writeAsStringSync(
            jsonEncode({
              'snapshot': snapshot,
              'spec': input['spec'],
              'scenario': input['fixtureScenario'],
              'artworkProfile': input['fixtureArtwork'],
              'fixtureOnly': true,
              'productionApproved': false,
              'physicalSampleValidated': false,
            }),
          );
        }
        expect(result.report['missingAssets'], isEmpty);
        expect(result.interiorPageCount, spec.pageCount);
      } catch (error) {
        if (Platform.environment['SNAPFIT_WORKER_FIXTURE'] == 'true') {
          final path = Platform.environment['SNAPFIT_RENDER_OUTPUT'];
          final raw = error is PrintPreflightException
              ? error.code
              : error is StateError
              ? error.message.toString()
              : error is FormatException
              ? error.message
              : 'renderer_test_failure';
          final code = RegExp(r'^[a-z0-9_]{1,80}$').hasMatch(raw)
              ? raw
              : 'renderer_test_failure';
          if (path != null && Directory(path).existsSync()) {
            File('$path/fixture-render-failure.json').writeAsStringSync(
              jsonEncode({
                'fixtureOnly': true,
                'errorCode': code,
                'productionApproved': false,
                'physicalSampleValidated': false,
              }),
              flush: true,
            );
          }
        }
        rethrow;
      }
    });
  }, timeout: const Timeout(Duration(minutes: 15)));
}
