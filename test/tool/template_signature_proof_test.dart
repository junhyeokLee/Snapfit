import 'dart:convert';
import 'dart:io';
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
import '../widget/ai_album_start_step_test.dart' show wrapCreation;

const _stock = 'assets/templates/jeju_travel/images/approved_stock/';
// Existing bundled samples, not photographs captured on a user's phone.
const _editorial = 'assets/templates/original_editorial/images/';
const _replacementPhotos = {
  '웨딩': [
    'assets/templates/wedding_editorial/images/approved_stock/ceremony_group.jpg',
    'assets/templates/wedding_editorial/images/approved_stock/bouquet_hand.jpg',
    'assets/templates/wedding_editorial/images/approved_stock/closing_shadow.jpg',
  ],
  '여행': [
    '${_stock}arrival_station.jpg',
    '${_stock}road_window.jpg',
    '${_stock}sunset_people.jpg',
  ],
  '일상': [
    'assets/frame_preview/quiet_room.jpg',
    'assets/frame_preview/artist_palette.jpg',
    '${_editorial}daily_fruit.png',
  ],
  '성장·육아': [
    'assets/templates/soft_babybook/images/approved_stock/field_baby.jpg',
    'assets/templates/soft_babybook/images/approved_stock/parent_back.jpg',
    'assets/templates/soft_babybook/images/approved_stock/book_bed.jpg',
  ],
  '가족·친구': [
    '${_editorial}family_kitchen.png',
    '${_editorial}family_friends.png',
    '${_editorial}family_table.png',
  ],
  '커플·기념일': [
    'assets/templates/save_the_date/images/approved_stock/closing_couple.jpg',
    '${_stock}cafe_detail.jpg',
    'assets/templates/save_the_date/images/approved_stock/hands_flowers.jpg',
  ],
  '반려동물': [
    '${_editorial}pet_rest.png',
    '${_editorial}pet_cat.png',
    'assets/frame_preview/forest_trail.jpg',
  ],
};
const _freeExamples = [
  FreeCollectionVolume.garden,
  FreeCollectionVolume.postcards,
  FreeCollectionVolume.objects,
  FreeCollectionVolume.firstYear,
  FreeCollectionVolume.familyTable,
  FreeCollectionVolume.dateFilm,
  FreeCollectionVolume.walkClub,
];
const _spreads = [6, 6, 9, 14, 13, 8, 14];

List<Map<String, dynamic>> _replace(
  List<Map<String, dynamic>> pages,
  List<String> photos,
) {
  var slot = 0;
  return [
    for (final page in pages)
      {
        ...page,
        'layers': [
          for (final raw in (page['layers'] as List).cast<Map>())
            <String, dynamic>{
              ...raw,
              if (raw['type'] == 'image')
                'imageUrl': 'asset:${photos[slot++ % photos.length]}',
            },
        ],
      },
  ];
}

