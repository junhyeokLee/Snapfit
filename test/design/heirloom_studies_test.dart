import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/template_catalog_categories.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import '../../tool/template_studio/heirloom_preview.dart';
import '../widget/ai_album_start_step_test.dart'
    show loadCreationFonts, wrapCreation;
import '../widget/studio_decorations_test.dart' show capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCreationFonts();
    for (final f in [
      ('Eulyoo', 'Eulyoo1945-Regular.ttf'),
      ('BookMyungjo', 'BookkMyungjo_Bold.ttf'),
      ('Cormorant Garamond', 'Cormorant-Regular.ttf'),
    ]) {
      await (FontLoader(
        f.$1,
      )..addFont(rootBundle.load('assets/fonts/${f.$2}'))).load();
    }
  });
  test(
    'seven topics have isolated premium studies, never paid store entries',
    () {
      expect(premiumStudyEntries.map((e) => e.category), templateTopicOrder);
      expect(premiumStudyEntries.map((e) => e.id).toSet().length, 7);
      expect(authoredCollections.length, 37);
      expect(heirloomDecorations.length, 6);
      expect(studioDecorations, containsAll(heirloomDecorations));
      for (final study in HeirloomStudy.values) {
        expect(
          bundledCreationTemplates.any((t) => t.title == study.title),
          false,
        );
        final doc = study.document(CollectionAspect.square);
        expect(doc['qualityBaseline'], 'luminous-edition:8');
        expect(doc['catalogPublishable'], false);
        expect(doc['intendedTier'], 'premium');
        expect(doc['accessTier'], 'unassigned');
        expect(doc['aiGenerated'], false);
        expect(
          heirloomCopyFits(study, study.defaultCopy),
          true,
          reason: study.id,
        );
        expect(
          heirloomCopyFits(
            study,
            const EditorialCopy(place: '', period: '', byline: '', note: ''),
          ),
          false,
        );
      }
    },
  );
  test('approved baseline artwork is immutable and full edition is gated', () {
    for (final entry in premiumStudyEntries) {
      for (final aspect in CollectionAspect.values) {
        final approved =
            jsonDecode(
                  File(
                    'tool/template_studio/archives/approved-category-studies/${entry.id}/${aspect.name}.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final current =
            entry.study?.document(aspect) ?? buildLuminousEdition(aspect);
        for (final key in ['cover', 'pages', 'chapters']) {
          expect(
            current[key],
            approved[key],
            reason: '${entry.id}/${aspect.name}/$key',
          );
        }
        expect(current['approvalStatus'], 'approved-design-study');
      }
    }
    for (final aspect in CollectionAspect.values) {
      final baseline = templateDocumentPages(
        HeirloomStudy.wedding.document(aspect),
      );
      final doc = buildVowKeepsakeEdition(aspect);
      final full = templateDocumentPages(doc);
      expect(doc['catalogPublishable'], false);
      expect(doc['approvalStatus'], 'extension-awaiting-review');
      expect(doc['approvedBaselinePageMap'], [0, 1, 2, 3, 4, 5, 6, 19, 20]);
      expect((doc['releaseGates'] as Map)['price'], 'unset');
      expect(
        heirloomCopyFits(
          HeirloomStudy.wedding,
          HeirloomStudy.wedding.defaultCopy,
          fullEdition: true,
        ),
        true,
      );
      expect(full.take(7), baseline.take(7));
      for (var oldPage = 7; oldPage <= 8; oldPage++) {
        final actual = full[oldPage + 12], expected = baseline[oldPage];
        final a = actual['layers'] as List, e = expected['layers'] as List;
        expect(a.length, e.length);
        final layers = <Map<String, dynamic>>[];
        for (var i = 0; i < a.length; i++) {
          expect(
            a[i]['id'],
            startsWith('vow-keepsake_${aspect.name}_${oldPage + 12}_'),
          );
          layers.add({
            ...Map<String, dynamic>.from(a[i]),
            'id': e[i]['id'],
            if ((a[i]['id'] as String).endsWith('_folio')) 'text': e[i]['text'],
          });
        }
        expect({
          ...actual,
          'name': expected['name'],
          'spreadIndex': expected['spreadIndex'],
          'layers': layers,
        }, expected);
      }
    }
  });
  test('24 to 36 page volumes preserve artwork, endings and release gates', () {
    Map<String, dynamic> artwork(Map<String, dynamic> page) => {
      ...page,
      'name': '',
      'side': '',
      'spreadIndex': 0,
      'layers': [
        for (final layer in page['layers'] as List)
          if ((layer['id'] as String).endsWith('_folio'))
            {...Map<String, dynamic>.from(layer), 'text': ''}
          else
            layer,
      ],
    };
    for (final volume in PremiumVolume.values) {
      expect(volume.pageCounts.first, 24);
      expect(volume.extendedPages, isIn([24, 32, 36]));
      expect(
        () => volume.document(CollectionAspect.square, innerPages: 22),
        throwsArgumentError,
      );
      for (final aspect in CollectionAspect.values) {
        final base = volume == PremiumVolume.travel
            ? buildLuminousEdition(aspect)
            : volume == PremiumVolume.wedding
            ? buildVowKeepsakeEdition(aspect)
            : volume.study!.document(aspect);
        final baseline = templateDocumentPages(base);
        final minimum = volume.document(aspect, innerPages: 24);
        for (final count in volume.pageCounts) {
          final doc = volume.document(aspect, innerPages: count);
          final pages = templateDocumentPages(doc);
          expect(pages.length, count + 1);
          expect(doc['innerPageCount'], count);
          expect(doc['approvedAt'], '2026-09-09');
          expect(doc['catalogPublishable'], false);
          expect(doc['approvalStatus'], 'approved-volume-design');
          expect(doc['accessTier'], 'premium');
          expect((doc['releaseGates'] as Map)['extensionDesign'], 'approved');
          expect(
            (doc['releaseGates'] as Map)['price'],
            'launch-price-set-sale-held',
          );
          final map = (doc['baselinePageMap'] as List).cast<int>();
          expect(map.length, baseline.length);
          expect(map.last, count);
          expect(map[map.length - 2], count - 1);
          final approvedMap = (doc['approvedBaselinePageMap'] as List)
              .cast<int>();
          expect(approvedMap.length, 9);
          expect(approvedMap, [
            for (final index
                in (base['approvedBaselinePageMap'] as List?) ??
                    List<int>.generate(9, (i) => i))
              map[index as int],
          ]);
          expect(approvedMap.last, count);
          for (var i = 0; i < baseline.length; i++) {
            expect(
              artwork(pages[map[i]]),
              artwork(baseline[i]),
              reason: '${volume.id}/$count/$aspect/baseline$i',
            );
          }
          final byRole = {for (final p in pages) p['role']: p};
          for (final p in templateDocumentPages(minimum)) {
            expect(
              artwork(byRole[p['role']]!),
              artwork(p),
              reason: '${volume.id}/$count preserves minimum ${p['role']}',
            );
          }
          for (final entry in (doc['chapters'] as List).indexed) {
            expect(entry.$2['from'], entry.$1 * 2 + 1);
            expect(entry.$2['to'], entry.$1 * 2 + 2);
          }
          expect((doc['chapters'] as List).length, count ~/ 2);
        }
      }
    }
  });
  for (final edition in [
    for (final s in HeirloomStudy.values)
      (id: s.id, count: 8, document: (CollectionAspect a) => s.document(a)),
    (
      id: 'vow-keepsake-20',
      count: 20,
      document: (CollectionAspect a) => buildVowKeepsakeEdition(a),
    ),
    for (final v in PremiumVolume.values)
      for (final count in v.pageCounts)
        (
          id: '${v.id}-$count',
          count: count,
          document: (CollectionAspect a) => v.document(a, innerPages: count),
        ),
  ]) {
    final editionId = edition.id;
    for (final aspect in CollectionAspect.values) {
      testWidgets(
        '$editionId/${aspect.name}: composition, text, slots and export',
        (tester) async {
          final doc = edition.document(aspect);
          final raw = templateDocumentPages(doc);
          final issues = <String>[];
          final ids = <String>{};
          final photoCounts = <int>{}, compositions = <String>{};
          final captures = <ui.Image>[];
          expect(raw.length, edition.count + 1);
          expect(raw.map((p) => p['role']).toSet().length, raw.length);
          for (final entry in raw.indexed) {
            final page = entry.$2;
            expect(
              page['side'],
              entry.$1 == 0
                  ? 'cover'
                  : entry.$1.isOdd
                  ? 'left'
                  : 'right',
            );
            expect(page['spreadIndex'], (entry.$1 + 1) ~/ 2);
            final layers = DataTemplateEngine.buildLayersFromJson(
              page,
              aspect.canvas,
            );
            final prepared = AlbumCreationTemplate.preparePages(
              [layers],
              sourceCanvas: aspect.canvas,
              cover: aspect.cover,
            ).single;
            final photos = layers
                .where((l) => l.type == LayerType.image)
                .toList();
            photoCounts.add(photos.length);
            compositions.add(
              photos
                  .map(
                    (l) =>
                        '${l.position}:${l.width}:${l.height}:${l.imageBackground}',
                  )
                  .join('|'),
            );
            if (entry.$1 == 0) {
              expect(photos.length, 1);
              expect(photos.single.position, Offset.zero);
              expect(
                Size(photos.single.width, photos.single.height),
                aspect.canvas,
              );
            }
            for (final e in layers.indexed) {
              final l = e.$2, r = l.position & Size(l.width, l.height);
              if (!ids.add(l.id)) issues.add('duplicate ${l.id}');
              if (r.left < -.1 ||
                  r.top < -.1 ||
                  r.right > aspect.canvas.width + .1 ||
                  r.bottom > aspect.canvas.height + .1)
                issues.add('${l.id}: bounds $r');
              final restored = LayerExportMapper.fromJson(
                LayerExportMapper.toJson(l, canvasSize: aspect.canvas),
                canvasSize: aspect.canvas,
              );
              expect(restored.text, l.text);
              if (l.type == LayerType.image) {
                expect(prepared[e.$1].imageUrl, isNull);
                expect(restored.imageBackground, l.imageBackground);
                expect(
                  File(l.imageUrl!.replaceFirst('asset:', '')).existsSync(),
                  true,
                );
              }
              if (l.type != LayerType.text) continue;
              final text = TextPainter(
                text: TextSpan(text: l.text, style: l.textStyle),
                textDirection: TextDirection.ltr,
                strutStyle: StrutStyle.fromTextStyle(
                  l.textStyle!,
                  forceStrutHeight: true,
                ),
              )..layout(maxWidth: l.width);
              if (text.height > l.height + .5)
                issues.add('${l.id}: text ${text.height} > ${l.height}');
              text.dispose();
              for (final other in layers.where(
                (o) => o.type == LayerType.image || o.type == LayerType.text,
              )) {
                if (other.id == l.id ||
                    !r
                        .deflate(.5)
                        .overlaps(
                          (other.position & Size(other.width, other.height))
                              .deflate(.5),
                        ))
                  continue;
                final source = (page['layers'] as List).singleWhere(
                  (item) => item['id'] == l.id,
                );
                final coverOverlay =
                    entry.$1 == 0 &&
                    other.type == LayerType.image &&
                    source['overlayImageId'] == other.id &&
                    l.zIndex > other.zIndex;
                if (!coverOverlay) issues.add('${l.id} overlaps ${other.id}');
              }
            }
            for (final l in page['layers'] as List) {
              final spec =
                  studioDecorationById(
                    l['style'] is String ? l['style'] : '',
                  ) ??
                  studioDecorationByAsset(
                    (l['imageUrl'] as String?)?.replaceFirst('asset:', ''),
                  );
              if (spec == null) continue;
              expect(
                l['w'] * aspect.canvas.width / (l['h'] * aspect.canvas.height),
                closeTo(spec.aspectRatio, .00001),
              );
            }
            captures.add(
              await capture(
                tester,
                TemplatePageRenderer(
                  layers: layers,
                  width: 360,
                  height: 360 / aspect.canvas.aspectRatio,
                  designCanvasSize: aspect.canvas,
                  preserveTypography: true,
                  showCanvasChrome: false,
                ),
              ),
            );
          }
          expect(photoCounts.length, greaterThanOrEqualTo(2));
          expect(compositions.length, greaterThanOrEqualTo(6));
          if (const bool.fromEnvironment('EXPORT_EDITION')) {
            await tester.runAsync(() async {
              final dir = Directory(
                'output/template-preview/$editionId/${aspect.name}',
              );
              await dir.create(recursive: true);
              Future<void> png(ui.Image i, String name) async =>
                  File('${dir.path}/$name.png').writeAsBytes(
                    (await i.toByteData(
                      format: ui.ImageByteFormat.png,
                    ))!.buffer.asUint8List(),
                  );
              for (final page in captures.indexed) {
                await png(page.$2, 'page-${page.$1}');
              }
              final w = captures.first.width, h = captures.first.height;
              final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
              canvas.drawColor(const Color(0xFFE2E7E4), BlendMode.src);
              canvas.drawImage(captures.first, Offset.zero, Paint());
              for (var n = 1; n < captures.length; n += 2) {
                final rec = ui.PictureRecorder(), spreadCanvas = Canvas(rec);
                spreadCanvas.drawImage(captures[n], Offset.zero, Paint());
                spreadCanvas.drawImage(
                  captures[n + 1],
                  Offset(w.toDouble(), 0),
                  Paint(),
                );
                final picture = rec.endRecording(),
                    spread = await picture.toImage(w * 2, h);
                await png(spread, 'spread-${(n + 1) ~/ 2}');
                canvas.drawImage(
                  spread,
                  Offset(0, ((n + 1) ~/ 2) * (h + 12.0)),
                  Paint(),
                );
                spread.dispose();
                picture.dispose();
              }
              for (var first = 1; first < captures.length; first += 6) {
                final rec = ui.PictureRecorder(), review = Canvas(rec);
                final remaining = (captures.length - first).clamp(0, 6);
                for (var i = 0; i < remaining; i++) {
                  review.drawImage(
                    captures[first + i],
                    Offset((i % 2) * w.toDouble(), (i ~/ 2) * (h + 12.0)),
                    Paint(),
                  );
                }
                final picture = rec.endRecording();
                final band = await picture.toImage(
                  w * 2,
                  ((remaining + 1) ~/ 2) * (h + 12),
                );
                await png(band, 'review-${(first - 1) ~/ 6 + 1}');
                band.dispose();
                picture.dispose();
              }
              final pic = recorder.endRecording(),
                  contact = await pic.toImage(
                    w * 2,
                    (h + 12) * ((captures.length + 1) ~/ 2),
                  );
              await png(contact, 'contact');
              contact.dispose();
              pic.dispose();
              await File(
                '${dir.path}/document.json',
              ).writeAsString(jsonEncode(doc));
            });
          }
          for (final image in captures) {
            image.dispose();
          }
          expect(issues, isEmpty);
        },
      );
    }
  }
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('$size: premium catalog topics and saved filters', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final previous = CatalogFavorites.instance;
      CatalogFavorites.instance = CatalogFavorites();
      addTearDown(() {
        CatalogFavorites.instance.dispose();
        CatalogFavorites.instance = previous;
      });
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(wrapCreation(const PremiumStudiesCatalog()));
      await tester.pumpAndSettle();
      expect(find.text('14종'), findsOneWidget);
      for (final element in find.byType(TemplatePageRenderer).evaluate()) {
        final renderer = element.widget as TemplatePageRenderer;
        final renderedSize = tester.getSize(find.byWidget(renderer));
        expect(renderer.width, closeTo(renderedSize.width, .01));
        expect(renderer.height, closeTo(renderedSize.height, .01));
      }
      await tester.tap(find.byType(ChoiceChip).at(1));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('template:vow-keepsake')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('template:luminous-edition')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('favorite-template:vow-keepsake')),
      );
      await tester.pumpAndSettle();
      expect(CatalogFavorites.instance.contains('template:vow-keepsake'), true);
      expect(tester.takeException(), isNull);
    });
  }
}
