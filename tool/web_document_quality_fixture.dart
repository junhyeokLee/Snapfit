// Isolated browser QA entrypoint. No application main, account, DB or upload.
// Build with SNAPFIT_DEFER_DOCUMENT_FONTS=true and the normal web packager.
// ?mode=eager is used only when the harness supplies the complete engine font
// manifest, to compare the same frozen sample artwork with deferred startup.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snap_fit/core/fonts/document_font_gate.dart';
import 'package:snap_fit/core/fonts/document_fonts.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/social/data/social_album_snapshot.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

@JS('__snapfitDocumentQuality')
external set _browserReport(JSAny? value);

const _photoAsset =
    'assets/templates/wedding_editorial/images/approved_stock/bouquet_hand.jpg';
const _photoSource = 'asset:$_photoAsset';
const _coverFonts = ['Eulyoo', 'Cormorant Garamond', 'Figma Hand'];

String _hash(List<int> bytes) => sha256.convert(bytes).toString();
String _jsonHash(Object? value) => _hash(utf8.encode(jsonEncode(value)));
Uint8List _bytes(ByteData data) =>
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

Map<String, dynamic> _text(
  String id,
  String text,
  String family,
  double y, {
  double size = .055,
  int weight = 3,
}) => {
  'id': id,
  'type': 'TEXT',
  'x': .08,
  'y': y,
  'width': .84,
  'height': .12,
  'scale': 1,
  'rotation': 0,
  'zIndex': 2,
  'opacity': 1,
  'payload': {
    'text': text,
    'textAlign': 'center',
    'textStyle': {
      'fontFamily': family,
      'fontSizeRatio': size,
      'fontWeight': weight,
      'color': '#FF19383E',
      'height': 1.12,
      'letterSpacing': .2,
    },
  },
};

Map<String, dynamic> _photo(String id, {double rotation = 0}) => {
  'id': id,
  'type': 'IMAGE',
  'x': .08,
  'y': .30,
  'width': .84,
  'height': .49,
  'scale': 1,
  'rotation': rotation,
  'zIndex': 1,
  'opacity': 1,
  'payload': {
    'originalUrl': _photoSource,
    'previewUrl': _photoSource,
    'imageBackground': 'round',
    'imageOffsetRatio': {'x': .12, 'y': -.04},
  },
};

Map<String, dynamic> _snapshot() => {
  'album': {
    'ratio': '1',
    'cover_layers_json': jsonEncode({
      'pages': [
        {
          'index': 0,
          'isCover': true,
          'backgroundColor': 0xFFF1F8F5,
          'layers': [
            _text('title', '우리의 평범한 하루', 'Eulyoo', .055, size: .064),
            _text(
              'latin',
              'SnapFit — our everyday',
              'Cormorant Garamond',
              .18,
              size: .046,
              weight: 7,
            ),
            _photo('cover-photo', rotation: 7),
            _text('hand', '한 장씩 남긴 우리의 기록', 'Figma Hand', .84, size: .05),
          ],
        },
        {
          'index': 1,
          'isCover': false,
          'backgroundColor': 0xFFFFF7EC,
          'layers': [
            _text('run', '사진과 함께 기억하는 날', 'Run', .06, size: .052, weight: 6),
            _photo('inner-photo', rotation: -6),
            _text(
              'hand-alias',
              '가나다 한글 한 / AV fi ffi',
              'FigmaHand',
              .84,
              size: .048,
            ),
          ],
        },
        {
          'index': 2,
          'isCover': false,
          'backgroundColor': 0xFFE9F7FA,
          'layers': [
            _text(
              'book',
              '오래 보고 싶은 순간',
              'BookMyungjo',
              .09,
              size: .056,
              weight: 7,
            ),
            _photo('last-photo'),
            _text('noto', '저장된 위치와 글자 크기를 그대로', 'NotoSans', .85, size: .038),
          ],
        },
      ],
    }),
  },
  'pages': <Map<String, dynamic>>[],
};

