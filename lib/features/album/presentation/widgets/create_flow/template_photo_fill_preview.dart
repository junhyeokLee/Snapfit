import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../shared/web/web_design.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import '../../../domain/entities/layer.dart';
import 'creation_workspace.dart';
import 'template_photo_fill_plan.dart';
import '../../../../../shared/widgets/experience_icon.dart';

Future<bool?> showTemplatePhotoFillPreview(
  BuildContext context, {
  required TemplatePhotoFillPlan plan,
  required List<List<LayerModel>> pages,
  required Size canvas,
  required Map<String, File> files,
  required bool preserveTypography,
  required bool Function() isCurrent,
  required void Function(BuildContext) onOpened,
  List<Color?>? pageBackgroundColors,
}) => showWebAwareDialog<bool>(
  context: context,
  maxWidth: 1000,
  maxHeight: 840,
  builder: (previewContext) {
    onOpened(previewContext);
    return TemplatePhotoFillPreview(
      plan: plan,
      pages: pages,
      canvas: canvas,
      pageBackgroundColors: pageBackgroundColors,
      files: files,
      preserveTypography: preserveTypography,
      isCurrent: isCurrent,
    );
  },
);

class TemplatePhotoFillPreview extends StatefulWidget {
  const TemplatePhotoFillPreview({
    super.key,
    required this.plan,
    required this.pages,
    required this.canvas,
    required this.files,
    required this.preserveTypography,
    required this.isCurrent,
    this.pageBackgroundColors,
  });

  final TemplatePhotoFillPlan plan;
  final List<List<LayerModel>> pages;
  final Size canvas;
  final Map<String, File> files;
  final bool preserveTypography;
  final bool Function() isCurrent;
  final List<Color?>? pageBackgroundColors;

  @override
  State<TemplatePhotoFillPreview> createState() =>
      _TemplatePhotoFillPreviewState();
}

class _TemplatePhotoFillPreviewState extends State<TemplatePhotoFillPreview> {
  late int _page = widget.plan.placements.first.page;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: math.min(840, MediaQuery.sizeOf(context).height * .92),
    child: Material(
      key: const ValueKey('photo-fill-batch-preview'),
      color: ExperienceFormStyle.surface(context),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final stageHeight = (bounds.maxHeight - 240).clamp(160.0, 460.0);
            final pagePlacements = widget.plan.placements
                .where((placement) => placement.page == _page)
                .length;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '순서대로 담아봤어요',
                              style: ExperienceFormStyle.text(
                                context,
                                21,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '미리보기 닫기',
                            onPressed: () => Navigator.pop(context, false),
                            icon: const ExperienceIcon('X'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '고른 사진 ${widget.plan.placements.length}장을 빈 칸에 담았어요. 적용 전에 넘겨보세요.',
                        style: ExperienceFormStyle.text(
                          context,
                          13,
                          secondary: true,
                        ).copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: stageHeight,
                        child: CreationPaperStage(
                          inset: 12,
                          child: FittedBox(
                            child: TemplatePageRenderer(
                              key: ValueKey('photo-fill-batch-page-$_page'),
                              layers: widget.pages[_page],
                              backgroundColor:
                                  widget.pageBackgroundColors != null &&
                                      _page <
                                          widget.pageBackgroundColors!.length
                                  ? widget.pageBackgroundColors![_page]
                                  : null,
                              width: widget.canvas.width,
                              height: widget.canvas.height,
                              designCanvasSize: widget.canvas,
                              localFiles: {
                                for (final layer in widget.pages[_page])
                                  if (widget.files['$_page:${layer.id}']
                                      case final file?)
                                    layer.id: file,
                              },
                              preserveTypography: widget.preserveTypography,
                              showCanvasChrome: false,
                              cacheNetworkImages: true,
                              imageDecodeWidth: 1200,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            key: const ValueKey('photo-fill-batch-previous'),
                            tooltip: '이전 페이지',
                            onPressed: _page == 0
                                ? null
                                : () => setState(() => _page--),
                            icon: const ExperienceIcon('ChevronLeft'),
                          ),
                          Expanded(
                            child: Text(
                              '${_page == 0 ? '표지' : '$_page쪽'} · '
                              '${pagePlacements == 0 ? '기존 구성' : '사진 $pagePlacements장 채움'}',
                              textAlign: TextAlign.center,
                              style: ExperienceFormStyle.text(context, 12),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('photo-fill-batch-next'),
                            tooltip: '다음 페이지',
                            onPressed: _page == widget.pages.length - 1
                                ? null
                                : () => setState(() => _page++),
                            icon: const ExperienceIcon('ChevronRight'),
                          ),
                        ],
                      ),
                      Text(
                        [
                          if (widget.plan.remainingEmptySlots > 0)
                            '빈 칸 ${widget.plan.remainingEmptySlots}개는 나중에 채울 수 있어요.',
                          if (widget.plan.remainingPhotos.isNotEmpty)
                            '남은 사진 ${widget.plan.remainingPhotos.length}장은 선택한 사진에 그대로 둬요.',
                          '기존 사진과 구도는 그대로예요. 새 사진의 구도는 적용 후 조정할 수 있어요.',
                        ].join('\n'),
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ).copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          key: const ValueKey('photo-fill-batch-cancel'),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          key: const ValueKey('photo-fill-batch-apply'),
                          style: CreationStyle.primary(context),
                          onPressed: () =>
                              Navigator.pop(context, widget.isCurrent()),
                          child: Text(
                            '사진 ${widget.plan.placements.length}장 채우기',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
