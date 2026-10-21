import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

const _emitImages = bool.fromEnvironment('WIND_ATLAS_MEMORY_IMAGES');
const _selected = [0, 3, 4, 7, 8, 13, 14];
const _pairs = [
  [0],
  [3, 4],
  [7, 8],
  [13, 14],
];
const _longCopy = EditorialCopy(
  place: '포르투에서 리스본까지, 여름의 작은 마을들',
  period: '2026년 6월 12일 — 2026년 6월 18일',
  byline: '수연과 지후 / OUR SUMMER JOURNAL',
  note:
      '기차에서 내리자 바다 냄새가 먼저 났다. 짐을 맡기고 골목으로 나갔다. '
      '지도에 표시해 둔 길을 지나쳐도 괜찮았다. 작은 가게에서 물을 사고, '
      '광장 그늘에 앉아 돌아갈 시간을 한 번 미뤘다.\n\n'
      '그날의 사진에는 파란 창문과 흰 벽이 남았다. 사진 밖에는 커피가 식는 동안 '
      '나눈 이야기와, 서로 다른 속도로 걷다가 다시 나란해진 발걸음이 있었다. '
      '이 기록을 읽으면 그 길부터 떠올리고 싶다.',
);
const _emptyCopy = EditorialCopy(place: '', period: '', byline: '', note: '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'signature cover and facing spreads render in RAM with real fonts',
    (tester) async {
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = const Size(1600, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final summaries = <Map<String, Object?>>[];
      for (final aspect in CollectionAspect.values) {
        summaries.add(
          await _inspect(tester, aspect, 'authored', windAtlasCopy),
        );
        summaries.add(await _inspect(tester, aspect, 'long-copy', _longCopy));
        summaries.add(await _inspect(tester, aspect, 'empty-copy', _emptyCopy));
      }
      // Existing local samples exercise portrait, group, dark and ordinary
      // landscape crops. They are samples, never customer photographs.
      for (final sample in const {
        'people': 'assets/templates/original_editorial/images/couple_walk.png',
        'portrait':
            'assets/templates/scrapbook/images/sources/city_weekend.png',
        'group':
            'assets/templates/original_editorial/images/family_friends.png',
        'dark':
            'assets/templates/original_editorial/images/cover_friends_evening.png',
        'landscape':
            'assets/templates/jeju_travel/images/sources/jeju_ocean.jpg',
      }.entries) {
        summaries.add(
          await _inspect(
            tester,
            CollectionAspect.square,
            sample.key,
            windAtlasCopy,
            replacement: sample.value,
          ),
        );
      }
      // This is a stdout protocol. Image-enabled output MUST be consumed in RAM,
      // never redirected to a file. No filesystem or export API is imported.
      // ignore: avoid_print
      print('SNAPFIT_WIND_ATLAS_METRICS_V1:${jsonEncode(summaries)}');
    },
  );
}

Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.whereType<Map>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).whereType<Map>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<Map<String, Object?>> _inspect(
  WidgetTester tester,
  CollectionAspect aspect,
  String name,
  EditorialCopy copy, {
  String? replacement,
}) async {
  final document = buildWindAtlas(aspect, copy: copy);
  final raw = templateDocumentPages(document);
  final pages = {
    for (final index in _selected)
      index: DataTemplateEngine.buildLayersFromJson(raw[index], aspect.canvas),
  };
  var textCount = 0, photoCount = 0, decoded = 0;
  for (final page in pages.entries) {
    for (final layer in page.value) {
      if (layer.type == LayerType.text) {
        textCount++;
        final painter = TextPainter(
          text: TextSpan(text: layer.text, style: layer.textStyle),
          textAlign: layer.textAlign ?? TextAlign.left,
          textDirection: TextDirection.ltr,
          strutStyle: StrutStyle.fromTextStyle(
            layer.textStyle!,
            forceStrutHeight: true,
          ),
        )..layout(maxWidth: layer.width);
        expect(
          painter.height,
          lessThanOrEqualTo(layer.height + .5),
          reason: '$name/${aspect.name}/${layer.id}: ${layer.text}',
        );
        expect(
          painter.computeLineMetrics().every(
            (l) => l.width <= layer.width + .5,
          ),
          isTrue,
          reason: '$name/${aspect.name}/${layer.id}: width overflow',
        );
        painter.dispose();
      }
      if (layer.type == LayerType.image) photoCount++;
    }
  }
  for (final pair in _pairs) {
    final captures = <ui.Image>[];
    try {
      for (final index in pair) {
        final result = await _capture(
          tester,
          aspect,
          pages[index]!,
          replacement,
        );
        captures.add(result.image);
        decoded += result.decoded;
      }
      if (_emitImages &&
          (name == 'authored' || aspect == CollectionAspect.square)) {
        final sheet = (await tester.runAsync(() => _join(captures)))!;
        try {
          await tester.runAsync(() async {
            final bytes = (await sheet.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            // ignore: avoid_print
            print(
              'SNAPFIT_MEMORY_IMAGE_V1:${jsonEncode({'id': 'wind-atlas-${aspect.name}-$name-${pair.join('-')}', 'mimeType': 'image/png', 'width': sheet.width, 'height': sheet.height, 'base64': base64Encode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))})}',
            );
          });
        } finally {
          sheet.dispose();
        }
      }
    } finally {
      for (final image in captures) image.dispose();
    }
  }
  return {
    'aspect': aspect.name,
    'case': name,
    'pages': _selected,
    'textCount': textCount,
    'photoCount': photoCount,
    'decodedImages': decoded,
    'textOverflow': 0,
  };
}

Future<({ui.Image image, int decoded})> _capture(
  WidgetTester tester,
  CollectionAspect aspect,
  List<LayerModel> layers,
  String? replacement,
) async {
  const width = 480.0;
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSans'),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: TemplatePageRenderer(
              layers: layers,
              width: width,
              height: width / aspect.canvas.aspectRatio,
              designCanvasSize: aspect.canvas,
              preserveTypography: true,
              normalizeToContentBounds: false,
              showCanvasChrome: false,
              imageDecodeWidth: 1200,
              photoBuilder: replacement == null
                  ? null
                  : (layer, _) => Image.asset(
                      replacement,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      cacheWidth: 1200,
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  final images = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
  expect(
    images.length,
    greaterThanOrEqualTo(layers.where((l) => l.type == LayerType.image).length),
  );
  expect(images.every((i) => i.image != null), isTrue);
  expect(tester.takeException(), isNull);
  final image = (await tester.runAsync(
    () => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
        .toImage(),
  ))!;
  return (image: image, decoded: images.length);
}

Future<ui.Image> _join(List<ui.Image> images) async {
  final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFF6F2E9), BlendMode.src);
  var x = 0.0;
  for (final image in images) {
    canvas.drawImage(image, Offset(x, 0), Paint());
    x += image.width;
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(x.round(), images.first.height);
  } finally {
    picture.dispose();
  }
}