// Deliberately small local fixture stock, at the production encoder's 300dpi.
// This proves PDF/font/photo behavior, not a real product/vendor specification.
PrintVendorSpec _spec() => PrintVendorSpec.fromJson({
  'id': 'isolated-browser-font-quality-20mm',
  'specVersion': 'fixture-only-v1',
  'verified': false,
  'dpi': 300,
  'minimumPhotoPpi': 100,
  'colorSpace': 'sRGB',
  'pageCount': 2,
  'minInteriorPages': 2,
  'maxInteriorPages': 80,
  'pageMultiple': 2,
  'interior': {'trimWidthMm': 20, 'trimHeightMm': 20, 'bleedMm': 1},
  'cover': {
    'widthMm': 45,
    'heightMm': 22,
    'back': {'xMm': 1, 'yMm': 1, 'widthMm': 20, 'heightMm': 20},
    'front': {'xMm': 24, 'yMm': 1, 'widthMm': 20, 'heightMm': 20},
  },
});

Map<String, dynamic> _geometry(PrintAlbumDocument document) => {
  for (final page in document.pages)
    '${page.index}': {
      'canvas': [page.canvasSize.width, page.canvasSize.height],
      'layers': [
        for (final layer in page.layers)
          {
            'id': layer.id,
            'type': layer.type.name,
            'position': [layer.position.dx, layer.position.dy],
            'size': [layer.width, layer.height],
            'scale': layer.scale,
            'rotation': layer.rotation,
            'opacity': layer.opacity,
            'photoOffset': [layer.imageOffset?.dx, layer.imageOffset?.dy],
            'original': layer.originalUrl,
            'text': layer.text,
            'font': layer.textStyle?.fontFamily,
            'fontSize': layer.textStyle?.fontSize,
            'fontWeight': layer.textStyle?.fontWeight?.value,
          },
      ],
    },
};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'NotoSans'),
      home: const _QualityFixture(),
    ),
  );
}

class _QualityFixture extends StatefulWidget {
  const _QualityFixture();
  @override
  State<_QualityFixture> createState() => _QualityFixtureState();
}

class _QualityFixtureState extends State<_QualityFixture> {
  final _snapshotValue = _snapshot();
  late final PrintAlbumDocument _document;
  final _errors = <String>[];
  final _artifacts = <String, String>{};
  final _proof = <String, dynamic>{};
  ui.Image? _photoImage;
  String _phase = 'Interface first frame';
  bool _showGate = false, _gateMounted = false, _gateMountedBeforeReady = false;
  bool _done = false, _passed = false;
  void Function(FlutterErrorDetails)? _previousErrorHandler;

  @override
  void initState() {
    super.initState();
    _document = PrintAlbumDocument.fromSnapshot(_snapshotValue);
    _previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      _errors.add(details.exceptionAsString());
      _previousErrorHandler?.call(details);
    };
    _browserReport = {'done': false, 'phase': _phase}.jsify();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  void _progress(String phase) {
    if (mounted) setState(() => _phase = phase);
    _browserReport = {'done': false, 'phase': phase}.jsify();
  }

