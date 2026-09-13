import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_phrase_catalog.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/studio_phrase_picker.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';

const atelierSets = [
  (
    name: '보태니컬',
    photo: 'petal_couple',
    frame: 'studioOvalMat',
    phrase: 'vow-day',
    art: ['studioOlivePress', 'studioRoseSilk'],
  ),
  (
    name: '여행 기록',
    photo: 'travel_harbor',
    frame: 'studioPostcard',
    phrase: 'travel-place',
    art: ['studioCoastStamp', 'studioArchiveTag'],
  ),
  (
    name: '작은 축하',
    photo: 'growth_birthday',
    frame: 'studioDoubleMat',
    phrase: 'baby-first',
    art: ['studioGouacheCake', 'studioPaperRosette'],
  ),
  (
    name: '페이퍼 아카이브',
    photo: 'daily_desk',
    frame: 'studioPhotoCorners',
    phrase: 'daily-kept',
    art: ['studioBlueFibre', 'studioGlassineEnvelope'],
  ),
];

List<LayerModel> atelierPreviewLayers({
  required int set,
  required CollectionAspect aspect,
  required String frame,
  required StudioPhrase phrase,
  required String photo,
  String? decoration,
  String? customText,
}) {
  final c = aspect.canvas;
  final layers = <LayerModel>[];
  void art(String id, double x, double y, double width, {double rotation = 0}) {
    final spec = studioDecorationById(id)!;
    final w = math.min(
      c.width * width,
      c.height * (1 - y - .02) * spec.aspectRatio,
    );
    layers.add(
      LayerModel(
        id: 'art-$id',
        type: LayerType.sticker,
        position: Offset(c.width * x, c.height * y),
        width: w,
        height: w / spec.aspectRatio,
        imageUrl: 'asset:${spec.assetPath}',
        rotation: rotation,
        zIndex: layers.length,
      ),
    );
  }

  void image(double x, double y, double w, double h, {double rotation = 0}) {
    layers.add(
      LayerModel(
        id: 'photo',
        type: LayerType.image,
        position: Offset(c.width * x, c.height * y),
        width: c.width * w,
        height: c.height * h,
        imageUrl: 'asset:assets/templates/original_editorial/images/$photo.png',
        imageBackground: frame,
        rotation: rotation,
        zIndex: layers.length,
      ),
    );
  }

  void text(double x, double y, double w, double h) {
    final value = customText ?? phrase.text;
    var fontSize = phrase.lettering.size * 1.3;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: phrase.alignment,
    );
    while (fontSize > 8) {
      painter.text = TextSpan(
        text: value,
        style: phrase.lettering.style.copyWith(fontSize: fontSize),
      );
      painter.layout(maxWidth: c.width * w);
      if (painter.height <= c.height * h - 4) break;
      fontSize -= .5;
    }
    painter.dispose();
    layers.add(
      LayerModel(
        id: 'phrase',
        type: LayerType.text,
        text: value,
        position: Offset(c.width * x, c.height * y),
        width: c.width * w,
        height: c.height * h,
        textStyle: phrase.lettering.style.copyWith(fontSize: fontSize),
        textAlign: phrase.alignment,
        zIndex: layers.length,
      ),
    );
  }

  final ids = atelierSets[set].art;
  final lastArt = decoration ?? ids.last;
  switch (set) {
    case 0:
      image(.19, .26, .62, .55);
      art(ids.first, .62, .64, .29);
      art(lastArt, .04, .61, .28, rotation: -.09);
      text(.12, .055, .76, .19);
    case 1:
      image(.075, .28, .72, .52, rotation: -.025);
      art(ids.first, .72, .35, .22, rotation: .045);
      art(lastArt, .65, .66, .27, rotation: .035);
      text(.07, .06, .76, .2);
    case 2:
      image(.14, .09, .72, .5);
      art(ids.first, .04, .61, .28);
      art(lastArt, .74, .45, .22, rotation: .05);
      text(.33, .66, .6, .23);
    default:
      art(ids.first, .02, .08, .94, rotation: -.02);
      image(.15, .22, .72, .49, rotation: .025);
      art(lastArt, .66, .70, .27, rotation: -.035);
      text(.06, .77, .59, .19);
  }
  return layers;
}

class AtelierPreview extends StatefulWidget {
  const AtelierPreview({super.key});
  @override
  State<AtelierPreview> createState() => _AtelierPreviewState();
}

class _AtelierPreviewState extends State<AtelierPreview> {
  int _set = 0;
  CollectionAspect _aspect = CollectionAspect.portrait;
  String _frame = atelierSets.first.frame;
  StudioPhrase _phrase = studioPhrases.first;
  String? _decoration, _customText;
  bool _alternatePhoto = false;

  void _selectSet(int index) => setState(() {
    _set = index;
    _frame = atelierSets[index].frame;
    _phrase = studioPhrases.singleWhere(
      (p) => p.id == atelierSets[index].phrase,
    );
    _decoration = null;
    _customText = null;
    _alternatePhoto = false;
  });

