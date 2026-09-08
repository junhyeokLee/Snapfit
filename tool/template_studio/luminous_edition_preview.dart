import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'lightbound_preview.dart';
import 'prose_comparison.dart';
import 'luminous_materials.dart';

List<List<LayerModel>> luminousPages(
  CollectionAspect aspect, {
  LuminousCopy copy = const LuminousCopy(),
  bool photos = true,
}) => templateDocumentPages(buildLuminousEdition(aspect, copy: copy))
    .map(
      (p) => DataTemplateEngine.buildLayersFromJson(p, aspect.canvas)
          .map(
            (l) => !photos && l.type == LayerType.image
                ? l.copyWith(clearImage: true)
                : l,
          )
          .toList(),
    )
    .toList();

bool luminousCopyFits(LuminousCopy copy) {
  if ([copy.first, copy.second, copy.third].any((v) => v.trim().isEmpty))
    return false;
  for (final aspect in CollectionAspect.values) {
    for (final l in luminousPages(aspect, copy: copy).expand((p) => p)) {
      if (l.type != LayerType.text) continue;
      final painter = TextPainter(
        text: TextSpan(text: l.text, style: l.textStyle),
        textDirection: TextDirection.ltr,
        strutStyle: StrutStyle.fromTextStyle(
          l.textStyle!,
          forceStrutHeight: true,
        ),
      )..layout(maxWidth: l.width);
      final fits = painter.height <= l.height + .5;
      painter.dispose();
      if (!fits) return false;
    }
  }
  return true;
}

class LuminousEditionPreview extends StatelessWidget {
  const LuminousEditionPreview({super.key});
  @override
  Widget build(BuildContext context) => AuthoredDraftPreview<LuminousCopy>(
    title: luminousEditionTitle,
    chapters: luminousEditionSpreads,
    editionLabel: '유료 후보 · 미등록',
    initialCopy: const LuminousCopy(),
    buildPages: (aspect, copy, photos) =>
        luminousPages(aspect, copy: copy, photos: photos),
    copySheet: (copy) => LuminousCopySheet(copy: copy),
    extraControls: [
      IconButton(
        tooltip: '꾸밈 재료',
        icon: const Icon(Icons.auto_awesome_mosaic_outlined),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LuminousMaterials()),
        ),
      ),
      IconButton(
        tooltip: '무료와 비교',
        icon: const Icon(Icons.compare_outlined),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProseComparison()),
        ),
      ),
      const CatalogFavoriteButton(
        itemKey: 'template:luminous-edition',
        label: luminousEditionTitle,
      ),
    ],
  );
}

class LuminousCopySheet extends StatefulWidget {
  const LuminousCopySheet({super.key, required this.copy});
  final LuminousCopy copy;
  @override
  State<LuminousCopySheet> createState() => _LuminousCopySheetState();
}

class _LuminousCopySheetState extends State<LuminousCopySheet> {
  late final fields = [
    widget.copy.first,
    widget.copy.second,
    widget.copy.third,
    widget.copy.names,
    widget.copy.date,
  ].map((v) => TextEditingController(text: v)).toList();
  String? error;
  @override
  void dispose() {
    for (final f in fields) {
      f.dispose();
    }
    super.dispose();
  }

  void apply() {
    final copy = LuminousCopy(
      first: fields[0].text.trim(),
      second: fields[1].text.trim(),
      third: fields[2].text.trim(),
      names: fields[3].text.trim(),
      date: fields[4].text.trim(),
    );
    if (!luminousCopyFits(copy)) {
      setState(() => error = '제목을 채우고 문구 길이를 확인해 주세요.');
      return;
    }
    Navigator.pop(context, copy);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: math.max(
        100,
        math.min(
          640,
          MediaQuery.sizeOf(context).height * .9 -
              MediaQuery.viewInsetsOf(context).bottom,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            ListTile(
              title: const Text('표제 편집'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '문구 적용',
                    onPressed: apply,
                    icon: const Icon(Icons.check_rounded),
                  ),
                  IconButton(
                    tooltip: '문구 편집 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  for (final e in [
                    '윗줄',
                    '아랫줄 앞',
                    '아랫줄 뒤',
                    '함께한 이름',
                    '날짜',
                  ].indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        controller: fields[e.$1],
                        maxLength: e.$1 < 3 ? 4 : 24,
                        decoration: InputDecoration(
                          labelText: e.$2,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