  Future<Map<String, dynamic>> _capture(
    Widget child,
    Size size,
    String name,
  ) async {
    final image = await renderPrintWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.noScaling),
          child: Theme(
            data: ThemeData(useMaterial3: true, fontFamily: 'NotoSans'),
            child: ColoredBox(
              color: _document.cover.backgroundColor,
              child: child,
            ),
          ),
        ),
      ),
      size,
      1,
    );
    try {
      final rgba = _bytes(
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
      );
      final png = _bytes(
        (await image.toByteData(format: ui.ImageByteFormat.png))!,
      );
      _artifacts['$name.png'] = base64Encode(png);
      return {
        'pixelSha': _hash(rgba),
        'pngSha': _hash(png),
        'width': image.width,
        'height': image.height,
      };
    } finally {
      image.dispose();
    }
  }

  Widget _layerCanvas() => PrintAlbumPageCanvas(
    page: _document.cover,
    images: {_photoSource: _photoImage!},
  );

  Widget _templateCanvas() => TemplatePageRenderer(
    layers: _document.cover.layers,
    width: _document.cover.canvasSize.width,
    height: _document.cover.canvasSize.height,
    designCanvasSize: _document.cover.canvasSize,
    preserveTypography: true,
    normalizeToContentBounds: false,
    photoBuilder: (_, __) => RawImage(
      image: _photoImage,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    ),
  );

  Future<void> _run() async {
    final originalSnapshotHash = _jsonHash(_snapshotValue);
    final originalGeometryHash = _jsonHash(_geometry(_document));
    try {
      if (!DocumentFonts.deferred)
        throw StateError('Build this fixture with deferred fonts enabled');
      final eager = Uri.base.queryParameters['mode'] == 'eager';
      if (eager) {
        // The harness, never production, supplies the full engine manifest.
        for (final entry in DocumentFonts.sourceDeclarations) {
          DocumentFonts.markLoaded(entry['family'] as String);
        }
      }
      _proof.addAll({
        'mode': eager ? 'eager' : 'deferred',
        'documentFontsDeferred': DocumentFonts.deferred,
        'coverFontsReadyBeforeGate': DocumentFonts.areReady(_coverFonts),
        'snapshotShaBefore': originalSnapshotHash,
        'geometryShaBefore': originalGeometryHash,
      });
      _progress('Loading the original bundled sample photo');
      final source = _bytes(await rootBundle.load(_photoAsset));
      final codec = await ui.instantiateImageCodec(source);
      try {
        _photoImage = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      _proof['originalPhoto'] = {
        'asset': _photoAsset,
        'bytes': source.length,
        'sha': _hash(source),
        'width': _photoImage!.width,
        'height': _photoImage!.height,
      };

      _progress('Waiting for the real document font gate');
      setState(() => _showGate = true);
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (!_gateMounted) {
        if (DateTime.now().isAfter(deadline))
          throw StateError('Font gate did not mount artwork');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await WidgetsBinding.instance.endOfFrame;
      _proof['gateMountedBeforeReady'] = _gateMountedBeforeReady;
      _proof['coverFontsReadyAfterGate'] = DocumentFonts.areReady(_coverFonts);
      _proof['layerBeforeAll'] = await _capture(
        _layerCanvas(),
        _document.cover.canvasSize,
        'layer-before-all',
      );
      _proof['templateBeforeAll'] = await _capture(
        _templateCanvas(),
        _document.cover.canvasSize,
        'template-before-all',
      );

      _progress('Real print verification and two-page PDF generation');
      _proof['printOnlyFontReadyBeforeExport'] = DocumentFonts.areReady(const [
        'Run',
      ]);
      final reads = <String>[];
      Future<Uint8List> loadOriginal(String sourceName) async {
        reads.add(sourceName);
        if (sourceName != _photoSource)
          throw StateError('Unexpected external photo: $sourceName');
        return source;
      }

      final exporter = AlbumPrintExporter(
        assetLoader: loadOriginal,
        loadOnlyUsedFonts: true,
      );
      final preflight = await exporter.verify(
        snapshot: _snapshotValue,
        spec: _spec(),
      );
      final exported = await exporter.generate(
        snapshot: _snapshotValue,
        spec: _spec(),
      );
      if (!ascii
          .decode(exported.coverPdf.take(8).toList())
          .startsWith('%PDF-1.')) {
        throw StateError('No real cover PDF was generated');
      }
      _artifacts['cover.pdf'] = base64Encode(exported.coverPdf);
      _artifacts['interior.pdf'] = base64Encode(exported.interiorPdf);
      _proof['print'] = {
        'preflight': preflight,
        'report': exported.report,
        'interiorPageCount': exported.interiorPageCount,
        'coverPdfSha': _hash(exported.coverPdf),
        'coverPdfBytes': exported.coverPdf.length,
        'interiorPdfSha': _hash(exported.interiorPdf),
        'interiorPdfBytes': exported.interiorPdf.length,
        'requestedPhotoSources': reads,
        'printOnlyFontReadyAfterExport': DocumentFonts.areReady(const ['Run']),
      };

      _progress('Real publication snapshot with a separately deferred font');
      final publicationSnapshot =
          jsonDecode(jsonEncode(_snapshotValue)) as Map<String, dynamic>;
      final album = publicationSnapshot['album'] as Map<String, dynamic>;
      final publicationJson = (album['cover_layers_json'] as String)
          .replaceFirst('Eulyoo', 'HanSans');
      album['cover_layers_json'] = publicationJson;
      final publication = PrintAlbumDocument.fromSnapshot(publicationSnapshot);
      final renderer = SocialSnapshotRenderer(loader: loadOriginal);
      _proof['publicationOnlyFontReadyBeforePrepare'] = DocumentFonts.areReady(
        const ['HanSans'],
      );
      await renderer.prepareFonts(publication.pages);
      final publicationPng = await renderer.renderPage(
        publication.cover,
        theme: ThemeData(useMaterial3: true, fontFamily: 'NotoSans'),
      );
      _artifacts['publication.png'] = base64Encode(publicationPng);
      final publicationCodec = await ui.instantiateImageCodec(publicationPng);
      try {
        final publicationImage = (await publicationCodec.getNextFrame()).image;
        try {
          _proof['publication'] = {
            'pngSha': _hash(publicationPng),
            'pixelSha': _hash(
              _bytes(
                (await publicationImage.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!,
              ),
            ),
            'width': publicationImage.width,
            'height': publicationImage.height,
            'fontReadyAfterPrepare': DocumentFonts.areReady(const ['HanSans']),
          };
        } finally {
          publicationImage.dispose();
        }
      } finally {
        publicationCodec.dispose();
      }

      _progress(
        'Preparing all edit fonts and checking unchanged saved artwork',
      );
      await DocumentFonts.ensureAll();
      _proof['allFontsReadyForEditing'] = DocumentFonts.allReady;
      _proof['layerAfterAll'] = await _capture(
        _layerCanvas(),
        _document.cover.canvasSize,
        'layer-after-all',
      );
      _proof['templateAfterAll'] = await _capture(
        _templateCanvas(),
        _document.cover.canvasSize,
        'template-after-all',
      );
      _proof['snapshotShaAfter'] = _jsonHash(_snapshotValue);
      _proof['geometryShaAfter'] = _jsonHash(_geometry(_document));
      _proof['sourceSnapshotUnchanged'] =
          originalSnapshotHash == _proof['snapshotShaAfter'];
      _proof['savedGeometryUnchanged'] =
          originalGeometryHash == _proof['geometryShaAfter'];
      final layerBefore = _proof['layerBeforeAll'] as Map;
      final layerAfter = _proof['layerAfterAll'] as Map;
      final templateBefore = _proof['templateBeforeAll'] as Map;
      final templateAfter = _proof['templateAfterAll'] as Map;
      _proof['layerPixelsUnchangedAfterAllFonts'] =
          layerBefore['pixelSha'] == layerAfter['pixelSha'];
      _proof['templatePixelsUnchangedAfterAllFonts'] =
          templateBefore['pixelSha'] == templateAfter['pixelSha'];
      _passed =
          !_gateMountedBeforeReady &&
          _proof['sourceSnapshotUnchanged'] == true &&
          _proof['savedGeometryUnchanged'] == true &&
          _proof['layerPixelsUnchangedAfterAllFonts'] == true &&
          _proof['templatePixelsUnchangedAfterAllFonts'] == true &&
          exported.interiorPageCount == 2 &&
          DocumentFonts.allReady &&
          _errors.isEmpty;
      _phase = _passed
          ? 'Document quality checks passed'
          : 'Document quality check failed';
    } catch (error, stack) {
      _errors.add('$error\n$stack');
      _phase = 'Document quality check failed';
    } finally {
      _showGate = false;
      _done = true;
      if (mounted) setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      _photoImage?.dispose();
      _photoImage = null;
      _browserReport = {
        'done': true,
        'passed': _passed,
        'phase': _phase,
        'proof': _proof,
        'errors': _errors,
        'artifacts': _artifacts,
        'isolated': {
          'databaseAccess': false,
          'authenticationAccess': false,
          'customerDataUsed': false,
          'photoUploads': false,
          'printSpec':
              'Local 20mm, 300dpi, two-page fixture stock; not a product/vendor validation',
        },
      }.jsify();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('SnapFit · isolated document quality proof'),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_phase, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text(
            'Frozen sample album · original bundled photo · no account or server writes',
          ),
          const SizedBox(height: 20),
          if (_showGate && _photoImage != null)
            SizedBox.fromSize(
              size: _document.cover.canvasSize,
              child: DocumentFontGate(
                families: _coverFonts,
                placeholder: const Center(child: CircularProgressIndicator()),
                builder: (_) {
                  _gateMounted = true;
                  _gateMountedBeforeReady |= !DocumentFonts.areReady(
                    _coverFonts,
                  );
                  return _layerCanvas();
                },
              ),
            ),
          if (_done)
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                for (final name in [
                  'layer-after-all.png',
                  'template-after-all.png',
                  'publication.png',
                ])
                  if (_artifacts[name] case final String value)
                    SizedBox(
                      width: 330,
                      child: Column(
                        children: [
                          Text(name),
                          const SizedBox(height: 8),
                          Image.memory(
                            base64Decode(value),
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          if (_errors.isNotEmpty)
            Text(_errors.join('\n'), style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    FlutterError.onError = _previousErrorHandler;
    super.dispose();
  }
}
