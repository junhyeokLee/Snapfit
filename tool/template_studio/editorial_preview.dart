import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'lightbound_preview.dart';

List<List<LayerModel>> editorialPreviewPages(
  EditorialVolume volume,
  CollectionAspect aspect,
  EditorialCopy copy, {
  bool photos = true,
}) => templateDocumentPages(volume.document(aspect, copy: copy))
    .map(
      (page) => DataTemplateEngine.buildLayersFromJson(page, aspect.canvas)
          .map(
            (layer) => !photos && layer.type == LayerType.image
                ? layer.copyWith(clearImage: true)
                : layer,
          )
          .toList(),
    )
    .toList();

bool editorialCopyFits(EditorialVolume volume, EditorialCopy copy) {
  for (final aspect in CollectionAspect.values) {
    for (final layer in editorialPreviewPages(
      volume,
      aspect,
      copy,
    ).expand((p) => p)) {
      if (layer.type != LayerType.text) continue;
      final painter = TextPainter(
        text: TextSpan(text: layer.text, style: layer.textStyle),
        textDirection: TextDirection.ltr,
        strutStyle: StrutStyle.fromTextStyle(
          layer.textStyle!,
          forceStrutHeight: true,
        ),
      )..layout(maxWidth: layer.width);
      final fits = painter.height <= layer.height + .5;
      painter.dispose();
      if (!fits) return false;
    }
  }
  return true;
}

class EditorialPreview extends StatelessWidget {
  const EditorialPreview({super.key, required this.volume});
  final EditorialVolume volume;
  @override
  Widget build(BuildContext context) => AuthoredDraftPreview<EditorialCopy>(
    title: volume.title,
    chapters: volume.chapters,
    initialCopy: volume.defaultCopy,
    buildPages: (aspect, copy, photos) =>
        editorialPreviewPages(volume, aspect, copy, photos: photos),
    copySheet: (copy) => EditorialCopySheet(
      copy: copy,
      placeLabel: volume == EditorialVolume.journey ? '여행지' : '기록의 계절',
      validateCopy: (next) => editorialCopyFits(volume, next),
    ),
  );
}

class EditorialCopySheet extends StatefulWidget {
  const EditorialCopySheet({
    super.key,
    required this.placeLabel,
    required this.copy,
    required this.validateCopy,
  });
  final String placeLabel;
  final bool Function(EditorialCopy) validateCopy;
  final EditorialCopy copy;
  @override
  State<EditorialCopySheet> createState() => _EditorialCopySheetState();
}

class _EditorialCopySheetState extends State<EditorialCopySheet> {
  final _form = GlobalKey<FormState>();
  late final _place = TextEditingController(text: widget.copy.place);
  late final _period = TextEditingController(text: widget.copy.period);
  late final _byline = TextEditingController(text: widget.copy.byline);
  late final _note = TextEditingController(text: widget.copy.note);
  String? _error;

  @override
  void dispose() {
    for (final controller in [_place, _period, _byline, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    final copy = EditorialCopy(
      place: _place.text.trim(),
      period: _period.text.trim(),
      byline: _byline.text.trim(),
      note: _note.text.trim(),
    );
    if (!widget.validateCopy(copy)) {
      setState(() => _error = '문구가 페이지 여백을 넘어요. 글자 수나 줄바꿈을 줄여 주세요.');
      return;
    }
    Navigator.of(context).pop(copy);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: math
          .min(
            650.0,
            MediaQuery.sizeOf(context).height * .9 -
                MediaQuery.viewInsetsOf(context).bottom,
          )
          .clamp(100.0, 650.0),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '앨범 문구',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '문구 적용',
                    onPressed: _apply,
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Form(
                  key: _form,
                  child: Column(
                    children: [
                      for (final field in [
                        (_place, widget.placeLabel, 24),
                        (_period, '기록 기간', 28),
                        (_byline, '기록한 사람', 16),
                      ])
                        TextFormField(
                          controller: field.$1,
                          maxLength: field.$3,
                          decoration: InputDecoration(labelText: field.$2),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? '내용을 입력해 주세요.'
                              : null,
                        ),
                      TextFormField(
                        controller: _note,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: 220,
                        decoration: const InputDecoration(
                          labelText: '마지막 페이지의 기록',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? '기록을 입력해 주세요.'
                            : null,
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