  @override
  Widget build(BuildContext context) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: const Text('소재 스튜디오', style: TextStyle(fontSize: 17)),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '문구 수정',
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: () async {
              final controller = TextEditingController(
                text: _customText ?? _phrase.text,
              );
              final value = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('문구'),
                  content: TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 100,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('적용'),
                    ),
                  ],
                ),
              );
              // The dialog can remain mounted during its reverse transition.
              await Future<void>.delayed(const Duration(milliseconds: 250));
              controller.dispose();
              if (mounted && value != null && value.isNotEmpty)
                setState(() => _customText = value);
            },
          ),
          IconButton(
            tooltip: '스토어',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => Navigator.pushNamed(context, '/store'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (var i = 0; i < atelierSets.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(atelierSets[i].name),
                        selected: _set == i,
                        onSelected: (_) => _selectSet(i),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 700;
                  final photo = _alternatePhoto
                      ? [
                          'couple_walk',
                          'travel_street',
                          'growth_walk',
                          'family_friends',
                        ][_set]
                      : atelierSets[_set].photo;
                  final canvas = ColoredBox(
                    color: const Color(0xFFECEFED),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: _aspect.canvas.aspectRatio,
                                child: LayoutBuilder(
                                  builder: (context, box) => Semantics(
                                    image: true,
                                    label: '${atelierSets[_set].name} 조합 미리보기',
                                    child: RepaintBoundary(
                                      key: const ValueKey('atelier-artwork'),
                                      child: ColoredBox(
                                        color: const Color(0xFFFCFCFA),
                                        child: TemplatePageRenderer(
                                          width: box.maxWidth,
                                          height: box.maxHeight,
                                          designCanvasSize: _aspect.canvas,
                                          layers: atelierPreviewLayers(
                                            set: _set,
                                            aspect: _aspect,
                                            frame: _frame,
                                            phrase: _phrase,
                                            photo: photo,
                                            decoration: _decoration,
                                            customText: _customText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SegmentedButton<CollectionAspect>(
                                segments: [
                                  for (final aspect in CollectionAspect.values)
                                    ButtonSegment(
                                      value: aspect,
                                      label: SizedBox(
                                        width: 40,
                                        child: Text(
                                          switch (aspect) {
                                            CollectionAspect.portrait => '세로',
                                            CollectionAspect.square => '정사각',
                                            _ => '가로',
                                          },
                                          maxLines: 1,
                                          softWrap: false,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                                selected: {_aspect},
                                showSelectedIcon: false,
                                style: const ButtonStyle(
                                  textStyle: WidgetStatePropertyAll(
                                    TextStyle(fontSize: 12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onSelectionChanged: (value) =>
                                    setState(() => _aspect = value.single),
                              ),
                              IconButton(
                                tooltip: '사진 교체',
                                icon: const Icon(Icons.swap_horiz_rounded),
                                onPressed: () => setState(
                                  () => _alternatePhoto = !_alternatePhoto,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  final picker = DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: '프레임'),
                            Tab(text: '소재'),
                            Tab(text: '문구'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              CatalogFavoriteGrid<ImageFrameStyle>(
                                items: imageFrameStyles.sublist(1, 7),
                                keyOf: (frame) =>
                                    CatalogFavoriteKeys.frame(frame.key),
                                labelOf: (frame) => frame.label,
                                mainAxisExtent: 188,
                                itemBuilder: (context, frame) {
                                  return Semantics(
                                    button: true,
                                    selected: _frame == frame.key,
                                    label: '${frame.label} 적용',
                                    excludeSemantics: true,
                                    onTap: () =>
                                        setState(() => _frame = frame.key),
                                    child: Material(
                                      color: _frame == frame.key
                                          ? const Color(0xFFD9EEEA)
                                          : const Color(0xFFF1F3F2),
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () =>
                                            setState(() => _frame = frame.key),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            44,
                                            12,
                                            12,
                                          ),
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: StudioMaterial(
                                                  style: frame.key,
                                                  child: Image.asset(
                                                    'assets/templates/original_editorial/images/$photo.png',
                                                    fit: BoxFit.cover,
                                                    cacheWidth: 300,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                frame.label,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              CatalogFavoriteGrid<StudioDecorationSpec>(
                                items: atelierDecorations,
                                keyOf: (spec) => CatalogFavoriteKeys.decoration(
                                  spec.insertionValue,
                                ),
                                labelOf: (spec) => spec.label,
                                mainAxisExtent: 190,
                                itemBuilder: (context, spec) {
                                  return Semantics(
                                    button: true,
                                    label: '${spec.label} 적용',
                                    excludeSemantics: true,
                                    onTap: () =>
                                        setState(() => _decoration = spec.id),
                                    child: Material(
                                      color: const Color(0xFFF0F3F2),
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () => setState(
                                          () => _decoration = spec.id,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            44,
                                            12,
                                            12,
                                          ),
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: StudioDecoration(
                                                  spec: spec,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                spec.label,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              StudioPhrasePicker(
                                onSelect: (value) => setState(() {
                                  _phrase = value;
                                  _customText = null;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  return wide
                      ? Row(
                          children: [
                            Expanded(child: canvas),
                            SizedBox(width: 370, child: picker),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(flex: 5, child: canvas),
                            Expanded(flex: 4, child: picker),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