Future<ui.Image> _captureSpread(
  WidgetTester tester,
  List<Map<String, dynamic>> pages,
  CollectionAspect aspect,
) async {
  final key = GlobalKey();
  const width = 1000.0;
  final height = width / 2 / aspect.canvas.aspectRatio;
  for (final page in pages) {
    expect(
      DataTemplateEngine.buildLayersFromJson(page, aspect.canvas),
      isNotEmpty,
    );
  }
  await tester.pumpWidget(
    wrapCreation(
      Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: width,
            height: height,
            child: Row(
              children: [
                for (final page in pages)
                  Expanded(
                    child: FittedBox(
                      child: TemplatePageRenderer(
                        layers: DataTemplateEngine.buildLayersFromJson(
                          page,
                          aspect.canvas,
                        ),
                        width: aspect.canvas.width,
                        height: aspect.canvas.height,
                        designCanvasSize: aspect.canvas,
                        preserveTypography: true,
                        imageDecodeWidth: 1000,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      Object? error;
      await precacheImage(
        (element.widget as Image).image,
        element,
        onError: (e, _) => error = e,
      );
      expect(error, isNull);
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  late ui.Image image;
  await tester.runAsync(() async {
    image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
  });
  await tester.pumpWidget(const SizedBox());
  return image;
}

Future<void> _save(ui.Image image, String path) async {
  final rgba = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  var visible = 0;
  for (var i = 3; i < rgba.length; i += 4 * 107) {
    if (rgba[i] > 240) visible++;
  }
  expect(
    visible,
    greaterThan(image.width * image.height / 107 * .8),
    reason: '$path must not be an empty proof',
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
}

Future<void> _verifyPhotoReplacement(
  ui.Image before,
  ui.Image after,
  List<Map<String, dynamic>> pages,
  CollectionAspect aspect,
) async {
  final a = (await before.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final b = (await after.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  expect(after.width, before.width);
  expect(after.height, before.height);
  var sampled = 0, changed = 0;
  final scaleX = before.width / 2 / aspect.canvas.width;
  final scaleY = before.height / aspect.canvas.height;
  for (final entry in pages.indexed) {
    final layers = DataTemplateEngine.buildLayersFromJson(
      entry.$2,
      aspect.canvas,
    );
    for (final photo in layers.where((l) => l.type == LayerType.image)) {
      final region =
          Rect.fromLTWH(
            entry.$1 * before.width / 2 +
                (photo.position.dx + photo.width * .2) * scaleX,
            (photo.position.dy + photo.height * .2) * scaleY,
            photo.width * .6 * scaleX,
            photo.height * .6 * scaleY,
          ).intersect(
            Rect.fromLTWH(
              0,
              0,
              before.width.toDouble(),
              before.height.toDouble(),
            ),
          );
      for (var y = region.top.ceil(); y < region.bottom; y += 5) {
        for (var x = region.left.ceil(); x < region.right; x += 5) {
          sampled++;
          final i = (y * before.width + x) * 4;
          final difference =
              (a[i] - b[i]).abs() +
              (a[i + 1] - b[i + 1]).abs() +
              (a[i + 2] - b[i + 2]).abs();
          if (difference > 24) changed++;
        }
      }
    }
  }
  expect(sampled, greaterThan(100));
  expect(
    changed,
    greaterThan(sampled * .05),
    reason:
        'replacement must change actual photograph pixels, not only preserve opaque paper',
  );
}

void main() {
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });
  testWidgets(
    'native free and premium compositions survive bundled snapshot replacement',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final output = Directory('output/premium-atelier-qa')
        ..createSync(recursive: true);
      final books = <String, dynamic>{};
      for (final entry in AtelierEdition.values.indexed) {
        final index = entry.$1,
            edition = entry.$2,
            free = _freeExamples[entry.$1];
        final spread = _spreads[index];
        final photos = _replacementPhotos[edition.category]!;
        books[edition.id] = {
          'freeTitle': free.title,
          'freeId': free.id,
          'spread': spread,
        };
        for (final aspect in CollectionAspect.values) {
          final premiumPages = templateDocumentPages(
            edition.document(aspect),
          ).skip(spread * 2 - 1).take(2).toList();
          final freePages = templateDocumentPages(
            free.document(aspect),
          ).skip(1).take(2).toList();
          final premium = await _captureSpread(
            tester,
            _replace(premiumPages, photos),
            aspect,
          );
          final basic = await _captureSpread(
            tester,
            _replace(freePages, photos),
            aspect,
          );
          final freeOriginal = await _captureSpread(tester, freePages, aspect);
          final premiumOriginal = await _captureSpread(
            tester,
            premiumPages,
            aspect,
          );
          await tester.runAsync(() async {
            await _verifyPhotoReplacement(
              freeOriginal,
              basic,
              freePages,
              aspect,
            );
            await _verifyPhotoReplacement(
              premiumOriginal,
              premium,
              premiumPages,
              aspect,
            );
            await _save(
              premium,
              '${output.path}/${edition.id}-${aspect.name}-replacement.png',
            );
            await _save(
              basic,
              '${output.path}/${edition.id}-${aspect.name}-free-replacement.png',
            );
            await _save(
              freeOriginal,
              '${output.path}/${edition.id}-${aspect.name}-free-example.png',
            );
            final recorder = ui.PictureRecorder(),
                size = Size(2080, premium.height + 110.0);
            final canvas = Canvas(recorder)
              ..drawColor(const Color(0xFFF2F5F4), BlendMode.src);
            void label(String value, double x) {
              final text = TextPainter(
                textDirection: TextDirection.ltr,
                text: TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 24,
                    color: Color(0xFF20312D),
                    letterSpacing: 0,
                  ),
                ),
              )..layout(maxWidth: 1000);
              text.paint(canvas, Offset(x, 22));
              text.dispose();
            }

            label('무료 / ${free.title}', 24);
            label('유료 후보 / ${edition.title}', 1056);
            canvas.drawImage(basic, const Offset(24, 78), Paint());
            canvas.drawImage(premium, const Offset(1056, 78), Paint());
            final picture = recorder.endRecording();
            final comparison = await picture.toImage(
              size.width.toInt(),
              size.height.toInt(),
            );
            await _save(
              comparison,
              '${output.path}/${edition.id}-${aspect.name}-replacement-comparison.png',
            );
            comparison.dispose();
            picture.dispose();
          });
          premium.dispose();
          premiumOriginal.dispose();
          basic.dispose();
          freeOriginal.dispose();
        }
      }
      final review = {
        'revision': '2026-10-16-signature-typography',
        'nativeRenderer': true,
        'physicalDeviceValidated': false,
        'printProofComplete': false,
        'replacementSources': _replacementPhotos,
        'replacementSourceType':
            'existing-bundled-samples-not-user-phone-captures',
        'freeHeadingsRefined': 32,
        'freeBaselineBooksPreserved': 5,
        'premiumFrameStylesAdded': 7,
        'replacementChangesPhotoPixels': true,
        'actualSalesActivated': false,
        'books': books,
      };
      File(
        '${output.path}/signature-review.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(review));
      File(
        '${output.path}/signature-data.js',
      ).writeAsStringSync('const signatureProofData = ${jsonEncode(books)};\n');
    },
    skip: !const bool.fromEnvironment('EXPORT_SIGNATURE_PROOF'),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
